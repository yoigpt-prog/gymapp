-- Migration: Add exercise_slug column to exercises table

ALTER TABLE exercises ADD COLUMN IF NOT EXISTS exercise_slug text;

-- Function to generate slug
CREATE OR REPLACE FUNCTION generate_exercise_slug(name text, ex_id text, ex_equipment text DEFAULT NULL, ex_body_part text DEFAULT NULL) RETURNS text AS $$
DECLARE
    base_slug text;
    final_slug text;
    conflict_count integer;
    counter integer := 2;
BEGIN
    -- lowercase, replace non-alphanumeric with hyphens, trim hyphens, and most importantly TRIM WHITESPACE
    base_slug := trim(both '-' from lower(regexp_replace(trim(name), '[^a-zA-Z0-9]+', '-', 'g')));
    final_slug := base_slug;

    -- check for existing slug in table
    LOOP
        SELECT count(*) INTO conflict_count FROM exercises WHERE exercise_slug = final_slug AND id::text != ex_id;
        EXIT WHEN conflict_count = 0;
        
        -- Strategy 1: Try adding equipment
        IF counter = 2 AND ex_equipment IS NOT NULL AND ex_equipment != '' AND ex_equipment != 'None' THEN
            final_slug := base_slug || '-' || trim(both '-' from lower(regexp_replace(trim(ex_equipment), '[^a-zA-Z0-9]+', '-', 'g')));
        -- Strategy 2: Try adding body part
        ELSIF (counter = 2 OR counter = 3) AND ex_body_part IS NOT NULL AND ex_body_part != '' THEN
            final_slug := base_slug || '-' || trim(both '-' from lower(regexp_replace(trim(ex_body_part), '[^a-zA-Z0-9]+', '-', 'g')));
        -- Strategy 3: Just use a simple increment
        ELSE
            final_slug := base_slug || '-' || counter;
            counter := counter + 1;
        END IF;

        -- Re-check conflict_count for the new final_slug
        SELECT count(*) INTO conflict_count FROM exercises WHERE exercise_slug = final_slug AND id::text != ex_id;
        EXIT WHEN conflict_count = 0;
        
        -- If even Strategy 1/2 failed, start incrementing
        IF counter = 2 THEN counter := 3; END IF;
    END LOOP;

    RETURN final_slug;
END;
$$ LANGUAGE plpgsql;

-- Backfill data
UPDATE exercises
SET exercise_slug = generate_exercise_slug(exercise_name, id::text, equipment, body_part);

-- Make it NOT NULL
ALTER TABLE exercises ALTER COLUMN exercise_slug SET NOT NULL;
ALTER TABLE exercises ADD CONSTRAINT exercises_slug_unique UNIQUE (exercise_slug);

-- Create an index for fast lookups
CREATE INDEX IF NOT EXISTS idx_exercises_slug ON exercises(exercise_slug);

-- Auto-slug trigger for new inserts/updates
CREATE OR REPLACE FUNCTION set_exercise_slug_trigger() RETURNS trigger AS $$
BEGIN
    IF NEW.exercise_slug IS NULL OR (TG_OP = 'UPDATE' AND NEW.exercise_name != OLD.exercise_name) THEN
        NEW.exercise_slug := generate_exercise_slug(NEW.exercise_name, NEW.id::text, NEW.equipment, NEW.body_part);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_exercise_slug ON exercises;
CREATE TRIGGER trigger_set_exercise_slug
BEFORE INSERT OR UPDATE ON exercises
FOR EACH ROW
EXECUTE FUNCTION set_exercise_slug_trigger();
