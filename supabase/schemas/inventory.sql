-- Schema: inventory
-- Domain 2: Inventory Management System (DIMS)
-- This file contains all table and function definitions for plant inventory management
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS plants;

-- Physical locations where plants are stored (greenhouse, dome #2, etc.)
CREATE TABLE IF NOT EXISTS inventory.storage_locations (
    id              BIGSERIAL PRIMARY KEY,
    name            TEXT NOT NULL,                  -- e.g. "Greenhouse A", "Dome #2", "Quarantine Area"
    location_type   TEXT NOT NULL CHECK (location_type IN ('greenhouse', 'dome', 'storage', 'quarantine', 'other')),
    description     TEXT,
    capacity        INTEGER,                        -- Optional: max number of plants
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (name)
);

-- Physical plant instances in inventory
-- Note: Species information now comes from plants.species table
CREATE TABLE IF NOT EXISTS inventory.plant_instances (
    id                  BIGSERIAL PRIMARY KEY,
    species_id          BIGINT NOT NULL REFERENCES plants.species(id) ON DELETE CASCADE,
    storage_location_id BIGINT REFERENCES inventory.storage_locations(id),  -- Where this plant currently is (NULL = staging area)
    identifier          TEXT,                                               -- Internal tag/label like "CACTUS-042"
    quantity            INTEGER NOT NULL DEFAULT 1,                         -- For batch tracking
    status              TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'reserved', 'sold', 'removed')),
    is_public           BOOLEAN NOT NULL DEFAULT true,                      -- Whether visible to public (false = staging/private)
    acquired_date       DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Stock requests for new plants (staff-initiated)
CREATE TABLE IF NOT EXISTS inventory.stock_requests (
    id                  BIGSERIAL PRIMARY KEY,
    requested_by_user_id BIGINT NOT NULL REFERENCES auth0.users(id),        -- Staff member making request
    species_id          BIGINT REFERENCES plants.species(id),               -- Null if requesting new species
    requested_species_name TEXT,                                           -- Free-form if species not in catalog
    quantity            INTEGER NOT NULL CHECK (quantity > 0),
    priority            TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    status              TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'ordered', 'received', 'rejected')),
    justification       TEXT,                                              -- Why we need these plants
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Staff notes/logs for individual plants
CREATE TABLE IF NOT EXISTS inventory.plant_notes (
    id                  BIGSERIAL PRIMARY KEY,
    plant_instance_id   BIGINT NOT NULL REFERENCES inventory.plant_instances(id) ON DELETE CASCADE,
    staff_user_id       BIGINT NOT NULL REFERENCES auth0.users(id),         -- Staff user who wrote the note
    note_type           TEXT NOT NULL CHECK (note_type IN ('observation', 'maintenance', 'issue', 'transfer', 'other')),
    content             TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_storage_locations_location_type ON inventory.storage_locations(location_type);
CREATE INDEX IF NOT EXISTS idx_plant_instances_species_id ON inventory.plant_instances(species_id);
CREATE INDEX IF NOT EXISTS idx_plant_instances_storage_location_id ON inventory.plant_instances(storage_location_id);
CREATE INDEX IF NOT EXISTS idx_plant_instances_identifier ON inventory.plant_instances(identifier);
CREATE INDEX IF NOT EXISTS idx_plant_instances_status ON inventory.plant_instances(status);
CREATE INDEX IF NOT EXISTS idx_plant_instances_is_public ON inventory.plant_instances(is_public);
CREATE INDEX IF NOT EXISTS idx_stock_requests_requested_by_user_id ON inventory.stock_requests(requested_by_user_id);
CREATE INDEX IF NOT EXISTS idx_stock_requests_species_id ON inventory.stock_requests(species_id);
CREATE INDEX IF NOT EXISTS idx_stock_requests_status ON inventory.stock_requests(status);
CREATE INDEX IF NOT EXISTS idx_stock_requests_priority ON inventory.stock_requests(priority);
CREATE INDEX IF NOT EXISTS idx_plant_notes_plant_instance_id ON inventory.plant_notes(plant_instance_id);
CREATE INDEX IF NOT EXISTS idx_plant_notes_staff_user_id ON inventory.plant_notes(staff_user_id);
CREATE INDEX IF NOT EXISTS idx_plant_notes_note_type ON inventory.plant_notes(note_type);
CREATE INDEX IF NOT EXISTS idx_plant_notes_created_at ON inventory.plant_notes(created_at);

-- Schema Permissions
-- Grant full permissions to postgres role
GRANT ALL ON SCHEMA inventory TO postgres;

-- Grant usage to authenticated and anon roles
GRANT USAGE ON SCHEMA inventory TO authenticated, anon;

-- Grant all privileges on all future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA inventory GRANT ALL ON TABLES TO postgres;

-- Grant select/insert/update/delete to authenticated users on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA inventory GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- Grant usage on sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA inventory GRANT USAGE ON SEQUENCES TO postgres, authenticated;

-- Grant execute on functions
ALTER DEFAULT PRIVILEGES IN SCHEMA inventory GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

