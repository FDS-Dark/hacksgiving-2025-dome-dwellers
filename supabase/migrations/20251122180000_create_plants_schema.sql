-- Migration: Create plants schema for plant encyclopedia
-- This migration creates the plants schema with species and articles tables

-- Create plants schema
CREATE SCHEMA IF NOT EXISTS plants;

-- Create species table
CREATE TABLE IF NOT EXISTS plants.species (
    id              BIGSERIAL PRIMARY KEY,
    scientific_name TEXT NOT NULL,
    common_name     TEXT,
    description     TEXT,
    care_notes      TEXT,
    image_url       TEXT,
    thumbnail_url   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (scientific_name)
);

-- Create articles table
CREATE TABLE IF NOT EXISTS plants.articles (
    id                  BIGSERIAL PRIMARY KEY,
    species_id          BIGINT NOT NULL REFERENCES plants.species(id) ON DELETE CASCADE,
    article_content     TEXT NOT NULL,
    author_user_id      BIGINT REFERENCES auth0.users(id),
    published           BOOLEAN NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (species_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_species_scientific_name ON plants.species(scientific_name);
CREATE INDEX IF NOT EXISTS idx_species_common_name ON plants.species(common_name);
CREATE INDEX IF NOT EXISTS idx_articles_species_id ON plants.articles(species_id);
CREATE INDEX IF NOT EXISTS idx_articles_published ON plants.articles(published);

-- Grant permissions
GRANT ALL ON SCHEMA plants TO postgres;
GRANT USAGE ON SCHEMA plants TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT USAGE ON SEQUENCES TO postgres, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA plants GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

-- Create stored procedures
-- Function: Get plant species list for encyclopedia
CREATE OR REPLACE FUNCTION plants.get_species_list(
    p_search TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_order_by TEXT DEFAULT 'common_name'
)
RETURNS TABLE (
    id BIGINT,
    scientific_name TEXT,
    common_name TEXT,
    description TEXT,
    image_url TEXT,
    thumbnail_url TEXT,
    has_article BOOLEAN,
    created_at TIMESTAMPTZ
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
        s.thumbnail_url,
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
    care_notes TEXT,
    image_url TEXT,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ
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
        s.care_notes,
        s.image_url,
        s.thumbnail_url,
        s.created_at
    FROM plants.species s
    WHERE s.id = p_species_id;
END;
$$;

-- Function: Get plant article
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

-- Function: Get full encyclopedia entry
CREATE OR REPLACE FUNCTION plants.get_encyclopedia_entry(
    p_species_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    scientific_name TEXT,
    common_name TEXT,
    description TEXT,
    care_notes TEXT,
    image_url TEXT,
    thumbnail_url TEXT,
    article_id BIGINT,
    article_content TEXT,
    article_author_id BIGINT,
    article_created_at TIMESTAMPTZ,
    article_updated_at TIMESTAMPTZ,
    species_created_at TIMESTAMPTZ
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
        s.care_notes,
        s.image_url,
        s.thumbnail_url,
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
$$;

-- Function: Count species
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

-- Function: Create or update species
CREATE OR REPLACE FUNCTION plants.upsert_species(
    p_scientific_name TEXT,
    p_id BIGINT DEFAULT NULL,
    p_common_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_care_notes TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_thumbnail_url TEXT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    scientific_name TEXT,
    common_name TEXT,
    description TEXT,
    care_notes TEXT,
    image_url TEXT,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_id IS NULL THEN
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
$$;

-- Function: Create or update article
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

-- Function: Delete article
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

