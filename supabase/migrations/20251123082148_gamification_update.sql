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

CREATE OR REPLACE FUNCTION gamification.discover_plant_from_qr(p_user_id bigint, p_qr_token uuid)
 RETURNS TABLE(success boolean, message text, discovery_id bigint, catalog_entry_id bigint, catalog_number integer, species_name text, already_discovered boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_scrapbook_id BIGINT;
    v_qr_code_id BIGINT;
    v_plant_instance_id BIGINT;
    v_species_id BIGINT;
    v_catalog_entry_id BIGINT;
    v_catalog_number INTEGER;
    v_species_name TEXT;
    v_discovery_id BIGINT;
    v_already_discovered BOOLEAN := FALSE;
BEGIN
    -- Validate QR code exists and is active
    SELECT qc.id, qc.plant_instance_id
    INTO v_qr_code_id, v_plant_instance_id
    FROM gamification.qr_codes qc
    WHERE qc.code_token = p_qr_token AND qc.active = TRUE;
    
    IF v_qr_code_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Invalid or inactive QR code'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, FALSE;
        RETURN;
    END IF;
    
    -- Record the scan
    INSERT INTO gamification.qr_scans (user_id, qr_code_id)
    VALUES (p_user_id, v_qr_code_id);
    
    -- Get the species from the plant instance
    SELECT pi.species_id INTO v_species_id
    FROM inventory.plant_instances pi
    WHERE pi.id = v_plant_instance_id;
    
    IF v_species_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Plant species not found'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, FALSE;
        RETURN;
    END IF;
    
    -- Get catalog entry for this species
    SELECT cc.id, cc.catalog_number, ps.common_name
    INTO v_catalog_entry_id, v_catalog_number, v_species_name
    FROM gamification.collectible_catalog cc
    INNER JOIN plants.species ps ON cc.plant_species_id = ps.id
    WHERE cc.plant_species_id = v_species_id AND cc.active = TRUE;
    
    IF v_catalog_entry_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Plant not in collectible catalog'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, FALSE;
        RETURN;
    END IF;
    
    -- Get or create user's scrapbook
    v_scrapbook_id := gamification.get_or_create_default_scrapbook(p_user_id);
    
    -- Check if already discovered
    SELECT id INTO v_discovery_id
    FROM gamification.plant_discoveries
    WHERE scrapbook_id = v_scrapbook_id AND catalog_entry_id = v_catalog_entry_id;
    
    IF v_discovery_id IS NOT NULL THEN
        v_already_discovered := TRUE;
        RETURN QUERY SELECT TRUE, 'Plant already in your scrapbook'::TEXT, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_already_discovered;
        RETURN;
    END IF;
    
    -- Create new discovery
    INSERT INTO gamification.plant_discoveries (scrapbook_id, catalog_entry_id)
    VALUES (v_scrapbook_id, v_catalog_entry_id)
    RETURNING id INTO v_discovery_id;
    
    RETURN QUERY SELECT TRUE, 'Plant discovered!'::TEXT, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_already_discovered;
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


