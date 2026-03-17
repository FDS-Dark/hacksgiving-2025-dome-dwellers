-- Schema: plants
-- Domain: Plant Encyclopedia
-- This file contains all table definitions for the plant encyclopedia system
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS plants;

-- Reference table for plant species-level information
CREATE TABLE IF NOT EXISTS plants.species (
    id              BIGSERIAL PRIMARY KEY,
    scientific_name TEXT NOT NULL,
    common_name     TEXT,
    description     TEXT,
    image_url       TEXT,                           -- Primary image for the plant
    UNIQUE (scientific_name)
);

-- Encyclopedia articles for plant species
CREATE TABLE IF NOT EXISTS plants.articles (
    id                  BIGSERIAL PRIMARY KEY,
    species_id          BIGINT NOT NULL REFERENCES plants.species(id) ON DELETE CASCADE,
    article_content     TEXT NOT NULL,                                      -- Full article text in markdown/HTML
    author_user_id      BIGINT REFERENCES auth0.users(id),                  -- Staff member who wrote the article
    published           BOOLEAN NOT NULL DEFAULT false,                     -- Only show published articles
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (species_id)                                                     -- One article per species
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_species_scientific_name ON plants.species(scientific_name);
CREATE INDEX IF NOT EXISTS idx_species_common_name ON plants.species(common_name);
CREATE INDEX IF NOT EXISTS idx_articles_species_id ON plants.articles(species_id);
CREATE INDEX IF NOT EXISTS idx_articles_published ON plants.articles(published);

-- Schema: plants
-- Stored Procedures for Plant Encyclopedia
-- This file contains all stored procedures for plant encyclopedia operations

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS plants;

-- ==================== PLANT ENCYCLOPEDIA FUNCTIONS ====================

-- Function: Get plant species list for encyclopedia (without articles)
CREATE OR REPLACE FUNCTION plants.get_species_list(
    p_search TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_order_by TEXT DEFAULT 'common_name'  -- 'common_name', 'scientific_name', 'created_at'
)
RETURNS TABLE (
    id BIGINT,
    scientific_name TEXT,
    common_name TEXT,
    description TEXT,
    image_url TEXT,
    has_article BOOLEAN
)
LANGUAGE plpgsql
AS $$
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
        ) as has_article
    FROM plants.species s
    WHERE 
        (p_search IS NULL OR 
         s.scientific_name ILIKE '%' || p_search || '%' OR 
         s.common_name ILIKE '%' || p_search || '%')
    ORDER BY 
        CASE 
            WHEN p_order_by = 'common_name' THEN s.common_name
            WHEN p_order_by = 'scientific_name' THEN s.scientific_name
            ELSE s.common_name
        END ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- Function: Get single plant species by ID
CREATE OR REPLACE FUNCTION plants.get_species_by_id(
    p_species_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    scientific_name TEXT,
    common_name TEXT,
    description TEXT,
    image_url TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.scientific_name,
        s.common_name,
        s.description,
        s.image_url
    FROM plants.species s
    WHERE s.id = p_species_id;
END;
$$;

-- Function: Get plant article for a species
CREATE OR REPLACE FUNCTION plants.get_article(
    p_species_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    species_id BIGINT,
    article_content TEXT,
    author_user_id BIGINT,
    published BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.species_id,
        a.article_content,
        a.author_user_id,
        a.published,
        a.created_at,
        a.updated_at
    FROM plants.articles a
    WHERE a.species_id = p_species_id
      AND a.published = true;
END;
$$;

-- Function: Get plant species with article (full encyclopedia entry)
CREATE OR REPLACE FUNCTION plants.get_encyclopedia_entry(
    p_species_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    scientific_name TEXT,
    common_name TEXT,
    description TEXT,
    image_url TEXT,
    article_id BIGINT,
    article_content TEXT,
    article_author_id BIGINT,
    article_created_at TIMESTAMPTZ,
    article_updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
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
        a.updated_at as article_updated_at
    FROM plants.species s
    LEFT JOIN plants.articles a ON a.species_id = s.id AND a.published = true
    WHERE s.id = p_species_id;
END;
$$;

-- Function: Count plant species (for pagination)
CREATE OR REPLACE FUNCTION plants.count_species(
    p_search TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    total_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO total_count
    FROM plants.species s
    WHERE 
        (p_search IS NULL OR 
         s.scientific_name ILIKE '%' || p_search || '%' OR 
         s.common_name ILIKE '%' || p_search || '%');
    
    RETURN total_count;
END;
$$;

-- Function: Create or update plant species
CREATE OR REPLACE FUNCTION plants.upsert_species(
    p_scientific_name TEXT,
    p_id BIGINT DEFAULT NULL,
    p_common_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    scientific_name TEXT,
    common_name TEXT,
    description TEXT,
    image_url TEXT
)
LANGUAGE plpgsql
AS $$
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
            species.image_url;
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
            species.image_url;
    END IF;
END;
$$;

-- Function: Create or update plant article
CREATE OR REPLACE FUNCTION plants.upsert_article(
    p_species_id BIGINT,
    p_article_content TEXT,
    p_author_user_id BIGINT DEFAULT NULL,
    p_published BOOLEAN DEFAULT false
)
RETURNS TABLE (
    id BIGINT,
    species_id BIGINT,
    article_content TEXT,
    author_user_id BIGINT,
    published BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO plants.articles (
        species_id, article_content, author_user_id, published, updated_at
    ) VALUES (
        p_species_id, p_article_content, p_author_user_id, p_published, NOW()
    )
    ON CONFLICT (species_id) 
    DO UPDATE SET
        article_content = EXCLUDED.article_content,
        author_user_id = COALESCE(EXCLUDED.author_user_id, articles.author_user_id),
        published = EXCLUDED.published,
        updated_at = NOW()
    RETURNING 
        articles.id,
        articles.species_id,
        articles.article_content,
        articles.author_user_id,
        articles.published,
        articles.created_at,
        articles.updated_at;
END;
$$;

-- Function: Delete plant article
CREATE OR REPLACE FUNCTION plants.delete_article(
    p_species_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM plants.articles
    WHERE species_id = p_species_id;
    
    RETURN FOUND;
END;
$$;



-- Schema Permissions
-- Grant full permissions to postgres role
GRANT ALL ON SCHEMA plants TO postgres;

-- Grant usage to authenticated and anon roles
GRANT USAGE ON SCHEMA plants TO authenticated, anon;

-- Grant all privileges on all future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT ALL ON TABLES TO postgres;

-- Grant select/insert/update/delete to authenticated users on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- Grant usage on sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT USAGE ON SEQUENCES TO postgres, authenticated;

-- Grant execute on functions
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

