-- Migration: Add QR Code Management Stored Procedures and Schema Updates
-- Date: 2025-11-23 05:30:00
-- Description: Adds stored procedures for admin QR code management and updates qr_codes table

-- Update qr_codes table to ensure plant_instance_id uniqueness (one QR per plant instance)
-- Drop existing table if it exists and recreate with the unique constraint
-- This is safe because this is a new feature and shouldn't have production data yet
ALTER TABLE IF EXISTS gamification.qr_codes 
DROP CONSTRAINT IF EXISTS qr_codes_plant_instance_id_key;

ALTER TABLE gamification.qr_codes 
ADD CONSTRAINT qr_codes_plant_instance_id_key UNIQUE (plant_instance_id);

-- Function: Get all QR codes with plant details for admin management
CREATE OR REPLACE FUNCTION gamification.get_all_qr_codes()
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    plant_instance_id BIGINT,
    active BOOLEAN,
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
        qc.created_at,
        ps.id AS species_id,
        ps.common_name,
        ps.scientific_name,
        pi.accession_number,
        pl.name AS location_name,
        d.name AS dome_name,
        COUNT(qs.id) AS scan_count
    FROM gamification.qr_codes qc
    INNER JOIN inventory.plant_instances pi ON qc.plant_instance_id = pi.id
    INNER JOIN plants.species ps ON pi.species_id = ps.id
    LEFT JOIN inventory.locations pl ON pi.location_id = pl.id
    LEFT JOIN domes.domes d ON pl.dome_id = d.id
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    GROUP BY qc.id, qc.code_token, qc.plant_instance_id, qc.active, qc.created_at,
             ps.id, ps.common_name, ps.scientific_name, pi.accession_number,
             pl.name, d.name
    ORDER BY qc.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Bulk create QR codes for multiple plant instances
CREATE OR REPLACE FUNCTION gamification.bulk_create_qr_codes(p_plant_instance_ids BIGINT[])
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    plant_instance_id BIGINT,
    active BOOLEAN,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    INSERT INTO gamification.qr_codes (code_token, plant_instance_id)
    SELECT gen_random_uuid(), unnest(p_plant_instance_ids)
    ON CONFLICT (plant_instance_id) DO NOTHING
    RETURNING id AS qr_code_id, code_token, plant_instance_id, active, created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get QR codes by plant instance
CREATE OR REPLACE FUNCTION gamification.get_qr_codes_by_plant_instance(p_plant_instance_id BIGINT)
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    active BOOLEAN,
    created_at TIMESTAMPTZ,
    scan_count BIGINT
) AS $$
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
    WHERE qc.plant_instance_id = p_plant_instance_id
    GROUP BY qc.id, qc.code_token, qc.active, qc.created_at
    ORDER BY qc.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions for new functions
GRANT EXECUTE ON FUNCTION gamification.get_all_qr_codes() TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.bulk_create_qr_codes(BIGINT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_qr_codes_by_plant_instance(BIGINT) TO authenticated;

-- Add comments for documentation
COMMENT ON FUNCTION gamification.get_all_qr_codes() IS 'Admin function to retrieve all QR codes with detailed plant information';
COMMENT ON FUNCTION gamification.bulk_create_qr_codes(BIGINT[]) IS 'Bulk create QR codes for multiple plant instances, skipping duplicates';
COMMENT ON FUNCTION gamification.get_qr_codes_by_plant_instance(BIGINT) IS 'Get all QR codes associated with a specific plant instance';

