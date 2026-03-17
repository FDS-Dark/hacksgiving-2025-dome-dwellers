drop function if exists "public"."upsert_user"(p_auth0_user_id text, p_email text, p_display_name text, p_name text, p_given_name text, p_family_name text, p_picture_url text, p_locale text, p_profile_metadata jsonb, p_app_metadata jsonb, p_updated_at timestamp with time zone);

alter table "auth0"."users" add column "app_metadata" jsonb;

alter table "auth0"."users" add column "is_active" boolean not null default true;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.upsert_user(p_auth0_user_id text, p_email text, p_display_name text, p_name text, p_given_name text, p_family_name text, p_picture_url text, p_locale text, p_profile_metadata jsonb, p_app_metadata jsonb, p_is_active boolean, p_updated_at timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;


