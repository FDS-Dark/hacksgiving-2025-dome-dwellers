CREATE OR REPLACE FUNCTION public.upsert_user(
    p_auth0_user_id   TEXT,
    p_email           TEXT,
    p_display_name    TEXT,
    p_name            TEXT,
    p_given_name      TEXT,
    p_family_name     TEXT,
    p_picture_url     TEXT,
    p_locale          TEXT,
    p_profile_metadata JSONB,
    p_app_metadata     JSONB,
    p_is_active       BOOLEAN,
    p_updated_at      TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO auth0.users (
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
    is_active,
    created_at,
    updated_at
  ) VALUES (
    p_auth0_user_id,
    p_email,
    p_display_name,
    p_name,
    p_given_name,
    p_family_name,
    p_picture_url,
    p_locale,
    p_profile_metadata,
    p_app_metadata,
    p_is_active,
    NOW(),
    p_updated_at
  )
  ON CONFLICT (auth0_user_id)  -- assuming this is unique
  DO UPDATE SET
    email            = EXCLUDED.email,
    display_name     = EXCLUDED.display_name,
    name             = EXCLUDED.name,
    given_name       = EXCLUDED.given_name,
    family_name      = EXCLUDED.family_name,
    picture_url      = EXCLUDED.picture_url,
    locale           = EXCLUDED.locale,
    profile_metadata = EXCLUDED.profile_metadata,
    app_metadata     = EXCLUDED.app_metadata,
    is_active        = EXCLUDED.is_active,
    updated_at       = EXCLUDED.updated_at
  ;
END;
$$;