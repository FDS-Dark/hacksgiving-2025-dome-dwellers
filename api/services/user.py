from databridge.user_databridge import UserDatabridge
from models.user import User, UserProfile, Role
from structlog import get_logger
from fastapi import HTTPException
import json
from typing import Optional

logger = get_logger()


class UserService:
    """Service layer for user operations"""

    def __init__(self, databridge: UserDatabridge):
        self.databridge = databridge

    async def get_user_profile(self, auth0_user_id: str) -> UserProfile:
        """
        Get user profile by Auth0 user ID
        
        Args:
            auth0_user_id: The Auth0 user ID (sub)
            
        Returns:
            UserProfile model with user data and role names
            
        Raises:
            HTTPException: 404 if user not found
        """
        try:
            user_df = await self.databridge.get_user_by_auth0_id(auth0_user_id)

            print(user_df)

            if user_df.empty:
                raise HTTPException(
                    status_code=404,
                    detail=f"User with auth0_user_id {auth0_user_id} not found"
                )

            user_data = user_df.iloc[0].to_dict()
            
            # Parse roles from JSONB
            roles_json = user_data.get('roles', '[]')
            if isinstance(roles_json, str):
                roles_data = json.loads(roles_json)
            else:
                roles_data = roles_json if roles_json else []
            
            # Extract just the role names for UserProfile
            role_names = [role['name'] for role in roles_data]
            
            return UserProfile(
                id=user_data['id'],
                auth0_user_id=user_data['auth0_user_id'],
                email=user_data.get('email'),
                display_name=user_data.get('display_name'),
                name=user_data.get('name'),
                given_name=user_data.get('given_name'),
                family_name=user_data.get('family_name'),
                picture_url=user_data.get('picture_url'),
                locale=user_data.get('locale'),
                roles=role_names,
                created_at=user_data['created_at'],
                updated_at=user_data['updated_at']
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in get_user_profile service: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail="Failed to fetch user profile"
            )

    async def get_user(self, auth0_user_id: str) -> User:
        """
        Get complete user information with full role objects
        
        Args:
            auth0_user_id: The Auth0 user ID (sub)
            
        Returns:
            User model with full user data and roles
            
        Raises:
            HTTPException: 404 if user not found
        """
        try:
            user_df = await self.databridge.get_user_by_auth0_id(auth0_user_id)

            if user_df.empty:
                raise HTTPException(
                    status_code=404,
                    detail=f"User with auth0_user_id {auth0_user_id} not found"
                )

            user_data = user_df.iloc[0].to_dict()
            
            # Parse roles from JSONB
            roles_json = user_data.get('roles', '[]')
            if isinstance(roles_json, str):
                roles_data = json.loads(roles_json)
            else:
                roles_data = roles_json if roles_json else []
            
            # Create Role objects
            roles = [Role(**role) for role in roles_data]
            
            return User(
                id=user_data['id'],
                auth0_user_id=user_data['auth0_user_id'],
                email=user_data.get('email'),
                display_name=user_data.get('display_name'),
                name=user_data.get('name'),
                given_name=user_data.get('given_name'),
                family_name=user_data.get('family_name'),
                picture_url=user_data.get('picture_url'),
                locale=user_data.get('locale'),
                is_active=user_data['is_active'],
                roles=roles,
                created_at=user_data['created_at'],
                updated_at=user_data['updated_at']
            )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in get_user service: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail="Failed to fetch user"
            )

    async def create_or_update_user(
        self,
        auth0_user_id: str,
        email: Optional[str] = None,
        display_name: Optional[str] = None,
        name: Optional[str] = None,
        given_name: Optional[str] = None,
        family_name: Optional[str] = None,
        picture_url: Optional[str] = None,
        locale: Optional[str] = None,
    ) -> User:
        """
        Create or update user information
        
        Args:
            auth0_user_id: The Auth0 user ID (sub)
            email: User's email
            display_name: Display name
            name: Full name
            given_name: First name
            family_name: Last name
            picture_url: Profile picture URL
            locale: User's locale/language preference
            
        Returns:
            User model with created/updated user data
        """
        try:
            # Upsert the user
            user_df = await self.databridge.upsert_user(
                auth0_user_id=auth0_user_id,
                email=email,
                display_name=display_name,
                name=name,
                given_name=given_name,
                family_name=family_name,
                picture_url=picture_url,
                locale=locale,
            )

            if user_df.empty:
                raise HTTPException(
                    status_code=500,
                    detail="Failed to create/update user"
                )

            # Get the full user with roles
            return await self.get_user(auth0_user_id)

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_or_update_user service: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail="Failed to create/update user"
            )

