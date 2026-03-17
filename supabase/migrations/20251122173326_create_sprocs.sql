set check_function_bodies = off;

CREATE OR REPLACE FUNCTION dome.cancel_registration(p_registration_id bigint)
 RETURNS TABLE(id bigint, event_id bigint, user_id bigint, attendee_name text, attendee_email text, attendee_phone text, registration_time timestamp with time zone, status text, notes text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT * FROM dome.update_registration_status(p_registration_id, 'cancelled');
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.count_event_registrations(p_event_id bigint, p_status text DEFAULT 'registered'::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)::INTEGER INTO v_count
    FROM dome.event_registrations
    WHERE event_id = p_event_id
    AND status = p_status;
    
    RETURN v_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.count_events(p_event_type text DEFAULT NULL::text, p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)::INTEGER INTO v_count
    FROM dome.events e
    WHERE 
        (p_event_type IS NULL OR e.event_type = p_event_type)
        AND (p_start_date IS NULL OR e.start_time >= p_start_date)
        AND (p_end_date IS NULL OR e.end_time <= p_end_date);
    
    RETURN v_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.create_event(p_title text, p_event_type text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_description text DEFAULT NULL::text, p_location text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_registration_required boolean DEFAULT false, p_registration_url text DEFAULT NULL::text, p_image_url text DEFAULT NULL::text, p_created_by_user_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(id bigint, title text, description text, event_type text, start_time timestamp with time zone, end_time timestamp with time zone, location text, capacity integer, registration_required boolean, registration_url text, image_url text, created_by_user_id bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Validate end_time > start_time
    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'End time must be after start time';
    END IF;

    RETURN QUERY
    INSERT INTO dome.events (
        title,
        description,
        event_type,
        start_time,
        end_time,
        location,
        capacity,
        registration_required,
        registration_url,
        image_url,
        created_by_user_id
    ) VALUES (
        p_title,
        p_description,
        p_event_type,
        p_start_time,
        p_end_time,
        p_location,
        p_capacity,
        p_registration_required,
        p_registration_url,
        p_image_url,
        p_created_by_user_id
    )
    RETURNING 
        dome.events.id,
        dome.events.title,
        dome.events.description,
        dome.events.event_type,
        dome.events.start_time,
        dome.events.end_time,
        dome.events.location,
        dome.events.capacity,
        dome.events.registration_required,
        dome.events.registration_url,
        dome.events.image_url,
        dome.events.created_by_user_id,
        dome.events.created_at,
        dome.events.updated_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.create_event_registration(p_event_id bigint, p_attendee_name text, p_attendee_email text DEFAULT NULL::text, p_attendee_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_user_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(id bigint, event_id bigint, user_id bigint, attendee_name text, attendee_email text, attendee_phone text, registration_time timestamp with time zone, status text, notes text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_capacity INTEGER;
    v_registration_count INTEGER;
BEGIN
    -- Check if event exists and get capacity
    SELECT capacity INTO v_capacity
    FROM dome.events
    WHERE dome.events.id = p_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event not found';
    END IF;

    -- Check capacity if set
    IF v_capacity IS NOT NULL THEN
        SELECT COUNT(*)::INTEGER INTO v_registration_count
        FROM dome.event_registrations
        WHERE event_registrations.event_id = p_event_id
        AND status = 'registered';

        IF v_registration_count >= v_capacity THEN
            RAISE EXCEPTION 'Event is full';
        END IF;
    END IF;

    -- Create registration
    RETURN QUERY
    INSERT INTO dome.event_registrations (
        event_id,
        user_id,
        attendee_name,
        attendee_email,
        attendee_phone,
        notes
    ) VALUES (
        p_event_id,
        p_user_id,
        p_attendee_name,
        p_attendee_email,
        p_attendee_phone,
        p_notes
    )
    RETURNING 
        event_registrations.id,
        event_registrations.event_id,
        event_registrations.user_id,
        event_registrations.attendee_name,
        event_registrations.attendee_email,
        event_registrations.attendee_phone,
        event_registrations.registration_time,
        event_registrations.status,
        event_registrations.notes;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.delete_event(p_event_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_deleted BOOLEAN;
BEGIN
    DELETE FROM dome.events
    WHERE id = p_event_id;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.get_event_by_id(p_event_id bigint)
 RETURNS TABLE(id bigint, title text, description text, event_type text, start_time timestamp with time zone, end_time timestamp with time zone, location text, capacity integer, registration_required boolean, registration_url text, image_url text, created_by_user_id bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.title,
        e.description,
        e.event_type,
        e.start_time,
        e.end_time,
        e.location,
        e.capacity,
        e.registration_required,
        e.registration_url,
        e.image_url,
        e.created_by_user_id,
        e.created_at,
        e.updated_at
    FROM dome.events e
    WHERE e.id = p_event_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.get_event_registrations(p_event_id bigint DEFAULT NULL::bigint, p_user_id bigint DEFAULT NULL::bigint, p_status text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, event_id bigint, user_id bigint, attendee_name text, attendee_email text, attendee_phone text, registration_time timestamp with time zone, status text, notes text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.event_id,
        r.user_id,
        r.attendee_name,
        r.attendee_email,
        r.attendee_phone,
        r.registration_time,
        r.status,
        r.notes
    FROM dome.event_registrations r
    WHERE 
        (p_event_id IS NULL OR r.event_id = p_event_id)
        AND (p_user_id IS NULL OR r.user_id = p_user_id)
        AND (p_status IS NULL OR r.status = p_status)
    ORDER BY r.registration_time DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.get_events(p_event_type text DEFAULT NULL::text, p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_location text DEFAULT NULL::text, p_registration_required boolean DEFAULT NULL::boolean, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(id bigint, title text, description text, event_type text, start_time timestamp with time zone, end_time timestamp with time zone, location text, capacity integer, registration_required boolean, registration_url text, image_url text, created_by_user_id bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.title,
        e.description,
        e.event_type,
        e.start_time,
        e.end_time,
        e.location,
        e.capacity,
        e.registration_required,
        e.registration_url,
        e.image_url,
        e.created_by_user_id,
        e.created_at,
        e.updated_at
    FROM dome.events e
    WHERE 
        (p_event_type IS NULL OR e.event_type = p_event_type)
        AND (p_start_date IS NULL OR e.start_time >= p_start_date)
        AND (p_end_date IS NULL OR e.end_time <= p_end_date)
        AND (p_location IS NULL OR e.location ILIKE '%' || p_location || '%')
        AND (p_registration_required IS NULL OR e.registration_required = p_registration_required)
    ORDER BY e.start_time ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.get_registration_by_id(p_registration_id bigint)
 RETURNS TABLE(id bigint, event_id bigint, user_id bigint, attendee_name text, attendee_email text, attendee_phone text, registration_time timestamp with time zone, status text, notes text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.event_id,
        r.user_id,
        r.attendee_name,
        r.attendee_email,
        r.attendee_phone,
        r.registration_time,
        r.status,
        r.notes
    FROM dome.event_registrations r
    WHERE r.id = p_registration_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.get_upcoming_events(p_limit integer DEFAULT 10)
 RETURNS TABLE(id bigint, title text, description text, event_type text, start_time timestamp with time zone, end_time timestamp with time zone, location text, capacity integer, registration_required boolean, registration_url text, image_url text, created_by_user_id bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.title,
        e.description,
        e.event_type,
        e.start_time,
        e.end_time,
        e.location,
        e.capacity,
        e.registration_required,
        e.registration_url,
        e.image_url,
        e.created_by_user_id,
        e.created_at,
        e.updated_at
    FROM dome.events e
    WHERE e.start_time >= NOW()
    ORDER BY e.start_time ASC
    LIMIT p_limit;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.update_event(p_event_id bigint, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_event_type text DEFAULT NULL::text, p_start_time timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_time timestamp with time zone DEFAULT NULL::timestamp with time zone, p_location text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_registration_required boolean DEFAULT NULL::boolean, p_registration_url text DEFAULT NULL::text, p_image_url text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, title text, description text, event_type text, start_time timestamp with time zone, end_time timestamp with time zone, location text, capacity integer, registration_required boolean, registration_url text, image_url text, created_by_user_id bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    UPDATE dome.events e
    SET
        title = COALESCE(p_title, e.title),
        description = COALESCE(p_description, e.description),
        event_type = COALESCE(p_event_type, e.event_type),
        start_time = COALESCE(p_start_time, e.start_time),
        end_time = COALESCE(p_end_time, e.end_time),
        location = COALESCE(p_location, e.location),
        capacity = COALESCE(p_capacity, e.capacity),
        registration_required = COALESCE(p_registration_required, e.registration_required),
        registration_url = COALESCE(p_registration_url, e.registration_url),
        image_url = COALESCE(p_image_url, e.image_url),
        updated_at = NOW()
    WHERE e.id = p_event_id
    RETURNING 
        e.id,
        e.title,
        e.description,
        e.event_type,
        e.start_time,
        e.end_time,
        e.location,
        e.capacity,
        e.registration_required,
        e.registration_url,
        e.image_url,
        e.created_by_user_id,
        e.created_at,
        e.updated_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION dome.update_registration_status(p_registration_id bigint, p_status text, p_notes text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, event_id bigint, user_id bigint, attendee_name text, attendee_email text, attendee_phone text, registration_time timestamp with time zone, status text, notes text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    UPDATE dome.event_registrations r
    SET
        status = p_status,
        notes = COALESCE(p_notes, r.notes)
    WHERE r.id = p_registration_id
    RETURNING 
        r.id,
        r.event_id,
        r.user_id,
        r.attendee_name,
        r.attendee_email,
        r.attendee_phone,
        r.registration_time,
        r.status,
        r.notes;
END;
$function$
;


