alter table "inventory"."plant_species" add column "species_id" bigint;

alter table "inventory"."plant_species" add constraint "plant_species_species_id_fkey" FOREIGN KEY (species_id) REFERENCES plants.species(id) not valid;

alter table "inventory"."plant_species" validate constraint "plant_species_species_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION plants.upsert_species(p_scientific_name text, p_id bigint DEFAULT NULL::bigint, p_common_name text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_care_notes text DEFAULT NULL::text, p_image_url text DEFAULT NULL::text, p_thumbnail_url text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, scientific_name text, common_name text, description text, care_notes text, image_url text, thumbnail_url text, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_id IS NULL THEN
        -- Insert new species
        RETURN QUERY
        INSERT INTO plants.species (
            scientific_name, common_name, description, care_notes, image_url, thumbnail_url
        ) VALUES (
            p_scientific_name, p_common_name, p_description, p_care_notes, p_image_url, p_thumbnail_url
        )
        RETURNING 
            species.id,
            species.scientific_name,
            species.common_name,
            species.description,
            species.care_notes,
            species.image_url,
            species.thumbnail_url,
            species.created_at;
    ELSE
        -- Update existing species
        RETURN QUERY
        UPDATE plants.species
        SET 
            scientific_name = COALESCE(p_scientific_name, species.scientific_name),
            common_name = COALESCE(p_common_name, species.common_name),
            description = COALESCE(p_description, species.description),
            care_notes = COALESCE(p_care_notes, species.care_notes),
            image_url = COALESCE(p_image_url, species.image_url),
            thumbnail_url = COALESCE(p_thumbnail_url, species.thumbnail_url)
        WHERE species.id = p_id
        RETURNING 
            species.id,
            species.scientific_name,
            species.common_name,
            species.description,
            species.care_notes,
            species.image_url,
            species.thumbnail_url,
            species.created_at;
    END IF;
END;
$function$
;


