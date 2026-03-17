


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "agent";


ALTER SCHEMA "agent" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "auth0";


ALTER SCHEMA "auth0" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "dome";


ALTER SCHEMA "dome" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "gamification";


ALTER SCHEMA "gamification" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "inventory";


ALTER SCHEMA "inventory" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "plants";


ALTER SCHEMA "plants" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "staff";


ALTER SCHEMA "staff" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";






CREATE OR REPLACE FUNCTION "auth0"."get_user_by_auth0_id"("p_auth0_user_id" "text") RETURNS TABLE("id" bigint, "auth0_user_id" "text", "email" "text", "display_name" "text", "name" "text", "given_name" "text", "family_name" "text", "picture_url" "text", "locale" "text", "profile_metadata" "jsonb", "app_metadata" "jsonb", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "roles" "jsonb")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.auth0_user_id,
        u.email,
        u.display_name,
        u.name,
        u.given_name,
        u.family_name,
        u.picture_url,
        u.locale,
        u.profile_metadata,
        u.app_metadata,
        u.is_active,
        u.created_at,
        u.updated_at,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', r.id,
                        'name', r.name
                    )
                )
                FROM auth0.user_roles ur
                JOIN auth0.roles r ON r.id = ur.role_id
                WHERE ur.user_id = u.id
            ),
            '[]'::jsonb
        ) as roles
    FROM auth0.users u
    WHERE u.auth0_user_id = p_auth0_user_id
      AND u.is_active = true;
END;
$$;


