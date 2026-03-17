from typing import Optional, List, Dict, Any
from databridge.supabase_databridge import SupabaseDatabridge


class TasksDatabridge(SupabaseDatabridge):
    """Databridge for task management operations"""

    async def get_all_tasks(self) -> List[Dict[str, Any]]:
        """
        Get all tasks from all users
        """
        query = "SELECT * FROM tasks.get_all_tasks()"
        df = await self.execute_query(query)
        
        if df.empty:
            return []
        
        return [
            {
                "id": int(row["id"]),
                "user_id": int(row["user_id"]),
                "user_name": row["user_name"],
                "user_email": row["user_email"],
                "text": row["text"],
                "completed": bool(row["completed"]),
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
                "completed_at": row["completed_at"].isoformat() if row["completed_at"] else None,
            }
            for _, row in df.iterrows()
        ]

    async def get_user_tasks(self, user_id: int) -> List[Dict[str, Any]]:
        """
        Get all tasks for a specific user
        """
        query = "SELECT * FROM tasks.get_user_tasks(:user_id)"
        df = await self.execute_query(query, {"user_id": user_id})
        
        if df.empty:
            return []
        
        return [
            {
                "id": int(row["id"]),
                "user_id": int(row["user_id"]),
                "text": row["text"],
                "completed": bool(row["completed"]),
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
                "completed_at": row["completed_at"].isoformat() if row["completed_at"] else None,
            }
            for _, row in df.iterrows()
        ]

    async def create_task(self, user_id: int, text: str) -> Optional[Dict[str, Any]]:
        """
        Create a new task
        """
        query = "SELECT * FROM tasks.create_task(:user_id, :text)"
        df = await self.execute_query(query, {"user_id": user_id, "text": text})
        
        if df.empty:
            return None
        
        row = df.iloc[0]
        return {
            "id": int(row["id"]),
            "user_id": int(row["user_id"]),
            "text": row["text"],
            "completed": bool(row["completed"]),
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
            "completed_at": row["completed_at"].isoformat() if row["completed_at"] else None,
        }

    async def toggle_task(self, task_id: int, user_id: int) -> Optional[Dict[str, Any]]:
        """
        Toggle task completion status
        """
        query = "SELECT * FROM tasks.toggle_task(:task_id, :user_id)"
        df = await self.execute_query(query, {"task_id": task_id, "user_id": user_id})
        
        if df.empty:
            return None
        
        row = df.iloc[0]
        return {
            "id": int(row["id"]),
            "user_id": int(row["user_id"]),
            "text": row["text"],
            "completed": bool(row["completed"]),
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
            "completed_at": row["completed_at"].isoformat() if row["completed_at"] else None,
        }

    async def delete_task(self, task_id: int, user_id: int) -> bool:
        """
        Delete a task
        """
        query = "SELECT tasks.delete_task(:task_id, :user_id) as result"
        result = await self.execute_scalar(query, {"task_id": task_id, "user_id": user_id})
        return bool(result)

