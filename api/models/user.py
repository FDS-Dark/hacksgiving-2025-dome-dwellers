from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime


class Role(BaseModel):
    """User role model"""
    id: int
    name: str


class User(BaseModel):
    """Complete user model with roles"""
    id: int
    auth0_user_id: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    name: Optional[str] = None
    given_name: Optional[str] = None
    family_name: Optional[str] = None
    picture_url: Optional[str] = None
    locale: Optional[str] = None
    is_active: bool = True
    roles: List[Role] = []
    created_at: datetime
    updated_at: datetime


class UserProfile(BaseModel):
    """User profile for /me endpoint"""
    id: int
    auth0_user_id: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    name: Optional[str] = None
    given_name: Optional[str] = None
    family_name: Optional[str] = None
    picture_url: Optional[str] = None
    locale: Optional[str] = None
    roles: List[str] = []
    created_at: datetime
    updated_at: datetime

