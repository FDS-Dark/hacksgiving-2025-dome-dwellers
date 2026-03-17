from typing import List, Optional, Dict, Any
from uuid import UUID
from databridge.scrapbook_databridge import ScrapbookDatabridge
from models.scrapbook import (
    CollectibleCatalogEntry,
    DiscoveryDetails,
    DiscoveryResponse,
    CollectionStats,
    QRCodeInfo,
)


class ScrapbookService:
    def __init__(self, databridge: ScrapbookDatabridge):
        self.databridge = databridge

    async def get_user_catalog(self, user_id: int) -> List[CollectibleCatalogEntry]:
        """Get the full collectible catalog with user's discovery status"""
        catalog_data = await self.databridge.get_user_collectible_catalog(user_id)
        return [CollectibleCatalogEntry(**entry) for entry in catalog_data]

    async def scan_qr_code(self, user_id: int, qr_token: UUID) -> DiscoveryResponse:
        """Process a QR code scan and record discovery"""
        result = await self.databridge.discover_plant_from_qr(user_id, qr_token)
        return DiscoveryResponse(**result)

    async def get_discovery_details(
        self, user_id: int, catalog_entry_id: int
    ) -> Optional[DiscoveryDetails]:
        """Get detailed information about a specific discovery"""
        details = await self.databridge.get_discovery_details(user_id, catalog_entry_id)
        if details:
            return DiscoveryDetails(**details)
        return None

    async def update_discovery_notes(
        self, user_id: int, discovery_id: int, notes: str
    ) -> bool:
        """Update personal notes for a discovery"""
        return await self.databridge.update_discovery_notes(user_id, discovery_id, notes)

    async def toggle_favorite(self, user_id: int, discovery_id: int) -> bool:
        """Toggle favorite status for a discovery"""
        return await self.databridge.toggle_discovery_favorite(user_id, discovery_id)

    async def get_collection_stats(self, user_id: int) -> CollectionStats:
        """Get user's collection statistics"""
        stats_data = await self.databridge.get_user_collection_stats(user_id)
        return CollectionStats(**stats_data)

    async def get_qr_info(self, qr_token: UUID) -> Optional[QRCodeInfo]:
        """Get information about a QR code"""
        qr_data = await self.databridge.get_qr_code_by_token(qr_token)
        if qr_data:
            return QRCodeInfo(**qr_data)
        return None

    async def create_qr_code(self, species_id: int) -> QRCodeInfo:
        """Create a new QR code for a plant species"""
        qr_data = await self.databridge.create_qr_code(species_id)
        return QRCodeInfo(**qr_data)

    async def deactivate_qr_code(self, qr_code_id: int) -> bool:
        """Deactivate a QR code"""
        return await self.databridge.deactivate_qr_code(qr_code_id)

