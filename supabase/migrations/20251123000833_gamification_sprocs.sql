create sequence "gamification"."collectible_catalog_id_seq";

alter table "gamification"."plant_discoveries" drop constraint "plant_discoveries_plant_species_id_fkey";

alter table "gamification"."plant_discoveries" drop constraint "plant_discoveries_scrapbook_id_plant_species_id_key";

drop index if exists "gamification"."idx_plant_discoveries_plant_species_id";

drop index if exists "gamification"."plant_discoveries_scrapbook_id_plant_species_id_key";


  create table "gamification"."collectible_catalog" (
    "id" bigint not null default nextval('gamification.collectible_catalog_id_seq'::regclass),
    "catalog_number" integer not null,
    "plant_species_id" bigint not null,
    "rarity_tier" text not null default 'common'::text,
    "featured_order" integer,
    "collectible_since" timestamp with time zone not null default now(),
    "active" boolean not null default true
      );


alter table "gamification"."plant_discoveries" drop column "plant_species_id";

alter table "gamification"."plant_discoveries" add column "catalog_entry_id" bigint not null;

alter sequence "gamification"."collectible_catalog_id_seq" owned by "gamification"."collectible_catalog"."id";

CREATE UNIQUE INDEX collectible_catalog_catalog_number_key ON gamification.collectible_catalog USING btree (catalog_number);

CREATE UNIQUE INDEX collectible_catalog_pkey ON gamification.collectible_catalog USING btree (id);

CREATE UNIQUE INDEX collectible_catalog_plant_species_id_key ON gamification.collectible_catalog USING btree (plant_species_id);

CREATE INDEX idx_collectible_catalog_active ON gamification.collectible_catalog USING btree (active);

CREATE INDEX idx_collectible_catalog_catalog_number ON gamification.collectible_catalog USING btree (catalog_number);

CREATE INDEX idx_collectible_catalog_plant_species_id ON gamification.collectible_catalog USING btree (plant_species_id);

CREATE INDEX idx_collectible_catalog_rarity_tier ON gamification.collectible_catalog USING btree (rarity_tier);

CREATE INDEX idx_plant_discoveries_catalog_entry_id ON gamification.plant_discoveries USING btree (catalog_entry_id);

CREATE UNIQUE INDEX plant_discoveries_scrapbook_id_catalog_entry_id_key ON gamification.plant_discoveries USING btree (scrapbook_id, catalog_entry_id);

alter table "gamification"."collectible_catalog" add constraint "collectible_catalog_pkey" PRIMARY KEY using index "collectible_catalog_pkey";

alter table "gamification"."collectible_catalog" add constraint "collectible_catalog_catalog_number_key" UNIQUE using index "collectible_catalog_catalog_number_key";

alter table "gamification"."collectible_catalog" add constraint "collectible_catalog_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES plants.species(id) not valid;

alter table "gamification"."collectible_catalog" validate constraint "collectible_catalog_plant_species_id_fkey";

alter table "gamification"."collectible_catalog" add constraint "collectible_catalog_plant_species_id_key" UNIQUE using index "collectible_catalog_plant_species_id_key";

alter table "gamification"."collectible_catalog" add constraint "collectible_catalog_rarity_tier_check" CHECK ((rarity_tier = ANY (ARRAY['common'::text, 'uncommon'::text, 'rare'::text, 'legendary'::text]))) not valid;

alter table "gamification"."collectible_catalog" validate constraint "collectible_catalog_rarity_tier_check";

alter table "gamification"."plant_discoveries" add constraint "plant_discoveries_catalog_entry_id_fkey" FOREIGN KEY (catalog_entry_id) REFERENCES gamification.collectible_catalog(id) not valid;

alter table "gamification"."plant_discoveries" validate constraint "plant_discoveries_catalog_entry_id_fkey";

alter table "gamification"."plant_discoveries" add constraint "plant_discoveries_scrapbook_id_catalog_entry_id_key" UNIQUE using index "plant_discoveries_scrapbook_id_catalog_entry_id_key";

set check_function_bodies = off;

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

CREATE OR REPLACE FUNCTION gamification.get_discovery_details(p_user_id bigint, p_catalog_entry_id bigint)
 RETURNS TABLE(discovery_id bigint, catalog_number integer, plant_species_id bigint, species_name text, scientific_name text, family text, rarity_tier text, discovered_at timestamp with time zone, user_notes text, is_favorite boolean, plant_article jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION gamification.get_or_create_default_scrapbook(p_user_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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

CREATE OR REPLACE FUNCTION gamification.toggle_discovery_favorite(p_user_id bigint, p_discovery_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION gamification.update_discovery_notes(p_user_id bigint, p_discovery_id bigint, p_notes text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;


