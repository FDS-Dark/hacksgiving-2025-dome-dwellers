from typing import List, Optional
from databridge.announcements_databridge import AnnouncementsDatabridge
from models.announcements import Announcement, AnnouncementCreate, AnnouncementUpdate


class AnnouncementsService:
    def __init__(self, databridge: AnnouncementsDatabridge):
        self.databridge = databridge

    async def get_all_announcements(self) -> List[Announcement]:
        """Get all announcements"""
        announcements_data = await self.databridge.get_all_announcements()
        return [Announcement(**announcement) for announcement in announcements_data]

    async def create_announcement(
        self, author_id: int, announcement: AnnouncementCreate
    ) -> Optional[Announcement]:
        """Create a new announcement"""
        announcement_data = await self.databridge.create_announcement(
            author_id=author_id,
            title=announcement.title,
            message=announcement.message,
        )
        if announcement_data:
            return Announcement(**announcement_data)
        return None

    async def update_announcement(
        self, announcement_id: int, author_id: int, announcement: AnnouncementUpdate
    ) -> bool:
        """Update an announcement"""
        return await self.databridge.update_announcement(
            announcement_id=announcement_id,
            author_id=author_id,
            title=announcement.title,
            message=announcement.message,
        )

    async def delete_announcement(
        self, announcement_id: int, author_id: int
    ) -> bool:
        """Delete an announcement"""
        return await self.databridge.delete_announcement(
            announcement_id=announcement_id, author_id=author_id
        )

