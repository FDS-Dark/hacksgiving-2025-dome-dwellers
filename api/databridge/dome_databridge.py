from databridge.supabase_databridge import SupabaseDatabridge
from engine.supabase_engine import SupabaseDBEngine
from typing import Any, Optional
from structlog import get_logger
import pandas as pd
from datetime import datetime

logger = get_logger()


class DomeDatabridge(SupabaseDatabridge):
    """Databridge for dome-related database operations using Supabase stored procedures"""

    def __init__(self, engine: SupabaseDBEngine) -> None:
        super().__init__(engine)

    # ==================== EVENT OPERATIONS ====================

    async def get_events(
        self,
        event_type: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        location: Optional[str] = None,
        registration_required: Optional[bool] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> pd.DataFrame:
        """Fetch events with optional filters using stored procedure"""
        query = """
            SELECT * FROM dome.get_events(
                :p_event_type,
                :p_start_date,
                :p_end_date,
                :p_location,
                :p_registration_required,
                :p_limit,
                :p_offset
            )
        """
        params = {
            "p_event_type": event_type,
            "p_start_date": start_date,
            "p_end_date": end_date,
            "p_location": location,
            "p_registration_required": registration_required,
            "p_limit": limit,
            "p_offset": offset,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching events: {str(e)}")
            raise

    async def get_event_by_id(self, event_id: int) -> pd.DataFrame:
        """Fetch a single event by ID"""
        query = "SELECT * FROM dome.get_event_by_id(:p_event_id)"
        params = {"p_event_id": event_id}
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching event {event_id}: {str(e)}")
            raise

    async def get_upcoming_events(self, limit: int = 10) -> pd.DataFrame:
        """Fetch upcoming events"""
        query = "SELECT * FROM dome.get_upcoming_events(:p_limit)"
        params = {"p_limit": limit}
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching upcoming events: {str(e)}")
            raise

    async def create_event(
        self,
        title: str,
        event_type: str,
        start_time: datetime,
        end_time: datetime,
        description: Optional[str] = None,
        location: Optional[str] = None,
        capacity: Optional[int] = None,
        registration_required: bool = False,
        registration_url: Optional[str] = None,
        image_url: Optional[str] = None,
        created_by_user_id: Optional[int] = None,
    ) -> pd.DataFrame:
        """Create a new event"""
        query = """
            SELECT * FROM dome.create_event(
                :p_title,
                :p_event_type,
                :p_start_time,
                :p_end_time,
                :p_description,
                :p_location,
                :p_capacity,
                :p_registration_required,
                :p_registration_url,
                :p_image_url,
                :p_created_by_user_id
            )
        """
        params = {
            "p_title": title,
            "p_event_type": event_type,
            "p_start_time": start_time,
            "p_end_time": end_time,
            "p_description": description,
            "p_location": location,
            "p_capacity": capacity,
            "p_registration_required": registration_required,
            "p_registration_url": registration_url,
            "p_image_url": image_url,
            "p_created_by_user_id": created_by_user_id,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error creating event: {str(e)}")
            raise

    async def update_event(
        self,
        event_id: int,
        title: Optional[str] = None,
        description: Optional[str] = None,
        event_type: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        location: Optional[str] = None,
        capacity: Optional[int] = None,
        registration_required: Optional[bool] = None,
        registration_url: Optional[str] = None,
        image_url: Optional[str] = None,
    ) -> pd.DataFrame:
        """Update an existing event"""
        query = """
            SELECT * FROM dome.update_event(
                :p_event_id,
                :p_title,
                :p_description,
                :p_event_type,
                :p_start_time,
                :p_end_time,
                :p_location,
                :p_capacity,
                :p_registration_required,
                :p_registration_url,
                :p_image_url
            )
        """
        params = {
            "p_event_id": event_id,
            "p_title": title,
            "p_description": description,
            "p_event_type": event_type,
            "p_start_time": start_time,
            "p_end_time": end_time,
            "p_location": location,
            "p_capacity": capacity,
            "p_registration_required": registration_required,
            "p_registration_url": registration_url,
            "p_image_url": image_url,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error updating event {event_id}: {str(e)}")
            raise

    async def delete_event(self, event_id: int) -> bool:
        """Delete an event"""
        query = "SELECT dome.delete_event(:p_event_id)"
        params = {"p_event_id": event_id}
        try:
            result = await self.execute_scalar(query, params)
            return bool(result)
        except Exception as e:
            logger.error(f"Error deleting event {event_id}: {str(e)}")
            raise

    async def count_events(
        self,
        event_type: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> int:
        """Count total events matching filters"""
        query = """
            SELECT dome.count_events(
                :p_event_type,
                :p_start_date,
                :p_end_date
            )
        """
        params = {
            "p_event_type": event_type,
            "p_start_date": start_date,
            "p_end_date": end_date,
        }
        try:
            result = await self.execute_scalar(query, params)
            return int(result) if result is not None else 0
        except Exception as e:
            logger.error(f"Error counting events: {str(e)}")
            raise

    # ==================== EVENT REGISTRATION OPERATIONS ====================

    async def create_event_registration(
        self,
        event_id: int,
        attendee_name: str,
        attendee_email: Optional[str] = None,
        attendee_phone: Optional[str] = None,
        notes: Optional[str] = None,
        user_id: Optional[int] = None,
    ) -> pd.DataFrame:
        """Create a new event registration"""
        query = """
            SELECT * FROM dome.create_event_registration(
                :p_event_id,
                :p_attendee_name,
                :p_attendee_email,
                :p_attendee_phone,
                :p_notes,
                :p_user_id
            )
        """
        params = {
            "p_event_id": event_id,
            "p_attendee_name": attendee_name,
            "p_attendee_email": attendee_email,
            "p_attendee_phone": attendee_phone,
            "p_notes": notes,
            "p_user_id": user_id,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error creating event registration: {str(e)}")
            raise

    async def get_event_registrations(
        self,
        event_id: Optional[int] = None,
        user_id: Optional[int] = None,
        status: Optional[str] = None,
    ) -> pd.DataFrame:
        """Get event registrations with optional filters"""
        query = """
            SELECT * FROM dome.get_event_registrations(
                :p_event_id,
                :p_user_id,
                :p_status
            )
        """
        params = {
            "p_event_id": event_id,
            "p_user_id": user_id,
            "p_status": status,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching event registrations: {str(e)}")
            raise

    async def get_registration_by_id(self, registration_id: int) -> pd.DataFrame:
        """Get a single registration by ID"""
        query = "SELECT * FROM dome.get_registration_by_id(:p_registration_id)"
        params = {"p_registration_id": registration_id}
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error fetching registration {registration_id}: {str(e)}")
            raise

    async def count_event_registrations(self, event_id: int, status: str = "registered") -> int:
        """Count registrations for an event"""
        query = """
            SELECT dome.count_event_registrations(
                :p_event_id,
                :p_status
            )
        """
        params = {
            "p_event_id": event_id,
            "p_status": status,
        }
        try:
            result = await self.execute_scalar(query, params)
            return int(result) if result is not None else 0
        except Exception as e:
            logger.error(f"Error counting registrations for event {event_id}: {str(e)}")
            raise

    async def update_registration_status(
        self,
        registration_id: int,
        status: str,
        notes: Optional[str] = None,
    ) -> pd.DataFrame:
        """Update registration status"""
        query = """
            SELECT * FROM dome.update_registration_status(
                :p_registration_id,
                :p_status,
                :p_notes
            )
        """
        params = {
            "p_registration_id": registration_id,
            "p_status": status,
            "p_notes": notes,
        }
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error updating registration {registration_id}: {str(e)}")
            raise

    async def cancel_registration(self, registration_id: int) -> pd.DataFrame:
        """Cancel a registration"""
        query = "SELECT * FROM dome.cancel_registration(:p_registration_id)"
        params = {"p_registration_id": registration_id}
        try:
            return await self.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error cancelling registration {registration_id}: {str(e)}")
            raise

