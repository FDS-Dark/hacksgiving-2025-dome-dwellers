from typing import List, Optional
from databridge.tasks_databridge import TasksDatabridge
from models.tasks import Task, TaskWithUser


class TasksService:
    def __init__(self, databridge: TasksDatabridge):
        self.databridge = databridge

    async def get_all_tasks(self) -> List[TaskWithUser]:
        """Get all tasks from all users"""
        tasks_data = await self.databridge.get_all_tasks()
        return [TaskWithUser(**task) for task in tasks_data]

    async def get_user_tasks(self, user_id: int) -> List[Task]:
        """Get all tasks for a specific user"""
        tasks_data = await self.databridge.get_user_tasks(user_id)
        return [Task(**task) for task in tasks_data]

    async def create_task(self, user_id: int, text: str) -> Optional[Task]:
        """Create a new task"""
        task_data = await self.databridge.create_task(user_id, text)
        if task_data:
            return Task(**task_data)
        return None

    async def toggle_task(self, task_id: int, user_id: int) -> Optional[Task]:
        """Toggle task completion status"""
        task_data = await self.databridge.toggle_task(task_id, user_id)
        if task_data:
            return Task(**task_data)
        return None

    async def delete_task(self, task_id: int, user_id: int) -> bool:
        """Delete a task"""
        return await self.databridge.delete_task(task_id, user_id)

