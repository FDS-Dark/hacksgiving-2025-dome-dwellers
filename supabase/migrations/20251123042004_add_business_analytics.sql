create sequence "staff"."feedback_id_seq";


  create table "staff"."feedback" (
    "id" bigint not null default nextval('staff.feedback_id_seq'::regclass),
    "user_id" bigint,
    "rating" integer not null,
    "tropics_rating" integer,
    "desert_rating" integer,
    "show_rating" integer,
    "staff_friendliness" integer,
    "cleanliness" integer,
    "additional_comments" text,
    "created_at" timestamp with time zone not null default now()
      );


alter sequence "staff"."feedback_id_seq" owned by "staff"."feedback"."id";

CREATE UNIQUE INDEX feedback_pkey ON staff.feedback USING btree (id);

CREATE INDEX idx_feedback_created_at ON staff.feedback USING btree (created_at);

CREATE INDEX idx_feedback_rating ON staff.feedback USING btree (rating);

CREATE INDEX idx_feedback_user_id ON staff.feedback USING btree (user_id) WHERE (user_id IS NOT NULL);

alter table "staff"."feedback" add constraint "feedback_pkey" PRIMARY KEY using index "feedback_pkey";

alter table "staff"."feedback" add constraint "feedback_cleanliness_check" CHECK (((cleanliness IS NULL) OR ((cleanliness >= 1) AND (cleanliness <= 5)))) not valid;

alter table "staff"."feedback" validate constraint "feedback_cleanliness_check";

alter table "staff"."feedback" add constraint "feedback_desert_rating_check" CHECK (((desert_rating IS NULL) OR ((desert_rating >= 1) AND (desert_rating <= 5)))) not valid;

alter table "staff"."feedback" validate constraint "feedback_desert_rating_check";

alter table "staff"."feedback" add constraint "feedback_rating_check" CHECK (((rating >= 1) AND (rating <= 5))) not valid;

alter table "staff"."feedback" validate constraint "feedback_rating_check";

alter table "staff"."feedback" add constraint "feedback_show_rating_check" CHECK (((show_rating IS NULL) OR ((show_rating >= 1) AND (show_rating <= 5)))) not valid;

alter table "staff"."feedback" validate constraint "feedback_show_rating_check";

alter table "staff"."feedback" add constraint "feedback_staff_friendliness_check" CHECK (((staff_friendliness IS NULL) OR ((staff_friendliness >= 1) AND (staff_friendliness <= 5)))) not valid;

alter table "staff"."feedback" validate constraint "feedback_staff_friendliness_check";

alter table "staff"."feedback" add constraint "feedback_tropics_rating_check" CHECK (((tropics_rating IS NULL) OR ((tropics_rating >= 1) AND (tropics_rating <= 5)))) not valid;

alter table "staff"."feedback" validate constraint "feedback_tropics_rating_check";

alter table "staff"."feedback" add constraint "feedback_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) not valid;

alter table "staff"."feedback" validate constraint "feedback_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION gamification.auto_add_plant_to_catalog()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
;

CREATE TRIGGER trigger_add_plant_to_catalog AFTER INSERT ON plants.species FOR EACH ROW EXECUTE FUNCTION gamification.auto_add_plant_to_catalog();


