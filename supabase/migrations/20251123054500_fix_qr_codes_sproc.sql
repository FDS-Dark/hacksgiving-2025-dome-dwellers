-- Migration: Fix QR Code Management Stored Procedure
-- Date: 2025-11-23 05:45:00
-- Description: Fixes gamification.get_all_qr_codes() to use correct table and column names

-- Drop and recreate the function with correct table/column references
DROP FUNCTION IF EXISTS gamification.get_all_qr_codes();

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
        pi.identifier AS accession_number,
        sl.name AS location_name,
        sl.name AS dome_name,
        COUNT(qs.id) AS scan_count
    FROM gamification.qr_codes qc
    INNER JOIN inventory.plant_instances pi ON qc.plant_instance_id = pi.id
    INNER JOIN plants.species ps ON pi.species_id = ps.id
    LEFT JOIN inventory.storage_locations sl ON pi.storage_location_id = sl.id
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    GROUP BY qc.id, qc.code_token, qc.plant_instance_id, qc.active, qc.created_at,
             ps.id, ps.common_name, ps.scientific_name, pi.identifier,
             sl.name
    ORDER BY qc.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION gamification.get_all_qr_codes() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION gamification.get_all_qr_codes() IS 'Admin function to retrieve all QR codes with detailed plant information (fixed to use correct table names)';

