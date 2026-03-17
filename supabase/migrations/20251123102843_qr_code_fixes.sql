drop function if exists "gamification"."get_all_qr_codes"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION gamification.get_all_qr_codes()
 RETURNS TABLE(qr_code_id bigint, code_token uuid, species_id bigint, location_id bigint, active boolean, created_at timestamp with time zone, common_name text, scientific_name text, location_name text, scan_count bigint, has_public_instances boolean, public_instance_count bigint, total_instance_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        qc.id AS qr_code_id,
        qc.code_token,
        qc.plant_species_id AS species_id,
        qc.location_id,
        qc.active,
        qc.created_at,
        ps.common_name,
        ps.scientific_name,
        sl.name AS location_name,
        COUNT(DISTINCT qs.id) AS scan_count,
        EXISTS(SELECT 1 FROM inventory.plant_instances pi WHERE pi.species_id = qc.plant_species_id AND pi.is_public = TRUE) AS has_public_instances,
        COUNT(DISTINCT CASE WHEN pi.is_public THEN pi.id END) AS public_instance_count,
        COUNT(DISTINCT pi.id) AS total_instance_count
    FROM gamification.qr_codes qc
    INNER JOIN plants.species ps ON qc.plant_species_id = ps.id
    LEFT JOIN inventory.storage_locations sl ON qc.location_id = sl.id
    LEFT JOIN gamification.qr_scans qs ON qs.qr_code_id = qc.id
    LEFT JOIN inventory.plant_instances pi ON pi.species_id = qc.plant_species_id
    GROUP BY qc.id, qc.code_token, qc.plant_species_id, qc.location_id, qc.active, qc.created_at,
             ps.common_name, ps.scientific_name, sl.name
    ORDER BY qc.created_at DESC;
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
    WHERE qc.plant_species_id = p_species_id
    GROUP BY qc.id, qc.code_token, qc.active, qc.created_at;
END;
$function$
;


