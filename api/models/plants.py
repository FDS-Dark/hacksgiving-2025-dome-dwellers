from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, Literal

# Sort order types
PlantSortOrder = Literal["common_name", "scientific_name"]


# ==================== PLANT SPECIES MODELS ====================

class PlantSpeciesBase(BaseModel):
    """Base plant species model"""
    scientific_name: str = Field(..., min_length=1, max_length=255)
    common_name: Optional[str] = Field(None, max_length=255)
    description: Optional[str] = None
    image_url: Optional[str] = None


class PlantSpeciesCreate(PlantSpeciesBase):
    """Model for creating a new plant species"""
    pass


class PlantSpeciesUpdate(BaseModel):
    """Model for updating plant species (all fields optional)"""
    scientific_name: Optional[str] = Field(None, min_length=1, max_length=255)
    common_name: Optional[str] = Field(None, max_length=255)
    description: Optional[str] = None
    image_url: Optional[str] = None


class PlantSpecies(PlantSpeciesBase):
    """Full plant species model with database fields"""
    id: int

    class Config:
        from_attributes = True


class PlantSpeciesListItem(BaseModel):
    """Condensed plant species for list view (encyclopedia index)"""
    id: int
    scientific_name: str
    common_name: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    has_article: bool

    class Config:
        from_attributes = True


class PlantSpeciesListResponse(BaseModel):
    """Response model for listing plant species"""
    plants: list[PlantSpeciesListItem]
    total: int


class PlantSpeciesFilters(BaseModel):
    """Model for filtering plant species"""
    search: Optional[str] = Field(None, description="Search in scientific or common name")
    order_by: PlantSortOrder = Field(default="common_name", description="Sort field")
    limit: int = Field(default=50, ge=1, le=100)
    offset: int = Field(default=0, ge=0)


# ==================== PLANT ARTICLE MODELS ====================

class PlantArticleBase(BaseModel):
    """Base plant article model"""
    article_content: str = Field(..., min_length=1)
    published: bool = False


class PlantArticleCreate(PlantArticleBase):
    """Model for creating a plant article"""
    species_id: int
    author_user_id: Optional[int] = None


class PlantArticleUpdate(BaseModel):
    """Model for updating a plant article"""
    article_content: Optional[str] = Field(None, min_length=1)
    published: Optional[bool] = None
    author_user_id: Optional[int] = None


class PlantArticle(PlantArticleBase):
    """Full plant article model"""
    id: int
    species_id: int
    author_user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ==================== ENCYCLOPEDIA ENTRY MODEL ====================

class PlantEncyclopediaEntry(BaseModel):
    """Complete encyclopedia entry with species info and article"""
    id: int
    scientific_name: str
    common_name: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    article_id: Optional[int] = None
    article_content: Optional[str] = None
    article_author_id: Optional[int] = None
    article_created_at: Optional[datetime] = None
    article_updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

