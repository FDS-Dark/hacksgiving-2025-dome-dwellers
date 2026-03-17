from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, Literal

# Event Types
EventType = Literal["tour", "class", "exhibition", "special_event", "other"]


# Event Models
class EventBase(BaseModel):
    """Base event model with common fields"""
    title: str
    description: Optional[str] = None
    event_type: EventType
    start_time: datetime
    end_time: datetime
    location: Optional[str] = None
    capacity: Optional[int] = None
    registration_required: bool = False
    registration_url: Optional[str] = None
    image_url: Optional[str] = None


class EventCreate(EventBase):
    """Model for creating a new event"""
    created_by_user_id: Optional[int] = None


class EventUpdate(BaseModel):
    """Model for updating an event (all fields optional)"""
    title: Optional[str] = None
    description: Optional[str] = None
    event_type: Optional[EventType] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    capacity: Optional[int] = None
    registration_required: Optional[bool] = None
    registration_url: Optional[str] = None
    image_url: Optional[str] = None


class Event(EventBase):
    """Full event model with database fields"""
    id: int
    created_by_user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class EventListResponse(BaseModel):
    """Response model for listing events"""
    events: list[Event]
    total: int


class EventFilters(BaseModel):
    """Model for filtering events"""
    event_type: Optional[EventType] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    location: Optional[str] = None
    registration_required: Optional[bool] = None
    limit: int = Field(default=50, ge=1, le=100)
    offset: int = Field(default=0, ge=0)


# Event Registration Models
RegistrationStatus = Literal["registered", "attended", "cancelled", "no_show"]


class EventRegistrationCreate(BaseModel):
    """Model for creating an event registration"""
    event_id: int
    attendee_name: str = Field(..., min_length=1, max_length=255)
    attendee_email: Optional[str] = Field(None, max_length=255)
    attendee_phone: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = None


class EventRegistrationUpdate(BaseModel):
    """Model for updating an event registration"""
    status: Optional[RegistrationStatus] = None
    notes: Optional[str] = None


class EventRegistration(BaseModel):
    """Full event registration model"""
    id: int
    event_id: int
    user_id: Optional[int] = None
    attendee_name: str
    attendee_email: Optional[str] = None
    attendee_phone: Optional[str] = None
    registration_time: datetime
    status: RegistrationStatus
    notes: Optional[str] = None

    class Config:
        from_attributes = True


class EventRegistrationWithEvent(EventRegistration):
    """Event registration with event details"""
    event: Event


class EventWithRegistrationCount(Event):
    """Event with registration count"""
    registration_count: int
    is_full: bool

