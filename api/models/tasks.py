from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class Task(BaseModel):
    id: int
    user_id: int
    text: str
    completed: bool
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None


class TaskWithUser(BaseModel):
    id: int
    user_id: int
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    text: str
    completed: bool
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None


class CreateTaskRequest(BaseModel):
    text: str = Field(..., min_length=1, description="The task text")


class UpdateTaskRequest(BaseModel):
    text: Optional[str] = Field(None, min_length=1, description="The task text")
    completed: Optional[bool] = Field(None, description="Task completion status")

