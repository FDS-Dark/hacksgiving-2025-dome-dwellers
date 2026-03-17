from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.responses import StreamingResponse
from typing import List, Optional
import io

from models.scrapbook import (
    QRCodeDetail,
    QRCodeCreateRequest,
    QRCodeBulkCreateRequest,
    QRCodeBulkCreateResponse,
    QRCodeInfo,
)
from services.qr_admin import QRAdminService
from dependencies import get_qr_admin_service, get_current_user, get_optional_current_user

router = APIRouter(prefix="/admin/qr", tags=["qr-admin"])


@router.get("/codes", response_model=List[QRCodeDetail])
async def list_all_qr_codes(
    user=Depends(get_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    List all QR codes with detailed plant information.
    Admin endpoint for QR code management.
    """
    return await service.get_all_qr_codes()


@router.post("/codes", response_model=QRCodeInfo)
async def create_qr_code(
    request: QRCodeCreateRequest,
    user=Depends(get_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Create a new QR code for a plant species.
    Admin endpoint for generating QR codes.
    """
    return await service.create_qr_code(request.species_id, request.location_id)


@router.post("/codes/bulk", response_model=QRCodeBulkCreateResponse)
async def bulk_create_qr_codes(
    request: QRCodeBulkCreateRequest,
    user=Depends(get_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Bulk create QR codes for multiple plant species.
    Admin endpoint for batch QR code generation.
    """
    return await service.bulk_create_qr_codes(request.species_ids, request.location_ids)


@router.get("/codes/{qr_code_id}/image")
async def get_qr_code_image(
    qr_code_id: int,
    token: Optional[str] = Query(None),
    user=Depends(get_optional_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Generate and download a QR code image.
    Returns a PNG image of the QR code with deep link.
    Accepts authentication via header or ?token= query parameter.
    """
    if user is None or (hasattr(user, 'empty') and user.empty):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    
    image_bytes = await service.generate_qr_code_image(qr_code_id)
    
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code not found",
        )
    
    return StreamingResponse(
        io.BytesIO(image_bytes),
        media_type="image/png",
        headers={
            "Content-Disposition": f"attachment; filename=qr_code_{qr_code_id}.png"
        }
    )


@router.get("/codes/{qr_code_id}/image-with-label")
async def get_qr_code_image_with_label(
    qr_code_id: int,
    token: Optional[str] = Query(None),
    user=Depends(get_optional_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Generate and download a QR code image with plant information label.
    Returns a PNG image of the QR code with plant name and details.
    Accepts authentication via header or ?token= query parameter.
    """
    if user is None or (hasattr(user, 'empty') and user.empty):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    
    image_bytes = await service.generate_qr_code_image_with_label(qr_code_id)
    
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code not found",
        )
    
    return StreamingResponse(
        io.BytesIO(image_bytes),
        media_type="image/png",
        headers={
            "Content-Disposition": f"attachment; filename=qr_code_labeled_{qr_code_id}.png"
        }
    )


@router.post("/codes/export-all")
async def export_all_qr_codes(
    user=Depends(get_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Export all QR codes as a ZIP file containing individual PNG images.
    Each image is labeled with plant information.
    """
    zip_bytes = await service.export_all_qr_codes()
    
    return StreamingResponse(
        io.BytesIO(zip_bytes),
        media_type="application/zip",
        headers={
            "Content-Disposition": "attachment; filename=qr_codes_export.zip"
        }
    )


@router.delete("/codes/{qr_code_id}")
async def deactivate_qr_code(
    qr_code_id: int,
    user=Depends(get_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Deactivate a QR code.
    Admin endpoint for disabling QR codes.
    """
    success = await service.deactivate_qr_code(qr_code_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code not found",
        )
    return {"success": True, "message": "QR code deactivated"}


@router.post("/codes/{qr_code_id}/activate")
async def activate_qr_code(
    qr_code_id: int,
    user=Depends(get_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Activate a previously deactivated QR code.
    Admin endpoint for re-enabling QR codes.
    """
    success = await service.activate_qr_code(qr_code_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code not found",
        )
    return {"success": True, "message": "QR code activated"}


@router.get("/species/{species_id}/code", response_model=QRCodeInfo)
async def get_qr_code_for_species(
    species_id: int,
    user=Depends(get_current_user),
    service: QRAdminService = Depends(get_qr_admin_service),
):
    """
    Get the QR code associated with a specific plant species.
    """
    qr_code = await service.get_qr_code_by_species(species_id)
    if not qr_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code not found for this species",
        )
    return qr_code

