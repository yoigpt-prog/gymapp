-- ============================================================
-- generate_multi_week_meal_plan.sql
-- Run this in Supabase SQL Editor to replace the existing
-- generate_user_meal_plan function.
-- ============================================================

CREATE OR REPLACE FUNCTION generate_user_meal_plan(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_goal           text;
  v_diet           text;
  v_duration_weeks int;
  v_total_days     int;
  v_week_index     int;
  v_template_row   record;
  v_computed_day   int;
  v_inserted_count int := 0;
  v_template_count int := 0;
BEGIN

  -- ----------------------------------------------------------------
  -- 1. Read user preferences
  -- ----------------------------------------------------------------
  SELECT goal, diet, duration_weeks
    INTO v_goal, v_diet, v_duration_weeks
    FROM user_preferences
   WHERE user_id = p_user_id
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'message', 'No user_preferences found for user',
      'user_id', p_user_id
    );
  END IF;

  -- Default duration to 4 weeks if not set
  IF v_duration_weeks IS NULL OR v_duration_weeks < 1 THEN
    v_duration_weeks := 4;
  END IF;

  v_total_days := v_duration_weeks * 7;

  RAISE NOTICE 'Generating meal plan for user %, goal=%, diet=%, duration=% weeks (% days)',
    p_user_id, v_goal, v_diet, v_duration_weeks, v_total_days;

  -- ----------------------------------------------------------------
  -- 2. Count matching template rows
  -- ----------------------------------------------------------------
  SELECT count(*)
    INTO v_template_count
    FROM meal_templates
   WHERE goal_type = v_goal
     AND diet_group = v_diet;

  IF v_template_count = 0 THEN
    -- Fallback: try matching goal only (ignore diet)
    SELECT count(*)
      INTO v_template_count
      FROM meal_templates
     WHERE goal_type = v_goal;

    IF v_template_count = 0 THEN
      RETURN jsonb_build_object(
        'status', 'error',
        'message', 'No meal templates found',
        'goal', v_goal,
        'diet', v_diet
      );
    END IF;

    RAISE NOTICE 'No templates for diet=%, falling back to goal-only match', v_diet;
    v_diet := NULL; -- Signal to query without diet filter below
  END IF;

  -- ----------------------------------------------------------------
  -- 3. Delete existing plan for this user
  -- ----------------------------------------------------------------
  DELETE FROM user_meal_plan WHERE user_id = p_user_id;

  -- ----------------------------------------------------------------
  -- 4. Generate: loop weeks × template days
  -- ----------------------------------------------------------------
  FOR v_week_index IN 0 .. (v_duration_weeks - 1) LOOP

    -- Iterate over all 7 template days for this week
    FOR v_template_row IN (
      SELECT day_number,
             breakfast_meal_id,
             lunch_meal_id,
             snack_meal_id,
             dinner_meal_id
        FROM meal_templates
       WHERE goal_type = v_goal
         AND (v_diet IS NULL OR diet_group = v_diet)
       ORDER BY day_number ASC
       LIMIT 7
    ) LOOP

      v_computed_day := (v_week_index * 7) + v_template_row.day_number;

      -- Insert breakfast
      IF v_template_row.breakfast_meal_id IS NOT NULL THEN
        INSERT INTO user_meal_plan (user_id, day, meal_type, meal_id)
        VALUES (p_user_id, v_computed_day, 'breakfast', v_template_row.breakfast_meal_id);
        v_inserted_count := v_inserted_count + 1;
      END IF;

      -- Insert lunch
      IF v_template_row.lunch_meal_id IS NOT NULL THEN
        INSERT INTO user_meal_plan (user_id, day, meal_type, meal_id)
        VALUES (p_user_id, v_computed_day, 'lunch', v_template_row.lunch_meal_id);
        v_inserted_count := v_inserted_count + 1;
      END IF;

      -- Insert snack
      IF v_template_row.snack_meal_id IS NOT NULL THEN
        INSERT INTO user_meal_plan (user_id, day, meal_type, meal_id)
        VALUES (p_user_id, v_computed_day, 'snack', v_template_row.snack_meal_id);
        v_inserted_count := v_inserted_count + 1;
      END IF;

      -- Insert dinner
      IF v_template_row.dinner_meal_id IS NOT NULL THEN
        INSERT INTO user_meal_plan (user_id, day, meal_type, meal_id)
        VALUES (p_user_id, v_computed_day, 'dinner', v_template_row.dinner_meal_id);
        v_inserted_count := v_inserted_count + 1;
      END IF;

    END LOOP; -- template rows
  END LOOP; -- weeks

  RAISE NOTICE 'Inserted % rows into user_meal_plan for user %', v_inserted_count, p_user_id;

  RETURN jsonb_build_object(
    'status',         'success',
    'user_id',        p_user_id,
    'goal',           v_goal,
    'diet',           v_diet,
    'duration_weeks', v_duration_weeks,
    'total_days',     v_total_days,
    'inserted_count', v_inserted_count
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'ERROR in generate_user_meal_plan: %', SQLERRM;
    RETURN jsonb_build_object(
      'status',  'error',
      'message', SQLERRM
    );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION generate_user_meal_plan(uuid) TO authenticated;
