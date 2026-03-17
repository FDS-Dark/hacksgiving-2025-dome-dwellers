from fastapi import APIRouter, Depends, status, Query
from services.inventory import InventoryService
from models.inventory import (
    PlantSpecies,
    PlantSpeciesCreate,
    PlantInstance,
    PlantInstanceCreate,
    PlantInstanceUpdate,
    PlantInstanceWithDetails,
    StorageLocation,
    StorageLocationCreate,
    PlantNote,
    PlantNoteCreate,
    StockRequest,
    StockRequestCreate,
)
from typing import Optional
from dependencies import get_inventory_service

router = APIRouter(prefix="/inventory", tags=["inventory"])


@router.post("/plant-species", response_model=PlantSpecies, status_code=status.HTTP_201_CREATED)
async def create_plant_species(
    species_data: PlantSpeciesCreate,
    service: InventoryService = Depends(get_inventory_service),
) -> PlantSpecies:
    """
    Create a new plant species
    
    **Required fields:**
    - **scientific_name**: Scientific name of the plant species
    
    **Optional fields:**
    - **common_name**: Common name of the plant
    - **description**: Description of the plant species
    """
    return await service.create_plant_species(species_data)


@router.post("/plant-instances", response_model=PlantInstance, status_code=status.HTTP_201_CREATED)
async def create_plant_instance(
    instance_data: PlantInstanceCreate,
    service: InventoryService = Depends(get_inventory_service),
) -> PlantInstance:
    """
    Create a new plant instance
    
    **Required fields:**
    - **species_id**: ID of the plant species (from plants.species table)
    
    **Optional fields:**
    - **storage_location_id**: ID of the storage location
    - **identifier**: Internal tag/label (e.g., "CACTUS-042")
    - **quantity**: Number of plants (default: 1)
    - **status**: Status of the plant (default: "available")
    - **acquired_date**: Date the plant was acquired
    - **notes**: Additional notes
    """
    return await service.create_plant_instance(instance_data)


@router.post("/storage-locations", response_model=StorageLocation, status_code=status.HTTP_201_CREATED)
async def create_storage_location(
    location_data: StorageLocationCreate,
    service: InventoryService = Depends(get_inventory_service),
) -> StorageLocation:
    """
    Create a new storage location
    
    **Required fields:**
    - **name**: Name of the location (e.g., "Greenhouse A", "Dome #2")
    - **location_type**: Type of location (greenhouse, dome, storage, quarantine, other)
    
    **Optional fields:**
    - **description**: Description of the location
    - **capacity**: Maximum number of plants
    """
    return await service.create_storage_location(location_data)


@router.post("/plant-notes", response_model=PlantNote, status_code=status.HTTP_201_CREATED)
async def create_plant_note(
    note_data: PlantNoteCreate,
    service: InventoryService = Depends(get_inventory_service),
) -> PlantNote:
    """
    Create a new plant note
    
    **Required fields:**
    - **plant_instance_id**: ID of the plant instance
    - **staff_user_id**: ID of the staff user creating the note
    - **note_type**: Type of note (observation, maintenance, issue, transfer, other)
    - **content**: Content of the note
    """
    return await service.create_plant_note(note_data)


@router.post("/stock-requests", response_model=StockRequest, status_code=status.HTTP_201_CREATED)
async def create_stock_request(
    request_data: StockRequestCreate,
    service: InventoryService = Depends(get_inventory_service),
) -> StockRequest:
    """
    Create a new stock request
    
    **Required fields:**
    - **requested_by_user_id**: ID of the staff member making the request
    - **quantity**: Number of plants requested (must be > 0)
    
    **Optional fields:**
    - **species_id**: ID of the plant species from plants.species (if known)
    - **requested_species_name**: Free-form species name (if species not in catalog)
    - **priority**: Priority level (default: "normal")
    - **status**: Request status (default: "pending")
    - **justification**: Why these plants are needed
    - **notes**: Additional notes
    """
    return await service.create_stock_request(request_data)


@router.get("/plant-instances", response_model=list[PlantInstanceWithDetails])
async def get_plant_instances(
    storage_location_id: Optional[int] = Query(None, description="Filter by storage location ID"),
    status: Optional[str] = Query(None, description="Filter by status"),
    species_id: Optional[int] = Query(None, description="Filter by plant species ID"),
    service: InventoryService = Depends(get_inventory_service),
) -> list[PlantInstanceWithDetails]:
    """
    Get plant instances with species and location information
    
    - **storage_location_id**: Filter by storage location ID
    - **status**: Filter by status (available, reserved, sold, removed)
    - **species_id**: Filter by plant species ID (from plants.species table)
    """
    instances = await service.get_plant_instances(
        storage_location_id=storage_location_id,
        status=status,
        species_id=species_id,
    )
    return [PlantInstanceWithDetails(**instance) for instance in instances]


@router.get("/storage-locations", response_model=list[StorageLocation])
async def get_storage_locations(
    location_type: Optional[str] = Query(None, description="Filter by location type"),
    service: InventoryService = Depends(get_inventory_service),
) -> list[StorageLocation]:
    """
    Get storage locations
    
    - **location_type**: Filter by location type (greenhouse, dome, storage, quarantine, other)
    """
    return await service.get_storage_locations(location_type=location_type)


@router.get("/plant-species", response_model=list[PlantSpecies])
async def get_plant_species(
    search: Optional[str] = Query(None, description="Search by scientific or common name"),
    service: InventoryService = Depends(get_inventory_service),
) -> list[PlantSpecies]:
    """
    Get plant species
    
    - **search**: Search term for scientific or common name
    """
    return await service.get_plant_species(search=search)


@router.put("/plant-instances/{instance_id}", response_model=PlantInstance)
async def update_plant_instance(
    instance_id: int,
    instance_data: PlantInstanceUpdate,
    service: InventoryService = Depends(get_inventory_service),
) -> PlantInstance:
    """
    Update a plant instance
    
    All fields are optional - only provided fields will be updated.
    
    - **instance_id**: The plant instance ID to update
    - **instance_data**: Fields to update
    """
    return await service.update_plant_instance(instance_id, instance_data)


@router.patch("/plant-instances/{instance_id}", response_model=PlantInstance)
async def patch_plant_instance(
    instance_id: int,
    instance_data: PlantInstanceUpdate,
    service: InventoryService = Depends(get_inventory_service),
) -> PlantInstance:
    """
    Partially update a plant instance (alias for PUT)
    
    - **instance_id**: The plant instance ID to update
    - **instance_data**: Fields to update
    """
    return await service.update_plant_instance(instance_id, instance_data)