drop function if exists "gamification"."bulk_create_qr_codes"(p_plant_species_ids bigint[], p_location_ids bigint[]);

drop function if exists "gamification"."get_qr_codes_by_species_and_location"(p_plant_species_id bigint, p_location_id bigint);

drop function if exists "gamification"."get_all_qr_codes"();

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

CREATE OR REPLACE FUNCTION gamification.auto_add_plant_to_catalog()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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


