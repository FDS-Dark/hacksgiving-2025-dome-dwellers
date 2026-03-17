-- Schema: tasks
-- Domain: Task Management System
-- This file contains all table and function definitions for collaborative task management
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS tasks;

-- Tasks table for collaborative task management
CREATE TABLE IF NOT EXISTS tasks.tasks (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES auth0.users(id) ON DELETE CASCADE,
    text            TEXT NOT NULL,
    completed       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks.tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks.tasks(completed);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks.tasks(created_at DESC);

-- Trigger function to auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION tasks.set_updated_at_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Trigger on tasks table
DROP TRIGGER IF EXISTS trg_tasks_updated_at ON tasks.tasks;
CREATE TRIGGER trg_tasks_updated_at
  BEFORE UPDATE ON tasks.tasks
  FOR EACH ROW
  EXECUTE FUNCTION tasks.set_updated_at_timestamp();

-- Trigger to set completed_at timestamp
CREATE OR REPLACE FUNCTION tasks.set_completed_at_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.completed = TRUE AND OLD.completed = FALSE THEN
    NEW.completed_at = NOW();
  ELSIF NEW.completed = FALSE AND OLD.completed = TRUE THEN
    NEW.completed_at = NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tasks_completed_at ON tasks.tasks;
CREATE TRIGGER trg_tasks_completed_at
  BEFORE UPDATE ON tasks.tasks
  FOR EACH ROW
  EXECUTE FUNCTION tasks.set_completed_at_timestamp();

-- ==================== TASK FUNCTIONS ====================

-- Function: Get all tasks for display (all users)
CREATE OR REPLACE FUNCTION tasks.get_all_tasks()
RETURNS TABLE (
    id BIGINT,
    user_id BIGINT,
    user_name TEXT,
    user_email TEXT,
    text TEXT,
    completed BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Function: Get tasks for a specific user
CREATE OR REPLACE FUNCTION tasks.get_user_tasks(p_user_id BIGINT)
RETURNS TABLE (
    id BIGINT,
    user_id BIGINT,
    text TEXT,
    completed BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Function: Create a new task
CREATE OR REPLACE FUNCTION tasks.create_task(
    p_user_id BIGINT,
    p_text TEXT
)
RETURNS TABLE (
    id BIGINT,
    user_id BIGINT,
    text TEXT,
    completed BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Function: Toggle task completion status
CREATE OR REPLACE FUNCTION tasks.toggle_task(
    p_task_id BIGINT,
    p_user_id BIGINT
)
RETURNS TABLE (
    id BIGINT,
    user_id BIGINT,
    text TEXT,
    completed BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Function: Delete a task
CREATE OR REPLACE FUNCTION tasks.delete_task(
    p_task_id BIGINT,
    p_user_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted BOOLEAN := FALSE;
BEGIN
    DELETE FROM tasks.tasks
    WHERE id = p_task_id AND user_id = p_user_id;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION tasks.get_all_tasks() TO authenticated;
GRANT EXECUTE ON FUNCTION tasks.get_user_tasks(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION tasks.create_task(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION tasks.toggle_task(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION tasks.delete_task(BIGINT, BIGINT) TO authenticated;

-- Schema Permissions
GRANT USAGE ON SCHEMA tasks TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tasks TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA tasks TO authenticated;

