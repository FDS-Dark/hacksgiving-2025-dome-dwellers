from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from uuid import UUID


class CollectibleCatalogEntry(BaseModel):
    catalog_id: int
    catalog_number: int
    plant_species_id: int
    species_name: Optional[str] = None
    scientific_name: str
    image_url: Optional[str] = None
    rarity_tier: str
    featured_order: Optional[int] = None
    is_discovered: bool
    discovered_at: Optional[datetime] = None
    discovery_id: Optional[int] = None
    user_notes: Optional[str] = None
    is_favorite: bool = False


class DiscoveryDetails(BaseModel):
    discovery_id: int
    catalog_number: int
    plant_species_id: int
    species_name: Optional[str] = None
    scientific_name: str
    family: Optional[str] = None
    rarity_tier: str
    discovered_at: datetime
    user_notes: Optional[str] = None
    is_favorite: bool = False
    plant_article: Dict[str, Any]


class DiscoveryResponse(BaseModel):
    success: bool
    message: str
    discovery_id: Optional[int] = None
    catalog_entry_id: Optional[int] = None
    catalog_number: Optional[int] = None
    species_name: Optional[str] = None
    plant_species_id: Optional[int] = None
    already_discovered: bool = False


class CollectionStats(BaseModel):
    total_collectibles: int
    total_discovered: int
    discovery_percentage: float
    common_discovered: int
    uncommon_discovered: int
    rare_discovered: int
    legendary_discovered: int
    favorites_count: int
    recent_discoveries: List[int]


class UpdateNotesRequest(BaseModel):
    notes: str = Field(..., description="Personal notes about the discovery")


class QRCodeInfo(BaseModel):
    id: int
    code_token: str
    species_id: int
    location_id: Optional[int] = None
    active: bool
    common_name: Optional[str] = None
    scientific_name: Optional[str] = None
    location_name: Optional[str] = None
    created_at: Optional[datetime] = None


class QRCodeDetail(BaseModel):
    qr_code_id: int
    code_token: str
    species_id: int
    location_id: Optional[int] = None
    active: bool
    is_public: bool = True
    created_at: datetime
    common_name: Optional[str] = None
    scientific_name: str
    location_name: Optional[str] = None
    scan_count: int = 0
    deep_link_url: Optional[str] = None


class QRCodeCreateRequest(BaseModel):
    species_id: int = Field(..., description="The plant species to create a QR code for")
    location_id: Optional[int] = Field(None, description="Optional location ID for the QR code")


class QRCodeBulkCreateRequest(BaseModel):
    species_ids: List[int] = Field(..., description="List of plant species IDs to create QR codes for")
    location_ids: Optional[List[Optional[int]]] = Field(None, description="Optional list of location IDs matching species IDs")


class QRCodeBulkCreateResponse(BaseModel):
    created_count: int
    qr_codes: List[QRCodeInfo]


class ScanQRRequest(BaseModel):
    qr_token: UUID = Field(..., description="The QR code token to scan")

