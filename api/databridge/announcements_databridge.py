from typing import List, Dict, Any, Optional
from databridge.supabase_databridge import SupabaseDatabridge


class AnnouncementsDatabridge(SupabaseDatabridge):
    """Databridge for announcements operations"""

    async def get_all_announcements(self) -> List[Dict[str, Any]]:
        """Get all announcements with author details"""
        query = "SELECT * FROM announcements.get_all_announcements()"
        df = await self.execute_query(query, {})
        
        if df.empty:
            return []
        
        return [
            {
                "id": row["id"],
                "title": row["title"],
                "message": row["message"],
                "author_id": row["author_id"],
                "author_name": row["author_name"],
                "author_email": row["author_email"],
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
            }
            for _, row in df.iterrows()
        ]

    async def create_announcement(
        self, author_id: int, title: str, message: str
    ) -> Optional[Dict[str, Any]]:
        """Create a new announcement"""
        query = "SELECT * FROM announcements.create_announcement(:author_id, :title, :message)"
        df = await self.execute_query(
            query, {"author_id": author_id, "title": title, "message": message}
        )
        
        if df.empty:
            return None
        
        row = df.iloc[0]
        return {
            "id": row["id"],
            "title": row["title"],
            "message": row["message"],
            "author_id": row["author_id"],
            "author_name": row["author_name"],
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
        }

    async def update_announcement(
        self, announcement_id: int, author_id: int, title: str, message: str
    ) -> bool:
        """Update an announcement (only if author matches)"""
        query = "SELECT announcements.update_announcement(:announcement_id, :author_id, :title, :message) as result"
        result = await self.execute_scalar(
            query,
            {
                "announcement_id": announcement_id,
                "author_id": author_id,
                "title": title,
                "message": message,
            },
        )
        return bool(result)

    async def delete_announcement(
        self, announcement_id: int, author_id: int
    ) -> bool:
        """Delete an announcement (only if author matches)"""
        query = "SELECT announcements.delete_announcement(:announcement_id, :author_id) as result"
        result = await self.execute_scalar(
            query, {"announcement_id": announcement_id, "author_id": author_id}
        )
        return bool(result)

