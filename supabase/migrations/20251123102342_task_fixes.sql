set check_function_bodies = off;

CREATE OR REPLACE FUNCTION tasks.toggle_task(p_task_id bigint, p_user_id bigint)
 RETURNS TABLE(id bigint, user_id bigint, text text, completed boolean, created_at timestamp with time zone, updated_at timestamp with time zone, completed_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE tasks.tasks
    SET completed = NOT tasks.tasks.completed
    WHERE tasks.tasks.id = p_task_id AND tasks.tasks.user_id = p_user_id;

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


