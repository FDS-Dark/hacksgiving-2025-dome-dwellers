from typing import Optional, List, Dict, Any
from uuid import UUID
from datetime import datetime
from databridge.supabase_databridge import SupabaseDatabridge


class ScrapbookDatabridge(SupabaseDatabridge):
    """Databridge for scrapbook and gamification operations"""

    async def get_user_collectible_catalog(self, user_id: int) -> List[Dict[str, Any]]:
        """
        Get all collectible catalog entries with discovery status for a user
        """
        query = "SELECT * FROM gamification.get_user_collectible_catalog(:user_id)"
        df = await self.execute_query(query, {"user_id": user_id})
        
        if df.empty:
            return []
        
        return [
            {
                "catalog_id": row["catalog_id"],
                "catalog_number": row["catalog_number"],
                "plant_species_id": row["plant_species_id"],
                "species_name": row["species_name"],
                "scientific_name": row["scientific_name"],
                "image_url": row.get("image_url"),
                "rarity_tier": row["rarity_tier"],
                "featured_order": row["featured_order"],
                "is_discovered": row["is_discovered"],
                "discovered_at": row["discovered_at"].isoformat() if row["discovered_at"] else None,
                "discovery_id": row["discovery_id"],
                "user_notes": row["user_notes"],
                "is_favorite": row["is_favorite"],
            }
            for _, row in df.iterrows()
        ]

    async def get_or_create_default_scrapbook(self, user_id: int) -> int:
        """
        Get or create the default scrapbook for a user
        """
        query = "SELECT gamification.get_or_create_default_scrapbook(:user_id) as scrapbook_id"
        result = await self.execute_scalar(query, {"user_id": user_id})
        return result

    async def discover_plant_from_qr(self, user_id: int, qr_token: UUID) -> Dict[str, Any]:
        """
        Record a plant discovery from QR code scan
        """
        query = "SELECT * FROM gamification.discover_plant_from_qr(:user_id, :qr_token)"
        df = await self.execute_query(query, {"user_id": user_id, "qr_token": str(qr_token)})
        
        if df.empty:
            return {
                "success": False,
                "message": "Failed to process QR code",
                "discovery_id": None,
                "catalog_entry_id": None,
                "catalog_number": None,
                "species_name": None,
                "already_discovered": False,
            }
        
        row = df.iloc[0]
        return {
            "success": row["success"],
            "message": row["message"],
            "discovery_id": row["discovery_id"],
            "catalog_entry_id": row["catalog_entry_id"],
            "catalog_number": row["catalog_number"],
            "species_name": row["species_name"],
            "plant_species_id": row["plant_species_id"],
            "already_discovered": row["already_discovered"],
        }

    async def update_discovery_notes(
        self, user_id: int, discovery_id: int, notes: str
    ) -> bool:
        """
        Update personal notes for a discovery
        """
        query = "SELECT gamification.update_discovery_notes(:user_id, :discovery_id, :notes) as result"
        result = await self.execute_scalar(query, {"user_id": user_id, "discovery_id": discovery_id, "notes": notes})
        return bool(result)

    async def toggle_discovery_favorite(self, user_id: int, discovery_id: int) -> bool:
        """
        Toggle favorite status for a discovery
        Returns the new favorite status
        """
        query = "SELECT gamification.toggle_discovery_favorite(:user_id, :discovery_id) as result"
        result = await self.execute_scalar(query, {"user_id": user_id, "discovery_id": discovery_id})
        return bool(result)

    async def get_discovery_details(
        self, user_id: int, catalog_entry_id: int
    ) -> Optional[Dict[str, Any]]:
        """
        Get full details for a specific discovery
        """
        query = "SELECT * FROM gamification.get_discovery_details(:user_id, :catalog_entry_id)"
        df = await self.execute_query(query, {"user_id": user_id, "catalog_entry_id": catalog_entry_id})
        
        if df.empty:
            return None
        
        row = df.iloc[0]
        return {
            "discovery_id": row["discovery_id"],
            "catalog_number": row["catalog_number"],
            "plant_species_id": row["plant_species_id"],
            "species_name": row["species_name"],
            "scientific_name": row["scientific_name"],
            "family": row["family"],
            "rarity_tier": row["rarity_tier"],
            "discovered_at": row["discovered_at"].isoformat() if row["discovered_at"] else None,
            "user_notes": row["user_notes"],
            "is_favorite": row["is_favorite"],
            "plant_article": row["plant_article"],
        }

    async def get_user_collection_stats(self, user_id: int) -> Dict[str, Any]:
        """
        Get collection statistics for a user
        """
        query = "SELECT * FROM gamification.get_user_collection_stats(:user_id)"
        df = await self.execute_query(query, {"user_id": user_id})
        
        if df.empty:
            return {
                "total_collectibles": 0,
                "total_discovered": 0,
                "discovery_percentage": 0.0,
                "common_discovered": 0,
                "uncommon_discovered": 0,
                "rare_discovered": 0,
                "legendary_discovered": 0,
                "favorites_count": 0,
                "recent_discoveries": [],
            }
        
        row = df.iloc[0]
        return {
            "total_collectibles": int(row["total_collectibles"]),
            "total_discovered": int(row["total_discovered"]),
            "discovery_percentage": float(row["discovery_percentage"]) if row["discovery_percentage"] else 0.0,
            "common_discovered": int(row["common_discovered"]),
            "uncommon_discovered": int(row["uncommon_discovered"]),
            "rare_discovered": int(row["rare_discovered"]),
            "legendary_discovered": int(row["legendary_discovered"]),
            "favorites_count": int(row["favorites_count"]),
            "recent_discoveries": row["recent_discoveries"] if row["recent_discoveries"] else [],
        }

    async def get_qr_code_by_token(self, qr_token: UUID) -> Optional[Dict[str, Any]]:
        """
        Get QR code details by token
        """
        query = """
            SELECT qc.id, qc.code_token, qc.plant_species_id, qc.location_id, qc.active,
                   ps.common_name, ps.scientific_name, sl.name as location_name
            FROM gamification.qr_codes qc
            INNER JOIN plants.species ps ON qc.plant_species_id = ps.id
            LEFT JOIN inventory.storage_locations sl ON qc.location_id = sl.id
            WHERE qc.code_token = :qr_token
        """
        df = await self.execute_query(query, {"qr_token": str(qr_token)})
        
        if df.empty:
            return None
        
        row = df.iloc[0]
        return {
            "id": row["id"],
            "code_token": str(row["code_token"]),
            "plant_species_id": row["plant_species_id"],
            "location_id": row["location_id"] if row["location_id"] else None,
            "active": row["active"],
            "common_name": row["common_name"],
            "scientific_name": row["scientific_name"],
            "location_name": row["location_name"] if row["location_name"] else None,
        }

    async def create_qr_code(self, plant_species_id: int, location_id: Optional[int] = None) -> Dict[str, Any]:
        """
        Create a new QR code for a plant species
        """
        query = """
            INSERT INTO gamification.qr_codes (code_token, plant_species_id, location_id)
            VALUES (gen_random_uuid(), :plant_species_id, :location_id)
            RETURNING id, code_token, plant_species_id, location_id, active, created_at
        """
        df = await self.execute_query(query, {"plant_species_id": plant_species_id, "location_id": location_id})
        
        if df.empty:
            raise Exception("Failed to create QR code")
        
        row = df.iloc[0]
        return {
            "id": row["id"],
            "code_token": str(row["code_token"]),
            "plant_species_id": row["plant_species_id"],
            "location_id": row["location_id"] if row["location_id"] else None,
            "active": row["active"],
            "created_at": row["created_at"].isoformat(),
        }

    async def deactivate_qr_code(self, qr_code_id: int) -> bool:
        """
        Deactivate a QR code
        """
        query = """
            UPDATE gamification.qr_codes
            SET active = FALSE
            WHERE id = :qr_code_id
            RETURNING id
        """
        df = await self.execute_query(query, {"qr_code_id": qr_code_id})
        return not df.empty

    async def activate_qr_code(self, qr_code_id: int) -> bool:
        """
        Activate a QR code
        """
        query = """
            UPDATE gamification.qr_codes
            SET active = TRUE
            WHERE id = :qr_code_id
            RETURNING id
        """
        df = await self.execute_query(query, {"qr_code_id": qr_code_id})
        return not df.empty

    async def get_all_qr_codes(self) -> List[Dict[str, Any]]:
        """
        Get all QR codes with detailed plant information
        """
        query = "SELECT * FROM gamification.get_all_qr_codes()"
        df = await self.execute_query(query, {})
        
        if df.empty:
            return []

        return [
            {
                "qr_code_id": row["qr_code_id"],
                "code_token": str(row["code_token"]),
                "plant_species_id": row["species_id"],
                "location_id": row["location_id"] if row.get("location_id") else None,
                "active": row["active"],
                "is_public": row.get("is_public", True),
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                "common_name": row["common_name"],
                "scientific_name": row["scientific_name"],
                "location_name": row.get("location_name"),
                "scan_count": int(row["scan_count"]),
            }
            for _, row in df.iterrows()
        ]

    async def bulk_create_qr_codes(self, plant_species_ids: List[int], location_ids: List[Optional[int]]) -> List[Dict[str, Any]]:
        """
        Bulk create QR codes for multiple plant species
        """
        query = "SELECT * FROM gamification.bulk_create_qr_codes(:plant_species_ids, :location_ids)"
        df = await self.execute_query(query, {"plant_species_ids": plant_species_ids, "location_ids": location_ids})
        
        if df.empty:
            return []
        
        return [
            {
                "id": row["qr_code_id"],
                "code_token": str(row["code_token"]),
                "plant_species_id": row["plant_species_id"],
                "location_id": row["location_id"] if row.get("location_id") else None,
                "active": row["active"],
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            }
            for _, row in df.iterrows()
        ]

    async def get_qr_codes_by_species_and_location(
        self, plant_species_id: int, location_id: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Get all QR codes for a specific plant species and location
        """
        query = "SELECT * FROM gamification.get_qr_codes_by_species_and_location(:plant_species_id, :location_id)"
        df = await self.execute_query(query, {"plant_species_id": plant_species_id, "location_id": location_id})
        
        if df.empty:
            return []
        
        return [
            {
                "id": row["qr_code_id"],
                "code_token": str(row["code_token"]),
                "plant_species_id": plant_species_id,
                "location_id": row.get("location_id"),
                "active": row["active"],
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            }
            for _, row in df.iterrows()
        ]

    async def get_qr_code_by_id(self, qr_code_id: int) -> Optional[Dict[str, Any]]:
        """
        Get QR code details by ID
        """
        query = """
            SELECT id, code_token, plant_species_id, location_id, active, created_at
            FROM gamification.qr_codes
            WHERE id = :qr_code_id
        """
        df = await self.execute_query(query, {"qr_code_id": qr_code_id})
        
        if df.empty:
            return None
        
        row = df.iloc[0]
        return {
            "id": row["id"],
            "code_token": str(row["code_token"]),
            "plant_species_id": row["plant_species_id"],
            "location_id": row["location_id"] if row["location_id"] else None,
            "active": row["active"],
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
        }

    async def get_qr_code_details(self, qr_code_id: int) -> Optional[Dict[str, Any]]:
        """
        Get detailed QR code information including plant details
        """
        query = """
            SELECT qc.id, qc.code_token, qc.plant_species_id, qc.location_id, qc.active, qc.created_at,
                   ps.common_name, ps.scientific_name, sl.name as location_name
            FROM gamification.qr_codes qc
            INNER JOIN plants.species ps ON qc.plant_species_id = ps.id
            LEFT JOIN inventory.storage_locations sl ON qc.location_id = sl.id
            WHERE qc.id = :qr_code_id
        """
        df = await self.execute_query(query, {"qr_code_id": qr_code_id})
        
        if df.empty:
            return None
        
        row = df.iloc[0]
        return {
            "id": row["id"],
            "code_token": str(row["code_token"]),
            "plant_species_id": row["plant_species_id"],
            "location_id": row["location_id"] if row["location_id"] else None,
            "active": row["active"],
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            "common_name": row["common_name"],
            "scientific_name": row["scientific_name"],
            "location_name": row["location_name"] if row.get("location_name") else None,
        }

