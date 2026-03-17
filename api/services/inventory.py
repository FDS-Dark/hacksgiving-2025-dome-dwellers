from databridge.supabase_databridge import SupabaseDatabridge
from models.inventory import (
    PlantSpecies,
    PlantSpeciesCreate,
    PlantInstance,
    PlantInstanceCreate,
    PlantInstanceUpdate,
    StorageLocation,
    StorageLocationCreate,
    PlantNote,
    PlantNoteCreate,
    StockRequest,
    StockRequestCreate,
    StockRequestUpdate,
)
from structlog import get_logger
from typing import Optional
from fastapi import HTTPException
from datetime import date

logger = get_logger()


class InventoryService:
    """Service layer for inventory-related operations"""

    def __init__(self, databridge: SupabaseDatabridge):
        self.databridge = databridge

    async def create_plant_species(self, species_data: PlantSpeciesCreate) -> PlantSpecies:
        """
        Create a new plant species in plants.species table
        
        Args:
            species_data: PlantSpeciesCreate model with species data
            
        Returns:
            Created PlantSpecies model
        """
        try:
            query = """
                INSERT INTO plants.species (
                    scientific_name,
                    common_name,
                    description
                ) VALUES (
                    :p_scientific_name,
                    :p_common_name,
                    :p_description
                )
                RETURNING 
                    id,
                    scientific_name,
                    common_name,
                    description
            """
            params = {
                "p_scientific_name": species_data.scientific_name,
                "p_common_name": species_data.common_name,
                "p_description": species_data.description,
            }
            
            result_df = await self.databridge.execute_query(query, params)
            
            if result_df.empty:
                raise HTTPException(status_code=500, detail="Failed to create plant species")
            
            return PlantSpecies(**result_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_plant_species service: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to create plant species: {str(e)}")

    async def create_plant_instance(self, instance_data: PlantInstanceCreate) -> PlantInstance:
        """
        Create a new plant instance
        
        Args:
            instance_data: PlantInstanceCreate model with instance data
            
        Returns:
            Created PlantInstance model
        """
        try:
            query = """
                INSERT INTO inventory.plant_instances (
                    species_id,
                    storage_location_id,
                    identifier,
                    quantity,
                    status,
                    is_public,
                    acquired_date,
                    notes
                ) VALUES (
                    :p_species_id,
                    :p_storage_location_id,
                    :p_identifier,
                    :p_quantity,
                    :p_status,
                    :p_is_public,
                    :p_acquired_date,
                    :p_notes
                )
                RETURNING 
                    id,
                    species_id,
                    storage_location_id,
                    identifier,
                    quantity,
                    status,
                    is_public,
                    acquired_date,
                    notes,
                    created_at
            """
            params = {
                "p_species_id": instance_data.species_id,
                "p_storage_location_id": instance_data.storage_location_id,
                "p_identifier": instance_data.identifier,
                "p_quantity": instance_data.quantity,
                "p_status": instance_data.status,
                "p_is_public": instance_data.is_public,
                "p_acquired_date": instance_data.acquired_date,
                "p_notes": instance_data.notes,
            }
            
            result_df = await self.databridge.execute_query(query, params)
            
            if result_df.empty:
                raise HTTPException(status_code=500, detail="Failed to create plant instance")
            
            return PlantInstance(**result_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_plant_instance service: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to create plant instance: {str(e)}")

    async def create_storage_location(self, location_data: StorageLocationCreate) -> StorageLocation:
        """
        Create a new storage location
        
        Args:
            location_data: StorageLocationCreate model with location data
            
        Returns:
            Created StorageLocation model
        """
        try:
            query = """
                INSERT INTO inventory.storage_locations (
                    name,
                    location_type,
                    description,
                    capacity
                ) VALUES (
                    :p_name,
                    :p_location_type,
                    :p_description,
                    :p_capacity
                )
                RETURNING 
                    id,
                    name,
                    location_type,
                    description,
                    capacity,
                    created_at
            """
            params = {
                "p_name": location_data.name,
                "p_location_type": location_data.location_type,
                "p_description": location_data.description,
                "p_capacity": location_data.capacity,
            }
            
            result_df = await self.databridge.execute_query(query, params)
            
            if result_df.empty:
                raise HTTPException(status_code=500, detail="Failed to create storage location")
            
            return StorageLocation(**result_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_storage_location service: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to create storage location: {str(e)}")

    async def create_plant_note(self, note_data: PlantNoteCreate) -> PlantNote:
        """
        Create a new plant note
        
        Args:
            note_data: PlantNoteCreate model with note data
            
        Returns:
            Created PlantNote model
        """
        try:
            query = """
                INSERT INTO inventory.plant_notes (
                    plant_instance_id,
                    staff_user_id,
                    note_type,
                    content
                ) VALUES (
                    :p_plant_instance_id,
                    :p_staff_user_id,
                    :p_note_type,
                    :p_content
                )
                RETURNING 
                    id,
                    plant_instance_id,
                    staff_user_id,
                    note_type,
                    content,
                    created_at
            """
            params = {
                "p_plant_instance_id": note_data.plant_instance_id,
                "p_staff_user_id": note_data.staff_user_id,
                "p_note_type": note_data.note_type,
                "p_content": note_data.content,
            }
            
            result_df = await self.databridge.execute_query(query, params)
            
            if result_df.empty:
                raise HTTPException(status_code=500, detail="Failed to create plant note")
            
            return PlantNote(**result_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_plant_note service: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to create plant note: {str(e)}")

    async def create_stock_request(self, request_data: StockRequestCreate) -> StockRequest:
        """
        Create a new stock request
        
        Args:
            request_data: StockRequestCreate model with request data
            
        Returns:
            Created StockRequest model
        """
        try:
            query = """
                INSERT INTO inventory.stock_requests (
                    requested_by_user_id,
                    species_id,
                    requested_species_name,
                    quantity,
                    priority,
                    status,
                    justification,
                    notes
                ) VALUES (
                    :p_requested_by_user_id,
                    :p_species_id,
                    :p_requested_species_name,
                    :p_quantity,
                    :p_priority,
                    :p_status,
                    :p_justification,
                    :p_notes
                )
                RETURNING 
                    id,
                    requested_by_user_id,
                    species_id,
                    requested_species_name,
                    quantity,
                    priority,
                    status,
                    justification,
                    notes,
                    created_at,
                    updated_at
            """
            params = {
                "p_requested_by_user_id": request_data.requested_by_user_id,
                "p_species_id": request_data.species_id,
                "p_requested_species_name": request_data.requested_species_name,
                "p_quantity": request_data.quantity,
                "p_priority": request_data.priority,
                "p_status": request_data.status,
                "p_justification": request_data.justification,
                "p_notes": request_data.notes,
            }
            
            result_df = await self.databridge.execute_query(query, params)
            
            if result_df.empty:
                raise HTTPException(status_code=500, detail="Failed to create stock request")
            
            return StockRequest(**result_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_stock_request service: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to create stock request: {str(e)}")

    async def get_plant_instances(
        self,
        storage_location_id: Optional[int] = None,
        status: Optional[str] = None,
        species_id: Optional[int] = None,
    ) -> list[dict]:
        """
        Get plant instances with species and location information
        
        Args:
            storage_location_id: Filter by storage location ID
            status: Filter by status
            species_id: Filter by plant species ID
            
        Returns:
            List of plant instances with species and location data
        """
        try:
            query = """
                SELECT 
                    pi.id,
                    pi.species_id,
                    pi.storage_location_id,
                    pi.identifier,
                    pi.quantity,
                    pi.status,
                    pi.is_public,
                    pi.acquired_date,
                    pi.notes,
                    pi.created_at,
                    ps.scientific_name,
                    ps.common_name,
                    ps.description as species_description,
                    sl.name as location_name,
                    sl.location_type,
                    sl.description as location_description
                FROM inventory.plant_instances pi
                LEFT JOIN plants.species ps ON pi.species_id = ps.id
                LEFT JOIN inventory.storage_locations sl ON pi.storage_location_id = sl.id
                WHERE 1=1
            """
            params = {}
            
            if storage_location_id is not None:
                query += " AND pi.storage_location_id = :p_storage_location_id"
                params["p_storage_location_id"] = storage_location_id
            
            if status is not None:
                query += " AND pi.status = :p_status"
                params["p_status"] = status
            
            if species_id is not None:
                query += " AND pi.species_id = :p_species_id"
                params["p_species_id"] = species_id
            
            query += " ORDER BY pi.created_at DESC"
            
            result_df = await self.databridge.execute_query(query, params if params else None)
            
            instances = []
            if not result_df.empty:
                for _, row in result_df.iterrows():
                    instances.append(row.to_dict())
            
            return instances
            
        except Exception as e:
            logger.error(f"Error in get_plant_instances service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch plant instances")

    async def get_storage_locations(
        self,
        location_type: Optional[str] = None,
    ) -> list[StorageLocation]:
        """
        Get storage locations
        
        Args:
            location_type: Filter by location type
            
        Returns:
            List of storage locations
        """
        try:
            query = """
                SELECT 
                    id,
                    name,
                    location_type,
                    description,
                    capacity,
                    created_at
                FROM inventory.storage_locations
                WHERE 1=1
            """
            params = {}
            
            if location_type is not None:
                query += " AND location_type = :p_location_type"
                params["p_location_type"] = location_type
            
            query += " ORDER BY name"
            
            result_df = await self.databridge.execute_query(query, params if params else None)
            
            locations = []
            if not result_df.empty:
                for _, row in result_df.iterrows():
                    locations.append(StorageLocation(**row.to_dict()))
            
            return locations
            
        except Exception as e:
            logger.error(f"Error in get_storage_locations service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch storage locations")

    async def get_plant_species(
        self,
        search: Optional[str] = None,
    ) -> list[PlantSpecies]:
        """
        Get plant species from plants.species table
        
        Args:
            search: Search term for scientific or common name
            
        Returns:
            List of plant species
        """
        try:
            query = """
                SELECT 
                    id,
                    scientific_name,
                    common_name,
                    description
                FROM plants.species
                WHERE 1=1
            """
            params = {}
            
            if search is not None:
                query += " AND (scientific_name ILIKE :p_search OR common_name ILIKE :p_search)"
                params["p_search"] = f"%{search}%"
            
            query += " ORDER BY scientific_name"
            
            result_df = await self.databridge.execute_query(query, params if params else None)
            
            species = []
            if not result_df.empty:
                for _, row in result_df.iterrows():
                    species.append(PlantSpecies(**row.to_dict()))
            
            return species
            
        except Exception as e:
            logger.error(f"Error in get_plant_species service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch plant species")

    async def update_plant_instance(
        self,
        instance_id: int,
        instance_data: PlantInstanceUpdate,
    ) -> PlantInstance:
        """
        Update a plant instance
        
        Args:
            instance_id: The plant instance ID
            instance_data: PlantInstanceUpdate model with updated data
            
        Returns:
            Updated PlantInstance model
        """
        try:
            # Build dynamic UPDATE query
            update_fields = []
            params = {"p_instance_id": instance_id}
            
            if instance_data.species_id is not None:
                update_fields.append("species_id = :p_species_id")
                params["p_species_id"] = instance_data.species_id
            
            if instance_data.storage_location_id is not None:
                update_fields.append("storage_location_id = :p_storage_location_id")
                params["p_storage_location_id"] = instance_data.storage_location_id
            
            if instance_data.identifier is not None:
                update_fields.append("identifier = :p_identifier")
                params["p_identifier"] = instance_data.identifier
            
            if instance_data.quantity is not None:
                update_fields.append("quantity = :p_quantity")
                params["p_quantity"] = instance_data.quantity
            
            if instance_data.status is not None:
                update_fields.append("status = :p_status")
                params["p_status"] = instance_data.status
            
            if instance_data.is_public is not None:
                update_fields.append("is_public = :p_is_public")
                params["p_is_public"] = instance_data.is_public
            
            if instance_data.acquired_date is not None:
                update_fields.append("acquired_date = :p_acquired_date")
                params["p_acquired_date"] = instance_data.acquired_date
            
            if instance_data.notes is not None:
                update_fields.append("notes = :p_notes")
                params["p_notes"] = instance_data.notes
            
            if not update_fields:
                raise HTTPException(status_code=400, detail="No fields to update")
            
            query = f"""
                UPDATE inventory.plant_instances
                SET {', '.join(update_fields)}
                WHERE id = :p_instance_id
                RETURNING 
                    id,
                    species_id,
                    storage_location_id,
                    identifier,
                    quantity,
                    status,
                    is_public,
                    acquired_date,
                    notes,
                    created_at
            """
            
            result_df = await self.databridge.execute_query(query, params)
            
            if result_df.empty:
                raise HTTPException(status_code=404, detail=f"Plant instance {instance_id} not found")
            
            return PlantInstance(**result_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in update_plant_instance service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to update plant instance")
