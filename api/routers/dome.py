from fastapi import APIRouter, Depends, Query
from services.dome import DomeService
from models.dome import (
    Event,
    EventCreate,
    EventUpdate,
    EventListResponse,
    EventFilters,
    EventType,
    EventRegistration,
    EventRegistrationCreate,
    EventWithRegistrationCount,
)
from dependencies import get_dome_service
from typing import Optional
from datetime import datetime

router = APIRouter(prefix="/dome", tags=["dome"])


@router.get("/events", response_model=EventListResponse)
async def get_events(
    event_type: Optional[EventType] = Query(None, description="Filter by event type"),
    start_date: Optional[datetime] = Query(None, description="Filter events starting after this date"),
    end_date: Optional[datetime] = Query(None, description="Filter events ending before this date"),
    location: Optional[str] = Query(None, description="Filter by location (partial match)"),
    registration_required: Optional[bool] = Query(None, description="Filter by registration requirement"),
    limit: int = Query(50, ge=1, le=100, description="Maximum number of events to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    service: DomeService = Depends(get_dome_service),
) -> EventListResponse:
    """
    Get list of events with optional filters
    
    - **event_type**: Filter by event type (tour, class, exhibition, special_event, other)
    - **start_date**: Get events starting after this date
    - **end_date**: Get events ending before this date
    - **location**: Filter by location (case-insensitive partial match)
    - **registration_required**: Filter by registration requirement
    - **limit**: Maximum events to return (1-100, default 50)
    - **offset**: Pagination offset (default 0)
    """
    filters = EventFilters(
        event_type=event_type,
        start_date=start_date,
        end_date=end_date,
        location=location,
        registration_required=registration_required,
        limit=limit,
        offset=offset,
    )
    return await service.get_events(filters)


@router.get("/events/upcoming", response_model=list[Event])
async def get_upcoming_events(
    limit: int = Query(10, ge=1, le=50, description="Maximum number of events to return"),
    service: DomeService = Depends(get_dome_service),
) -> list[Event]:
    """
    Get upcoming events (starting from now)
    
    - **limit**: Maximum events to return (1-50, default 10)
    """
    return await service.get_upcoming_events(limit=limit)


@router.get("/events/{event_id}", response_model=Event)
async def get_event(
    event_id: int,
    service: DomeService = Depends(get_dome_service),
) -> Event:
    """
    Get a single event by ID
    
    - **event_id**: The event ID
    """
    return await service.get_event_by_id(event_id)


@router.post("/events", response_model=Event, status_code=201)
async def create_event(
    event_data: EventCreate,
    service: DomeService = Depends(get_dome_service),
) -> Event:
    """
    Create a new event
    
    **Required fields:**
    - **title**: Event title
    - **event_type**: Type of event (tour, class, exhibition, special_event, other)
    - **start_time**: Event start time (ISO 8601 format)
    - **end_time**: Event end time (must be after start_time)
    
    **Optional fields:**
    - **description**: Event description
    - **location**: Event location
    - **capacity**: Maximum attendees
    - **registration_required**: Whether registration is required (default: false)
    - **registration_url**: External registration URL
    - **image_url**: Event image URL
    - **created_by_user_id**: ID of staff member creating the event
    """
    return await service.create_event(event_data)


@router.put("/events/{event_id}", response_model=Event)
async def update_event(
    event_id: int,
    event_data: EventUpdate,
    service: DomeService = Depends(get_dome_service),
) -> Event:
    """
    Update an existing event
    
    All fields are optional - only provided fields will be updated.
    
    - **event_id**: The event ID to update
    - **event_data**: Fields to update
    """
    return await service.update_event(event_id, event_data)


@router.patch("/events/{event_id}", response_model=Event)
async def patch_event(
    event_id: int,
    event_data: EventUpdate,
    service: DomeService = Depends(get_dome_service),
) -> Event:
    """
    Partially update an existing event (alias for PUT)
    
    - **event_id**: The event ID to update
    - **event_data**: Fields to update
    """
    return await service.update_event(event_id, event_data)


@router.delete("/events/{event_id}")
async def delete_event(
    event_id: int,
    service: DomeService = Depends(get_dome_service),
) -> dict:
    """
    Delete an event
    
    - **event_id**: The event ID to delete
    """
    return await service.delete_event(event_id)


@router.get("/events/{event_id}/details", response_model=EventWithRegistrationCount)
async def get_event_details(
    event_id: int,
    service: DomeService = Depends(get_dome_service),
) -> EventWithRegistrationCount:
    """
    Get event with registration information (count, availability)
    
    - **event_id**: The event ID
    """
    return await service.get_event_with_registration_info(event_id)


# ==================== EVENT REGISTRATION ENDPOINTS ====================

@router.post("/events/{event_id}/register", response_model=EventRegistration, status_code=201)
async def register_for_event(
    event_id: int,
    registration_data: EventRegistrationCreate,
    service: DomeService = Depends(get_dome_service),
) -> EventRegistration:
    """
    Register for an event
    
    **Note:** Authentication not required, but authenticated users will have their user_id linked.
    
    **Required fields:**
    - **attendee_name**: Name of the person attending
    
    **Optional fields:**
    - **attendee_email**: Email address
    - **attendee_phone**: Phone number
    - **notes**: Additional notes or special requirements
    """
    # Override event_id from path
    registration_data.event_id = event_id
    
    # TODO: Extract user_id from JWT if authenticated
    # For now, allow anonymous registrations
    user_id = None
    
    return await service.register_for_event(registration_data, user_id=user_id)


@router.get("/registrations/my", response_model=list[EventRegistration])
async def get_my_registrations(
    service: DomeService = Depends(get_dome_service),
) -> list[EventRegistration]:
    """
    Get all registrations for the authenticated user
    
    **Requires authentication**
    """
    # TODO: Extract user_id from JWT
    user_id = 1  # Placeholder
    return await service.get_user_registrations(user_id)


@router.get("/events/{event_id}/registrations", response_model=list[EventRegistration])
async def get_event_registrations_list(
    event_id: int,
    service: DomeService = Depends(get_dome_service),
) -> list[EventRegistration]:
    """
    Get all registrations for an event
    
    **Requires admin/staff authentication**
    """
    return await service.get_event_registrations(event_id)


@router.delete("/registrations/{registration_id}")
async def cancel_event_registration(
    registration_id: int,
    service: DomeService = Depends(get_dome_service),
) -> dict:
    """
    Cancel a registration
    
    Users can only cancel their own registrations.
    """
    # TODO: Extract user_id from JWT if authenticated
    user_id = None  # Allow cancellation if user_id matches
    
    return await service.cancel_registration(registration_id, user_id=user_id)
