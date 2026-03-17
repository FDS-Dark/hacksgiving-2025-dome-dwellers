-- Schema: dome
-- Stored Procedures for Dome Events and Registrations
-- This file contains all stored procedures for dome-related operations

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS dome;

-- ==================== EVENT FUNCTIONS ====================

-- Function: Get events with filters
CREATE OR REPLACE FUNCTION dome.get_events(
    p_event_type TEXT DEFAULT NULL,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL,
    p_location TEXT DEFAULT NULL,
    p_registration_required BOOLEAN DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id BIGINT,
    title TEXT,
    description TEXT,
    event_type TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    location TEXT,
    capacity INTEGER,
    registration_required BOOLEAN,
    registration_url TEXT,
    image_url TEXT,
    created_by_user_id BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Get upcoming events
CREATE OR REPLACE FUNCTION dome.get_upcoming_events(
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    id BIGINT,
    title TEXT,
    description TEXT,
    event_type TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    location TEXT,
    capacity INTEGER,
    registration_required BOOLEAN,
    registration_url TEXT,
    image_url TEXT,
    created_by_user_id BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Get event by ID
CREATE OR REPLACE FUNCTION dome.get_event_by_id(
    p_event_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    title TEXT,
    description TEXT,
    event_type TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    location TEXT,
    capacity INTEGER,
    registration_required BOOLEAN,
    registration_url TEXT,
    image_url TEXT,
    created_by_user_id BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Count events with filters
CREATE OR REPLACE FUNCTION dome.count_events(
    p_event_type TEXT DEFAULT NULL,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Create event
CREATE OR REPLACE FUNCTION dome.create_event(
    p_title TEXT,
    p_event_type TEXT,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_description TEXT DEFAULT NULL,
    p_location TEXT DEFAULT NULL,
    p_capacity INTEGER DEFAULT NULL,
    p_registration_required BOOLEAN DEFAULT FALSE,
    p_registration_url TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_created_by_user_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    title TEXT,
    description TEXT,
    event_type TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    location TEXT,
    capacity INTEGER,
    registration_required BOOLEAN,
    registration_url TEXT,
    image_url TEXT,
    created_by_user_id BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Update event
CREATE OR REPLACE FUNCTION dome.update_event(
    p_event_id BIGINT,
    p_title TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_event_type TEXT DEFAULT NULL,
    p_start_time TIMESTAMPTZ DEFAULT NULL,
    p_end_time TIMESTAMPTZ DEFAULT NULL,
    p_location TEXT DEFAULT NULL,
    p_capacity INTEGER DEFAULT NULL,
    p_registration_required BOOLEAN DEFAULT NULL,
    p_registration_url TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    title TEXT,
    description TEXT,
    event_type TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    location TEXT,
    capacity INTEGER,
    registration_required BOOLEAN,
    registration_url TEXT,
    image_url TEXT,
    created_by_user_id BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Delete event
CREATE OR REPLACE FUNCTION dome.delete_event(
    p_event_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted BOOLEAN;
BEGIN
    DELETE FROM dome.events
    WHERE id = p_event_id;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$;

-- ==================== EVENT REGISTRATION FUNCTIONS ====================

-- Function: Create event registration
CREATE OR REPLACE FUNCTION dome.create_event_registration(
    p_event_id BIGINT,
    p_attendee_name TEXT,
    p_attendee_email TEXT DEFAULT NULL,
    p_attendee_phone TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_user_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    event_id BIGINT,
    user_id BIGINT,
    attendee_name TEXT,
    attendee_email TEXT,
    attendee_phone TEXT,
    registration_time TIMESTAMPTZ,
    status TEXT,
    notes TEXT
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Get event registrations
CREATE OR REPLACE FUNCTION dome.get_event_registrations(
    p_event_id BIGINT DEFAULT NULL,
    p_user_id BIGINT DEFAULT NULL,
    p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    event_id BIGINT,
    user_id BIGINT,
    attendee_name TEXT,
    attendee_email TEXT,
    attendee_phone TEXT,
    registration_time TIMESTAMPTZ,
    status TEXT,
    notes TEXT
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Get registration by ID
CREATE OR REPLACE FUNCTION dome.get_registration_by_id(
    p_registration_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    event_id BIGINT,
    user_id BIGINT,
    attendee_name TEXT,
    attendee_email TEXT,
    attendee_phone TEXT,
    registration_time TIMESTAMPTZ,
    status TEXT,
    notes TEXT
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Count event registrations
CREATE OR REPLACE FUNCTION dome.count_event_registrations(
    p_event_id BIGINT,
    p_status TEXT DEFAULT 'registered'
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)::INTEGER INTO v_count
    FROM dome.event_registrations
    WHERE event_id = p_event_id
    AND status = p_status;
    
    RETURN v_count;
END;
$$;

-- Function: Update registration status
CREATE OR REPLACE FUNCTION dome.update_registration_status(
    p_registration_id BIGINT,
    p_status TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    event_id BIGINT,
    user_id BIGINT,
    attendee_name TEXT,
    attendee_email TEXT,
    attendee_phone TEXT,
    registration_time TIMESTAMPTZ,
    status TEXT,
    notes TEXT
)
LANGUAGE plpgsql
AS $$
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
$$;

-- Function: Cancel registration
CREATE OR REPLACE FUNCTION dome.cancel_registration(
    p_registration_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    event_id BIGINT,
    user_id BIGINT,
    attendee_name TEXT,
    attendee_email TEXT,
    attendee_phone TEXT,
    registration_time TIMESTAMPTZ,
    status TEXT,
    notes TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM dome.update_registration_status(p_registration_id, 'cancelled');
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dome TO postgres, authenticated, anon;

