from databridge.plants_databridge import PlantsDatabridge
from models.plants import (
    PlantSpecies,
    PlantSpeciesCreate,
    PlantSpeciesUpdate,
    PlantSpeciesListItem,
    PlantSpeciesListResponse,
    PlantSpeciesFilters,
    PlantArticle,
    PlantArticleCreate,
    PlantArticleUpdate,
    PlantEncyclopediaEntry,
)
from structlog import get_logger
from typing import Optional
from fastapi import HTTPException

logger = get_logger()


class PlantsService:
    """Service layer for plant encyclopedia operations"""

    def __init__(self, databridge: PlantsDatabridge):
        self.databridge = databridge

    # ==================== SPECIES OPERATIONS ====================

    async def get_species_list(
        self, filters: PlantSpeciesFilters
    ) -> PlantSpeciesListResponse:
        """
        Get list of plant species for encyclopedia index
        
        Args:
            filters: PlantSpeciesFilters model with filter criteria
            
        Returns:
            PlantSpeciesListResponse with species list and total count
        """
        try:
            species_df = await self.databridge.get_species_list(
                search=filters.search,
                order_by=filters.order_by,
                limit=filters.limit,
                offset=filters.offset,
            )

            total = await self.databridge.count_species(search=filters.search)

            plants = []
            if not species_df.empty:
                for _, row in species_df.iterrows():
                    plants.append(PlantSpeciesListItem(**row.to_dict()))

            return PlantSpeciesListResponse(plants=plants, total=total)

        except Exception as e:
            logger.error(f"Error in get_species_list service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch plant species")

    async def get_species_by_id(self, species_id: int) -> PlantSpecies:
        """
        Get a single plant species by ID
        
        Args:
            species_id: The species ID
            
        Returns:
            PlantSpecies model
            
        Raises:
            HTTPException: 404 if species not found
        """
        try:
            species_df = await self.databridge.get_species_by_id(species_id)

            if species_df.empty:
                raise HTTPException(
                    status_code=404, detail=f"Plant species {species_id} not found"
                )

            return PlantSpecies(**species_df.iloc[0].to_dict())

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in get_species_by_id service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch plant species")

    async def create_species(
        self, species_data: PlantSpeciesCreate
    ) -> PlantSpecies:
        """
        Create a new plant species
        
        Args:
            species_data: PlantSpeciesCreate model with species data
            
        Returns:
            Created PlantSpecies model
        """
        try:
            species_df = await self.databridge.create_species(
                scientific_name=species_data.scientific_name,
                common_name=species_data.common_name,
                description=species_data.description,
                image_url=species_data.image_url,
            )

            if species_df.empty:
                raise HTTPException(
                    status_code=500, detail="Failed to create plant species"
                )

            return PlantSpecies(**species_df.iloc[0].to_dict())

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_species service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to create plant species")

    async def update_species(
        self, species_id: int, species_data: PlantSpeciesUpdate
    ) -> PlantSpecies:
        """
        Update an existing plant species
        
        Args:
            species_id: The species ID to update
            species_data: PlantSpeciesUpdate model with updated data
            
        Returns:
            Updated PlantSpecies model
            
        Raises:
            HTTPException: 404 if species not found
        """
        try:
            # Check if species exists
            await self.get_species_by_id(species_id)

            species_df = await self.databridge.update_species(
                species_id=species_id,
                scientific_name=species_data.scientific_name,
                common_name=species_data.common_name,
                description=species_data.description,
                image_url=species_data.image_url,
            )

            if species_df.empty:
                raise HTTPException(
                    status_code=404, detail=f"Plant species {species_id} not found"
                )

            return PlantSpecies(**species_df.iloc[0].to_dict())

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in update_species service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to update plant species")

    # ==================== ENCYCLOPEDIA ENTRY OPERATIONS ====================

    async def get_encyclopedia_entry(
        self, species_id: int
    ) -> PlantEncyclopediaEntry:
        """
        Get complete encyclopedia entry (species + article)
        
        Args:
            species_id: The species ID
            
        Returns:
            PlantEncyclopediaEntry model
            
        Raises:
            HTTPException: 404 if species not found
        """
        try:
            entry_df = await self.databridge.get_encyclopedia_entry(species_id)

            if entry_df.empty:
                raise HTTPException(
                    status_code=404, detail=f"Plant species {species_id} not found"
                )

            return PlantEncyclopediaEntry(**entry_df.iloc[0].to_dict())

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in get_encyclopedia_entry service: {str(e)}")
            raise HTTPException(
                status_code=500, detail="Failed to fetch encyclopedia entry"
            )

    # ==================== ARTICLE OPERATIONS ====================

    async def get_article(self, species_id: int) -> PlantArticle:
        """
        Get plant article for a species
        
        Args:
            species_id: The species ID
            
        Returns:
            PlantArticle model
            
        Raises:
            HTTPException: 404 if article not found
        """
        try:
            article_df = await self.databridge.get_article(species_id)

            if article_df.empty:
                raise HTTPException(
                    status_code=404,
                    detail=f"No published article found for species {species_id}",
                )

            return PlantArticle(**article_df.iloc[0].to_dict())

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in get_article service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch article")

    async def create_or_update_article(
        self, article_data: PlantArticleCreate
    ) -> PlantArticle:
        """
        Create or update a plant article
        
        Args:
            article_data: PlantArticleCreate model with article data
            
        Returns:
            Created/updated PlantArticle model
        """
        try:
            # Verify species exists
            await self.get_species_by_id(article_data.species_id)

            article_df = await self.databridge.upsert_article(
                species_id=article_data.species_id,
                article_content=article_data.article_content,
                author_user_id=article_data.author_user_id,
                published=article_data.published,
            )

            if article_df.empty:
                raise HTTPException(
                    status_code=500, detail="Failed to create/update article"
                )

            return PlantArticle(**article_df.iloc[0].to_dict())

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_or_update_article service: {str(e)}")
            raise HTTPException(
                status_code=500, detail="Failed to create/update article"
            )

    async def update_article(
        self, species_id: int, article_data: PlantArticleUpdate
    ) -> PlantArticle:
        """
        Update an existing plant article
        
        Args:
            species_id: The species ID
            article_data: PlantArticleUpdate model with updated data
            
        Returns:
            Updated PlantArticle model
        """
        try:
            # Get existing article
            existing_article = await self.get_article(species_id)

            # Merge updates
            article_content = (
                article_data.article_content
                if article_data.article_content is not None
                else existing_article.article_content
            )
            published = (
                article_data.published
                if article_data.published is not None
                else existing_article.published
            )
            author_user_id = (
                article_data.author_user_id
                if article_data.author_user_id is not None
                else existing_article.author_user_id
            )

            article_df = await self.databridge.upsert_article(
                species_id=species_id,
                article_content=article_content,
                author_user_id=author_user_id,
                published=published,
            )

            if article_df.empty:
                raise HTTPException(status_code=500, detail="Failed to update article")

            return PlantArticle(**article_df.iloc[0].to_dict())

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in update_article service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to update article")

    async def delete_article(self, species_id: int) -> dict:
        """
        Delete a plant article
        
        Args:
            species_id: The species ID
            
        Returns:
            Success message
        """
        try:
            deleted = await self.databridge.delete_article(species_id)

            if not deleted:
                raise HTTPException(
                    status_code=404,
                    detail=f"No article found for species {species_id}",
                )

            return {"message": f"Article for species {species_id} deleted successfully"}

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in delete_article service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to delete article")

