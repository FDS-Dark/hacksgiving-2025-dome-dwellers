export type EventType = 'tour' | 'class' | 'exhibition' | 'special_event' | 'other';
export type RegistrationStatus = 'registered' | 'attended' | 'cancelled' | 'no_show';

export interface Event {
  id: number;
  title: string;
  description: string | null;
  event_type: EventType;
  start_time: string;
  end_time: string;
  location: string | null;
  capacity: number | null;
  registration_required: boolean;
  registration_url: string | null;
  image_url: string | null;
  created_by_user_id: number | null;
  created_at: string;
  updated_at: string;
}

export interface EventRegistrationCreate {
  event_id: number;
  attendee_name: string;
  attendee_email?: string | null;
  attendee_phone?: string | null;
  notes?: string | null;
}

export interface EventRegistration {
  id: number;
  event_id: number;
  user_id: number | null;
  attendee_name: string;
  attendee_email: string | null;
  attendee_phone: string | null;
  registration_time: string;
  status: RegistrationStatus;
  notes: string | null;
}