ALTER FUNCTION "auth0"."get_user_by_auth0_id"("p_auth0_user_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "auth0"."set_updated_at_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "auth0"."set_updated_at_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "auth0"."upsert_user"("p_auth0_user_id" "text", "p_email" "text" DEFAULT NULL::"text", "p_display_name" "text" DEFAULT NULL::"text", "p_name" "text" DEFAULT NULL::"text", "p_given_name" "text" DEFAULT NULL::"text", "p_family_name" "text" DEFAULT NULL::"text", "p_picture_url" "text" DEFAULT NULL::"text", "p_locale" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "auth0_user_id" "text", "email" "text", "display_name" "text", "name" "text", "given_name" "text", "family_name" "text", "picture_url" "text", "locale" "text", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_user_id BIGINT;
    v_visitor_role_id SMALLINT;
BEGIN
    -- Get the visitor role ID
    SELECT r.id INTO v_visitor_role_id
    FROM auth0.roles r
    WHERE r.name = 'visitor';

    -- Insert or update user
    INSERT INTO auth0.users (
        auth0_user_id, email, display_name, name, given_name, 
        family_name, picture_url, locale
    ) VALUES (
        p_auth0_user_id, p_email, p_display_name, p_name, p_given_name,
        p_family_name, p_picture_url, p_locale
    )
    ON CONFLICT (auth0_user_id) 
    DO UPDATE SET
        email = COALESCE(EXCLUDED.email, users.email),
        display_name = COALESCE(EXCLUDED.display_name, users.display_name),
        name = COALESCE(EXCLUDED.name, users.name),
        given_name = COALESCE(EXCLUDED.given_name, users.given_name),
        family_name = COALESCE(EXCLUDED.family_name, users.family_name),
        picture_url = COALESCE(EXCLUDED.picture_url, users.picture_url),
        locale = COALESCE(EXCLUDED.locale, users.locale),
        updated_at = NOW()
    RETURNING users.id INTO v_user_id;

    -- Assign visitor role if user is new and doesn't have any roles
    IF NOT EXISTS (SELECT 1 FROM auth0.user_roles WHERE user_id = v_user_id) THEN
        IF v_visitor_role_id IS NOT NULL THEN
            INSERT INTO auth0.user_roles (user_id, role_id)
            VALUES (v_user_id, v_visitor_role_id)
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    -- Return the user
    RETURN QUERY
    SELECT 
        u.id,
        u.auth0_user_id,
        u.email,
        u.display_name,
        u.name,
        u.given_name,
        u.family_name,
        u.picture_url,
        u.locale,
        u.is_active,
        u.created_at,
        u.updated_at
    FROM auth0.users u
    WHERE u.id = v_user_id;
END;
$$;


ALTER FUNCTION "auth0"."upsert_user"("p_auth0_user_id" "text", "p_email" "text", "p_display_name" "text", "p_name" "text", "p_given_name" "text", "p_family_name" "text", "p_picture_url" "text", "p_locale" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."cancel_registration"("p_registration_id" bigint) RETURNS TABLE("id" bigint, "event_id" bigint, "user_id" bigint, "attendee_name" "text", "attendee_email" "text", "attendee_phone" "text", "registration_time" timestamp with time zone, "status" "text", "notes" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM dome.update_registration_status(p_registration_id, 'cancelled');
END;
$$;


ALTER FUNCTION "dome"."cancel_registration"("p_registration_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."count_event_registrations"("p_event_id" bigint, "p_status" "text" DEFAULT 'registered'::"text") RETURNS integer
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."count_event_registrations"("p_event_id" bigint, "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."count_events"("p_event_type" "text" DEFAULT NULL::"text", "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS integer
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."count_events"("p_event_type" "text", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."create_event"("p_title" "text", "p_event_type" "text", "p_start_time" timestamp with time zone, "p_end_time" timestamp with time zone, "p_description" "text" DEFAULT NULL::"text", "p_location" "text" DEFAULT NULL::"text", "p_capacity" integer DEFAULT NULL::integer, "p_registration_required" boolean DEFAULT false, "p_registration_url" "text" DEFAULT NULL::"text", "p_image_url" "text" DEFAULT NULL::"text", "p_created_by_user_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "title" "text", "description" "text", "event_type" "text", "start_time" timestamp with time zone, "end_time" timestamp with time zone, "location" "text", "capacity" integer, "registration_required" boolean, "registration_url" "text", "image_url" "text", "created_by_user_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."create_event"("p_title" "text", "p_event_type" "text", "p_start_time" timestamp with time zone, "p_end_time" timestamp with time zone, "p_description" "text", "p_location" "text", "p_capacity" integer, "p_registration_required" boolean, "p_registration_url" "text", "p_image_url" "text", "p_created_by_user_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."create_event_registration"("p_event_id" bigint, "p_attendee_name" "text", "p_attendee_email" "text" DEFAULT NULL::"text", "p_attendee_phone" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text", "p_user_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "event_id" bigint, "user_id" bigint, "attendee_name" "text", "attendee_email" "text", "attendee_phone" "text", "registration_time" timestamp with time zone, "status" "text", "notes" "text")
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."create_event_registration"("p_event_id" bigint, "p_attendee_name" "text", "p_attendee_email" "text", "p_attendee_phone" "text", "p_notes" "text", "p_user_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."delete_event"("p_event_id" bigint) RETURNS boolean
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."delete_event"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."get_event_by_id"("p_event_id" bigint) RETURNS TABLE("id" bigint, "title" "text", "description" "text", "event_type" "text", "start_time" timestamp with time zone, "end_time" timestamp with time zone, "location" "text", "capacity" integer, "registration_required" boolean, "registration_url" "text", "image_url" "text", "created_by_user_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."get_event_by_id"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."get_event_registrations"("p_event_id" bigint DEFAULT NULL::bigint, "p_user_id" bigint DEFAULT NULL::bigint, "p_status" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "event_id" bigint, "user_id" bigint, "attendee_name" "text", "attendee_email" "text", "attendee_phone" "text", "registration_time" timestamp with time zone, "status" "text", "notes" "text")
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."get_event_registrations"("p_event_id" bigint, "p_user_id" bigint, "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."get_events"("p_event_type" "text" DEFAULT NULL::"text", "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_location" "text" DEFAULT NULL::"text", "p_registration_required" boolean DEFAULT NULL::boolean, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" bigint, "title" "text", "description" "text", "event_type" "text", "start_time" timestamp with time zone, "end_time" timestamp with time zone, "location" "text", "capacity" integer, "registration_required" boolean, "registration_url" "text", "image_url" "text", "created_by_user_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."get_events"("p_event_type" "text", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_location" "text", "p_registration_required" boolean, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."get_registration_by_id"("p_registration_id" bigint) RETURNS TABLE("id" bigint, "event_id" bigint, "user_id" bigint, "attendee_name" "text", "attendee_email" "text", "attendee_phone" "text", "registration_time" timestamp with time zone, "status" "text", "notes" "text")
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."get_registration_by_id"("p_registration_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."get_upcoming_events"("p_limit" integer DEFAULT 10) RETURNS TABLE("id" bigint, "title" "text", "description" "text", "event_type" "text", "start_time" timestamp with time zone, "end_time" timestamp with time zone, "location" "text", "capacity" integer, "registration_required" boolean, "registration_url" "text", "image_url" "text", "created_by_user_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."get_upcoming_events"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."update_event"("p_event_id" bigint, "p_title" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_event_type" "text" DEFAULT NULL::"text", "p_start_time" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_time" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_location" "text" DEFAULT NULL::"text", "p_capacity" integer DEFAULT NULL::integer, "p_registration_required" boolean DEFAULT NULL::boolean, "p_registration_url" "text" DEFAULT NULL::"text", "p_image_url" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "title" "text", "description" "text", "event_type" "text", "start_time" timestamp with time zone, "end_time" timestamp with time zone, "location" "text", "capacity" integer, "registration_required" boolean, "registration_url" "text", "image_url" "text", "created_by_user_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."update_event"("p_event_id" bigint, "p_title" "text", "p_description" "text", "p_event_type" "text", "p_start_time" timestamp with time zone, "p_end_time" timestamp with time zone, "p_location" "text", "p_capacity" integer, "p_registration_required" boolean, "p_registration_url" "text", "p_image_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "dome"."update_registration_status"("p_registration_id" bigint, "p_status" "text", "p_notes" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "event_id" bigint, "user_id" bigint, "attendee_name" "text", "attendee_email" "text", "attendee_phone" "text", "registration_time" timestamp with time zone, "status" "text", "notes" "text")
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "dome"."update_registration_status"("p_registration_id" bigint, "p_status" "text", "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "gamification"."auto_add_plant_to_catalog"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_next_catalog_number INTEGER;
    v_rarity_tier TEXT;
    v_random_value NUMERIC;
BEGIN
    -- Get the next catalog number
    SELECT COALESCE(MAX(catalog_number), 0) + 1
    INTO v_next_catalog_number
    FROM gamification.collectible_catalog;
    
    -- Randomly assign rarity tier with weighted distribution
    v_random_value := RANDOM();
    
    v_rarity_tier := CASE 
        WHEN v_random_value < 0.50 THEN 'common'       -- 50% common
        WHEN v_random_value < 0.80 THEN 'uncommon'     -- 30% uncommon
        WHEN v_random_value < 0.95 THEN 'rare'         -- 15% rare
        ELSE 'legendary'                                -- 5% legendary
    END;
    
    -- Insert into collectible catalog
    INSERT INTO gamification.collectible_catalog (
        catalog_number,
        plant_species_id,
        rarity_tier,
        collectible_since,
        active
    ) VALUES (
        v_next_catalog_number,
        NEW.id,
        v_rarity_tier,
        NOW(),
        TRUE
    );
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "gamification"."auto_add_plant_to_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "gamification"."bulk_create_qr_codes"("p_plant_species_ids" bigint[], "p_location_ids" bigint[] DEFAULT NULL::bigint[]) RETURNS TABLE("qr_code_id" bigint, "code_token" "uuid", "plant_species_id" bigint, "location_id" bigint, "active" boolean, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_location_ids BIGINT[];
BEGIN
    -- If no location IDs provided, create array of NULLs
    IF p_location_ids IS NULL OR array_length(p_location_ids, 1) IS NULL THEN
        v_location_ids := array_fill(NULL::BIGINT, ARRAY[array_length(p_plant_species_ids, 1)]);
    ELSE
        v_location_ids := p_location_ids;
    END IF;

    RETURN QUERY
    INSERT INTO gamification.qr_codes (code_token, plant_species_id, location_id)
    SELECT 
        gen_random_uuid(), 
        unnest(p_plant_species_ids),
        unnest(v_location_ids)
    RETURNING id AS qr_code_id, code_token, plant_species_id, location_id, active, created_at;
END;
$$;


ALTER FUNCTION "gamification"."bulk_create_qr_codes"("p_plant_species_ids" bigint[], "p_location_ids" bigint[]) OWNER TO "postgres";


COMMENT ON FUNCTION "gamification"."bulk_create_qr_codes"("p_plant_species_ids" bigint[], "p_location_ids" bigint[]) IS 'Bulk create QR codes for multiple plant species with optional locations.';



CREATE OR REPLACE FUNCTION "gamification"."discover_plant_from_qr"("p_user_id" bigint, "p_qr_token" "uuid") RETURNS TABLE("success" boolean, "message" "text", "discovery_id" bigint, "catalog_entry_id" bigint, "catalog_number" integer, "species_name" "text", "plant_species_id" bigint, "already_discovered" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_scrapbook_id BIGINT;
    v_qr_code_id BIGINT;
    v_species_id BIGINT;
    v_catalog_entry_id BIGINT;
    v_catalog_number INTEGER;
    v_species_name TEXT;
    v_discovery_id BIGINT;
    v_already_discovered BOOLEAN := FALSE;
    v_has_public_instance BOOLEAN;
BEGIN
    -- Validate QR code exists and is active
    SELECT qc.id, qc.plant_species_id
    INTO v_qr_code_id, v_species_id
    FROM gamification.qr_codes qc
    WHERE qc.code_token = p_qr_token AND qc.active = TRUE;
    
    IF v_qr_code_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Invalid or inactive QR code'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, NULL::BIGINT, FALSE;
        RETURN;
    END IF;
    
    -- Record the scan
    INSERT INTO gamification.qr_scans (user_id, qr_code_id)
    VALUES (p_user_id, v_qr_code_id);
    
    -- Check if species has at least one public plant instance
    SELECT EXISTS (
        SELECT 1 FROM inventory.plant_instances pi
        WHERE pi.species_id = v_species_id
        AND pi.is_public = TRUE
    ) INTO v_has_public_instance;
    
    IF NOT v_has_public_instance THEN
        RETURN QUERY SELECT FALSE, 'This plant is not yet available for discovery'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, NULL::BIGINT, FALSE;
        RETURN;
    END IF;
    
    -- Get catalog entry for this species
    SELECT cc.id, cc.catalog_number, ps.common_name
    INTO v_catalog_entry_id, v_catalog_number, v_species_name
    FROM gamification.collectible_catalog cc
    INNER JOIN plants.species ps ON cc.plant_species_id = ps.id
    WHERE cc.plant_species_id = v_species_id AND cc.active = TRUE;
    
    IF v_catalog_entry_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Plant not in collectible catalog'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, NULL::BIGINT, FALSE;
        RETURN;
    END IF;
    
    -- Get or create user's scrapbook
    v_scrapbook_id := gamification.get_or_create_default_scrapbook(p_user_id);
    
    -- Check if already discovered (fully qualified to avoid ambiguity)
    SELECT pd.id INTO v_discovery_id
    FROM gamification.plant_discoveries pd
    WHERE pd.scrapbook_id = v_scrapbook_id AND pd.catalog_entry_id = v_catalog_entry_id;
    
    IF v_discovery_id IS NOT NULL THEN
        v_already_discovered := TRUE;
        RETURN QUERY SELECT TRUE, 'Plant already in your scrapbook'::TEXT, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_species_id, v_already_discovered;
        RETURN;
    END IF;
    
    -- Create new discovery (fully qualified to avoid ambiguity)
    INSERT INTO gamification.plant_discoveries (scrapbook_id, catalog_entry_id)
    VALUES (v_scrapbook_id, v_catalog_entry_id)
    RETURNING gamification.plant_discoveries.id INTO v_discovery_id;
    
    RETURN QUERY SELECT TRUE, 'Plant discovered!'::TEXT, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_species_id, v_already_discovered;
END;
$$;


ALTER FUNCTION "gamification"."discover_plant_from_qr"("p_user_id" bigint, "p_qr_token" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "gamification"."discover_plant_from_qr"("p_user_id" bigint, "p_qr_token" "uuid") IS 'Discovers a plant species from QR scan. Only allows discovery if species has at least one public plant instance. Returns plant_species_id for navigation.';



CREATE OR REPLACE FUNCTION "gamification"."get_all_qr_codes"() RETURNS TABLE("qr_code_id" bigint, "code_token" "uuid", "plant_species_id" bigint, "location_id" bigint, "active" boolean, "is_public" boolean, "created_at" timestamp with time zone, "common_name" "text", "scientific_name" "text", "location_name" "text", "scan_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qc.id AS qr_code_id,
        qc.code_token,
        qc.plant_species_id,
        qc.location_id,
        qc.active,
        EXISTS(SELECT 1 FROM inventory.plant_instances pi WHERE pi.species_id = qc.plant_species_id AND pi.is_public = TRUE) AS is_public,
        qc.created_at,
        ps.common_name,
        ps.scientific_name,
        sl.name AS location_name,
        COUNT(DISTINCT qs.id) AS scan_count
    FROM gamification.qr_codes qc
    INNER JOIN plants.species ps ON qc.plant_species_id = ps.id
    LEFT JOIN inventory.storage_locations sl ON qc.location_id = sl.id
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    GROUP BY qc.id, qc.code_token, qc.plant_species_id, qc.location_id, qc.active, qc.created_at,
             ps.common_name, ps.scientific_name, sl.name
    ORDER BY qc.created_at DESC;
END;
$$;


ALTER FUNCTION "gamification"."get_all_qr_codes"() OWNER TO "postgres";


COMMENT ON FUNCTION "gamification"."get_all_qr_codes"() IS 'Returns all QR codes with species information and location.';



CREATE OR REPLACE FUNCTION "gamification"."get_discovery_details"("p_user_id" bigint, "p_catalog_entry_id" bigint) RETURNS TABLE("discovery_id" bigint, "catalog_number" integer, "plant_species_id" bigint, "species_name" "text", "scientific_name" "text", "family" "text", "rarity_tier" "text", "discovered_at" timestamp with time zone, "user_notes" "text", "is_favorite" boolean, "plant_article" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pd.id AS discovery_id,
        cc.catalog_number,
        ps.id AS plant_species_id,
        ps.common_name AS species_name,
        ps.scientific_name,
        ps.family,
        cc.rarity_tier,
        pd.discovered_at,
        pd.notes AS user_notes,
        COALESCE(pd.favorite, FALSE) AS is_favorite,
        jsonb_build_object(
            'description', ps.description,
            'care_notes', ps.care_notes,
            'native_habitat', ps.native_habitat,
            'conservation_status', ps.conservation_status
        ) AS plant_article
    FROM gamification.plant_discoveries pd
    INNER JOIN gamification.scrapbooks sb ON pd.scrapbook_id = sb.id
    INNER JOIN gamification.collectible_catalog cc ON pd.catalog_entry_id = cc.id
    INNER JOIN plants.species ps ON cc.plant_species_id = ps.id
    WHERE sb.user_id = p_user_id
        AND cc.id = p_catalog_entry_id;
END;
$$;


ALTER FUNCTION "gamification"."get_discovery_details"("p_user_id" bigint, "p_catalog_entry_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "gamification"."get_or_create_default_scrapbook"("p_user_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_scrapbook_id BIGINT;
BEGIN
    SELECT id INTO v_scrapbook_id
    FROM gamification.scrapbooks
    WHERE user_id = p_user_id
    ORDER BY created_at
    LIMIT 1;
    
    IF v_scrapbook_id IS NULL THEN
        INSERT INTO gamification.scrapbooks (user_id, title, description)
        VALUES (p_user_id, 'My Plant Collection', 'My discovered plants from the domes')
        RETURNING id INTO v_scrapbook_id;
    END IF;
    
    RETURN v_scrapbook_id;
END;
$$;


ALTER FUNCTION "gamification"."get_or_create_default_scrapbook"("p_user_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "gamification"."get_qr_codes_by_species_and_location"("p_plant_species_id" bigint, "p_location_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("qr_code_id" bigint, "code_token" "uuid", "plant_species_id" bigint, "location_id" bigint, "active" boolean, "created_at" timestamp with time zone, "scan_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qc.id AS qr_code_id,
        qc.code_token,
        qc.plant_species_id,
        qc.location_id,
        qc.active,
        qc.created_at,
        COUNT(qs.id) AS scan_count
    FROM gamification.qr_codes qc
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    WHERE qc.plant_species_id = p_plant_species_id
      AND (p_location_id IS NULL OR qc.location_id = p_location_id OR (p_location_id IS NULL AND qc.location_id IS NULL))
    GROUP BY qc.id, qc.code_token, qc.plant_species_id, qc.location_id, qc.active, qc.created_at;
END;
$$;


ALTER FUNCTION "gamification"."get_qr_codes_by_species_and_location"("p_plant_species_id" bigint, "p_location_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "gamification"."get_qr_codes_by_species_and_location"("p_plant_species_id" bigint, "p_location_id" bigint) IS 'Get QR codes for a specific plant species and optional location.';



CREATE OR REPLACE FUNCTION "gamification"."get_user_collectible_catalog"("p_user_id" bigint) RETURNS TABLE("catalog_id" bigint, "catalog_number" integer, "plant_species_id" bigint, "species_name" "text", "scientific_name" "text", "rarity_tier" "text", "featured_order" integer, "is_discovered" boolean, "discovered_at" timestamp with time zone, "discovery_id" bigint, "user_notes" "text", "is_favorite" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cc.id AS catalog_id,
        cc.catalog_number,
        cc.plant_species_id,
        ps.common_name AS species_name,
        ps.scientific_name,
        cc.rarity_tier,
        cc.featured_order,
        CASE WHEN pd.id IS NOT NULL THEN TRUE ELSE FALSE END AS is_discovered,
        pd.discovered_at,
        pd.id AS discovery_id,
        pd.notes AS user_notes,
        COALESCE(pd.favorite, FALSE) AS is_favorite
    FROM gamification.collectible_catalog cc
    INNER JOIN plants.species ps ON cc.plant_species_id = ps.id
    LEFT JOIN gamification.scrapbooks sb ON sb.user_id = p_user_id
    LEFT JOIN gamification.plant_discoveries pd ON pd.catalog_entry_id = cc.id AND pd.scrapbook_id = sb.id
    WHERE cc.active = TRUE
    ORDER BY cc.catalog_number;
END;
$$;


ALTER FUNCTION "gamification"."get_user_collectible_catalog"("p_user_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "gamification"."get_user_collectible_catalog"("p_user_id" bigint) IS 'Returns collectible catalog filtered to only show species with at least one public plant instance.';



CREATE OR REPLACE FUNCTION "gamification"."get_user_collection_stats"("p_user_id" bigint) RETURNS TABLE("total_collectibles" integer, "total_discovered" integer, "discovery_percentage" numeric, "common_discovered" integer, "uncommon_discovered" integer, "rare_discovered" integer, "legendary_discovered" integer, "favorites_count" integer, "recent_discoveries" bigint[])
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_scrapbook_id BIGINT;
BEGIN
    v_scrapbook_id := gamification.get_or_create_default_scrapbook(p_user_id);
    
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER AS total_collectibles,
        COUNT(pd.id)::INTEGER AS total_discovered,
        ROUND((COUNT(pd.id)::NUMERIC / NULLIF(COUNT(*), 0)) * 100, 2) AS discovery_percentage,
        COUNT(*) FILTER (WHERE cc.rarity_tier = 'common' AND pd.id IS NOT NULL)::INTEGER AS common_discovered,
        COUNT(*) FILTER (WHERE cc.rarity_tier = 'uncommon' AND pd.id IS NOT NULL)::INTEGER AS uncommon_discovered,
        COUNT(*) FILTER (WHERE cc.rarity_tier = 'rare' AND pd.id IS NOT NULL)::INTEGER AS rare_discovered,
        COUNT(*) FILTER (WHERE cc.rarity_tier = 'legendary' AND pd.id IS NOT NULL)::INTEGER AS legendary_discovered,
        COUNT(*) FILTER (WHERE pd.favorite = TRUE)::INTEGER AS favorites_count,
        ARRAY_AGG(pd.id ORDER BY pd.discovered_at DESC) FILTER (WHERE pd.id IS NOT NULL) AS recent_discoveries
    FROM gamification.collectible_catalog cc
    LEFT JOIN gamification.plant_discoveries pd ON pd.catalog_entry_id = cc.id AND pd.scrapbook_id = v_scrapbook_id
    WHERE cc.active = TRUE;
END;
$$;


ALTER FUNCTION "gamification"."get_user_collection_stats"("p_user_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "gamification"."get_user_collection_stats"("p_user_id" bigint) IS 'Returns collection statistics counting only species with public instances.';



CREATE OR REPLACE FUNCTION "gamification"."toggle_discovery_favorite"("p_user_id" bigint, "p_discovery_id" bigint) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_new_status BOOLEAN;
BEGIN
    UPDATE gamification.plant_discoveries pd
    SET favorite = NOT COALESCE(pd.favorite, FALSE)
    FROM gamification.scrapbooks sb
    WHERE pd.id = p_discovery_id
        AND pd.scrapbook_id = sb.id
        AND sb.user_id = p_user_id
    RETURNING pd.favorite INTO v_new_status;
    
    RETURN v_new_status;
END;
$$;


ALTER FUNCTION "gamification"."toggle_discovery_favorite"("p_user_id" bigint, "p_discovery_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "gamification"."update_discovery_notes"("p_user_id" bigint, "p_discovery_id" bigint, "p_notes" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_updated BOOLEAN := FALSE;
BEGIN
    UPDATE gamification.plant_discoveries pd
    SET notes = p_notes
    FROM gamification.scrapbooks sb
    WHERE pd.id = p_discovery_id
        AND pd.scrapbook_id = sb.id
        AND sb.user_id = p_user_id;
    
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;


ALTER FUNCTION "gamification"."update_discovery_notes"("p_user_id" bigint, "p_discovery_id" bigint, "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."count_species"("p_search" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    total_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO total_count
    FROM plants.species s
    WHERE 
        (p_search IS NULL OR 
         s.scientific_name ILIKE '%' || p_search || '%' OR 
         s.common_name ILIKE '%' || p_search || '%');
    
    RETURN total_count;
END;
$$;


ALTER FUNCTION "plants"."count_species"("p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."delete_article"("p_species_id" bigint) RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    DELETE FROM plants.articles
    WHERE species_id = p_species_id;
    
    RETURN FOUND;
END;
$$;


ALTER FUNCTION "plants"."delete_article"("p_species_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."get_article"("p_species_id" bigint) RETURNS TABLE("id" bigint, "species_id" bigint, "article_content" "text", "author_user_id" bigint, "published" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.species_id,
        a.article_content,
        a.author_user_id,
        a.published,
        a.created_at,
        a.updated_at
    FROM plants.articles a
    WHERE a.species_id = p_species_id
      AND a.published = true;
END;
$$;


ALTER FUNCTION "plants"."get_article"("p_species_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."get_encyclopedia_entry"("p_species_id" bigint) RETURNS TABLE("id" bigint, "scientific_name" "text", "common_name" "text", "description" "text", "image_url" "text", "article_id" bigint, "article_content" "text", "article_author_id" bigint, "article_created_at" timestamp with time zone, "article_updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.scientific_name,
        s.common_name,
        s.description,
        s.image_url,
        a.id as article_id,
        a.article_content,
        a.author_user_id as article_author_id,
        a.created_at as article_created_at,
        a.updated_at as article_updated_at
    FROM plants.species s
    LEFT JOIN plants.articles a ON a.species_id = s.id AND a.published = true
    WHERE s.id = p_species_id;
END;
$$;


ALTER FUNCTION "plants"."get_encyclopedia_entry"("p_species_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."get_species_by_id"("p_species_id" bigint) RETURNS TABLE("id" bigint, "scientific_name" "text", "common_name" "text", "description" "text", "image_url" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.scientific_name,
        s.common_name,
        s.description,
        s.image_url
    FROM plants.species s
    WHERE s.id = p_species_id;
END;
$$;


ALTER FUNCTION "plants"."get_species_by_id"("p_species_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."get_species_list"("p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_order_by" "text" DEFAULT 'common_name'::"text") RETURNS TABLE("id" bigint, "scientific_name" "text", "common_name" "text", "description" "text", "image_url" "text", "has_article" boolean)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.scientific_name,
        s.common_name,
        s.description,
        s.image_url,
        EXISTS(
            SELECT 1 FROM plants.articles a 
            WHERE a.species_id = s.id AND a.published = true
        ) as has_article
    FROM plants.species s
    WHERE 
        (p_search IS NULL OR 
         s.scientific_name ILIKE '%' || p_search || '%' OR 
         s.common_name ILIKE '%' || p_search || '%')
    ORDER BY 
        CASE 
            WHEN p_order_by = 'common_name' THEN s.common_name
            WHEN p_order_by = 'scientific_name' THEN s.scientific_name
            ELSE s.common_name
        END ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;


ALTER FUNCTION "plants"."get_species_list"("p_search" "text", "p_limit" integer, "p_offset" integer, "p_order_by" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."upsert_article"("p_species_id" bigint, "p_article_content" "text", "p_author_user_id" bigint DEFAULT NULL::bigint, "p_published" boolean DEFAULT false) RETURNS TABLE("id" bigint, "species_id" bigint, "article_content" "text", "author_user_id" bigint, "published" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    INSERT INTO plants.articles (
        species_id, article_content, author_user_id, published, updated_at
    ) VALUES (
        p_species_id, p_article_content, p_author_user_id, p_published, NOW()
    )
    ON CONFLICT (species_id) 
    DO UPDATE SET
        article_content = EXCLUDED.article_content,
        author_user_id = COALESCE(EXCLUDED.author_user_id, articles.author_user_id),
        published = EXCLUDED.published,
        updated_at = NOW()
    RETURNING 
        articles.id,
        articles.species_id,
        articles.article_content,
        articles.author_user_id,
        articles.published,
        articles.created_at,
        articles.updated_at;
END;
$$;


ALTER FUNCTION "plants"."upsert_article"("p_species_id" bigint, "p_article_content" "text", "p_author_user_id" bigint, "p_published" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "plants"."upsert_species"("p_scientific_name" "text", "p_id" bigint DEFAULT NULL::bigint, "p_common_name" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_image_url" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "scientific_name" "text", "common_name" "text", "description" "text", "image_url" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF p_id IS NULL THEN
        -- Insert new species
        RETURN QUERY
        INSERT INTO plants.species (
            scientific_name, common_name, description, image_url
        ) VALUES (
            p_scientific_name, p_common_name, p_description, p_image_url
        )
        RETURNING 
            species.id,
            species.scientific_name,
            species.common_name,
            species.description,
            species.image_url;
    ELSE
        -- Update existing species
        RETURN QUERY
        UPDATE plants.species
        SET 
            scientific_name = COALESCE(p_scientific_name, species.scientific_name),
            common_name = COALESCE(p_common_name, species.common_name),
            description = COALESCE(p_description, species.description),
            image_url = COALESCE(p_image_url, species.image_url)
        WHERE species.id = p_id
        RETURNING 
            species.id,
            species.scientific_name,
            species.common_name,
            species.description,
            species.image_url;
    END IF;
END;
$$;


ALTER FUNCTION "plants"."upsert_species"("p_scientific_name" "text", "p_id" bigint, "p_common_name" "text", "p_description" "text", "p_image_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_user"("p_auth0_user_id" "text", "p_email" "text", "p_display_name" "text", "p_name" "text", "p_given_name" "text", "p_family_name" "text", "p_picture_url" "text", "p_locale" "text", "p_profile_metadata" "jsonb", "p_app_metadata" "jsonb", "p_is_active" boolean, "p_updated_at" timestamp with time zone) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO auth0.users (
    auth0_user_id,
    email,
    display_name,
    name,
    given_name,
    family_name,
    picture_url,
    locale,
    profile_metadata,
    app_metadata,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    p_auth0_user_id,
    p_email,
    p_display_name,
    p_name,
    p_given_name,
    p_family_name,
    p_picture_url,
    p_locale,
    p_profile_metadata,
    p_app_metadata,
    p_is_active,
    NOW(),
    p_updated_at
  )
  ON CONFLICT (auth0_user_id)  -- assuming this is unique
  DO UPDATE SET
    email            = EXCLUDED.email,
    display_name     = EXCLUDED.display_name,
    name             = EXCLUDED.name,
    given_name       = EXCLUDED.given_name,
    family_name      = EXCLUDED.family_name,
    picture_url      = EXCLUDED.picture_url,
    locale           = EXCLUDED.locale,
    profile_metadata = EXCLUDED.profile_metadata,
    app_metadata     = EXCLUDED.app_metadata,
    is_active        = EXCLUDED.is_active,
    updated_at       = EXCLUDED.updated_at
  ;
END;
$$;


ALTER FUNCTION "public"."upsert_user"("p_auth0_user_id" "text", "p_email" "text", "p_display_name" "text", "p_name" "text", "p_given_name" "text", "p_family_name" "text", "p_picture_url" "text", "p_locale" "text", "p_profile_metadata" "jsonb", "p_app_metadata" "jsonb", "p_is_active" boolean, "p_updated_at" timestamp with time zone) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "agent"."conversation_messages" (
    "id" bigint NOT NULL,
    "conversation_id" bigint NOT NULL,
    "sender_type" "text" NOT NULL,
    "message_text" "text" NOT NULL,
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "conversation_messages_sender_type_check" CHECK (("sender_type" = ANY (ARRAY['user'::"text", 'assistant'::"text"])))
);


ALTER TABLE "agent"."conversation_messages" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "agent"."conversation_messages_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "agent"."conversation_messages_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "agent"."conversation_messages_id_seq" OWNED BY "agent"."conversation_messages"."id";



CREATE TABLE IF NOT EXISTS "agent"."conversations" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "plant_species_id" bigint,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_activity_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "agent"."conversations" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "agent"."conversations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "agent"."conversations_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "agent"."conversations_id_seq" OWNED BY "agent"."conversations"."id";



CREATE TABLE IF NOT EXISTS "agent"."knowledge_chunks" (
    "id" bigint NOT NULL,
    "document_id" bigint NOT NULL,
    "chunk_text" "text" NOT NULL,
    "chunk_index" integer NOT NULL,
    "embedding" "public"."vector"(1536),
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "agent"."knowledge_chunks" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "agent"."knowledge_chunks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "agent"."knowledge_chunks_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "agent"."knowledge_chunks_id_seq" OWNED BY "agent"."knowledge_chunks"."id";



CREATE TABLE IF NOT EXISTS "agent"."knowledge_documents" (
    "id" bigint NOT NULL,
    "plant_species_id" bigint,
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "document_type" "text" NOT NULL,
    "source_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "knowledge_documents_document_type_check" CHECK (("document_type" = ANY (ARRAY['care_guide'::"text", 'fact_sheet'::"text", 'article'::"text", 'faq'::"text", 'other'::"text"])))
);


ALTER TABLE "agent"."knowledge_documents" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "agent"."knowledge_documents_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "agent"."knowledge_documents_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "agent"."knowledge_documents_id_seq" OWNED BY "agent"."knowledge_documents"."id";



CREATE TABLE IF NOT EXISTS "agent"."user_memories" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "memory_type" "text" NOT NULL,
    "content" "text" NOT NULL,
    "importance" integer DEFAULT 5,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_accessed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_memories_importance_check" CHECK ((("importance" >= 1) AND ("importance" <= 10))),
    CONSTRAINT "user_memories_memory_type_check" CHECK (("memory_type" = ANY (ARRAY['preference'::"text", 'fact'::"text", 'interest'::"text", 'goal'::"text", 'other'::"text"])))
);


ALTER TABLE "agent"."user_memories" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "agent"."user_memories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "agent"."user_memories_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "agent"."user_memories_id_seq" OWNED BY "agent"."user_memories"."id";



CREATE TABLE IF NOT EXISTS "auth0"."roles" (
    "id" smallint NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "auth0"."roles" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "auth0"."roles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "auth0"."roles_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "auth0"."roles_id_seq" OWNED BY "auth0"."roles"."id";



CREATE TABLE IF NOT EXISTS "auth0"."user_roles" (
    "user_id" bigint NOT NULL,
    "role_id" smallint NOT NULL
);


ALTER TABLE "auth0"."user_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "auth0"."users" (
    "id" bigint NOT NULL,
    "auth0_user_id" "text" NOT NULL,
    "email" "text",
    "display_name" "text",
    "name" "text",
    "given_name" "text",
    "family_name" "text",
    "picture_url" "text",
    "locale" "text",
    "profile_metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "app_metadata" "jsonb",
    "is_active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "auth0"."users" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "auth0"."users_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "auth0"."users_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "auth0"."users_id_seq" OWNED BY "auth0"."users"."id";



CREATE TABLE IF NOT EXISTS "dome"."event_registrations" (
    "id" bigint NOT NULL,
    "event_id" bigint NOT NULL,
    "user_id" bigint,
    "attendee_name" "text" NOT NULL,
    "attendee_email" "text",
    "attendee_phone" "text",
    "registration_time" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'registered'::"text" NOT NULL,
    "notes" "text",
    CONSTRAINT "event_registrations_status_check" CHECK (("status" = ANY (ARRAY['registered'::"text", 'attended'::"text", 'cancelled'::"text", 'no_show'::"text"])))
);


ALTER TABLE "dome"."event_registrations" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "dome"."event_registrations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "dome"."event_registrations_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "dome"."event_registrations_id_seq" OWNED BY "dome"."event_registrations"."id";



CREATE TABLE IF NOT EXISTS "dome"."events" (
    "id" bigint NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "event_type" "text" NOT NULL,
    "start_time" timestamp with time zone NOT NULL,
    "end_time" timestamp with time zone NOT NULL,
    "location" "text",
    "capacity" integer,
    "registration_required" boolean DEFAULT false NOT NULL,
    "registration_url" "text",
    "image_url" "text",
    "created_by_user_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "events_check" CHECK (("end_time" > "start_time")),
    CONSTRAINT "events_event_type_check" CHECK (("event_type" = ANY (ARRAY['tour'::"text", 'class'::"text", 'exhibition'::"text", 'special_event'::"text", 'other'::"text"])))
);


ALTER TABLE "dome"."events" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "dome"."events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "dome"."events_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "dome"."events_id_seq" OWNED BY "dome"."events"."id";



CREATE TABLE IF NOT EXISTS "dome"."info_pages" (
    "id" bigint NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "published" boolean DEFAULT true NOT NULL,
    "display_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "dome"."info_pages" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "dome"."info_pages_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "dome"."info_pages_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "dome"."info_pages_id_seq" OWNED BY "dome"."info_pages"."id";



CREATE TABLE IF NOT EXISTS "gamification"."achievements" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" NOT NULL,
    "icon_url" "text",
    "achievement_type" "text" NOT NULL,
    "threshold" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "gamification"."achievements" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."achievements_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."achievements_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."achievements_id_seq" OWNED BY "gamification"."achievements"."id";



CREATE TABLE IF NOT EXISTS "gamification"."collectible_catalog" (
    "id" bigint NOT NULL,
    "catalog_number" integer NOT NULL,
    "plant_species_id" bigint NOT NULL,
    "rarity_tier" "text" DEFAULT 'common'::"text" NOT NULL,
    "featured_order" integer,
    "collectible_since" timestamp with time zone DEFAULT "now"() NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    CONSTRAINT "collectible_catalog_rarity_tier_check" CHECK (("rarity_tier" = ANY (ARRAY['common'::"text", 'uncommon'::"text", 'rare'::"text", 'legendary'::"text"])))
);


ALTER TABLE "gamification"."collectible_catalog" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."collectible_catalog_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."collectible_catalog_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."collectible_catalog_id_seq" OWNED BY "gamification"."collectible_catalog"."id";



CREATE TABLE IF NOT EXISTS "gamification"."plant_discoveries" (
    "id" bigint NOT NULL,
    "scrapbook_id" bigint NOT NULL,
    "discovered_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "notes" "text",
    "favorite" boolean DEFAULT false NOT NULL,
    "catalog_entry_id" bigint NOT NULL
);


ALTER TABLE "gamification"."plant_discoveries" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."plant_discoveries_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."plant_discoveries_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."plant_discoveries_id_seq" OWNED BY "gamification"."plant_discoveries"."id";



CREATE TABLE IF NOT EXISTS "gamification"."qr_codes" (
    "id" bigint NOT NULL,
    "code_token" "uuid" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "plant_species_id" bigint NOT NULL,
    "location_id" bigint
);


ALTER TABLE "gamification"."qr_codes" OWNER TO "postgres";


COMMENT ON COLUMN "gamification"."qr_codes"."plant_species_id" IS 'The plant species this QR code represents';



COMMENT ON COLUMN "gamification"."qr_codes"."location_id" IS 'Optional location where this QR code is placed';



CREATE SEQUENCE IF NOT EXISTS "gamification"."qr_codes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."qr_codes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."qr_codes_id_seq" OWNED BY "gamification"."qr_codes"."id";



CREATE TABLE IF NOT EXISTS "gamification"."qr_scans" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "qr_code_id" bigint NOT NULL,
    "scanned_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "gamification"."qr_scans" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."qr_scans_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."qr_scans_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."qr_scans_id_seq" OWNED BY "gamification"."qr_scans"."id";



CREATE TABLE IF NOT EXISTS "gamification"."scrapbooks" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "gamification"."scrapbooks" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."scrapbooks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."scrapbooks_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."scrapbooks_id_seq" OWNED BY "gamification"."scrapbooks"."id";



CREATE TABLE IF NOT EXISTS "gamification"."trivia_answers" (
    "id" bigint NOT NULL,
    "question_id" bigint NOT NULL,
    "answer_text" "text" NOT NULL,
    "is_correct" boolean DEFAULT false NOT NULL,
    "explanation" "text"
);


ALTER TABLE "gamification"."trivia_answers" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."trivia_answers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."trivia_answers_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."trivia_answers_id_seq" OWNED BY "gamification"."trivia_answers"."id";



CREATE TABLE IF NOT EXISTS "gamification"."trivia_attempts" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "question_id" bigint NOT NULL,
    "selected_answer_id" bigint,
    "is_correct" boolean NOT NULL,
    "attempted_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "gamification"."trivia_attempts" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."trivia_attempts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."trivia_attempts_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."trivia_attempts_id_seq" OWNED BY "gamification"."trivia_attempts"."id";



CREATE TABLE IF NOT EXISTS "gamification"."trivia_questions" (
    "id" bigint NOT NULL,
    "plant_species_id" bigint,
    "question" "text" NOT NULL,
    "difficulty" "text" DEFAULT 'medium'::"text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "trivia_questions_difficulty_check" CHECK (("difficulty" = ANY (ARRAY['easy'::"text", 'medium'::"text", 'hard'::"text"])))
);


ALTER TABLE "gamification"."trivia_questions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."trivia_questions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."trivia_questions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."trivia_questions_id_seq" OWNED BY "gamification"."trivia_questions"."id";



CREATE TABLE IF NOT EXISTS "gamification"."user_achievements" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "achievement_id" bigint NOT NULL,
    "earned_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "gamification"."user_achievements" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "gamification"."user_achievements_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gamification"."user_achievements_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "gamification"."user_achievements_id_seq" OWNED BY "gamification"."user_achievements"."id";



CREATE TABLE IF NOT EXISTS "inventory"."plant_instances" (
    "id" bigint NOT NULL,
    "storage_location_id" bigint,
    "identifier" "text",
    "quantity" integer DEFAULT 1 NOT NULL,
    "status" "text" DEFAULT 'available'::"text" NOT NULL,
    "acquired_date" "date",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "species_id" bigint NOT NULL,
    "is_public" boolean DEFAULT true NOT NULL,
    CONSTRAINT "plant_instances_status_check" CHECK (("status" = ANY (ARRAY['available'::"text", 'reserved'::"text", 'sold'::"text", 'removed'::"text"])))
);


ALTER TABLE "inventory"."plant_instances" OWNER TO "postgres";


COMMENT ON COLUMN "inventory"."plant_instances"."is_public" IS 'Whether this plant instance is visible to the public. False indicates staging/private state.';



CREATE SEQUENCE IF NOT EXISTS "inventory"."plant_instances_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "inventory"."plant_instances_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "inventory"."plant_instances_id_seq" OWNED BY "inventory"."plant_instances"."id";



CREATE TABLE IF NOT EXISTS "inventory"."plant_notes" (
    "id" bigint NOT NULL,
    "plant_instance_id" bigint NOT NULL,
    "staff_user_id" bigint NOT NULL,
    "note_type" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "plant_notes_note_type_check" CHECK (("note_type" = ANY (ARRAY['observation'::"text", 'maintenance'::"text", 'issue'::"text", 'transfer'::"text", 'other'::"text"])))
);


ALTER TABLE "inventory"."plant_notes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "inventory"."plant_notes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "inventory"."plant_notes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "inventory"."plant_notes_id_seq" OWNED BY "inventory"."plant_notes"."id";



CREATE TABLE IF NOT EXISTS "inventory"."stock_requests" (
    "id" bigint NOT NULL,
    "requested_by_user_id" bigint NOT NULL,
    "requested_species_name" "text",
    "quantity" integer NOT NULL,
    "priority" "text" DEFAULT 'normal'::"text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "justification" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "species_id" bigint,
    CONSTRAINT "stock_requests_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'normal'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "stock_requests_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "stock_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'ordered'::"text", 'received'::"text", 'rejected'::"text"])))
);


ALTER TABLE "inventory"."stock_requests" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "inventory"."stock_requests_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "inventory"."stock_requests_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "inventory"."stock_requests_id_seq" OWNED BY "inventory"."stock_requests"."id";



CREATE TABLE IF NOT EXISTS "inventory"."storage_locations" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "location_type" "text" NOT NULL,
    "description" "text",
    "capacity" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "storage_locations_location_type_check" CHECK (("location_type" = ANY (ARRAY['greenhouse'::"text", 'dome'::"text", 'storage'::"text", 'quarantine'::"text", 'other'::"text"])))
);


ALTER TABLE "inventory"."storage_locations" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "inventory"."storage_locations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "inventory"."storage_locations_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "inventory"."storage_locations_id_seq" OWNED BY "inventory"."storage_locations"."id";



CREATE TABLE IF NOT EXISTS "plants"."articles" (
    "id" bigint NOT NULL,
    "species_id" bigint NOT NULL,
    "article_content" "text" NOT NULL,
    "author_user_id" bigint,
    "published" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "plants"."articles" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "plants"."articles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "plants"."articles_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "plants"."articles_id_seq" OWNED BY "plants"."articles"."id";



CREATE TABLE IF NOT EXISTS "plants"."species" (
    "id" bigint NOT NULL,
    "scientific_name" "text" NOT NULL,
    "common_name" "text",
    "description" "text",
    "image_url" "text"
);


ALTER TABLE "plants"."species" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "plants"."species_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "plants"."species_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "plants"."species_id_seq" OWNED BY "plants"."species"."id";



CREATE TABLE IF NOT EXISTS "staff"."announcements" (
    "id" bigint NOT NULL,
    "created_by_user_id" bigint NOT NULL,
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "priority" "text" DEFAULT 'normal'::"text" NOT NULL,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "announcements_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'normal'::"text", 'high'::"text", 'urgent'::"text"])))
);


ALTER TABLE "staff"."announcements" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "staff"."announcements_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "staff"."announcements_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "staff"."announcements_id_seq" OWNED BY "staff"."announcements"."id";



CREATE TABLE IF NOT EXISTS "staff"."feedback" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "rating" integer NOT NULL,
    "tropics_rating" integer,
    "desert_rating" integer,
    "show_rating" integer,
    "staff_friendliness" integer,
    "cleanliness" integer,
    "additional_comments" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "feedback_cleanliness_check" CHECK ((("cleanliness" IS NULL) OR (("cleanliness" >= 1) AND ("cleanliness" <= 5)))),
    CONSTRAINT "feedback_desert_rating_check" CHECK ((("desert_rating" IS NULL) OR (("desert_rating" >= 1) AND ("desert_rating" <= 5)))),
    CONSTRAINT "feedback_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5))),
    CONSTRAINT "feedback_show_rating_check" CHECK ((("show_rating" IS NULL) OR (("show_rating" >= 1) AND ("show_rating" <= 5)))),
    CONSTRAINT "feedback_staff_friendliness_check" CHECK ((("staff_friendliness" IS NULL) OR (("staff_friendliness" >= 1) AND ("staff_friendliness" <= 5)))),
    CONSTRAINT "feedback_tropics_rating_check" CHECK ((("tropics_rating" IS NULL) OR (("tropics_rating" >= 1) AND ("tropics_rating" <= 5))))
);


ALTER TABLE "staff"."feedback" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "staff"."feedback_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "staff"."feedback_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "staff"."feedback_id_seq" OWNED BY "staff"."feedback"."id";



CREATE TABLE IF NOT EXISTS "staff"."schedules" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "shift_start" timestamp with time zone NOT NULL,
    "shift_end" timestamp with time zone NOT NULL,
    "role_during_shift" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "schedules_check" CHECK (("shift_end" > "shift_start"))
);


ALTER TABLE "staff"."schedules" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "staff"."schedules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "staff"."schedules_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "staff"."schedules_id_seq" OWNED BY "staff"."schedules"."id";



CREATE TABLE IF NOT EXISTS "staff"."task_comments" (
    "id" bigint NOT NULL,
    "task_id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "comment" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "staff"."task_comments" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "staff"."task_comments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "staff"."task_comments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "staff"."task_comments_id_seq" OWNED BY "staff"."task_comments"."id";



CREATE TABLE IF NOT EXISTS "staff"."tasks" (
    "id" bigint NOT NULL,
    "created_by_user_id" bigint NOT NULL,
    "assigned_to_user_id" bigint,
    "title" "text" NOT NULL,
    "description" "text",
    "priority" "text" DEFAULT 'normal'::"text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "due_date" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "tasks_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'normal'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "tasks_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'in_progress'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "staff"."tasks" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "staff"."tasks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "staff"."tasks_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "staff"."tasks_id_seq" OWNED BY "staff"."tasks"."id";



ALTER TABLE ONLY "agent"."conversation_messages" ALTER COLUMN "id" SET DEFAULT "nextval"('"agent"."conversation_messages_id_seq"'::"regclass");



ALTER TABLE ONLY "agent"."conversations" ALTER COLUMN "id" SET DEFAULT "nextval"('"agent"."conversations_id_seq"'::"regclass");



ALTER TABLE ONLY "agent"."knowledge_chunks" ALTER COLUMN "id" SET DEFAULT "nextval"('"agent"."knowledge_chunks_id_seq"'::"regclass");



ALTER TABLE ONLY "agent"."knowledge_documents" ALTER COLUMN "id" SET DEFAULT "nextval"('"agent"."knowledge_documents_id_seq"'::"regclass");



ALTER TABLE ONLY "agent"."user_memories" ALTER COLUMN "id" SET DEFAULT "nextval"('"agent"."user_memories_id_seq"'::"regclass");



ALTER TABLE ONLY "auth0"."roles" ALTER COLUMN "id" SET DEFAULT "nextval"('"auth0"."roles_id_seq"'::"regclass");



ALTER TABLE ONLY "auth0"."users" ALTER COLUMN "id" SET DEFAULT "nextval"('"auth0"."users_id_seq"'::"regclass");



ALTER TABLE ONLY "dome"."event_registrations" ALTER COLUMN "id" SET DEFAULT "nextval"('"dome"."event_registrations_id_seq"'::"regclass");



ALTER TABLE ONLY "dome"."events" ALTER COLUMN "id" SET DEFAULT "nextval"('"dome"."events_id_seq"'::"regclass");



ALTER TABLE ONLY "dome"."info_pages" ALTER COLUMN "id" SET DEFAULT "nextval"('"dome"."info_pages_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."achievements" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."achievements_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."collectible_catalog" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."collectible_catalog_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."plant_discoveries" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."plant_discoveries_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."qr_codes" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."qr_codes_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."qr_scans" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."qr_scans_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."scrapbooks" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."scrapbooks_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."trivia_answers" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."trivia_answers_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."trivia_attempts" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."trivia_attempts_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."trivia_questions" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."trivia_questions_id_seq"'::"regclass");



ALTER TABLE ONLY "gamification"."user_achievements" ALTER COLUMN "id" SET DEFAULT "nextval"('"gamification"."user_achievements_id_seq"'::"regclass");



ALTER TABLE ONLY "inventory"."plant_instances" ALTER COLUMN "id" SET DEFAULT "nextval"('"inventory"."plant_instances_id_seq"'::"regclass");



ALTER TABLE ONLY "inventory"."plant_notes" ALTER COLUMN "id" SET DEFAULT "nextval"('"inventory"."plant_notes_id_seq"'::"regclass");



ALTER TABLE ONLY "inventory"."stock_requests" ALTER COLUMN "id" SET DEFAULT "nextval"('"inventory"."stock_requests_id_seq"'::"regclass");



ALTER TABLE ONLY "inventory"."storage_locations" ALTER COLUMN "id" SET DEFAULT "nextval"('"inventory"."storage_locations_id_seq"'::"regclass");



ALTER TABLE ONLY "plants"."articles" ALTER COLUMN "id" SET DEFAULT "nextval"('"plants"."articles_id_seq"'::"regclass");



ALTER TABLE ONLY "plants"."species" ALTER COLUMN "id" SET DEFAULT "nextval"('"plants"."species_id_seq"'::"regclass");



ALTER TABLE ONLY "staff"."announcements" ALTER COLUMN "id" SET DEFAULT "nextval"('"staff"."announcements_id_seq"'::"regclass");



ALTER TABLE ONLY "staff"."feedback" ALTER COLUMN "id" SET DEFAULT "nextval"('"staff"."feedback_id_seq"'::"regclass");



ALTER TABLE ONLY "staff"."schedules" ALTER COLUMN "id" SET DEFAULT "nextval"('"staff"."schedules_id_seq"'::"regclass");



ALTER TABLE ONLY "staff"."task_comments" ALTER COLUMN "id" SET DEFAULT "nextval"('"staff"."task_comments_id_seq"'::"regclass");



ALTER TABLE ONLY "staff"."tasks" ALTER COLUMN "id" SET DEFAULT "nextval"('"staff"."tasks_id_seq"'::"regclass");



ALTER TABLE ONLY "agent"."conversation_messages"
    ADD CONSTRAINT "conversation_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "agent"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "agent"."knowledge_chunks"
    ADD CONSTRAINT "knowledge_chunks_document_id_chunk_index_key" UNIQUE ("document_id", "chunk_index");



ALTER TABLE ONLY "agent"."knowledge_chunks"
    ADD CONSTRAINT "knowledge_chunks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "agent"."knowledge_documents"
    ADD CONSTRAINT "knowledge_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "agent"."user_memories"
    ADD CONSTRAINT "user_memories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth0"."roles"
    ADD CONSTRAINT "roles_name_key" UNIQUE ("name");



ALTER TABLE ONLY "auth0"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth0"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id", "role_id");



ALTER TABLE ONLY "auth0"."users"
    ADD CONSTRAINT "users_auth0_user_id_key" UNIQUE ("auth0_user_id");



ALTER TABLE ONLY "auth0"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "auth0"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "dome"."event_registrations"
    ADD CONSTRAINT "event_registrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "dome"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "dome"."info_pages"
    ADD CONSTRAINT "info_pages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "dome"."info_pages"
    ADD CONSTRAINT "info_pages_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "gamification"."achievements"
    ADD CONSTRAINT "achievements_name_key" UNIQUE ("name");



ALTER TABLE ONLY "gamification"."achievements"
    ADD CONSTRAINT "achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."collectible_catalog"
    ADD CONSTRAINT "collectible_catalog_catalog_number_key" UNIQUE ("catalog_number");



ALTER TABLE ONLY "gamification"."collectible_catalog"
    ADD CONSTRAINT "collectible_catalog_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."collectible_catalog"
    ADD CONSTRAINT "collectible_catalog_plant_species_id_key" UNIQUE ("plant_species_id");



ALTER TABLE ONLY "gamification"."plant_discoveries"
    ADD CONSTRAINT "plant_discoveries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."plant_discoveries"
    ADD CONSTRAINT "plant_discoveries_scrapbook_id_catalog_entry_id_key" UNIQUE ("scrapbook_id", "catalog_entry_id");



ALTER TABLE ONLY "gamification"."qr_codes"
    ADD CONSTRAINT "qr_codes_code_token_key" UNIQUE ("code_token");



ALTER TABLE ONLY "gamification"."qr_codes"
    ADD CONSTRAINT "qr_codes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."qr_scans"
    ADD CONSTRAINT "qr_scans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."scrapbooks"
    ADD CONSTRAINT "scrapbooks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."trivia_answers"
    ADD CONSTRAINT "trivia_answers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."trivia_attempts"
    ADD CONSTRAINT "trivia_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."trivia_questions"
    ADD CONSTRAINT "trivia_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."user_achievements"
    ADD CONSTRAINT "user_achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "gamification"."user_achievements"
    ADD CONSTRAINT "user_achievements_user_id_achievement_id_key" UNIQUE ("user_id", "achievement_id");



ALTER TABLE ONLY "inventory"."plant_instances"
    ADD CONSTRAINT "plant_instances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventory"."plant_notes"
    ADD CONSTRAINT "plant_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventory"."stock_requests"
    ADD CONSTRAINT "stock_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventory"."storage_locations"
    ADD CONSTRAINT "storage_locations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "inventory"."storage_locations"
    ADD CONSTRAINT "storage_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "plants"."articles"
    ADD CONSTRAINT "articles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "plants"."articles"
    ADD CONSTRAINT "articles_species_id_key" UNIQUE ("species_id");



ALTER TABLE ONLY "plants"."species"
    ADD CONSTRAINT "species_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "plants"."species"
    ADD CONSTRAINT "species_scientific_name_key" UNIQUE ("scientific_name");



ALTER TABLE ONLY "staff"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staff"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staff"."schedules"
    ADD CONSTRAINT "schedules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staff"."task_comments"
    ADD CONSTRAINT "task_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staff"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_conversation_messages_conversation_id" ON "agent"."conversation_messages" USING "btree" ("conversation_id");



CREATE INDEX "idx_conversation_messages_created_at" ON "agent"."conversation_messages" USING "btree" ("created_at");



CREATE INDEX "idx_conversation_messages_sender_type" ON "agent"."conversation_messages" USING "btree" ("sender_type");



CREATE INDEX "idx_conversations_last_activity_at" ON "agent"."conversations" USING "btree" ("last_activity_at");



CREATE INDEX "idx_conversations_plant_species_id" ON "agent"."conversations" USING "btree" ("plant_species_id");



CREATE INDEX "idx_conversations_started_at" ON "agent"."conversations" USING "btree" ("started_at");



CREATE INDEX "idx_conversations_user_id" ON "agent"."conversations" USING "btree" ("user_id");



CREATE INDEX "idx_knowledge_chunks_chunk_index" ON "agent"."knowledge_chunks" USING "btree" ("chunk_index");



CREATE INDEX "idx_knowledge_chunks_document_id" ON "agent"."knowledge_chunks" USING "btree" ("document_id");



CREATE INDEX "idx_knowledge_chunks_embedding" ON "agent"."knowledge_chunks" USING "ivfflat" ("embedding" "public"."vector_cosine_ops") WITH ("lists"='100');



CREATE INDEX "idx_knowledge_documents_document_type" ON "agent"."knowledge_documents" USING "btree" ("document_type");



CREATE INDEX "idx_knowledge_documents_plant_species_id" ON "agent"."knowledge_documents" USING "btree" ("plant_species_id");



CREATE INDEX "idx_knowledge_documents_updated_at" ON "agent"."knowledge_documents" USING "btree" ("updated_at");



CREATE INDEX "idx_user_memories_importance" ON "agent"."user_memories" USING "btree" ("importance");



CREATE INDEX "idx_user_memories_last_accessed_at" ON "agent"."user_memories" USING "btree" ("last_accessed_at");



CREATE INDEX "idx_user_memories_memory_type" ON "agent"."user_memories" USING "btree" ("memory_type");



CREATE INDEX "idx_user_memories_user_id" ON "agent"."user_memories" USING "btree" ("user_id");



CREATE INDEX "idx_user_roles_role_id" ON "auth0"."user_roles" USING "btree" ("role_id");



CREATE INDEX "idx_user_roles_user_id" ON "auth0"."user_roles" USING "btree" ("user_id");



CREATE INDEX "idx_users_auth0_user_id" ON "auth0"."users" USING "btree" ("auth0_user_id");



CREATE INDEX "idx_users_email" ON "auth0"."users" USING "btree" ("email");



CREATE INDEX "idx_event_registrations_event_id" ON "dome"."event_registrations" USING "btree" ("event_id");



CREATE INDEX "idx_event_registrations_status" ON "dome"."event_registrations" USING "btree" ("status");



CREATE INDEX "idx_event_registrations_user_id" ON "dome"."event_registrations" USING "btree" ("user_id");



CREATE INDEX "idx_events_created_by_user_id" ON "dome"."events" USING "btree" ("created_by_user_id");



CREATE INDEX "idx_events_end_time" ON "dome"."events" USING "btree" ("end_time");



CREATE INDEX "idx_events_event_type" ON "dome"."events" USING "btree" ("event_type");



CREATE INDEX "idx_events_start_time" ON "dome"."events" USING "btree" ("start_time");



CREATE INDEX "idx_info_pages_display_order" ON "dome"."info_pages" USING "btree" ("display_order");



CREATE INDEX "idx_info_pages_published" ON "dome"."info_pages" USING "btree" ("published");



CREATE INDEX "idx_info_pages_slug" ON "dome"."info_pages" USING "btree" ("slug");



CREATE INDEX "idx_achievements_achievement_type" ON "gamification"."achievements" USING "btree" ("achievement_type");



CREATE INDEX "idx_collectible_catalog_active" ON "gamification"."collectible_catalog" USING "btree" ("active");



CREATE INDEX "idx_collectible_catalog_catalog_number" ON "gamification"."collectible_catalog" USING "btree" ("catalog_number");



CREATE INDEX "idx_collectible_catalog_plant_species_id" ON "gamification"."collectible_catalog" USING "btree" ("plant_species_id");



CREATE INDEX "idx_collectible_catalog_rarity_tier" ON "gamification"."collectible_catalog" USING "btree" ("rarity_tier");



CREATE INDEX "idx_plant_discoveries_catalog_entry_id" ON "gamification"."plant_discoveries" USING "btree" ("catalog_entry_id");



CREATE INDEX "idx_plant_discoveries_discovered_at" ON "gamification"."plant_discoveries" USING "btree" ("discovered_at");



CREATE INDEX "idx_plant_discoveries_favorite" ON "gamification"."plant_discoveries" USING "btree" ("favorite");



CREATE INDEX "idx_plant_discoveries_scrapbook_id" ON "gamification"."plant_discoveries" USING "btree" ("scrapbook_id");



CREATE INDEX "idx_qr_codes_active" ON "gamification"."qr_codes" USING "btree" ("active");



CREATE INDEX "idx_qr_codes_code_token" ON "gamification"."qr_codes" USING "btree" ("code_token");



CREATE INDEX "idx_qr_codes_location_id" ON "gamification"."qr_codes" USING "btree" ("location_id");



CREATE INDEX "idx_qr_codes_plant_species_id" ON "gamification"."qr_codes" USING "btree" ("plant_species_id");



CREATE INDEX "idx_qr_codes_species_id" ON "gamification"."qr_codes" USING "btree" ("plant_species_id");



CREATE INDEX "idx_qr_scans_qr_code_id" ON "gamification"."qr_scans" USING "btree" ("qr_code_id");



CREATE INDEX "idx_qr_scans_scanned_at" ON "gamification"."qr_scans" USING "btree" ("scanned_at");



CREATE INDEX "idx_qr_scans_user_id" ON "gamification"."qr_scans" USING "btree" ("user_id");



CREATE INDEX "idx_scrapbooks_user_id" ON "gamification"."scrapbooks" USING "btree" ("user_id");



CREATE INDEX "idx_trivia_answers_is_correct" ON "gamification"."trivia_answers" USING "btree" ("is_correct");



CREATE INDEX "idx_trivia_answers_question_id" ON "gamification"."trivia_answers" USING "btree" ("question_id");



CREATE INDEX "idx_trivia_attempts_attempted_at" ON "gamification"."trivia_attempts" USING "btree" ("attempted_at");



CREATE INDEX "idx_trivia_attempts_question_id" ON "gamification"."trivia_attempts" USING "btree" ("question_id");



CREATE INDEX "idx_trivia_attempts_user_id" ON "gamification"."trivia_attempts" USING "btree" ("user_id");



CREATE INDEX "idx_trivia_questions_active" ON "gamification"."trivia_questions" USING "btree" ("active");



CREATE INDEX "idx_trivia_questions_difficulty" ON "gamification"."trivia_questions" USING "btree" ("difficulty");



CREATE INDEX "idx_trivia_questions_plant_species_id" ON "gamification"."trivia_questions" USING "btree" ("plant_species_id");



CREATE INDEX "idx_user_achievements_achievement_id" ON "gamification"."user_achievements" USING "btree" ("achievement_id");



CREATE INDEX "idx_user_achievements_earned_at" ON "gamification"."user_achievements" USING "btree" ("earned_at");



CREATE INDEX "idx_user_achievements_user_id" ON "gamification"."user_achievements" USING "btree" ("user_id");



CREATE INDEX "idx_plant_instances_identifier" ON "inventory"."plant_instances" USING "btree" ("identifier");



CREATE INDEX "idx_plant_instances_is_public" ON "inventory"."plant_instances" USING "btree" ("is_public");



CREATE INDEX "idx_plant_instances_species_id" ON "inventory"."plant_instances" USING "btree" ("species_id");



CREATE INDEX "idx_plant_instances_status" ON "inventory"."plant_instances" USING "btree" ("status");



CREATE INDEX "idx_plant_instances_storage_location_id" ON "inventory"."plant_instances" USING "btree" ("storage_location_id");



CREATE INDEX "idx_plant_notes_created_at" ON "inventory"."plant_notes" USING "btree" ("created_at");



CREATE INDEX "idx_plant_notes_note_type" ON "inventory"."plant_notes" USING "btree" ("note_type");



CREATE INDEX "idx_plant_notes_plant_instance_id" ON "inventory"."plant_notes" USING "btree" ("plant_instance_id");



CREATE INDEX "idx_plant_notes_staff_user_id" ON "inventory"."plant_notes" USING "btree" ("staff_user_id");



CREATE INDEX "idx_stock_requests_priority" ON "inventory"."stock_requests" USING "btree" ("priority");



CREATE INDEX "idx_stock_requests_requested_by_user_id" ON "inventory"."stock_requests" USING "btree" ("requested_by_user_id");



CREATE INDEX "idx_stock_requests_species_id" ON "inventory"."stock_requests" USING "btree" ("species_id");



CREATE INDEX "idx_stock_requests_status" ON "inventory"."stock_requests" USING "btree" ("status");



CREATE INDEX "idx_storage_locations_location_type" ON "inventory"."storage_locations" USING "btree" ("location_type");



CREATE INDEX "idx_articles_published" ON "plants"."articles" USING "btree" ("published");



CREATE INDEX "idx_articles_species_id" ON "plants"."articles" USING "btree" ("species_id");



CREATE INDEX "idx_species_common_name" ON "plants"."species" USING "btree" ("common_name");



CREATE INDEX "idx_species_scientific_name" ON "plants"."species" USING "btree" ("scientific_name");



CREATE INDEX "idx_announcements_created_at" ON "staff"."announcements" USING "btree" ("created_at");



CREATE INDEX "idx_announcements_created_by_user_id" ON "staff"."announcements" USING "btree" ("created_by_user_id");



CREATE INDEX "idx_announcements_expires_at" ON "staff"."announcements" USING "btree" ("expires_at") WHERE ("expires_at" IS NOT NULL);



CREATE INDEX "idx_announcements_priority" ON "staff"."announcements" USING "btree" ("priority");



CREATE INDEX "idx_feedback_created_at" ON "staff"."feedback" USING "btree" ("created_at");



CREATE INDEX "idx_feedback_rating" ON "staff"."feedback" USING "btree" ("rating");



CREATE INDEX "idx_feedback_user_id" ON "staff"."feedback" USING "btree" ("user_id") WHERE ("user_id" IS NOT NULL);



CREATE INDEX "idx_schedules_shift_end" ON "staff"."schedules" USING "btree" ("shift_end");



CREATE INDEX "idx_schedules_shift_start" ON "staff"."schedules" USING "btree" ("shift_start");



CREATE INDEX "idx_schedules_user_id" ON "staff"."schedules" USING "btree" ("user_id");



CREATE INDEX "idx_task_comments_task_id" ON "staff"."task_comments" USING "btree" ("task_id");



CREATE INDEX "idx_task_comments_user_id" ON "staff"."task_comments" USING "btree" ("user_id");



CREATE INDEX "idx_tasks_assigned_to_user_id" ON "staff"."tasks" USING "btree" ("assigned_to_user_id");



CREATE INDEX "idx_tasks_created_by_user_id" ON "staff"."tasks" USING "btree" ("created_by_user_id");



CREATE INDEX "idx_tasks_due_date" ON "staff"."tasks" USING "btree" ("due_date") WHERE ("due_date" IS NOT NULL);



CREATE INDEX "idx_tasks_priority" ON "staff"."tasks" USING "btree" ("priority");



CREATE INDEX "idx_tasks_status" ON "staff"."tasks" USING "btree" ("status");



CREATE OR REPLACE TRIGGER "trg_auth0_users_updated_at" BEFORE UPDATE ON "auth0"."users" FOR EACH ROW EXECUTE FUNCTION "auth0"."set_updated_at_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_add_plant_to_catalog" AFTER INSERT ON "plants"."species" FOR EACH ROW EXECUTE FUNCTION "gamification"."auto_add_plant_to_catalog"();



ALTER TABLE ONLY "agent"."conversation_messages"
    ADD CONSTRAINT "conversation_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "agent"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "agent"."conversations"
    ADD CONSTRAINT "conversations_plant_species_id_fkey" FOREIGN KEY ("plant_species_id") REFERENCES "plants"."species"("id");



ALTER TABLE ONLY "agent"."conversations"
    ADD CONSTRAINT "conversations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "agent"."knowledge_chunks"
    ADD CONSTRAINT "knowledge_chunks_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "agent"."knowledge_documents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "agent"."knowledge_documents"
    ADD CONSTRAINT "knowledge_documents_plant_species_id_fkey" FOREIGN KEY ("plant_species_id") REFERENCES "plants"."species"("id");



ALTER TABLE ONLY "agent"."user_memories"
    ADD CONSTRAINT "user_memories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth0"."user_roles"
    ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "auth0"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth0"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "dome"."event_registrations"
    ADD CONSTRAINT "event_registrations_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "dome"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "dome"."event_registrations"
    ADD CONSTRAINT "event_registrations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "dome"."events"
    ADD CONSTRAINT "events_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "gamification"."collectible_catalog"
    ADD CONSTRAINT "collectible_catalog_plant_species_id_fkey" FOREIGN KEY ("plant_species_id") REFERENCES "plants"."species"("id");



ALTER TABLE ONLY "gamification"."plant_discoveries"
    ADD CONSTRAINT "plant_discoveries_catalog_entry_id_fkey" FOREIGN KEY ("catalog_entry_id") REFERENCES "gamification"."collectible_catalog"("id");



ALTER TABLE ONLY "gamification"."plant_discoveries"
    ADD CONSTRAINT "plant_discoveries_scrapbook_id_fkey" FOREIGN KEY ("scrapbook_id") REFERENCES "gamification"."scrapbooks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "gamification"."qr_codes"
    ADD CONSTRAINT "qr_codes_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "inventory"."storage_locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "gamification"."qr_codes"
    ADD CONSTRAINT "qr_codes_species_id_fkey" FOREIGN KEY ("plant_species_id") REFERENCES "plants"."species"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "gamification"."qr_scans"
    ADD CONSTRAINT "qr_scans_qr_code_id_fkey" FOREIGN KEY ("qr_code_id") REFERENCES "gamification"."qr_codes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "gamification"."qr_scans"
    ADD CONSTRAINT "qr_scans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "gamification"."scrapbooks"
    ADD CONSTRAINT "scrapbooks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "gamification"."trivia_answers"
    ADD CONSTRAINT "trivia_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "gamification"."trivia_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "gamification"."trivia_attempts"
    ADD CONSTRAINT "trivia_attempts_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "gamification"."trivia_questions"("id");



ALTER TABLE ONLY "gamification"."trivia_attempts"
    ADD CONSTRAINT "trivia_attempts_selected_answer_id_fkey" FOREIGN KEY ("selected_answer_id") REFERENCES "gamification"."trivia_answers"("id");



ALTER TABLE ONLY "gamification"."trivia_attempts"
    ADD CONSTRAINT "trivia_attempts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "gamification"."trivia_questions"
    ADD CONSTRAINT "trivia_questions_plant_species_id_fkey" FOREIGN KEY ("plant_species_id") REFERENCES "plants"."species"("id");



ALTER TABLE ONLY "gamification"."user_achievements"
    ADD CONSTRAINT "user_achievements_achievement_id_fkey" FOREIGN KEY ("achievement_id") REFERENCES "gamification"."achievements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "gamification"."user_achievements"
    ADD CONSTRAINT "user_achievements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventory"."plant_instances"
    ADD CONSTRAINT "plant_instances_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "plants"."species"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventory"."plant_instances"
    ADD CONSTRAINT "plant_instances_storage_location_id_fkey" FOREIGN KEY ("storage_location_id") REFERENCES "inventory"."storage_locations"("id");



ALTER TABLE ONLY "inventory"."plant_notes"
    ADD CONSTRAINT "plant_notes_plant_instance_id_fkey" FOREIGN KEY ("plant_instance_id") REFERENCES "inventory"."plant_instances"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventory"."plant_notes"
    ADD CONSTRAINT "plant_notes_staff_user_id_fkey" FOREIGN KEY ("staff_user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "inventory"."stock_requests"
    ADD CONSTRAINT "stock_requests_requested_by_user_id_fkey" FOREIGN KEY ("requested_by_user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "inventory"."stock_requests"
    ADD CONSTRAINT "stock_requests_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "plants"."species"("id");



ALTER TABLE ONLY "plants"."articles"
    ADD CONSTRAINT "articles_author_user_id_fkey" FOREIGN KEY ("author_user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "plants"."articles"
    ADD CONSTRAINT "articles_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "plants"."species"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "staff"."announcements"
    ADD CONSTRAINT "announcements_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "staff"."feedback"
    ADD CONSTRAINT "feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "staff"."schedules"
    ADD CONSTRAINT "schedules_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "staff"."task_comments"
    ADD CONSTRAINT "task_comments_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "staff"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "staff"."task_comments"
    ADD CONSTRAINT "task_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "staff"."tasks"
    ADD CONSTRAINT "tasks_assigned_to_user_id_fkey" FOREIGN KEY ("assigned_to_user_id") REFERENCES "auth0"."users"("id");



ALTER TABLE ONLY "staff"."tasks"
    ADD CONSTRAINT "tasks_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth0"."users"("id");





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "plants" TO "authenticated";
GRANT USAGE ON SCHEMA "plants" TO "anon";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";






















































































































































GRANT ALL ON FUNCTION "gamification"."bulk_create_qr_codes"("p_plant_species_ids" bigint[], "p_location_ids" bigint[]) TO "authenticated";



GRANT ALL ON FUNCTION "gamification"."get_all_qr_codes"() TO "authenticated";



GRANT ALL ON FUNCTION "gamification"."get_qr_codes_by_species_and_location"("p_plant_species_id" bigint, "p_location_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "gamification"."get_user_collectible_catalog"("p_user_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "gamification"."get_user_collection_stats"("p_user_id" bigint) TO "authenticated";






GRANT ALL ON FUNCTION "plants"."count_species"("p_search" "text") TO "authenticated";



GRANT ALL ON FUNCTION "plants"."delete_article"("p_species_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "plants"."get_article"("p_species_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "plants"."get_encyclopedia_entry"("p_species_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "plants"."get_species_by_id"("p_species_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "plants"."get_species_list"("p_search" "text", "p_limit" integer, "p_offset" integer, "p_order_by" "text") TO "authenticated";



GRANT ALL ON FUNCTION "plants"."upsert_article"("p_species_id" bigint, "p_article_content" "text", "p_author_user_id" bigint, "p_published" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "plants"."upsert_species"("p_scientific_name" "text", "p_id" bigint, "p_common_name" "text", "p_description" "text", "p_image_url" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_user"("p_auth0_user_id" "text", "p_email" "text", "p_display_name" "text", "p_name" "text", "p_given_name" "text", "p_family_name" "text", "p_picture_url" "text", "p_locale" "text", "p_profile_metadata" "jsonb", "p_app_metadata" "jsonb", "p_is_active" boolean, "p_updated_at" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_user"("p_auth0_user_id" "text", "p_email" "text", "p_display_name" "text", "p_name" "text", "p_given_name" "text", "p_family_name" "text", "p_picture_url" "text", "p_locale" "text", "p_profile_metadata" "jsonb", "p_app_metadata" "jsonb", "p_is_active" boolean, "p_updated_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_user"("p_auth0_user_id" "text", "p_email" "text", "p_display_name" "text", "p_name" "text", "p_given_name" "text", "p_family_name" "text", "p_picture_url" "text", "p_locale" "text", "p_profile_metadata" "jsonb", "p_app_metadata" "jsonb", "p_is_active" boolean, "p_updated_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";












GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "service_role";















ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "plants" GRANT USAGE ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "plants" GRANT USAGE ON SEQUENCES TO "authenticated";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "plants" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "plants" GRANT ALL ON FUNCTIONS TO "authenticated";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "plants" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "plants" GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO "authenticated";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";


