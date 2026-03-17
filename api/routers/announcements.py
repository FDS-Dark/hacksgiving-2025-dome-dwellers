from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from models.announcements import Announcement, AnnouncementCreate, AnnouncementUpdate
from services.announcements import AnnouncementsService
from dependencies import get_announcements_service, get_current_user

router = APIRouter(prefix="/announcements", tags=["announcements"])


@router.get("", response_model=List[Announcement])
async def get_all_announcements(
    user=Depends(get_current_user),
    service: AnnouncementsService = Depends(get_announcements_service),
):
    """Get all announcements"""
    return await service.get_all_announcements()


@router.post("", response_model=Announcement, status_code=status.HTTP_201_CREATED)
async def create_announcement(
    announcement: AnnouncementCreate,
    user=Depends(get_current_user),
    service: AnnouncementsService = Depends(get_announcements_service),
):
    """Create a new announcement"""
    created_announcement = await service.create_announcement(
        author_id=user["id"], announcement=announcement
    )
    if not created_announcement:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create announcement",
        )
    return created_announcement


@router.put("/{announcement_id}", response_model=dict)
async def update_announcement(
    announcement_id: int,
    announcement: AnnouncementUpdate,
    user=Depends(get_current_user),
    service: AnnouncementsService = Depends(get_announcements_service),
):
    """Update an announcement (only author can update)"""
    success = await service.update_announcement(
        announcement_id=announcement_id,
        author_id=user["id"],
        announcement=announcement,
    )
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Announcement not found or you are not the author",
        )
    return {"success": True, "message": "Announcement updated successfully"}


@router.delete("/{announcement_id}", response_model=dict)
async def delete_announcement(
    announcement_id: int,
    user=Depends(get_current_user),
    service: AnnouncementsService = Depends(get_announcements_service),
):
    """Delete an announcement (only author can delete)"""
    success = await service.delete_announcement(
        announcement_id=announcement_id, author_id=user["id"]
    )
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Announcement not found or you are not the author",
        )
    return {"success": True, "message": "Announcement deleted successfully"}

