create extension if not exists "pg_net" with schema "extensions";

alter table "gamification"."qr_codes" drop constraint "qr_codes_species_id_fkey";

drop function if exists "gamification"."bulk_create_qr_codes"(p_plant_species_ids bigint[], p_location_ids bigint[]);

drop function if exists "gamification"."get_qr_codes_by_species_and_location"(p_plant_species_id bigint, p_location_id bigint);

drop function if exists "gamification"."get_all_qr_codes"();

drop index if exists "gamification"."idx_qr_codes_species_id";

alter table "gamification"."qr_codes" add constraint "qr_codes_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES plants.species(id) ON DELETE CASCADE not valid;

alter table "gamification"."qr_codes" validate constraint "qr_codes_plant_species_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION gamification.bulk_create_qr_codes(p_species_ids bigint[])
 RETURNS TABLE(qr_code_id bigint, code_token uuid, species_id bigint, active boolean, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    INSERT INTO gamification.qr_codes (code_token, species_id)
    SELECT gen_random_uuid(), unnest(p_species_ids)
    ON CONFLICT (species_id) DO NOTHING
    RETURNING id AS qr_code_id, code_token, species_id, active, created_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION gamification.get_qr_code_by_species(p_species_id bigint)
 RETURNS TABLE(qr_code_id bigint, code_token uuid, active boolean, created_at timestamp with time zone, scan_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        qc.id AS qr_code_id,
        qc.code_token,
        qc.active,
        qc.created_at,
        COUNT(qs.id) AS scan_count
    FROM gamification.qr_codes qc
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    WHERE qc.species_id = p_species_id
    GROUP BY qc.id, qc.code_token, qc.active, qc.created_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION auth0.get_user_by_auth0_id(p_auth0_user_id text)
 RETURNS TABLE(id bigint, auth0_user_id text, email text, display_name text, name text, given_name text, family_name text, picture_url text, locale text, profile_metadata jsonb, app_metadata jsonb, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, roles jsonb)
 LANGUAGE plpgsql
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION auth0.set_updated_at_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION auth0.upsert_user(p_auth0_user_id text, p_email text DEFAULT NULL::text, p_display_name text DEFAULT NULL::text, p_name text DEFAULT NULL::text, p_given_name text DEFAULT NULL::text, p_family_name text DEFAULT NULL::text, p_picture_url text DEFAULT NULL::text, p_locale text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, auth0_user_id text, email text, display_name text, name text, given_name text, family_name text, picture_url text, locale text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
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
$function$
;

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

CREATE OR REPLACE FUNCTION gamification.discover_plant_from_qr(p_user_id bigint, p_qr_token uuid)
 RETURNS TABLE(success boolean, message text, discovery_id bigint, catalog_entry_id bigint, catalog_number integer, species_name text, plant_species_id bigint, already_discovered boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
        RETURN QUERY SELECT FALSE, 'Invalid or inactive QR code'::text, NULL::bigint, NULL::bigint, NULL::integer, NULL::text, NULL::bigint, FALSE;
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
        RETURN QUERY SELECT FALSE, 'This plant is not yet available for discovery'::text, NULL::bigint, NULL::bigint, NULL::integer, NULL::text, NULL::bigint, FALSE;
        RETURN;
    END IF;

    -- Get catalog entry for this species
    SELECT cc.id, cc.catalog_number, ps.common_name
    INTO v_catalog_entry_id, v_catalog_number, v_species_name
    FROM gamification.collectible_catalog cc
    INNER JOIN plants.species ps ON cc.plant_species_id = ps.id
    WHERE cc.plant_species_id = v_species_id AND cc.active = TRUE;

    IF v_catalog_entry_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Plant not in collectible catalog'::text, NULL::bigint, NULL::bigint, NULL::integer, NULL::text, NULL::bigint, FALSE;
        RETURN;
    END IF;

    -- Get or create user's scrapbook
    v_scrapbook_id := gamification.get_or_create_default_scrapbook(p_user_id);

    -- Check if already discovered
    SELECT pd.id INTO v_discovery_id
    FROM gamification.plant_discoveries pd
    WHERE pd.scrapbook_id = v_scrapbook_id AND pd.catalog_entry_id = v_catalog_entry_id;

    IF v_discovery_id IS NOT NULL THEN
        v_already_discovered := TRUE;
        RETURN QUERY SELECT TRUE, 'Plant already in your scrapbook'::text, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_species_id, v_already_discovered;
        RETURN;
    END IF;

    -- Create new discovery
    INSERT INTO gamification.plant_discoveries (scrapbook_id, catalog_entry_id)
    VALUES (v_scrapbook_id, v_catalog_entry_id)
    RETURNING id INTO v_discovery_id;

    RETURN QUERY SELECT TRUE, 'Plant discovered!'::text, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_species_id, v_already_discovered;
END;
$function$
;

CREATE OR REPLACE FUNCTION gamification.get_all_qr_codes()
 RETURNS TABLE(qr_code_id bigint, code_token uuid, species_id bigint, active boolean, created_at timestamp with time zone, common_name text, scientific_name text, scan_count bigint, has_public_instances boolean, public_instance_count bigint, total_instance_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        qc.id AS qr_code_id,
        qc.code_token,
        qc.species_id,
        qc.active,
        qc.created_at,
        ps.common_name,
        ps.scientific_name,
        COUNT(DISTINCT qs.id) AS scan_count,
        EXISTS(SELECT 1 FROM inventory.plant_instances pi WHERE pi.species_id = qc.species_id AND pi.is_public = TRUE) AS has_public_instances,
        COUNT(DISTINCT CASE WHEN pi.is_public THEN pi.id END) AS public_instance_count,
        COUNT(DISTINCT pi.id) AS total_instance_count
    FROM gamification.qr_codes qc
    INNER JOIN plants.species ps ON qc.species_id = ps.id
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    LEFT JOIN inventory.plant_instances pi ON pi.species_id = qc.species_id
    GROUP BY qc.id, qc.code_token, qc.species_id, qc.active, qc.created_at,
             ps.common_name, ps.scientific_name
    ORDER BY qc.created_at DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION gamification.get_discovery_details(p_user_id bigint, p_catalog_entry_id bigint)
 RETURNS TABLE(discovery_id bigint, catalog_number integer, plant_species_id bigint, species_name text, scientific_name text, family text, rarity_tier text, discovered_at timestamp with time zone, user_notes text, is_favorite boolean, plant_article jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION gamification.get_or_create_default_scrapbook(p_user_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION gamification.get_user_collectible_catalog(p_user_id bigint)
 RETURNS TABLE(catalog_id bigint, catalog_number integer, plant_species_id bigint, species_name text, scientific_name text, rarity_tier text, featured_order integer, is_discovered boolean, discovered_at timestamp with time zone, discovery_id bigint, user_notes text, is_favorite boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION gamification.get_user_collection_stats(p_user_id bigint)
 RETURNS TABLE(total_collectibles integer, total_discovered integer, discovery_percentage numeric, common_discovered integer, uncommon_discovered integer, rare_discovered integer, legendary_discovered integer, favorites_count integer, recent_discoveries bigint[])
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION gamification.toggle_discovery_favorite(p_user_id bigint, p_discovery_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION gamification.update_discovery_notes(p_user_id bigint, p_discovery_id bigint, p_notes text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_user(p_auth0_user_id text, p_email text, p_display_name text, p_name text, p_given_name text, p_family_name text, p_picture_url text, p_locale text, p_profile_metadata jsonb, p_app_metadata jsonb, p_is_active boolean, p_updated_at timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;


