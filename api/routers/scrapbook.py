from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from uuid import UUID

from models.scrapbook import (
    CollectibleCatalogEntry,
    DiscoveryDetails,
    DiscoveryResponse,
    CollectionStats,
    UpdateNotesRequest,
    ScanQRRequest,
    QRCodeInfo,
)
from services.scrapbook import ScrapbookService
from dependencies import get_scrapbook_service, get_current_user

router = APIRouter(prefix="/scrapbook", tags=["scrapbook"])


@router.get("/catalog", response_model=List[CollectibleCatalogEntry])
async def get_collectible_catalog(
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Get the full collectible catalog with user's discovery status.
    Shows all plants available to collect and which ones the user has discovered.
    """
    return await service.get_user_catalog(user["id"])


@router.post("/scan", response_model=DiscoveryResponse)
async def scan_qr_code(
    request: ScanQRRequest,
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Scan a QR code to discover a plant.
    Records the discovery in the user's scrapbook if not already discovered.
    """
    return await service.scan_qr_code(user["id"], request.qr_token)


@router.get("/discovery/{catalog_entry_id}", response_model=Optional[DiscoveryDetails])
async def get_discovery_details(
    catalog_entry_id: int,
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Get detailed information about a discovered plant.
    Returns None if the plant hasn't been discovered by the user yet.
    """
    details = await service.get_discovery_details(user["id"], catalog_entry_id)
    if not details:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Discovery not found or plant not yet discovered",
        )
    return details


@router.put("/discovery/{discovery_id}/notes", response_model=dict)
async def update_discovery_notes(
    discovery_id: int,
    request: UpdateNotesRequest,
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Update personal notes for a discovered plant.
    """
    success = await service.update_discovery_notes(
        user["id"], discovery_id, request.notes
    )
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Discovery not found or unauthorized",
        )
    return {"success": True, "message": "Notes updated successfully"}


@router.post("/discovery/{discovery_id}/favorite", response_model=dict)
async def toggle_discovery_favorite(
    discovery_id: int,
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Toggle the favorite status of a discovered plant.
    Returns the new favorite status.
    """
    new_status = await service.toggle_favorite(user["id"], discovery_id)
    return {"success": True, "is_favorite": new_status}


@router.get("/stats", response_model=CollectionStats)
async def get_collection_stats(
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Get statistics about the user's plant collection.
    Includes total counts, percentages, and rarity breakdowns.
    """
    return await service.get_collection_stats(user["id"])


@router.get("/qr/{qr_token}", response_model=QRCodeInfo)
async def get_qr_info(
    qr_token: UUID,
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Get information about a QR code (public endpoint for previewing before scan).
    """
    qr_info = await service.get_qr_info(qr_token)
    if not qr_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code not found",
        )
    return qr_info


@router.post("/qr/create", response_model=QRCodeInfo)
async def create_qr_code(
    species_id: int,
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Create a new QR code for a plant species.
    Admin/staff endpoint for generating QR codes.
    """
    return await service.create_qr_code(species_id)


@router.post("/qr/{qr_code_id}/deactivate", response_model=dict)
async def deactivate_qr_code(
    qr_code_id: int,
    user=Depends(get_current_user),
    service: ScrapbookService = Depends(get_scrapbook_service),
):
    """
    Deactivate a QR code.
    Admin/staff endpoint for managing QR codes.
    """
    success = await service.deactivate_qr_code(qr_code_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code not found",
        )
    return {"success": True, "message": "QR code deactivated"}

