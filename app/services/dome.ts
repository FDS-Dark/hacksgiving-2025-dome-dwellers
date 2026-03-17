import { Event, EventRegistrationCreate, EventRegistration } from '@/types/dome';
import { API_BASE_URL } from '@/constants/config';


/**
 * Dome Service - handles all API calls for dome events
 * No authentication required for viewing events
 * Authentication required for registrations
 */
export const domeService = {
  // ==================== EVENT OPERATIONS (No Auth Required) ====================
  
  /**
   * Get all events with optional filters
   * @param filters - Optional event filters
   * @returns Promise with events list and total count
   */
  async getEvents(filters?: {
    event_type?: string;
    start_date?: string;
    end_date?: string;
    location?: string;
    registration_required?: boolean;
    limit?: number;
    offset?: number;
  }): Promise<{ events: Event[]; total: number }> {
    const params = new URLSearchParams();
    
    if (filters?.event_type) params.append('event_type', filters.event_type);
    if (filters?.start_date) params.append('start_date', filters.start_date);
    if (filters?.end_date) params.append('end_date', filters.end_date);
    if (filters?.location) params.append('location', filters.location);
    if (filters?.registration_required !== undefined) {
      params.append('registration_required', filters.registration_required.toString());
    }
    if (filters?.limit) params.append('limit', filters.limit.toString());
    if (filters?.offset) params.append('offset', filters.offset.toString());
    
    const url = `${API_BASE_URL}/dome/events${params.toString() ? `?${params.toString()}` : ''}`;
    
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch events: ${response.status} ${response.statusText}`);
    }
    
    return response.json();
  },

  /**
   * Get upcoming events
   * @param limit - Maximum number of events to return
   */
  async getUpcomingEvents(limit: number = 10): Promise<Event[]> {
    const response = await fetch(`${API_BASE_URL}/dome/events/upcoming?limit=${limit}`);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch upcoming events: ${response.status}`);
    }
    
    return response.json();
  },

  /**
   * Get single event by ID with registration info
   * @param eventId - Event ID
   */
  async getEventDetails(eventId: number): Promise<Event & { registration_count?: number; is_full?: boolean }> {
    const response = await fetch(`${API_BASE_URL}/dome/events/${eventId}/details`);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch event details: ${response.status}`);
    }
    
    return response.json();
  },

  // ==================== REGISTRATION OPERATIONS (Auth Required) ====================
  
  /**
   * Register for an event
   * @param eventId - Event ID
   * @param registrationData - Registration information
   * @param accessToken - Optional access token for authenticated users
   */
  async registerForEvent(
    eventId: number,
    registrationData: Omit<EventRegistrationCreate, 'event_id'>,
    accessToken?: string
  ): Promise<EventRegistration> {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    
    if (accessToken) {
      headers['Authorization'] = `Bearer ${accessToken}`;
    }
    
    const response = await fetch(`${API_BASE_URL}/dome/events/${eventId}/register`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        ...registrationData,
        event_id: eventId,
      }),
    });
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Failed to register' }));
      throw new Error(error.detail || `Registration failed: ${response.status}`);
    }
    
    return response.json();
  },

  /**
   * Get user's registrations (requires auth)
   * @param accessToken - Access token
   */
  async getMyRegistrations(accessToken: string): Promise<EventRegistration[]> {
    const response = await fetch(`${API_BASE_URL}/dome/registrations/my`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch registrations: ${response.status}`);
    }
    
    return response.json();
  },

  /**
   * Cancel a registration (requires auth)
   * @param registrationId - Registration ID
   * @param accessToken - Access token
   */
  async cancelRegistration(registrationId: number, accessToken: string): Promise<{ message: string }> {
    const response = await fetch(`${API_BASE_URL}/dome/registrations/${registrationId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to cancel registration: ${response.status}`);
    }
    
    return response.json();
  },
};

