from fastapi import APIRouter, Depends, Request, HTTPException, status
from services.user import UserService
from models.user import UserProfile
from dependencies import get_auth0_userinfo, get_user_service
from structlog import get_logger
import jwt
from settings import config
from dependencies import get_user_service

router = APIRouter(prefix="/user", tags=["user"])
logger = get_logger()

async def get_current_auth0_user_id(request: Request) -> str:
    """
    Extract and verify the Auth0 user ID from the request
    
    Args:
        request: FastAPI Request object
        
    Returns:
        Auth0 user ID (sub claim)
        
    Raises:
        HTTPException: If authentication fails
    """
    auth_header = request.headers.get("Authorization")

    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = auth_header.replace("Bearer ", "")

    try:
        # Decode the token to get user info
        payload = jwt.decode(
            token,
            algorithms=["RS256"],
            options={"verify_signature": False},
            audience=config.auth0.audience,
            issuer=f"https://{config.auth0.domain}/",
        )

        auth0_user_id = payload.get("sub")
        
        if not auth0_user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing sub claim",
            )

        return auth0_user_id

    except jwt.PyJWTError as e:
        logger.error(f"JWT token error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


@router.get("/me", response_model=UserProfile)
async def get_current_user_profile(
    request: Request,
    auth0_user_id: str = Depends(get_current_auth0_user_id),
    service: UserService = Depends(get_user_service),
) -> UserProfile:
    """
    Get the current authenticated user's profile
    
    Returns user information from the auth0.users schema, including:
    - Basic profile information (name, email, picture, etc.)
    - User roles (visitor, staff, admin)
    
    Requires a valid Auth0 bearer token in the Authorization header.
    
    If the user doesn't exist in the database yet, they will be automatically
    created with the 'visitor' role using information from the Auth0 token.
    """
    try:
        # Try to get existing user
        try:
            return await service.get_user_profile(auth0_user_id)
        except HTTPException as e:
            if e.status_code != 404:
                raise
            
            # User not found - create them from Auth0 userinfo
            logger.info(f"User not found in DB, creating from Auth0: {auth0_user_id}")
            
            # Extract token and get userinfo from Auth0
            auth_header = request.headers.get("Authorization", "")
            token = auth_header.replace("Bearer ", "")
            userinfo = await get_auth0_userinfo(token, auth0_user_id)
            
            if not userinfo:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to fetch user information from Auth0"
                )
            
            # Create user in database
            await service.create_or_update_user(
                auth0_user_id=auth0_user_id,
                email=userinfo.get("email"),
                display_name=userinfo.get("nickname") or userinfo.get("name"),
                name=userinfo.get("name"),
                given_name=userinfo.get("given_name"),
                family_name=userinfo.get("family_name"),
                picture_url=userinfo.get("picture"),
                locale=userinfo.get("locale"),
            )
            
            # Return the newly created user profile
            return await service.get_user_profile(auth0_user_id)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_current_user_profile: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve user profile"
        )

