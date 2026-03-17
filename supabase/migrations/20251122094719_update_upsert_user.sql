drop function if exists "public"."upsert_user"(p_auth0_user_id text, p_email text, p_display_name text, p_name text, p_given_name text, p_family_name text, p_picture_url text, p_locale text, p_profile_metadata jsonb, p_app_metadata jsonb, p_is_active boolean, p_updated_at timestamp with time zone);


CREATE OR REPLACE FUNCTION public.upsert_user(
    p_auth0_user_id    TEXT,
    p_email            TEXT,
    p_display_name     TEXT,
    p_name             TEXT,
    p_given_name       TEXT,
    p_family_name      TEXT,
    p_picture_url      TEXT,
    p_locale           TEXT,
    p_profile_metadata JSONB,
    p_app_metadata     JSONB,
    p_updated_at       TIMESTAMPTZ
)
RETURNS auth0.users AS $$
DECLARE
    v_user auth0.users;
BEGIN
    INSERT INTO auth0.users AS u (
        auth0_user_id,
        email,
        display_name,
        name,
        given_name,
        family_name,
        picture_url,
        locale,
        profile_metadata,
        app_metadata,
        updated_at
    )
    VALUES (
        p_auth0_user_id,
        p_email,
        COALESCE(p_display_name, p_name),
        p_name,
        p_given_name,
        p_family_name,
        p_picture_url,
        p_locale,
        p_profile_metadata,
        p_app_metadata,
        p_updated_at
    )
    ON CONFLICT (auth0_user_id) DO UPDATE
    SET
        email            = EXCLUDED.email,
        display_name     = COALESCE(EXCLUDED.display_name, EXCLUDED.name),
        name             = EXCLUDED.name,
        given_name       = EXCLUDED.given_name,
        family_name      = EXCLUDED.family_name,
        picture_url      = EXCLUDED.picture_url,
        locale           = EXCLUDED.locale,
        profile_metadata = EXCLUDED.profile_metadata,
        app_metadata     = EXCLUDED.app_metadata,
        updated_at       = EXCLUDED.updated_at
    RETURNING u.* INTO v_user;

    RETURN v_user;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;