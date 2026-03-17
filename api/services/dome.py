from databridge.dome_databridge import DomeDatabridge
from models.dome import (
    Event,
    EventCreate,
    EventUpdate,
    EventListResponse,
    EventFilters,
    EventRegistration,
    EventRegistrationCreate,
    EventRegistrationUpdate,
    EventWithRegistrationCount,
)
from structlog import get_logger
from typing import Optional
from fastapi import HTTPException

logger = get_logger()


class DomeService:
    """Service layer for dome-related operations"""

    def __init__(self, databridge: DomeDatabridge):
        self.databridge = databridge

    async def get_events(self, filters: EventFilters) -> EventListResponse:
        """
        Get list of events with optional filters
        
        Args:
            filters: EventFilters model with filter criteria
            
        Returns:
            EventListResponse with events and total count
        """
        try:
            # Fetch events from database
            events_df = await self.databridge.get_events(
                event_type=filters.event_type,
                start_date=filters.start_date,
                end_date=filters.end_date,
                location=filters.location,
                registration_required=filters.registration_required,
                limit=filters.limit,
                offset=filters.offset,
            )
            
            # Get total count for pagination
            total = await self.databridge.count_events(
                event_type=filters.event_type,
                start_date=filters.start_date,
                end_date=filters.end_date,
            )
            
            # Convert DataFrame to Event models
            events = []
            if not events_df.empty:
                for _, row in events_df.iterrows():
                    events.append(Event(**row.to_dict()))
            
            return EventListResponse(events=events, total=total)
            
        except Exception as e:
            logger.error(f"Error in get_events service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch events")

    async def get_event_by_id(self, event_id: int) -> Event:
        """
        Get a single event by ID
        
        Args:
            event_id: The event ID
            
        Returns:
            Event model
            
        Raises:
            HTTPException: 404 if event not found
        """
        try:
            event_df = await self.databridge.get_event_by_id(event_id)
            
            if event_df.empty:
                raise HTTPException(status_code=404, detail=f"Event {event_id} not found")
            
            return Event(**event_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in get_event_by_id service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch event")

    async def get_upcoming_events(self, limit: int = 10) -> list[Event]:
        """
        Get upcoming events
        
        Args:
            limit: Maximum number of events to return
            
        Returns:
            List of Event models
        """
        try:
            events_df = await self.databridge.get_upcoming_events(limit=limit)
            
            events = []
            if not events_df.empty:
                for _, row in events_df.iterrows():
                    events.append(Event(**row.to_dict()))
            
            return events
            
        except Exception as e:
            logger.error(f"Error in get_upcoming_events service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch upcoming events")

    async def create_event(self, event_data: EventCreate) -> Event:
        """
        Create a new event
        
        Args:
            event_data: EventCreate model with event data
            
        Returns:
            Created Event model
        """
        try:
            # Validate end_time > start_time
            if event_data.end_time <= event_data.start_time:
                raise HTTPException(
                    status_code=400,
                    detail="End time must be after start time"
                )
            
            event_df = await self.databridge.create_event(
                title=event_data.title,
                description=event_data.description,
                event_type=event_data.event_type,
                start_time=event_data.start_time,
                end_time=event_data.end_time,
                location=event_data.location,
                capacity=event_data.capacity,
                registration_required=event_data.registration_required,
                registration_url=event_data.registration_url,
                image_url=event_data.image_url,
                created_by_user_id=event_data.created_by_user_id,
            )
            
            if event_df.empty:
                raise HTTPException(status_code=500, detail="Failed to create event")
            
            return Event(**event_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in create_event service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to create event")

    async def update_event(self, event_id: int, event_data: EventUpdate) -> Event:
        """
        Update an existing event
        
        Args:
            event_id: The event ID to update
            event_data: EventUpdate model with updated data
            
        Returns:
            Updated Event model
            
        Raises:
            HTTPException: 404 if event not found
        """
        try:
            # Check if event exists
            existing_event = await self.get_event_by_id(event_id)
            
            # Validate times if both are being updated
            start = event_data.start_time if event_data.start_time else existing_event.start_time
            end = event_data.end_time if event_data.end_time else existing_event.end_time
            
            if end <= start:
                raise HTTPException(
                    status_code=400,
                    detail="End time must be after start time"
                )
            
            event_df = await self.databridge.update_event(
                event_id=event_id,
                title=event_data.title,
                description=event_data.description,
                event_type=event_data.event_type,
                start_time=event_data.start_time,
                end_time=event_data.end_time,
                location=event_data.location,
                capacity=event_data.capacity,
                registration_required=event_data.registration_required,
                registration_url=event_data.registration_url,
                image_url=event_data.image_url,
            )
            
            if event_df.empty:
                raise HTTPException(status_code=404, detail=f"Event {event_id} not found")
            
            return Event(**event_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in update_event service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to update event")

    async def delete_event(self, event_id: int) -> dict:
        """
        Delete an event
        
        Args:
            event_id: The event ID to delete
            
        Returns:
            Success message
            
        Raises:
            HTTPException: 404 if event not found
        """
        try:
            # Check if event exists
            await self.get_event_by_id(event_id)
            
            await self.databridge.delete_event(event_id)
            
            return {"message": f"Event {event_id} deleted successfully"}
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in delete_event service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to delete event")

    async def get_event_with_registration_info(self, event_id: int) -> EventWithRegistrationCount:
        """
        Get event with registration count and availability
        
        Args:
            event_id: The event ID
            
        Returns:
            EventWithRegistrationCount model
        """
        try:
            event = await self.get_event_by_id(event_id)
            registration_count = await self.databridge.count_event_registrations(event_id)
            
            is_full = False
            if event.capacity:
                is_full = registration_count >= event.capacity
            
            return EventWithRegistrationCount(
                **event.dict(),
                registration_count=registration_count,
                is_full=is_full,
            )
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in get_event_with_registration_info service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch event information")

    # ==================== EVENT REGISTRATION METHODS ====================

    async def register_for_event(
        self,
        registration_data: EventRegistrationCreate,
        user_id: Optional[int] = None,
    ) -> EventRegistration:
        """
        Register a user or guest for an event
        
        Args:
            registration_data: Registration information
            user_id: Optional authenticated user ID
            
        Returns:
            Created EventRegistration model
        """
        try:
            # Check if event exists and has capacity
            event = await self.get_event_by_id(registration_data.event_id)
            
            # Check if event requires registration
            if not event.registration_required:
                raise HTTPException(
                    status_code=400,
                    detail="This event does not require registration"
                )
            
            # Check capacity
            if event.capacity:
                registration_count = await self.databridge.count_event_registrations(
                    registration_data.event_id
                )
                if registration_count >= event.capacity:
                    raise HTTPException(
                        status_code=400,
                        detail="This event is full"
                    )
            
            # Create registration
            registration_df = await self.databridge.create_event_registration(
                event_id=registration_data.event_id,
                attendee_name=registration_data.attendee_name,
                attendee_email=registration_data.attendee_email,
                attendee_phone=registration_data.attendee_phone,
                notes=registration_data.notes,
                user_id=user_id,
            )
            
            if registration_df.empty:
                raise HTTPException(status_code=500, detail="Failed to create registration")
            
            return EventRegistration(**registration_df.iloc[0].to_dict())
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in register_for_event service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to register for event")

    async def get_user_registrations(self, user_id: int) -> list[EventRegistration]:
        """Get all registrations for a user"""
        try:
            registrations_df = await self.databridge.get_event_registrations(user_id=user_id)
            
            registrations = []
            if not registrations_df.empty:
                for _, row in registrations_df.iterrows():
                    registrations.append(EventRegistration(**row.to_dict()))
            
            return registrations
            
        except Exception as e:
            logger.error(f"Error in get_user_registrations service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch registrations")

    async def get_event_registrations(self, event_id: int) -> list[EventRegistration]:
        """Get all registrations for an event"""
        try:
            registrations_df = await self.databridge.get_event_registrations(event_id=event_id)
            
            registrations = []
            if not registrations_df.empty:
                for _, row in registrations_df.iterrows():
                    registrations.append(EventRegistration(**row.to_dict()))
            
            return registrations
            
        except Exception as e:
            logger.error(f"Error in get_event_registrations service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to fetch event registrations")

    async def cancel_registration(self, registration_id: int, user_id: Optional[int] = None) -> dict:
        """
        Cancel a registration
        
        Args:
            registration_id: The registration ID to cancel
            user_id: Optional user ID for authorization check
            
        Returns:
            Success message
        """
        try:
            # Get registration to verify ownership
            registration_df = await self.databridge.get_registration_by_id(registration_id)
            
            if registration_df.empty:
                raise HTTPException(status_code=404, detail="Registration not found")
            
            registration = registration_df.iloc[0]
            
            # Check if user owns this registration (if user_id provided)
            if user_id is not None and registration["user_id"] != user_id:
                raise HTTPException(
                    status_code=403,
                    detail="You are not authorized to cancel this registration"
                )
            
            # Cancel the registration
            await self.databridge.cancel_registration(registration_id)
            
            return {"message": "Registration cancelled successfully"}
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error in cancel_registration service: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to cancel registration")

