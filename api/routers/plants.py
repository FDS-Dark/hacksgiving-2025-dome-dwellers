from fastapi import APIRouter, Depends, Query
from services.plants import PlantsService
from models.plants import (
    PlantSpecies,
    PlantSpeciesCreate,
    PlantSpeciesUpdate,
    PlantSpeciesListResponse,
    PlantSpeciesFilters,
    PlantSortOrder,
    PlantArticle,
    PlantArticleCreate,
    PlantArticleUpdate,
    PlantEncyclopediaEntry,
)
from dependencies import get_plants_service
from typing import Optional

router = APIRouter(prefix="/plants", tags=["plants"])


# ==================== ENCYCLOPEDIA LIST ENDPOINTS ====================


@router.get("/encyclopedia", response_model=PlantSpeciesListResponse)
async def get_plant_encyclopedia_list(
    search: Optional[str] = Query(None, description="Search in scientific or common name"),
    order_by: PlantSortOrder = Query("common_name", description="Sort by field"),
    limit: int = Query(50, ge=1, le=100, description="Maximum plants to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    service: PlantsService = Depends(get_plants_service),
) -> PlantSpeciesListResponse:
    """
    Get list of plants for encyclopedia (without full articles)
    
    - **search**: Filter by scientific or common name (case-insensitive partial match)
    - **order_by**: Sort by 'common_name', 'scientific_name', or 'created_at'
    - **limit**: Maximum plants to return (1-100, default 50)
    - **offset**: Pagination offset (default 0)
    
    Returns list of plants with basic info, thumbnails, and whether they have articles.
    Articles are NOT included in this endpoint for performance.
    """
    filters = PlantSpeciesFilters(
        search=search,
        order_by=order_by,
        limit=limit,
        offset=offset,
    )
    return await service.get_species_list(filters)


@router.get("/encyclopedia/{species_id}", response_model=PlantEncyclopediaEntry)
async def get_plant_encyclopedia_entry(
    species_id: int,
    service: PlantsService = Depends(get_plants_service),
) -> PlantEncyclopediaEntry:
    """
    Get complete encyclopedia entry for a plant (species info + full article)
    
    - **species_id**: The plant species ID
    
    Returns complete plant information including the full article content.
    Use this endpoint when displaying a single plant's full page.
    """
    return await service.get_encyclopedia_entry(species_id)


# ==================== SPECIES MANAGEMENT ENDPOINTS ====================


@router.get("/species", response_model=PlantSpeciesListResponse)
async def get_species_list(
    search: Optional[str] = Query(None, description="Search in scientific or common name"),
    order_by: PlantSortOrder = Query("common_name", description="Sort by field"),
    limit: int = Query(50, ge=1, le=100, description="Maximum plants to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    service: PlantsService = Depends(get_plants_service),
) -> PlantSpeciesListResponse:
    """
    Get list of plant species (admin endpoint, same as /encyclopedia but clearer naming)
    """
    filters = PlantSpeciesFilters(
        search=search,
        order_by=order_by,
        limit=limit,
        offset=offset,
    )
    return await service.get_species_list(filters)


@router.get("/species/{species_id}", response_model=PlantSpecies)
async def get_species(
    species_id: int,
    service: PlantsService = Depends(get_plants_service),
) -> PlantSpecies:
    """
    Get a single plant species by ID (without article)
    
    - **species_id**: The plant species ID
    """
    return await service.get_species_by_id(species_id)


@router.post("/species", response_model=PlantSpecies, status_code=201)
async def create_species(
    species_data: PlantSpeciesCreate,
    service: PlantsService = Depends(get_plants_service),
) -> PlantSpecies:
    """
    Create a new plant species
    
    **Required fields:**
    - **scientific_name**: Scientific name (must be unique)
    
    **Optional fields:**
    - **common_name**: Common name
    - **description**: Short description
    - **image_url**: URL to primary image
    """
    return await service.create_species(species_data)


@router.put("/species/{species_id}", response_model=PlantSpecies)
async def update_species(
    species_id: int,
    species_data: PlantSpeciesUpdate,
    service: PlantsService = Depends(get_plants_service),
) -> PlantSpecies:
    """
    Update an existing plant species
    
    All fields are optional - only provided fields will be updated.
    
    - **species_id**: The species ID to update
    - **species_data**: Fields to update
    """
    return await service.update_species(species_id, species_data)


@router.patch("/species/{species_id}", response_model=PlantSpecies)
async def patch_species(
    species_id: int,
    species_data: PlantSpeciesUpdate,
    service: PlantsService = Depends(get_plants_service),
) -> PlantSpecies:
    """
    Partially update an existing plant species (alias for PUT)
    
    - **species_id**: The species ID to update
    - **species_data**: Fields to update
    """
    return await service.update_species(species_id, species_data)


# ==================== ARTICLE MANAGEMENT ENDPOINTS ====================


@router.get("/species/{species_id}/article", response_model=PlantArticle)
async def get_article(
    species_id: int,
    service: PlantsService = Depends(get_plants_service),
) -> PlantArticle:
    """
    Get published article for a plant species
    
    - **species_id**: The plant species ID
    
    Only returns published articles. Returns 404 if no published article exists.
    """
    return await service.get_article(species_id)


@router.post("/species/{species_id}/article", response_model=PlantArticle, status_code=201)
async def create_article(
    species_id: int,
    article_content: str = Query(..., description="Article content (markdown/HTML)"),
    published: bool = Query(False, description="Whether to publish immediately"),
    author_user_id: Optional[int] = Query(None, description="Author user ID"),
    service: PlantsService = Depends(get_plants_service),
) -> PlantArticle:
    """
    Create or update an article for a plant species
    
    - **species_id**: The plant species ID
    - **article_content**: Full article text (markdown or HTML)
    - **published**: Whether to publish the article (default: false)
    - **author_user_id**: Optional author user ID
    
    If an article already exists for this species, it will be updated.
    """
    article_data = PlantArticleCreate(
        species_id=species_id,
        article_content=article_content,
        published=published,
        author_user_id=author_user_id,
    )
    return await service.create_or_update_article(article_data)


@router.put("/species/{species_id}/article", response_model=PlantArticle)
async def update_article(
    species_id: int,
    article_data: PlantArticleUpdate,
    service: PlantsService = Depends(get_plants_service),
) -> PlantArticle:
    """
    Update an existing article
    
    - **species_id**: The plant species ID
    - **article_data**: Fields to update
    
    All fields are optional - only provided fields will be updated.
    """
    return await service.update_article(species_id, article_data)


@router.delete("/species/{species_id}/article")
async def delete_article(
    species_id: int,
    service: PlantsService = Depends(get_plants_service),
) -> dict:
    """
    Delete an article
    
    - **species_id**: The plant species ID
    """
    return await service.delete_article(species_id)

