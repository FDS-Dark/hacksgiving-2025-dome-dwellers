create schema if not exists "announcements";

create schema if not exists "tasks";

create sequence "announcements"."announcements_id_seq";

create sequence "tasks"."tasks_id_seq";


  create table "announcements"."announcements" (
    "id" bigint not null default nextval('announcements.announcements_id_seq'::regclass),
    "title" text not null,
    "message" text not null,
    "author_id" bigint not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "tasks"."tasks" (
    "id" bigint not null default nextval('tasks.tasks_id_seq'::regclass),
    "user_id" bigint not null,
    "text" text not null,
    "completed" boolean not null default false,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "completed_at" timestamp with time zone
      );


alter sequence "announcements"."announcements_id_seq" owned by "announcements"."announcements"."id";

alter sequence "tasks"."tasks_id_seq" owned by "tasks"."tasks"."id";

CREATE UNIQUE INDEX announcements_pkey ON announcements.announcements USING btree (id);

CREATE INDEX idx_announcements_author_id ON announcements.announcements USING btree (author_id);

CREATE INDEX idx_announcements_created_at ON announcements.announcements USING btree (created_at DESC);

CREATE INDEX idx_tasks_completed ON tasks.tasks USING btree (completed);

CREATE INDEX idx_tasks_created_at ON tasks.tasks USING btree (created_at DESC);

CREATE INDEX idx_tasks_user_id ON tasks.tasks USING btree (user_id);

CREATE UNIQUE INDEX tasks_pkey ON tasks.tasks USING btree (id);

alter table "announcements"."announcements" add constraint "announcements_pkey" PRIMARY KEY using index "announcements_pkey";

alter table "tasks"."tasks" add constraint "tasks_pkey" PRIMARY KEY using index "tasks_pkey";

alter table "announcements"."announcements" add constraint "announcements_author_id_fkey" FOREIGN KEY (author_id) REFERENCES auth0.users(id) ON DELETE CASCADE not valid;

alter table "announcements"."announcements" validate constraint "announcements_author_id_fkey";

alter table "tasks"."tasks" add constraint "tasks_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE CASCADE not valid;

alter table "tasks"."tasks" validate constraint "tasks_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION announcements.create_announcement(p_author_id bigint, p_title text, p_message text)
 RETURNS TABLE(id bigint, title text, message text, author_id bigint, author_name text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION announcements.delete_announcement(p_announcement_id bigint, p_author_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_deleted BOOLEAN := FALSE;
BEGIN
    DELETE FROM announcements.announcements
    WHERE id = p_announcement_id
        AND author_id = p_author_id;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$function$
;

CREATE OR REPLACE FUNCTION announcements.get_all_announcements()
 RETURNS TABLE(id bigint, title text, message text, author_id bigint, author_name text, author_email text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION announcements.update_announcement(p_announcement_id bigint, p_author_id bigint, p_title text, p_message text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION tasks.create_task(p_user_id bigint, p_text text)
 RETURNS TABLE(id bigint, user_id bigint, text text, completed boolean, created_at timestamp with time zone, updated_at timestamp with time zone, completed_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_task_id BIGINT;
BEGIN
    INSERT INTO tasks.tasks (user_id, text)
    VALUES (p_user_id, p_text)
    RETURNING tasks.id INTO v_task_id;

    RETURN QUERY
    SELECT 
        t.id,
        t.user_id,
        t.text,
        t.completed,
        t.created_at,
        t.updated_at,
        t.completed_at
    FROM tasks.tasks t
    WHERE t.id = v_task_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION tasks.delete_task(p_task_id bigint, p_user_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_deleted BOOLEAN := FALSE;
BEGIN
    DELETE FROM tasks.tasks
    WHERE id = p_task_id AND user_id = p_user_id;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$function$
;

CREATE OR REPLACE FUNCTION tasks.get_all_tasks()
 RETURNS TABLE(id bigint, user_id bigint, user_name text, user_email text, text text, completed boolean, created_at timestamp with time zone, updated_at timestamp with time zone, completed_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.user_id,
        COALESCE(u.display_name, u.name, u.email) AS user_name,
        u.email AS user_email,
        t.text,
        t.completed,
        t.created_at,
        t.updated_at,
        t.completed_at
    FROM tasks.tasks t
    INNER JOIN auth0.users u ON t.user_id = u.id
    ORDER BY t.created_at DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION tasks.get_user_tasks(p_user_id bigint)
 RETURNS TABLE(id bigint, user_id bigint, text text, completed boolean, created_at timestamp with time zone, updated_at timestamp with time zone, completed_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.user_id,
        t.text,
        t.completed,
        t.created_at,
        t.updated_at,
        t.completed_at
    FROM tasks.tasks t
    WHERE t.user_id = p_user_id
    ORDER BY t.created_at DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION tasks.set_completed_at_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.completed = TRUE AND OLD.completed = FALSE THEN
    NEW.completed_at = NOW();
  ELSIF NEW.completed = FALSE AND OLD.completed = TRUE THEN
    NEW.completed_at = NULL;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION tasks.set_updated_at_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION tasks.toggle_task(p_task_id bigint, p_user_id bigint)
 RETURNS TABLE(id bigint, user_id bigint, text text, completed boolean, created_at timestamp with time zone, updated_at timestamp with time zone, completed_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE tasks.tasks
    SET completed = NOT completed
    WHERE tasks.id = p_task_id AND tasks.user_id = p_user_id;

    RETURN QUERY
    SELECT 
        t.id,
        t.user_id,
        t.text,
        t.completed,
        t.created_at,
        t.updated_at,
        t.completed_at
    FROM tasks.tasks t
    WHERE t.id = p_task_id;
END;
$function$
;

grant delete on table "tasks"."tasks" to "authenticated";

grant insert on table "tasks"."tasks" to "authenticated";

grant select on table "tasks"."tasks" to "authenticated";

grant update on table "tasks"."tasks" to "authenticated";

CREATE TRIGGER trg_tasks_completed_at BEFORE UPDATE ON tasks.tasks FOR EACH ROW EXECUTE FUNCTION tasks.set_completed_at_timestamp();

CREATE TRIGGER trg_tasks_updated_at BEFORE UPDATE ON tasks.tasks FOR EACH ROW EXECUTE FUNCTION tasks.set_updated_at_timestamp();


