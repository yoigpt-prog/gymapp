-- ============================================================
-- seed_program_template_exercises.sql
-- Run this in Supabase SQL Editor.
--
-- Populates program_templates.exercise_id with REAL exercise IDs
-- from the exercises table, using modular day-index assignment.
--
-- Strategy:
--   • Picks exercises from exercises table ordered by id
--   • Assigns 6-8 exercises per workout day_index
--   • Uses DISTINCT template_key groups to cover all variants
--   • Skips rows where is_rest = true
-- ============================================================

DO $$
DECLARE
  v_template    RECORD;
  v_day         RECORD;
  v_ex_ids      text[];
  v_offset      int;
  v_count       int := 8;   -- exercises per workout day
  v_total_ex    int;
BEGIN
  -- How many exercises exist?
  SELECT COUNT(*) INTO v_total_ex FROM exercises;
  RAISE NOTICE 'Total exercises available: %', v_total_ex;

  -- Loop over every distinct template_key
  FOR v_template IN
    SELECT DISTINCT template_key, training_days
      FROM program_templates
     ORDER BY template_key
  LOOP
    RAISE NOTICE 'Seeding template_key=%', v_template.template_key;

    -- Loop over each workout day_index in this template
    FOR v_day IN
      SELECT DISTINCT day_index
        FROM program_templates
       WHERE template_key = v_template.template_key
         AND is_rest = false
       ORDER BY day_index
    LOOP
      -- Offset = (day_index - 1) * v_count, cycling through all exercises
      v_offset := ((v_day.day_index - 1) * v_count) % GREATEST(v_total_ex - v_count, 1);

      -- Pick v_count exercise IDs starting at v_offset
      SELECT array_agg(id ORDER BY id)
        INTO v_ex_ids
        FROM (
          SELECT id
            FROM exercises
           ORDER BY id
           LIMIT v_count
          OFFSET v_offset
        ) sub;

      IF v_ex_ids IS NULL OR array_length(v_ex_ids, 1) = 0 THEN
        -- Fallback: just take the first v_count exercises
        SELECT array_agg(id ORDER BY id)
          INTO v_ex_ids
          FROM (SELECT id FROM exercises ORDER BY id LIMIT v_count) sub;
      END IF;

      RAISE NOTICE '  day_index=% -> % exercises (offset=%)', 
        v_day.day_index, array_length(v_ex_ids, 1), v_offset;

      -- Update all rows in this template+day_index with round-robin exercise_id
      -- Each row in program_templates for a given (template_key, day_index) is
      -- one exercise slot. Assign exercise_ids in order.
      WITH ranked AS (
        SELECT id AS row_id,
               ROW_NUMBER() OVER (PARTITION BY template_key, day_index ORDER BY id) - 1 AS rn
          FROM program_templates
         WHERE template_key = v_template.template_key
           AND day_index    = v_day.day_index
           AND is_rest      = false
      )
      UPDATE program_templates pt
         SET exercise_id    = v_ex_ids[(r.rn % array_length(v_ex_ids, 1)) + 1],
             exercise_order = (r.rn + 1)
        FROM ranked r
       WHERE pt.id = r.row_id;

    END LOOP; -- day_index
  END LOOP; -- template_key

  RAISE NOTICE 'Done seeding exercise IDs.';
END $$;

-- ============================================================
-- VERIFICATION
-- ============================================================

-- Show a quick summary: how many workout rows have exercise_id now
SELECT
  template_key,
  training_days,
  day_index,
  COUNT(*)          AS total_rows,
  COUNT(exercise_id) AS rows_with_exercise_id,
  MIN(exercise_id)  AS first_id,
  MAX(exercise_id)  AS last_id
FROM program_templates
WHERE is_rest = false
GROUP BY template_key, training_days, day_index
ORDER BY template_key, day_index
LIMIT 40;
