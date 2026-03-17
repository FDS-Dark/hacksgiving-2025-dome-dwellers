alter table "inventory"."plant_instances" drop constraint "plant_instances_plant_species_id_fkey";

alter table "inventory"."plant_species" drop constraint "plant_species_scientific_name_key";

alter table "inventory"."stock_requests" drop constraint "stock_requests_plant_species_id_fkey";

alter table "agent"."conversations" drop constraint "conversations_plant_species_id_fkey";

alter table "agent"."knowledge_documents" drop constraint "knowledge_documents_plant_species_id_fkey";

alter table "gamification"."plant_discoveries" drop constraint "plant_discoveries_plant_species_id_fkey";

alter table "gamification"."trivia_questions" drop constraint "trivia_questions_plant_species_id_fkey";

alter table "inventory"."plant_species" drop constraint "plant_species_pkey";

drop index if exists "inventory"."idx_plant_instances_plant_species_id";

drop index if exists "inventory"."idx_plant_species_common_name";

drop index if exists "inventory"."idx_plant_species_scientific_name";

drop index if exists "inventory"."idx_stock_requests_plant_species_id";

drop index if exists "inventory"."plant_species_pkey";

drop index if exists "inventory"."plant_species_scientific_name_key";

drop table "inventory"."plant_species";

alter table "inventory"."plant_instances" drop column "plant_species_id";

alter table "inventory"."plant_instances" add column "species_id" bigint not null;

alter table "inventory"."stock_requests" drop column "plant_species_id";

alter table "inventory"."stock_requests" add column "species_id" bigint;

alter table "plants"."species" drop column "care_notes";

alter table "plants"."species" drop column "created_at";

alter table "plants"."species" drop column "thumbnail_url";

drop sequence if exists "inventory"."plant_species_id_seq";

CREATE INDEX idx_plant_instances_species_id ON inventory.plant_instances USING btree (species_id);

CREATE INDEX idx_stock_requests_species_id ON inventory.stock_requests USING btree (species_id);

alter table "inventory"."plant_instances" add constraint "plant_instances_species_id_fkey" FOREIGN KEY (species_id) REFERENCES plants.species(id) ON DELETE CASCADE not valid;

alter table "inventory"."plant_instances" validate constraint "plant_instances_species_id_fkey";

alter table "inventory"."stock_requests" add constraint "stock_requests_species_id_fkey" FOREIGN KEY (species_id) REFERENCES plants.species(id) not valid;

alter table "inventory"."stock_requests" validate constraint "stock_requests_species_id_fkey";

alter table "agent"."conversations" add constraint "conversations_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES plants.species(id) not valid;

alter table "agent"."conversations" validate constraint "conversations_plant_species_id_fkey";

alter table "agent"."knowledge_documents" add constraint "knowledge_documents_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES plants.species(id) not valid;

alter table "agent"."knowledge_documents" validate constraint "knowledge_documents_plant_species_id_fkey";

alter table "gamification"."plant_discoveries" add constraint "plant_discoveries_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES plants.species(id) not valid;

alter table "gamification"."plant_discoveries" validate constraint "plant_discoveries_plant_species_id_fkey";

alter table "gamification"."trivia_questions" add constraint "trivia_questions_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES plants.species(id) not valid;

alter table "gamification"."trivia_questions" validate constraint "trivia_questions_plant_species_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION auth0.get_user_by_auth0_id(p_auth0_user_id text)
 RETURNS TABLE(id bigint, auth0_user_id text, email text, display_name text, name text, given_name text, family_name text, picture_url text, locale text, profile_metadata jsonb, app_metadata jsonb, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, roles jsonb)
 LANGUAGE plpgsql
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION auth0.upsert_user(p_auth0_user_id text, p_email text DEFAULT NULL::text, p_display_name text DEFAULT NULL::text, p_name text DEFAULT NULL::text, p_given_name text DEFAULT NULL::text, p_family_name text DEFAULT NULL::text, p_picture_url text DEFAULT NULL::text, p_locale text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, auth0_user_id text, email text, display_name text, name text, given_name text, family_name text, picture_url text, locale text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
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
$function$
;


