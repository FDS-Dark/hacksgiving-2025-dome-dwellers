from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class AnnouncementBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    message: str = Field(..., min_length=1)


class AnnouncementCreate(AnnouncementBase):
    pass


class AnnouncementUpdate(AnnouncementBase):
    pass


class Announcement(AnnouncementBase):
    id: int
    author_id: int
    author_name: str
    author_email: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class AnnouncementListItem(BaseModel):
    id: int
    title: str
    message: str
    author_id: int
    author_name: str
    created_at: datetime
    updated_at: datetime

