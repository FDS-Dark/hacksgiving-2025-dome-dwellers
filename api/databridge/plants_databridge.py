from databridge.supabase_databridge import SupabaseDatabridge
from engine.supabase_engine import SupabaseDBEngine
from typing import Optional
from structlog import get_logger
import pandas as pd

logger = get_logger()


class PlantsDatabridge(SupabaseDatabridge):
    """Databridge for plant encyclopedia database operations using Supabase stored procedures"""

    def __init__(self, engine: SupabaseDBEngine) -> None:
        super().__init__(engine)

    # ==================== PLANT ENCYCLOPEDIA OPERATIONS ====================

    async def get_species_list(
        self,
        search: Optional[str] = None,
        order_by: str = "common_name",
        limit: int = 50,
        offset: int = 0,
    ) -> pd.DataFrame:
        """Fetch plant species list for encyclopedia index"""
        query = """
            SELECT * FROM plants.get_species_list(
                :p_search,
                :p_limit,
                :p_offset,
                :p_order_by
            )
        """
        params = {
            "p_search": search,
            "p_limit": limit,
            "p_offset": offset,
            "p_order_by": order_by,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching plant species list: {str(e)}")
            raise

    async def count_species(
        self,
        search: Optional[str] = None,
    ) -> int:
        """Count total plant species for pagination"""
        query = "SELECT plants.count_species(:p_search) as count"
        params = {"p_search": search}
        try:
            result = await self.execute_query(query, params)
            if result.empty:
                return 0
            return int(result.iloc[0]["count"])
        except Exception as e:
            logger.error(f"Error counting plant species: {str(e)}")
            raise

    async def get_species_by_id(self, species_id: int) -> pd.DataFrame:
        """Fetch a single plant species by ID"""
        query = "SELECT * FROM plants.get_species_by_id(:p_species_id)"
        params = {"p_species_id": species_id}
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching plant species {species_id}: {str(e)}")
            raise

    async def get_encyclopedia_entry(self, species_id: int) -> pd.DataFrame:
        """Fetch complete encyclopedia entry (species + article)"""
        query = "SELECT * FROM plants.get_encyclopedia_entry(:p_species_id)"
        params = {"p_species_id": species_id}
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(
                f"Error fetching encyclopedia entry for species {species_id}: {str(e)}"
            )
            raise

    async def get_article(self, species_id: int) -> pd.DataFrame:
        """Fetch plant article for a species"""
        query = "SELECT * FROM plants.get_article(:p_species_id)"
        params = {"p_species_id": species_id}
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching article for species {species_id}: {str(e)}")
            raise

    async def create_species(
        self,
        scientific_name: str,
        common_name: Optional[str] = None,
        description: Optional[str] = None,
        image_url: Optional[str] = None,
    ) -> pd.DataFrame:
        """Create a new plant species"""
        query = """
            SELECT * FROM plants.upsert_species(
                :p_scientific_name,
                NULL,
                :p_common_name,
                :p_description,
                :p_image_url
            )
        """
        params = {
            "p_scientific_name": scientific_name,
            "p_common_name": common_name,
            "p_description": description,
            "p_image_url": image_url,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error creating plant species: {str(e)}")
            raise

    async def update_species(
        self,
        species_id: int,
        scientific_name: Optional[str] = None,
        common_name: Optional[str] = None,
        description: Optional[str] = None,
        image_url: Optional[str] = None,
    ) -> pd.DataFrame:
        """Update an existing plant species"""
        query = """
            SELECT * FROM plants.upsert_species(
                :p_scientific_name,
                :p_id,
                :p_common_name,
                :p_description,
                :p_image_url
            )
        """
        params = {
            "p_id": species_id,
            "p_scientific_name": scientific_name,
            "p_common_name": common_name,
            "p_description": description,
            "p_image_url": image_url,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error updating plant species {species_id}: {str(e)}")
            raise

    async def upsert_article(
        self,
        species_id: int,
        article_content: str,
        author_user_id: Optional[int] = None,
        published: bool = False,
    ) -> pd.DataFrame:
        """Create or update a plant article"""
        query = """
            SELECT * FROM plants.upsert_article(
                :p_species_id,
                :p_article_content,
                :p_author_user_id,
                :p_published
            )
        """
        params = {
            "p_species_id": species_id,
            "p_article_content": article_content,
            "p_author_user_id": author_user_id,
            "p_published": published,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error upserting article for species {species_id}: {str(e)}")
            raise

    async def delete_article(self, species_id: int) -> bool:
        """Delete a plant article"""
        query = "SELECT plants.delete_article(:p_species_id) as deleted"
        params = {"p_species_id": species_id}
        try:
            result = await self.execute_query(query, params)
            if result.empty:
                return False
            return bool(result.iloc[0]["deleted"])
        except Exception as e:
            logger.error(f"Error deleting article for species {species_id}: {str(e)}")
            raise

