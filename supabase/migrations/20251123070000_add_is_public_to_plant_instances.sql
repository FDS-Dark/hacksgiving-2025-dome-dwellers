-- Add is_public column to inventory.plant_instances
-- This allows plants to be in a staging/private state before being made public

ALTER TABLE inventory.plant_instances
ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true;

-- Create index for filtering by public status
CREATE INDEX IF NOT EXISTS idx_plant_instances_is_public ON inventory.plant_instances(is_public);

-- Add comment for clarity
COMMENT ON COLUMN inventory.plant_instances.is_public IS 'Whether this plant instance is visible to the public. False indicates staging/private state.';

