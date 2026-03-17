-- Schema: gamification
-- Domain 5: Gamification System
-- This file contains all table and function definitions for user engagement features
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS gamification;

-- Collectible catalog - master list of all plants available for scrapbook collection
-- Defines the complete "pokedex" of plants with ordered numbering
CREATE TABLE IF NOT EXISTS gamification.collectible_catalog (
    id                  BIGSERIAL PRIMARY KEY,
    catalog_number      INTEGER NOT NULL UNIQUE,                -- Sequential number like pokedex (#001, #002, etc.)
    plant_species_id    BIGINT NOT NULL UNIQUE REFERENCES plants.species(id),  -- Which species is collectible
    rarity_tier         TEXT NOT NULL DEFAULT 'common' CHECK (rarity_tier IN ('common', 'uncommon', 'rare', 'legendary')),
    featured_order      INTEGER,                                -- Optional custom ordering for featured displays
    collectible_since   TIMESTAMPTZ NOT NULL DEFAULT NOW(),     -- When this plant was added to the catalog
    active              BOOLEAN NOT NULL DEFAULT TRUE           -- Can be set false to retire plants from collection
);

-- User scrapbooks (digital journey/collection)
-- Each user can have one or more scrapbooks
CREATE TABLE IF NOT EXISTS gamification.scrapbooks (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES auth0.users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,                                  -- e.g. "My Dome Visits"
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Scrapbook entries for discovered plants
-- When a user scans a plant, they "unlock" it in their scrapbook
CREATE TABLE IF NOT EXISTS gamification.plant_discoveries (
    id                  BIGSERIAL PRIMARY KEY,
    scrapbook_id        BIGINT NOT NULL REFERENCES gamification.scrapbooks(id) ON DELETE CASCADE,
    catalog_entry_id    BIGINT NOT NULL REFERENCES gamification.collectible_catalog(id),  -- Link to catalog entry
    discovered_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes               TEXT,                                   -- User's personal notes about this plant
    favorite            BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (scrapbook_id, catalog_entry_id)                     -- Can only discover each catalog entry once per scrapbook
);

-- QR codes for plant scanning
-- These are placed near physical plants in the domes
-- Each QR code represents a plant species at an optional location
CREATE TABLE IF NOT EXISTS gamification.qr_codes (
    id                  BIGSERIAL PRIMARY KEY,
    code_token          UUID NOT NULL UNIQUE,                   -- Opaque identifier encoded in QR
    plant_species_id    BIGINT NOT NULL REFERENCES plants.species(id) ON DELETE CASCADE,  -- Which species this QR is for
    location_id         BIGINT REFERENCES inventory.storage_locations(id) ON DELETE SET NULL,  -- Optional location for this QR code
    active              BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qr_codes_plant_species_id ON gamification.qr_codes(plant_species_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_location_id ON gamification.qr_codes(location_id);

-- History of QR scans for tracking and analytics
CREATE TABLE IF NOT EXISTS gamification.qr_scans (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT REFERENCES auth0.users(id),           -- Null for anonymous scans
    qr_code_id      BIGINT NOT NULL REFERENCES gamification.qr_codes(id) ON DELETE CASCADE,
    scanned_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trivia questions for the gamification system
CREATE TABLE IF NOT EXISTS gamification.trivia_questions (
    id              BIGSERIAL PRIMARY KEY,
    plant_species_id BIGINT REFERENCES plants.species(id),  -- Optional: link to specific plant
    question        TEXT NOT NULL,
    difficulty      TEXT NOT NULL DEFAULT 'medium' CHECK (difficulty IN ('easy', 'medium', 'hard')),
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trivia answer options (multiple choice)
CREATE TABLE IF NOT EXISTS gamification.trivia_answers (
    id              BIGSERIAL PRIMARY KEY,
    question_id     BIGINT NOT NULL REFERENCES gamification.trivia_questions(id) ON DELETE CASCADE,
    answer_text     TEXT NOT NULL,
    is_correct      BOOLEAN NOT NULL DEFAULT FALSE,
    explanation     TEXT                                        -- Optional explanation shown after answering
);

-- User trivia attempts/history
CREATE TABLE IF NOT EXISTS gamification.trivia_attempts (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT REFERENCES auth0.users(id) ON DELETE SET NULL,
    question_id     BIGINT NOT NULL REFERENCES gamification.trivia_questions(id),
    selected_answer_id BIGINT REFERENCES gamification.trivia_answers(id),
    is_correct      BOOLEAN NOT NULL,
    attempted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Achievements/badges
CREATE TABLE IF NOT EXISTS gamification.achievements (
    id              BIGSERIAL PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    description     TEXT NOT NULL,
    icon_url        TEXT,
    achievement_type TEXT NOT NULL,                             -- e.g. 'plants_discovered', 'trivia_master', 'event_attendee'
    threshold       INTEGER,                                    -- e.g. "discover 10 plants" = threshold 10
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User's earned achievements
CREATE TABLE IF NOT EXISTS gamification.user_achievements (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES auth0.users(id) ON DELETE CASCADE,
    achievement_id  BIGINT NOT NULL REFERENCES gamification.achievements(id) ON DELETE CASCADE,
    earned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, achievement_id)                            -- Can only earn each achievement once
);

-- Stored Procedures for Gamification Schema
-- Functions to support scrapbook and plant discovery features

-- Function: Get all collectible catalog entries with discovery status for a user
-- Returns the full catalog with whether each plant has been discovered
-- Only includes species that have at least one public plant instance
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
    plant_species_id BIGINT,
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
        RETURN QUERY SELECT FALSE, 'Invalid or inactive QR code'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, NULL::BIGINT, FALSE;
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
        RETURN QUERY SELECT FALSE, 'This plant is not yet available for discovery'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, NULL::BIGINT, FALSE;
        RETURN;
    END IF;
    
    -- Get catalog entry for this species
    SELECT cc.id, cc.catalog_number, ps.common_name
    INTO v_catalog_entry_id, v_catalog_number, v_species_name
    FROM gamification.collectible_catalog cc
    INNER JOIN plants.species ps ON cc.plant_species_id = ps.id
    WHERE cc.plant_species_id = v_species_id AND cc.active = TRUE;
    
    IF v_catalog_entry_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Plant not in collectible catalog'::TEXT, NULL::BIGINT, NULL::BIGINT, NULL::INTEGER, NULL::TEXT, NULL::BIGINT, FALSE;
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
        RETURN QUERY SELECT TRUE, 'Plant already in your scrapbook'::TEXT, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_species_id, v_already_discovered;
        RETURN;
    END IF;
    
    -- Create new discovery
    INSERT INTO gamification.plant_discoveries (scrapbook_id, catalog_entry_id)
    VALUES (v_scrapbook_id, v_catalog_entry_id)
    RETURNING id INTO v_discovery_id;
    
    RETURN QUERY SELECT TRUE, 'Plant discovered!'::TEXT, v_discovery_id, v_catalog_entry_id, v_catalog_number, v_species_name, v_species_id, v_already_discovered;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
-- Only counts species that have at least one public plant instance
CREATE OR REPLACE FUNCTION gamification.get_user_collection_stats(p_user_id bigint) RETURNS TABLE(
    total_collectibles integer,
    total_discovered integer,
    discovery_percentage numeric,
    common_discovered integer,
    uncommon_discovered integer,
    rare_discovered integer,
    legendary_discovered integer,
    favorites_count integer,
    recent_discoveries bigint[]
)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;

-- Function: Get all QR codes with plant details for admin management
-- Drop first because return type changed
DROP FUNCTION IF EXISTS gamification.get_all_qr_codes();

CREATE OR REPLACE FUNCTION gamification.get_all_qr_codes()
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    species_id BIGINT,
    location_id BIGINT,
    active BOOLEAN,
    created_at TIMESTAMPTZ,
    common_name TEXT,
    scientific_name TEXT,
    location_name TEXT,
    scan_count BIGINT,
    has_public_instances BOOLEAN,
    public_instance_count BIGINT,
    total_instance_count BIGINT
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Bulk create QR codes for multiple plant species
CREATE OR REPLACE FUNCTION gamification.bulk_create_qr_codes(p_species_ids BIGINT[])
RETURNS TABLE (
    qr_code_id BIGINT,
    code_token UUID,
    species_id BIGINT,
    active BOOLEAN,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    INSERT INTO gamification.qr_codes (code_token, species_id)
    SELECT gen_random_uuid(), unnest(p_species_ids)
    ON CONFLICT (species_id) DO NOTHING
    RETURNING id AS qr_code_id, code_token, species_id, active, created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get QR code by plant species
CREATE OR REPLACE FUNCTION gamification.get_qr_code_by_species(p_species_id BIGINT)
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
    WHERE qc.plant_species_id = p_species_id
    GROUP BY qc.id, qc.code_token, qc.active, qc.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to automatically add new plants to the collectible catalog
CREATE OR REPLACE FUNCTION gamification.auto_add_plant_to_catalog()
RETURNS TRIGGER AS $$
DECLARE
    v_next_catalog_number INTEGER;
    v_rarity_tier TEXT;
    v_random_value NUMERIC;
BEGIN
    -- Get the next catalog number
    SELECT COALESCE(MAX(catalog_number), 0) + 1
    INTO v_next_catalog_number
    FROM gamification.collectible_catalog;
    
    -- Randomly assign rarity tier with weighted distribution
    v_random_value := RANDOM();
    
    v_rarity_tier := CASE 
        WHEN v_random_value < 0.50 THEN 'common'       -- 50% common
        WHEN v_random_value < 0.80 THEN 'uncommon'     -- 30% uncommon
        WHEN v_random_value < 0.95 THEN 'rare'         -- 15% rare
        ELSE 'legendary'                                -- 5% legendary
    END;
    
    -- Insert into collectible catalog
    INSERT INTO gamification.collectible_catalog (
        catalog_number,
        plant_species_id,
        rarity_tier,
        collectible_since,
        active
    ) VALUES (
        v_next_catalog_number,
        NEW.id,
        v_rarity_tier,
        NOW(),
        TRUE
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on plants.species table
DROP TRIGGER IF EXISTS trigger_add_plant_to_catalog ON plants.species;

CREATE TRIGGER trigger_add_plant_to_catalog
    AFTER INSERT ON plants.species
    FOR EACH ROW
    EXECUTE FUNCTION gamification.auto_add_plant_to_catalog();

-- Grant execute permission
GRANT EXECUTE ON FUNCTION gamification.auto_add_plant_to_catalog() TO postgres, authenticated;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION gamification.get_user_collectible_catalog(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_or_create_default_scrapbook(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.discover_plant_from_qr(BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.update_discovery_notes(BIGINT, BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.toggle_discovery_favorite(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_discovery_details(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_user_collection_stats(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_all_qr_codes() TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.bulk_create_qr_codes(BIGINT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION gamification.get_qr_code_by_species(BIGINT) TO authenticated;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_collectible_catalog_catalog_number ON gamification.collectible_catalog(catalog_number);
CREATE INDEX IF NOT EXISTS idx_collectible_catalog_plant_species_id ON gamification.collectible_catalog(plant_species_id);
CREATE INDEX IF NOT EXISTS idx_collectible_catalog_rarity_tier ON gamification.collectible_catalog(rarity_tier);
CREATE INDEX IF NOT EXISTS idx_collectible_catalog_active ON gamification.collectible_catalog(active);
CREATE INDEX IF NOT EXISTS idx_scrapbooks_user_id ON gamification.scrapbooks(user_id);
CREATE INDEX IF NOT EXISTS idx_plant_discoveries_scrapbook_id ON gamification.plant_discoveries(scrapbook_id);
CREATE INDEX IF NOT EXISTS idx_plant_discoveries_catalog_entry_id ON gamification.plant_discoveries(catalog_entry_id);
CREATE INDEX IF NOT EXISTS idx_plant_discoveries_discovered_at ON gamification.plant_discoveries(discovered_at);
CREATE INDEX IF NOT EXISTS idx_plant_discoveries_favorite ON gamification.plant_discoveries(favorite);
CREATE INDEX IF NOT EXISTS idx_qr_codes_code_token ON gamification.qr_codes(code_token);
CREATE INDEX IF NOT EXISTS idx_qr_codes_active ON gamification.qr_codes(active);
CREATE INDEX IF NOT EXISTS idx_qr_scans_user_id ON gamification.qr_scans(user_id);
CREATE INDEX IF NOT EXISTS idx_qr_scans_qr_code_id ON gamification.qr_scans(qr_code_id);
CREATE INDEX IF NOT EXISTS idx_qr_scans_scanned_at ON gamification.qr_scans(scanned_at);
CREATE INDEX IF NOT EXISTS idx_trivia_questions_plant_species_id ON gamification.trivia_questions(plant_species_id);
CREATE INDEX IF NOT EXISTS idx_trivia_questions_difficulty ON gamification.trivia_questions(difficulty);
CREATE INDEX IF NOT EXISTS idx_trivia_questions_active ON gamification.trivia_questions(active);
CREATE INDEX IF NOT EXISTS idx_trivia_answers_question_id ON gamification.trivia_answers(question_id);
CREATE INDEX IF NOT EXISTS idx_trivia_answers_is_correct ON gamification.trivia_answers(is_correct);
CREATE INDEX IF NOT EXISTS idx_trivia_attempts_user_id ON gamification.trivia_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_trivia_attempts_question_id ON gamification.trivia_attempts(question_id);
CREATE INDEX IF NOT EXISTS idx_trivia_attempts_attempted_at ON gamification.trivia_attempts(attempted_at);
CREATE INDEX IF NOT EXISTS idx_achievements_achievement_type ON gamification.achievements(achievement_type);
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON gamification.user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON gamification.user_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_earned_at ON gamification.user_achievements(earned_at);

-- Schema Permissions
-- Grant full permissions to postgres role
GRANT ALL ON SCHEMA gamification TO postgres;

-- Grant usage to authenticated and anon roles
GRANT USAGE ON SCHEMA gamification TO authenticated, anon;

-- Grant all privileges on all future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA gamification GRANT ALL ON TABLES TO postgres;

-- Grant select/insert/update/delete to authenticated users on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA gamification GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- Grant usage on sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA gamification GRANT USAGE ON SEQUENCES TO postgres, authenticated;

-- Grant execute on functions
ALTER DEFAULT PRIVILEGES IN SCHEMA gamification GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

