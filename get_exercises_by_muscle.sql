-- ============================================================
-- get_exercises_by_muscle.sql
-- Supabase RPC that returns exercises sorted by custom
-- equipment priority using CASE ORDER BY.
--
-- Equipment priority:
--   1 = Dumbbell
--   2 = Leverage Machine
--   3 = Body weight
--   4 = Barbell
--   5 = EZ Barbell
--   6 = Cable
--   99 = everything else (last)
--
-- Run once in Supabase SQL Editor to deploy / update.
-- ============================================================

CREATE OR REPLACE FUNCTION get_exercises_by_muscle(
  p_muscle          text,          -- group_path value (case-insensitive match)
  p_is_male         boolean,       -- true = male exercises
  p_is_female       boolean,       -- true = female exercises
  p_equipment       text[] DEFAULT NULL,   -- equipment filter (NULL = no filter)
  p_difficulties    text[] DEFAULT NULL,   -- difficulty_level filter
  p_workout_types   text[] DEFAULT NULL,   -- exercise_type filter
  p_search          text  DEFAULT NULL,    -- free-text search (NULL = no search)
  p_ids             text[] DEFAULT NULL,   -- specific IDs filter (NULL = no filter)
  p_limit           int   DEFAULT 20,
  p_offset          int   DEFAULT 0
)
RETURNS TABLE (
  is_male           boolean,
  is_female         boolean,
  group_path        text,
  exercise_name     text,
  target_muscle     text,
  synergist         text,
  difficulty_level  text,
  instruction_1     text,
  instruction_2     text,
  instruction_3     text,
  instruction_4     text,
  urls              text,
  exercise_type     text,
  equipment         text,
  id                text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    e.is_male,
    e.is_female,
    e.group_path,
    e.exercise_name,
    e.target_muscle,
    e.synergist,
    e.difficulty_level,
    e.instruction_1,
    e.instruction_2,
    e.instruction_3,
    e.instruction_4,
    e.urls,
    e.exercise_type,
    e.equipment,
    e.id
  FROM exercises e
  WHERE
    -- Muscle group filter (case-insensitive, matches both 'lats' and 'Lats')
    LOWER(e.group_path) = LOWER(p_muscle)

    -- Gender filter
    AND (p_is_male  = false OR e.is_male  = true)
    AND (p_is_female = false OR e.is_female = true)

    -- Equipment filter (NULL means no restriction)
    AND (p_equipment IS NULL OR e.equipment = ANY(p_equipment))

    -- Difficulty filter
    AND (p_difficulties IS NULL OR e.difficulty_level = ANY(p_difficulties))

    -- Workout type filter
    AND (
      p_workout_types IS NULL 
      OR EXISTS (
        SELECT 1 FROM unnest(p_workout_types) AS wt
        WHERE e.exercise_type ILIKE '%' || wt || '%'
      )
    )

    -- Free-text search across multiple columns
    AND (
      p_search IS NULL
      OR e.exercise_name   ILIKE '%' || p_search || '%'
      OR e.group_path      ILIKE '%' || p_search || '%'
      OR e.target_muscle   ILIKE '%' || p_search || '%'
      OR e.equipment       ILIKE '%' || p_search || '%'
      OR e.synergist       ILIKE '%' || p_search || '%'
      OR e.exercise_type   ILIKE '%' || p_search || '%'
    )

    -- Specific IDs filter
    AND (p_ids IS NULL OR e.id = ANY(p_ids))

  ORDER BY
    -- Custom equipment priority
    CASE e.equipment
      WHEN 'Dumbbell'          THEN 1
      WHEN 'Leverage Machine'  THEN 2
      WHEN 'Body weight'       THEN 3
      WHEN 'Barbell'           THEN 4
      WHEN 'EZ Barbell'        THEN 5
      WHEN 'Cable'             THEN 6
      ELSE                          99
    END ASC,
    -- Alphabetical within each equipment group
    e.exercise_name ASC

  LIMIT  p_limit
  OFFSET p_offset;
$$;

-- Grant access to authenticated (and anon if needed)
GRANT EXECUTE ON FUNCTION get_exercises_by_muscle(
  text, boolean, boolean,
  text[], text[], text[],
  text, text[], int, int
) TO authenticated, anon;
