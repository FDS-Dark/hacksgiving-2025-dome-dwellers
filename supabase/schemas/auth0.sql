-- Schema: auth0
-- Domain 1: Users & Roles (Auth0-backed Authentication)
-- This file contains all table and function definitions for the auth0 schema
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS auth0;

-- Core app users (visitors + staff)
-- Auth is delegated to Auth0 - no passwords stored here
CREATE TABLE IF NOT EXISTS auth0.users (
    id               BIGSERIAL PRIMARY KEY,
    auth0_user_id    TEXT UNIQUE NOT NULL,           -- Auth0 'sub' identifier (e.g. "auth0|abc123")
    email            TEXT UNIQUE,                    -- Convenience mirror from Auth0 (not source of truth)
    display_name     TEXT,
    name             TEXT,
    given_name       TEXT,
    family_name      TEXT,
    picture_url      TEXT,
    locale           TEXT,
    profile_metadata JSONB,
    app_metadata     JSONB,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- App roles (managed locally, not in Auth0)
-- Used for RBAC in app logic
CREATE TABLE IF NOT EXISTS auth0.roles (
    id          SMALLSERIAL PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL                -- Expected: 'visitor', 'staff', 'admin'
);

-- Many-to-many relationship between users and roles
CREATE TABLE IF NOT EXISTS auth0.user_roles (
    user_id BIGINT NOT NULL REFERENCES auth0.users(id) ON DELETE CASCADE,
    role_id SMALLINT NOT NULL REFERENCES auth0.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_users_auth0_user_id ON auth0.users(auth0_user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON auth0.users(email);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON auth0.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON auth0.user_roles(role_id);

-- Trigger function to auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION auth0.set_updated_at_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Trigger on users table
DROP TRIGGER IF EXISTS trg_auth0_users_updated_at ON auth0.users;
CREATE TRIGGER trg_auth0_users_updated_at
  BEFORE UPDATE ON auth0.users
  FOR EACH ROW
  EXECUTE FUNCTION auth0.set_updated_at_timestamp();

-- Insert default roles (idempotent)
INSERT INTO auth0.roles (name) VALUES ('visitor'), ('staff'), ('admin')
ON CONFLICT (name) DO NOTHING;

-- ==================== USER FUNCTIONS ====================

-- Function: Get user by auth0_user_id with roles
CREATE OR REPLACE FUNCTION auth0.get_user_by_auth0_id(
    p_auth0_user_id TEXT
)
RETURNS TABLE (
    id BIGINT,
    auth0_user_id TEXT,
    email TEXT,
    display_name TEXT,
    name TEXT,
    given_name TEXT,
    family_name TEXT,
    picture_url TEXT,
    locale TEXT,
    profile_metadata JSONB,
    app_metadata JSONB,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    roles JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.auth0_user_id,
        u.email,
        u.display_name,
        u.name,
        u.given_name,
        u.family_name,
        u.picture_url,
        u.locale,
        u.profile_metadata,
        u.app_metadata,
        u.is_active,
        u.created_at,
        u.updated_at,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', r.id,
                        'name', r.name
                    )
                )
                FROM auth0.user_roles ur
                JOIN auth0.roles r ON r.id = ur.role_id
                WHERE ur.user_id = u.id
            ),
            '[]'::jsonb
        ) as roles
    FROM auth0.users u
    WHERE u.auth0_user_id = p_auth0_user_id
      AND u.is_active = true;
END;
$$;

-- Function: Get or create user by auth0_user_id
CREATE OR REPLACE FUNCTION auth0.upsert_user(
    p_auth0_user_id TEXT,
    p_email TEXT DEFAULT NULL,
    p_display_name TEXT DEFAULT NULL,
    p_name TEXT DEFAULT NULL,
    p_given_name TEXT DEFAULT NULL,
    p_family_name TEXT DEFAULT NULL,
    p_picture_url TEXT DEFAULT NULL,
    p_locale TEXT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    auth0_user_id TEXT,
    email TEXT,
    display_name TEXT,
    name TEXT,
    given_name TEXT,
    family_name TEXT,
    picture_url TEXT,
    locale TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id BIGINT;
    v_visitor_role_id SMALLINT;
BEGIN
    -- Get the visitor role ID
    SELECT r.id INTO v_visitor_role_id
    FROM auth0.roles r
    WHERE r.name = 'visitor';

    -- Insert or update user
    INSERT INTO auth0.users (
        auth0_user_id, email, display_name, name, given_name, 
        family_name, picture_url, locale
    ) VALUES (
        p_auth0_user_id, p_email, p_display_name, p_name, p_given_name,
        p_family_name, p_picture_url, p_locale
    )
    ON CONFLICT (auth0_user_id) 
    DO UPDATE SET
        email = COALESCE(EXCLUDED.email, users.email),
        display_name = COALESCE(EXCLUDED.display_name, users.display_name),
        name = COALESCE(EXCLUDED.name, users.name),
        given_name = COALESCE(EXCLUDED.given_name, users.given_name),
        family_name = COALESCE(EXCLUDED.family_name, users.family_name),
        picture_url = COALESCE(EXCLUDED.picture_url, users.picture_url),
        locale = COALESCE(EXCLUDED.locale, users.locale),
        updated_at = NOW()
    RETURNING users.id INTO v_user_id;

    -- Assign visitor role if user is new and doesn't have any roles
    IF NOT EXISTS (SELECT 1 FROM auth0.user_roles WHERE user_id = v_user_id) THEN
        IF v_visitor_role_id IS NOT NULL THEN
            INSERT INTO auth0.user_roles (user_id, role_id)
            VALUES (v_user_id, v_visitor_role_id)
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    -- Return the user
    RETURN QUERY
    SELECT 
        u.id,
        u.auth0_user_id,
        u.email,
        u.display_name,
        u.name,
        u.given_name,
        u.family_name,
        u.picture_url,
        u.locale,
        u.is_active,
        u.created_at,
        u.updated_at
    FROM auth0.users u
    WHERE u.id = v_user_id;
END;
$$;

-- Schema Permissions
-- Grant full permissions to postgres role
GRANT ALL ON SCHEMA auth0 TO postgres;

-- Grant usage to authenticated and anon roles
GRANT USAGE ON SCHEMA auth0 TO authenticated, anon;

-- Grant all privileges on all future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA auth0 GRANT ALL ON TABLES TO postgres;

-- Grant select/insert/update/delete to authenticated users on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA auth0 GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- Grant usage on sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA auth0 GRANT USAGE ON SEQUENCES TO postgres, authenticated;

-- Grant execute on functions
ALTER DEFAULT PRIVILEGES IN SCHEMA auth0 GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;
