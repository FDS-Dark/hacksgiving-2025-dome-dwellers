from pydantic import BaseModel, Field
from datetime import datetime, date
from typing import Optional, Literal

# Plant Status Types
PlantStatus = Literal["available", "reserved", "sold", "removed"]
LocationType = Literal["greenhouse", "dome", "storage", "quarantine", "other"]
NoteType = Literal["observation", "maintenance", "issue", "transfer", "other"]
StockRequestPriority = Literal["low", "normal", "high", "urgent"]
StockRequestStatus = Literal["pending", "approved", "ordered", "received", "rejected"]


# Plant Species Models
class PlantSpeciesBase(BaseModel):
    """Base plant species model"""
    scientific_name: str
    common_name: Optional[str] = None
    description: Optional[str] = None


class PlantSpeciesCreate(PlantSpeciesBase):
    """Model for creating a new plant species"""
    pass


class PlantSpecies(PlantSpeciesBase):
    """Full plant species model with database fields"""
    id: int

    class Config:
        from_attributes = True


# Plant Instance Models
class PlantInstanceBase(BaseModel):
    """Base plant instance model"""
    species_id: int
    storage_location_id: Optional[int] = None
    identifier: Optional[str] = None
    quantity: int = Field(default=1, ge=1)
    status: PlantStatus = "available"
    is_public: bool = True
    acquired_date: Optional[date] = None
    notes: Optional[str] = None


class PlantInstanceCreate(PlantInstanceBase):
    """Model for creating a new plant instance"""
    pass


class PlantInstanceUpdate(BaseModel):
    """Model for updating a plant instance (all fields optional)"""
    species_id: Optional[int] = None
    storage_location_id: Optional[int] = None
    identifier: Optional[str] = None
    quantity: Optional[int] = Field(None, ge=1)
    status: Optional[PlantStatus] = None
    is_public: Optional[bool] = None
    acquired_date: Optional[date] = None
    notes: Optional[str] = None


class PlantInstance(PlantInstanceBase):
    """Full plant instance model with database fields"""
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


class PlantInstanceWithDetails(PlantInstance):
    """Plant instance with species and location details"""
    scientific_name: Optional[str] = None
    common_name: Optional[str] = None
    species_description: Optional[str] = None
    location_name: Optional[str] = None
    location_type: Optional[LocationType] = None
    location_description: Optional[str] = None

    class Config:
        from_attributes = True


# Storage Location Models
class StorageLocationBase(BaseModel):
    """Base storage location model"""
    name: str
    location_type: LocationType
    description: Optional[str] = None
    capacity: Optional[int] = Field(None, ge=1)


class StorageLocationCreate(StorageLocationBase):
    """Model for creating a new storage location"""
    pass


class StorageLocation(StorageLocationBase):
    """Full storage location model with database fields"""
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# Plant Note Models
class PlantNoteBase(BaseModel):
    """Base plant note model"""
    plant_instance_id: int
    staff_user_id: int
    note_type: NoteType
    content: str


class PlantNoteCreate(PlantNoteBase):
    """Model for creating a new plant note"""
    pass


class PlantNote(PlantNoteBase):
    """Full plant note model with database fields"""
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# Stock Request Models
class StockRequestBase(BaseModel):
    """Base stock request model"""
    requested_by_user_id: int
    species_id: Optional[int] = None
    requested_species_name: Optional[str] = None
    quantity: int = Field(..., ge=1)
    priority: StockRequestPriority = "normal"
    status: StockRequestStatus = "pending"
    justification: Optional[str] = None
    notes: Optional[str] = None


class StockRequestCreate(StockRequestBase):
    """Model for creating a new stock request"""
    pass


class StockRequestUpdate(BaseModel):
    """Model for updating a stock request (all fields optional)"""
    species_id: Optional[int] = None
    requested_species_name: Optional[str] = None
    quantity: Optional[int] = Field(None, ge=1)
    priority: Optional[StockRequestPriority] = None
    status: Optional[StockRequestStatus] = None
    justification: Optional[str] = None
    notes: Optional[str] = None


class StockRequest(StockRequestBase):
    """Full stock request model with database fields"""
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

