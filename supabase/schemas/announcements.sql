-- Schema: announcements
-- Domain: Staff Communication System
-- This file contains all table and function definitions for announcements

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS announcements;

-- Announcements table
CREATE TABLE IF NOT EXISTS announcements.announcements (
    id                  BIGSERIAL PRIMARY KEY,
    title               TEXT NOT NULL,
    message             TEXT NOT NULL,
    author_id           BIGINT NOT NULL REFERENCES auth0.users(id) ON DELETE CASCADE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Function: Get all announcements with author details
CREATE OR REPLACE FUNCTION announcements.get_all_announcements()
RETURNS TABLE (
    id BIGINT,
    title TEXT,
    message TEXT,
    author_id BIGINT,
    author_name TEXT,
    author_email TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.title,
        a.message,
        a.author_id,
        COALESCE(u.display_name, u.name, u.email) AS author_name,
        u.email AS author_email,
        a.created_at,
        a.updated_at
    FROM announcements.announcements a
    INNER JOIN auth0.users u ON a.author_id = u.id
    ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Create announcement
CREATE OR REPLACE FUNCTION announcements.create_announcement(
    p_author_id BIGINT,
    p_title TEXT,
    p_message TEXT
)
RETURNS TABLE (
    id BIGINT,
    title TEXT,
    message TEXT,
    author_id BIGINT,
    author_name TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_announcement_id BIGINT;
BEGIN
    INSERT INTO announcements.announcements (author_id, title, message)
    VALUES (p_author_id, p_title, p_message)
    RETURNING announcements.id INTO v_announcement_id;
    
    RETURN QUERY
    SELECT 
        a.id,
        a.title,
        a.message,
        a.author_id,
        COALESCE(u.display_name, u.name, u.email) AS author_name,
        a.created_at,
        a.updated_at
    FROM announcements.announcements a
    INNER JOIN auth0.users u ON a.author_id = u.id
    WHERE a.id = v_announcement_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Update announcement
CREATE OR REPLACE FUNCTION announcements.update_announcement(
    p_announcement_id BIGINT,
    p_author_id BIGINT,
    p_title TEXT,
    p_message TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated BOOLEAN := FALSE;
BEGIN
    UPDATE announcements.announcements
    SET 
        title = p_title,
        message = p_message,
        updated_at = NOW()
    WHERE id = p_announcement_id
        AND author_id = p_author_id;
    
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Delete announcement
CREATE OR REPLACE FUNCTION announcements.delete_announcement(
    p_announcement_id BIGINT,
    p_author_id BIGINT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_deleted BOOLEAN := FALSE;
BEGIN
    DELETE FROM announcements.announcements
    WHERE id = p_announcement_id
        AND author_id = p_author_id;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION announcements.get_all_announcements() TO authenticated;
GRANT EXECUTE ON FUNCTION announcements.create_announcement(BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION announcements.update_announcement(BIGINT, BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION announcements.delete_announcement(BIGINT, BIGINT) TO authenticated;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_announcements_author_id ON announcements.announcements(author_id);
CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON announcements.announcements(created_at DESC);

-- Schema Permissions
GRANT ALL ON SCHEMA announcements TO postgres;
GRANT USAGE ON SCHEMA announcements TO authenticated, anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA announcements GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA announcements GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA announcements GRANT USAGE ON SEQUENCES TO postgres, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA announcements GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

