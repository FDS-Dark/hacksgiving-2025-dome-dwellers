-- Migration: Update gamification functions to respect is_public field
-- This ensures private plants are not discoverable through QR codes or visible in scrapbooks

-- Update the discover_plant_from_qr function to check is_public
CREATE OR REPLACE FUNCTION gamification.discover_plant_from_qr(
    p_user_id BIGINT,
    p_qr_token UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    discovery_id BIGINT,
    catalog_entry_id BIGINT,
    catalog_number INTEGER,
    species_name TEXT,
    already_discovered BOOLEAN
) AS $$
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
    v_is_public BOOLEAN;
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
    
    -- Get the species from the plant instance and check if it's public
    SELECT pi.species_id, pi.is_public INTO v_species_id, v_is_public
    FROM inventory.plant_instances pi
    WHERE pi.id = v_plant_instance_id;
    
    IF v_species_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Plant species not found'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, FALSE;
        RETURN;
    END IF;
    
    -- Check if plant instance is public
    IF v_is_public = FALSE THEN
        RETURN QUERY SELECT FALSE, 'This plant is not yet available for discovery'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, FALSE;
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_user_collectible_catalog to only show species with public instances
CREATE OR REPLACE FUNCTION gamification.get_user_collectible_catalog(p_user_id BIGINT)
RETURNS TABLE (
    catalog_id BIGINT,
    catalog_number INTEGER,
    plant_species_id BIGINT,
    species_name TEXT,
    scientific_name TEXT,
    rarity_tier TEXT,
    featured_order INTEGER,
    is_discovered BOOLEAN,
    discovered_at TIMESTAMPTZ,
    discovery_id BIGINT,
    user_notes TEXT,
    is_favorite BOOLEAN
) AS $$
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
        AND EXISTS (
            SELECT 1 FROM inventory.plant_instances pi
            WHERE pi.species_id = cc.plant_species_id
            AND pi.is_public = TRUE
        )
    ORDER BY cc.catalog_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_user_collection_stats to only count species with public instances
CREATE OR REPLACE FUNCTION gamification.get_user_collection_stats(p_user_id BIGINT)
RETURNS TABLE (
    total_collectibles INTEGER,
    total_discovered INTEGER,
    discovery_percentage NUMERIC,
    common_discovered INTEGER,
    uncommon_discovered INTEGER,
    rare_discovered INTEGER,
    legendary_discovered INTEGER,
    favorites_count INTEGER,
    recent_discoveries BIGINT[]
) AS $$
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
    WHERE cc.active = TRUE
        AND EXISTS (
            SELECT 1 FROM inventory.plant_instances pi
            WHERE pi.species_id = cc.plant_species_id
            AND pi.is_public = TRUE
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_all_qr_codes to include is_public field
-- Must drop first because return type is changing
DROP FUNCTION IF EXISTS gamification.get_all_qr_codes();

CREATE OR REPLACE FUNCTION gamification.get_all_qr_codes()
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    plant_instance_id BIGINT,
    active BOOLEAN,
    is_public BOOLEAN,
    created_at TIMESTAMPTZ,
    species_id BIGINT,
    common_name TEXT,
    scientific_name TEXT,
    accession_number TEXT,
    location_name TEXT,
    dome_name TEXT,
    scan_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qc.id AS qr_code_id,
        qc.code_token,
        qc.plant_instance_id,
        qc.active,
        pi.is_public,
        qc.created_at,
        ps.id AS species_id,
        ps.common_name,
        ps.scientific_name,
        pi.identifier AS accession_number,
        sl.name AS location_name,
        sl.name AS dome_name,
        COUNT(qs.id) AS scan_count
    FROM gamification.qr_codes qc
    INNER JOIN inventory.plant_instances pi ON qc.plant_instance_id = pi.id
    INNER JOIN plants.species ps ON pi.species_id = ps.id
    LEFT JOIN inventory.storage_locations sl ON pi.storage_location_id = sl.id
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    GROUP BY qc.id, qc.code_token, qc.plant_instance_id, qc.active, pi.is_public, qc.created_at,
             ps.id, ps.common_name, ps.scientific_name, pi.identifier,
             sl.name
    ORDER BY qc.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions (maintain existing permissions)
GRANT EXECUTE ON FUNCTION gamification.discover_plant_from_qr(BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_user_collectible_catalog(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_user_collection_stats(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_all_qr_codes() TO authenticated;

-- Add comment
COMMENT ON FUNCTION gamification.discover_plant_from_qr IS 'Discovers a plant from QR scan. Only allows discovery of public plants (is_public = true).';
COMMENT ON FUNCTION gamification.get_user_collectible_catalog IS 'Returns collectible catalog filtered to only show species with at least one public plant instance.';
COMMENT ON FUNCTION gamification.get_user_collection_stats IS 'Returns collection statistics counting only species with public instances.';

