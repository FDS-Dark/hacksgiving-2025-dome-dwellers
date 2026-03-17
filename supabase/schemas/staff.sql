-- Schema: staff
-- Domain 3: Staff Management
-- This file contains all table and function definitions for staff operations
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS staff;

-- Staff announcements (broadcast messages to all staff)
CREATE TABLE IF NOT EXISTS staff.announcements (
    id              BIGSERIAL PRIMARY KEY,
    created_by_user_id BIGINT NOT NULL REFERENCES auth0.users(id),  -- Admin/manager who created it
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    priority        TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    expires_at      TIMESTAMPTZ,                                   -- Optional expiration time
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Staff tasks (assignments for individual staff or teams)
CREATE TABLE IF NOT EXISTS staff.tasks (
    id                  BIGSERIAL PRIMARY KEY,
    created_by_user_id  BIGINT NOT NULL REFERENCES auth0.users(id), -- Who assigned the task
    assigned_to_user_id BIGINT REFERENCES auth0.users(id),          -- Who should do it (null = unassigned)
    title               TEXT NOT NULL,
    description         TEXT,
    priority            TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    status              TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    due_date            TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task comments/updates
CREATE TABLE IF NOT EXISTS staff.task_comments (
    id              BIGSERIAL PRIMARY KEY,
    task_id         BIGINT NOT NULL REFERENCES staff.tasks(id) ON DELETE CASCADE,
    user_id         BIGINT NOT NULL REFERENCES auth0.users(id),
    comment         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Staff schedules/shifts
CREATE TABLE IF NOT EXISTS staff.schedules (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES auth0.users(id) ON DELETE CASCADE,
    shift_start     TIMESTAMPTZ NOT NULL,
    shift_end       TIMESTAMPTZ NOT NULL,
    role_during_shift TEXT,                                        -- e.g. 'greeter', 'guide', 'inventory', 'maintenance'
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (shift_end > shift_start)
);

-- Visitor feedback
CREATE TABLE IF NOT EXISTS staff.feedback (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT REFERENCES auth0.users(id),         -- Optional: anonymous feedback allowed
    rating              INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5), -- Overall visit rating (required)
    tropics_rating      INTEGER CHECK (tropics_rating IS NULL OR (tropics_rating >= 1 AND tropics_rating <= 5)),
    desert_rating       INTEGER CHECK (desert_rating IS NULL OR (desert_rating >= 1 AND desert_rating <= 5)),
    show_rating         INTEGER CHECK (show_rating IS NULL OR (show_rating >= 1 AND show_rating <= 5)),
    staff_friendliness  INTEGER CHECK (staff_friendliness IS NULL OR (staff_friendliness >= 1 AND staff_friendliness <= 5)),
    cleanliness         INTEGER CHECK (cleanliness IS NULL OR (cleanliness >= 1 AND cleanliness <= 5)),
    additional_comments TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_announcements_created_by_user_id ON staff.announcements(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_announcements_priority ON staff.announcements(priority);
CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON staff.announcements(created_at);
CREATE INDEX IF NOT EXISTS idx_announcements_expires_at ON staff.announcements(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_created_by_user_id ON staff.tasks(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to_user_id ON staff.tasks(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON staff.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON staff.tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON staff.tasks(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_task_comments_task_id ON staff.task_comments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_comments_user_id ON staff.task_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_schedules_user_id ON staff.schedules(user_id);
CREATE INDEX IF NOT EXISTS idx_schedules_shift_start ON staff.schedules(shift_start);
CREATE INDEX IF NOT EXISTS idx_schedules_shift_end ON staff.schedules(shift_end);
CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON staff.feedback(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feedback_rating ON staff.feedback(rating);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON staff.feedback(created_at);

-- Schema Permissions
-- Grant full permissions to postgres role
GRANT ALL ON SCHEMA staff TO postgres;

-- Grant usage to authenticated and anon roles
GRANT USAGE ON SCHEMA staff TO authenticated, anon;

-- Grant all privileges on all future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA staff GRANT ALL ON TABLES TO postgres;

-- Grant select/insert/update/delete to authenticated users on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA staff GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- Grant usage on sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA staff GRANT USAGE ON SEQUENCES TO postgres, authenticated;

-- Grant execute on functions
ALTER DEFAULT PRIVILEGES IN SCHEMA staff GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

