drop function if exists "plants"."upsert_species"(p_scientific_name text, p_id bigint, p_common_name text, p_description text, p_image_url text, p_thumbnail_url text);

drop function if exists "plants"."get_encyclopedia_entry"(p_species_id bigint);

drop function if exists "plants"."get_species_by_id"(p_species_id bigint);

drop function if exists "plants"."get_species_list"(p_search text, p_limit integer, p_offset integer, p_order_by text);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION plants.upsert_species(p_scientific_name text, p_id bigint DEFAULT NULL::bigint, p_common_name text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_image_url text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, scientific_name text, common_name text, description text, image_url text, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_id IS NULL THEN
        -- Insert new species
        RETURN QUERY
        INSERT INTO plants.species (
            scientific_name, common_name, description, image_url
        ) VALUES (
            p_scientific_name, p_common_name, p_description, p_image_url
        )
        RETURNING 
            species.id,
            species.scientific_name,
            species.common_name,
            species.description,
            species.image_url,
            species.created_at;
    ELSE
        -- Update existing species
        RETURN QUERY
        UPDATE plants.species
        SET 
            scientific_name = COALESCE(p_scientific_name, species.scientific_name),
            common_name = COALESCE(p_common_name, species.common_name),
            description = COALESCE(p_description, species.description),
            image_url = COALESCE(p_image_url, species.image_url)
        WHERE species.id = p_id
        RETURNING 
            species.id,
            species.scientific_name,
            species.common_name,
            species.description,
            species.image_url,
            species.created_at;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION plants.get_encyclopedia_entry(p_species_id bigint)
 RETURNS TABLE(id bigint, scientific_name text, common_name text, description text, image_url text, article_id bigint, article_content text, article_author_id bigint, article_created_at timestamp with time zone, article_updated_at timestamp with time zone, species_created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.scientific_name,
        s.common_name,
        s.description,
        s.image_url,
        a.id as article_id,
        a.article_content,
        a.author_user_id as article_author_id,
        a.created_at as article_created_at,
        a.updated_at as article_updated_at,
        s.created_at as species_created_at
    FROM plants.species s
    LEFT JOIN plants.articles a ON a.species_id = s.id AND a.published = true
    WHERE s.id = p_species_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION plants.get_species_by_id(p_species_id bigint)
 RETURNS TABLE(id bigint, scientific_name text, common_name text, description text, image_url text, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.scientific_name,
        s.common_name,
        s.description,
        s.image_url,
        s.created_at
    FROM plants.species s
    WHERE s.id = p_species_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION plants.get_species_list(p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_order_by text DEFAULT 'common_name'::text)
 RETURNS TABLE(id bigint, scientific_name text, common_name text, description text, image_url text, has_article boolean, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.scientific_name,
        s.common_name,
        s.description,
        s.image_url,
        EXISTS(
            SELECT 1 FROM plants.articles a 
            WHERE a.species_id = s.id AND a.published = true
        ) as has_article,
        s.created_at
    FROM plants.species s
    WHERE 
        (p_search IS NULL OR 
         s.scientific_name ILIKE '%' || p_search || '%' OR 
         s.common_name ILIKE '%' || p_search || '%')
    ORDER BY 
        CASE 
            WHEN p_order_by = 'common_name' THEN s.common_name
            WHEN p_order_by = 'scientific_name' THEN s.scientific_name
            ELSE NULL
        END ASC,
        CASE 
            WHEN p_order_by = 'created_at' THEN s.created_at
            ELSE NULL
        END DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$
;


