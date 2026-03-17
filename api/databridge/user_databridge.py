from databridge.supabase_databridge import SupabaseDatabridge
from engine.supabase_engine import SupabaseDBEngine
from structlog import get_logger
import pandas as pd
from typing import Optional

logger = get_logger()


class UserDatabridge(SupabaseDatabridge):
    """Databridge for user operations"""

    def __init__(self, engine: SupabaseDBEngine) -> None:
        super().__init__(engine)
        logger.info("Initialized User databridge")

    async def get_user_by_auth0_id(self, auth0_user_id: str) -> pd.DataFrame:
        """
        Get user by Auth0 user ID with roles
        
        Args:
            auth0_user_id: The Auth0 user ID (sub)
            
        Returns:
            DataFrame with user data and roles as JSON
        """
        try:
            query = "SELECT * FROM auth0.get_user_by_auth0_id(:p_auth0_user_id)"
            params = {"p_auth0_user_id": auth0_user_id}
            
            result = await self.execute_query(query, params)
            logger.info(f"Retrieved user for auth0_id: {auth0_user_id}")
            
            return result
        except Exception as e:
            logger.error(f"Error getting user by auth0_id {auth0_user_id}: {str(e)}")
            raise

    async def upsert_user(
        self,
        auth0_user_id: str,
        email: Optional[str] = None,
        display_name: Optional[str] = None,
        name: Optional[str] = None,
        given_name: Optional[str] = None,
        family_name: Optional[str] = None,
        picture_url: Optional[str] = None,
        locale: Optional[str] = None,
    ) -> pd.DataFrame:
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
            DataFrame with created/updated user data
        """
        try:
            query = """
                SELECT * FROM auth0.upsert_user(
                    :p_auth0_user_id,
                    :p_email,
                    :p_display_name,
                    :p_name,
                    :p_given_name,
                    :p_family_name,
                    :p_picture_url,
                    :p_locale
                )
            """
            params = {
                "p_auth0_user_id": auth0_user_id,
                "p_email": email,
                "p_display_name": display_name,
                "p_name": name,
                "p_given_name": given_name,
                "p_family_name": family_name,
                "p_picture_url": picture_url,
                "p_locale": locale,
            }
            
            result = await self.execute_query(query, params)
            logger.info(f"Upserted user: {auth0_user_id}")
            
            return result
        except Exception as e:
            logger.error(f"Error upserting user {auth0_user_id}: {str(e)}")
            raise

