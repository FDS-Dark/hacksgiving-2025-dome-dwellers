-- Schema: dome
-- Domain 4: Dome Information
-- This file contains all table and function definitions for visitor-facing dome content
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS dome;

-- Dome events (classes, tours, special exhibitions, etc.)
CREATE TABLE IF NOT EXISTS dome.events (
    id              BIGSERIAL PRIMARY KEY,
    title           TEXT NOT NULL,
    description     TEXT,
    event_type      TEXT NOT NULL CHECK (event_type IN ('tour', 'class', 'exhibition', 'special_event', 'other')),
    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ NOT NULL,
    location        TEXT,                                       -- Freeform location description (e.g. "Main Dome", "Education Center")
    capacity        INTEGER,                                    -- Max attendees
    registration_required BOOLEAN NOT NULL DEFAULT FALSE,
    registration_url TEXT,                                      -- External registration link if needed
    image_url       TEXT,
    created_by_user_id BIGINT REFERENCES auth0.users(id),       -- Staff member who created event
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (end_time > start_time)
);

-- Event registrations (if handling internally)
CREATE TABLE IF NOT EXISTS dome.event_registrations (
    id              BIGSERIAL PRIMARY KEY,
    event_id        BIGINT NOT NULL REFERENCES dome.events(id) ON DELETE CASCADE,
    user_id         BIGINT REFERENCES auth0.users(id) ON DELETE SET NULL,  -- Null for anonymous/guest registrations
    attendee_name   TEXT NOT NULL,                              -- Name of person attending
    attendee_email  TEXT,
    attendee_phone  TEXT,
    registration_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          TEXT NOT NULL DEFAULT 'registered' CHECK (status IN ('registered', 'attended', 'cancelled', 'no_show')),
    notes           TEXT
);

-- General dome information/pages
-- Can be used for FAQs, hours, policies, etc.
CREATE TABLE IF NOT EXISTS dome.info_pages (
    id              BIGSERIAL PRIMARY KEY,
    slug            TEXT NOT NULL UNIQUE,                       -- URL-friendly identifier (e.g. 'hours', 'faq', 'policies')
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,                              -- Markdown or HTML content
    published       BOOLEAN NOT NULL DEFAULT TRUE,
    display_order   INTEGER,                                    -- For sorting pages
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_events_event_type ON dome.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_start_time ON dome.events(start_time);
CREATE INDEX IF NOT EXISTS idx_events_end_time ON dome.events(end_time);
CREATE INDEX IF NOT EXISTS idx_events_created_by_user_id ON dome.events(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_event_id ON dome.event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_user_id ON dome.event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_status ON dome.event_registrations(status);
CREATE INDEX IF NOT EXISTS idx_info_pages_slug ON dome.info_pages(slug);
CREATE INDEX IF NOT EXISTS idx_info_pages_published ON dome.info_pages(published);
CREATE INDEX IF NOT EXISTS idx_info_pages_display_order ON dome.info_pages(display_order);

-- Schema Permissions
-- Grant full permissions to postgres role
GRANT ALL ON SCHEMA dome TO postgres;

-- Grant usage to authenticated and anon roles
GRANT USAGE ON SCHEMA dome TO authenticated, anon;

-- Grant all privileges on all future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA dome GRANT ALL ON TABLES TO postgres;

-- Grant select/insert/update/delete to authenticated users on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA dome GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- Grant usage on sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA dome GRANT USAGE ON SEQUENCES TO postgres, authenticated;

-- Grant execute on functions
ALTER DEFAULT PRIVILEGES IN SCHEMA dome GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

