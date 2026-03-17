async def get_auth0_userinfo(token: str, user_id: str = None) -> Dict[str, Any]:
    """
    Fetch user information from Auth0's userinfo endpoint with LRU caching.

    Args:
        token: The Auth0 access token
        user_id: The Auth0 user ID (for caching by user instead of token)

    Returns:
        User information dictionary or None if the request fails
    """
    # Use user_id for caching if provided, otherwise fall back to token
    cache_key = user_id if user_id else token

    # Check cache first
    cached_userinfo = userinfo_cache.get(cache_key)
    if cached_userinfo is not None:
        return cached_userinfo

    # Fetch user info from Auth0
    try:
        async with httpx.AsyncClient() as client:
            userinfo_url = f"https://{config.auth0.domain}/userinfo"
            headers = {"Authorization": f"Bearer {token}"}
            response = await client.get(userinfo_url, headers=headers)

            if response.status_code == 200:
                userinfo = response.json()
                logger.info("Successfully fetched user info from Auth0")

                # Cache the result using cache_key
                userinfo_cache.put(cache_key, userinfo)

                return userinfo
            else:
                logger.error(
                    f"Failed to fetch user info: {response.status_code} - {response.text}"
                )
                # if ratelimited
                if response.status_code == 429:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Failed to authenticate user. Please try again later.",
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail=f"Failed to fetch user info: {response.status_code} - {response.text}",
                    )
    except HTTPException:
        # Re-raise HTTPException as-is
        raise
    except Exception as e:
        logger.error(f"Error fetching user info: {str(e)}")
        return None


async def get_current_user(request: Request) -> AuthUser | None:
    """
    Dependency function that extracts and validates the JWT token from the Authorization header
    and returns the current authenticated user information.

    Args:
        request: FastAPI Request object

    Returns:
        AuthUser containing user information

    Raises:
        HTTPException: If token is invalid or user is not authenticated
    """
    # Get the authorization header
    auth_header = request.headers.get("Authorization")

    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Extract the token
    token = auth_header.replace("Bearer ", "")

    try:
        # Decode the token and extract user info
        payload = jwt.decode(
            token,
            algorithms=["RS256"],
            options={"verify_signature": False},  # Set to True in production
            audience=config.auth0.audience,
            issuer=f"https://{config.auth0.domain}/",
        )

        # Create a user info object with basic fields from the token
        user_info = {
            "id": payload.get("sub"),  # Auth0 user ID
            "permissions": payload.get("permissions", []),
            # "roles": payload.get(
            #     # "https://myapp.com/roles", []
            #     [],
            # ),  # Custom namespace for roles
            "roles": [],
        }

        # Fetch detailed user info from Auth0's userinfo endpoint using cached function
        try:
            userinfo = await get_auth0_userinfo(token, payload.get("sub"))
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Failed to authenticate user. Please try again later.",
            )

        if userinfo is not None:
            # Update user_info with data from userinfo endpoint
            user_info.update(
                {
                    "email": userinfo.get("email"),
                    "name": userinfo.get("name"),
                    "nickname": userinfo.get("nickname"),
                    "picture": userinfo.get("picture"),
                }
            )

        return AuthUser(**user_info)

    except jwt.PyJWTError as e:
        logger.error(f"JWT token error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )