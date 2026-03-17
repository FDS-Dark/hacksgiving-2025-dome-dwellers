-- Migration: Change QR codes to link to species instead of plant instances
-- QR codes should represent a plant species, not individual instances

-- Drop the existing constraint and column
ALTER TABLE gamification.qr_codes
DROP CONSTRAINT IF EXISTS qr_codes_plant_instance_id_key;

ALTER TABLE gamification.qr_codes
DROP CONSTRAINT IF EXISTS qr_codes_plant_instance_id_fkey;

-- Temporarily allow NULL for migration
ALTER TABLE gamification.qr_codes
ALTER COLUMN plant_instance_id DROP NOT NULL;

-- Add new plant_species_id column
ALTER TABLE gamification.qr_codes
ADD COLUMN IF NOT EXISTS plant_species_id BIGINT REFERENCES plants.species(id) ON DELETE CASCADE;

-- Add location_id column (optional - QR code can be for a species at a specific location)
ALTER TABLE gamification.qr_codes
ADD COLUMN IF NOT EXISTS location_id BIGINT REFERENCES inventory.storage_locations(id) ON DELETE SET NULL;

-- Migrate existing data: get species_id from plant_instance_id
UPDATE gamification.qr_codes qc
SET plant_species_id = pi.species_id
FROM inventory.plant_instances pi
WHERE qc.plant_instance_id = pi.id
AND qc.plant_species_id IS NULL;

-- Make plant_species_id NOT NULL
ALTER TABLE gamification.qr_codes
ALTER COLUMN plant_species_id SET NOT NULL;

-- Drop old plant_instance_id column
ALTER TABLE gamification.qr_codes
DROP COLUMN plant_instance_id;

-- Add index for plant_species_id lookups
CREATE INDEX IF NOT EXISTS idx_qr_codes_plant_species_id ON gamification.qr_codes(plant_species_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_location_id ON gamification.qr_codes(location_id);

-- Add comments
COMMENT ON COLUMN gamification.qr_codes.plant_species_id IS 'The plant species this QR code represents';
COMMENT ON COLUMN gamification.qr_codes.location_id IS 'Optional location where this QR code is placed';

-- Update discover_plant_from_qr function
DROP FUNCTION IF EXISTS gamification.discover_plant_from_qr(BIGINT, UUID);

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
        RETURN QUERY SELECT FALSE, 'Invalid or inactive QR code'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, FALSE;
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

-- Update get_all_qr_codes function
DROP FUNCTION IF EXISTS gamification.get_all_qr_codes();

CREATE OR REPLACE FUNCTION gamification.get_all_qr_codes()
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    plant_species_id BIGINT,
    location_id BIGINT,
    active BOOLEAN,
    is_public BOOLEAN,
    created_at TIMESTAMPTZ,
    common_name TEXT,
    scientific_name TEXT,
    location_name TEXT,
    scan_count BIGINT
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update bulk_create_qr_codes function to work with species and locations
DROP FUNCTION IF EXISTS gamification.bulk_create_qr_codes(BIGINT[]);
DROP FUNCTION IF EXISTS gamification.bulk_create_qr_codes(BIGINT[], BIGINT[]);

CREATE OR REPLACE FUNCTION gamification.bulk_create_qr_codes(
    p_plant_species_ids BIGINT[],
    p_location_ids BIGINT[] DEFAULT NULL
)
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    plant_species_id BIGINT,
    location_id BIGINT,
    active BOOLEAN,
    created_at TIMESTAMPTZ
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_qr_codes_by_plant_instance to get_qr_codes_by_species_and_location
DROP FUNCTION IF EXISTS gamification.get_qr_codes_by_plant_instance(BIGINT);
DROP FUNCTION IF EXISTS gamification.get_qr_code_by_species(BIGINT);
DROP FUNCTION IF EXISTS gamification.get_qr_codes_by_species_and_location(BIGINT, BIGINT);

CREATE OR REPLACE FUNCTION gamification.get_qr_codes_by_species_and_location(
    p_plant_species_id BIGINT,
    p_location_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    plant_species_id BIGINT,
    location_id BIGINT,
    active BOOLEAN,
    created_at TIMESTAMPTZ,
    scan_count BIGINT
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION gamification.discover_plant_from_qr(BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_all_qr_codes() TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.bulk_create_qr_codes(BIGINT[], BIGINT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_qr_codes_by_species_and_location(BIGINT, BIGINT) TO authenticated;

-- Update comments
COMMENT ON FUNCTION gamification.discover_plant_from_qr IS 'Discovers a plant species from QR scan. Only allows discovery if species has at least one public plant instance.';
COMMENT ON FUNCTION gamification.get_all_qr_codes IS 'Returns all QR codes with species information and location.';
COMMENT ON FUNCTION gamification.bulk_create_qr_codes IS 'Bulk create QR codes for multiple plant species with optional locations.';
COMMENT ON FUNCTION gamification.get_qr_codes_by_species_and_location IS 'Get QR codes for a specific plant species and optional location.';

