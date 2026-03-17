-- Stored Procedures for Gamification Schema
-- Functions to support scrapbook and plant discovery features

-- Function: Get all collectible catalog entries with discovery status for a user
-- Returns the full catalog with whether each plant has been discovered
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
    ORDER BY cc.catalog_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get or create default scrapbook for user
CREATE OR REPLACE FUNCTION gamification.get_or_create_default_scrapbook(p_user_id BIGINT)
RETURNS BIGINT AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Record a plant discovery from QR scan
CREATE OR REPLACE FUNCTION gamification.discover_plant_from_qr(
    p_user_id bigint,
    p_qr_token uuid
) RETURNS TABLE(
    success boolean,
    message text,
    discovery_id bigint,
    catalog_entry_id bigint,
    catalog_number integer,
    species_name text,
    plant_species_id bigint,
    already_discovered boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
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
$$;


-- Function: Update discovery notes
CREATE OR REPLACE FUNCTION gamification.update_discovery_notes(
    p_user_id BIGINT,
    p_discovery_id BIGINT,
    p_notes TEXT
)
RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Toggle discovery favorite status
CREATE OR REPLACE FUNCTION gamification.toggle_discovery_favorite(
    p_user_id BIGINT,
    p_discovery_id BIGINT
)
RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get discovery details with full plant info
CREATE OR REPLACE FUNCTION gamification.get_discovery_details(
    p_user_id BIGINT,
    p_catalog_entry_id BIGINT
)
RETURNS TABLE (
    discovery_id BIGINT,
    catalog_number INTEGER,
    plant_species_id BIGINT,
    species_name TEXT,
    scientific_name TEXT,
    family TEXT,
    rarity_tier TEXT,
    discovered_at TIMESTAMPTZ,
    user_notes TEXT,
    is_favorite BOOLEAN,
    plant_article JSONB
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get user collection statistics
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
    WHERE cc.active = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION gamification.get_user_collectible_catalog(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_or_create_default_scrapbook(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.discover_plant_from_qr(BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.update_discovery_notes(BIGINT, BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.toggle_discovery_favorite(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_discovery_details(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_user_collection_stats(BIGINT) TO authenticated;

