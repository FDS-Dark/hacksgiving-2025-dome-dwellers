from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from models.tasks import Task, TaskWithUser, CreateTaskRequest
from services.tasks import TasksService
from dependencies import get_tasks_service, get_current_user

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("/all", response_model=List[TaskWithUser])
async def get_all_tasks(
    user=Depends(get_current_user),
    service: TasksService = Depends(get_tasks_service),
):
    """
    Get all tasks from all users.
    Useful for collaborative task viewing.
    """
    return await service.get_all_tasks()


@router.get("/my", response_model=List[Task])
async def get_my_tasks(
    user=Depends(get_current_user),
    service: TasksService = Depends(get_tasks_service),
):
    """
    Get all tasks for the current user.
    """
    return await service.get_user_tasks(user["id"])


@router.post("/", response_model=Task, status_code=status.HTTP_201_CREATED)
async def create_task(
    request: CreateTaskRequest,
    user=Depends(get_current_user),
    service: TasksService = Depends(get_tasks_service),
):
    """
    Create a new task for the current user.
    """
    task = await service.create_task(user["id"], request.text)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create task",
        )
    return task


@router.post("/{task_id}/toggle", response_model=Task)
async def toggle_task(
    task_id: int,
    user=Depends(get_current_user),
    service: TasksService = Depends(get_tasks_service),
):
    """
    Toggle task completion status.
    Only the task owner can toggle their task.
    """
    task = await service.toggle_task(task_id, user["id"])
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found or unauthorized",
        )
    return task


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: int,
    user=Depends(get_current_user),
    service: TasksService = Depends(get_tasks_service),
):
    """
    Delete a task.
    Only the task owner can delete their task.
    """
    success = await service.delete_task(task_id, user["id"])
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found or unauthorized",
        )

