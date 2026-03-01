-- ============================================================
-- generate_workout_plan.sql
-- Run this in Supabase SQL Editor.
-- ============================================================

-- 1. Create Relational Tables
CREATE TABLE IF NOT EXISTS public.user_workout_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ai_plan_id UUID NOT NULL REFERENCES public.ai_plans(id) ON DELETE CASCADE,
    day_number INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_workout_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_workout_day_id UUID NOT NULL REFERENCES public.user_workout_days(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL,
    exercise_order INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_workout_days_plan ON public.user_workout_days(ai_plan_id);
CREATE INDEX IF NOT EXISTS idx_user_workout_exercises_day ON public.user_workout_exercises(user_workout_day_id);

-- 2. Create the RPC function
CREATE OR REPLACE FUNCTION generate_user_workout_plan(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_goal            text;
  v_location        text;
  v_gender          text;
  v_training_days   int;
  v_template_key    text;
  v_ai_plan_id      uuid;
  v_day_number      int;
  v_workout_day_id  uuid;
BEGIN

  -- A. Get user plan from ai_plans using user_id
  -- Fetches the latest active plan for this user
  SELECT id INTO v_ai_plan_id
    FROM ai_plans
   WHERE user_id = p_user_id AND is_active = true
   ORDER BY created_at DESC
   LIMIT 1;

  -- If the user somehow has no plan in ai_plans, create a shell record for them
  IF v_ai_plan_id IS NULL THEN
      INSERT INTO ai_plans (user_id, is_active, plan_json, schedule_json, created_at)
      VALUES (p_user_id, true, '{}'::jsonb, '{}'::jsonb, now())
      RETURNING id INTO v_ai_plan_id;
  END IF;
  -- B. Determine: template_key, training_days, user gender from user_preferences
  SELECT goal, training_location, gender, training_days
    INTO v_goal, v_location, v_gender, v_training_days
    FROM user_preferences
   WHERE user_id = p_user_id
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'No preferences found for user');
  END IF;

  -- Normalize goal to match template_key suffixes
  IF v_goal ILIKE '%fat%' OR v_goal ILIKE '%weight%' OR v_goal ILIKE '%lose%' THEN
    v_goal := 'fat_loss';
  ELSIF v_goal ILIKE '%muscle%' OR v_goal ILIKE '%size%' OR v_goal ILIKE '%build%' THEN
    v_goal := 'build_muscle';
  ELSE
    v_goal := 'fat_loss'; -- Default fallback
  END IF;

  -- Determine template_key (with fallbacks for loose matching)
  SELECT DISTINCT template_key INTO v_template_key
    FROM program_templates
   WHERE goal_code = v_goal AND training_location = v_location AND gender = v_gender AND training_days = v_training_days
   LIMIT 1;

  IF v_template_key IS NULL THEN
    SELECT DISTINCT template_key INTO v_template_key
      FROM program_templates
     WHERE goal_code = v_goal AND training_location = v_location AND training_days = v_training_days
     LIMIT 1;
  END IF;

  IF v_template_key IS NULL THEN
    SELECT DISTINCT template_key INTO v_template_key
      FROM program_templates
     WHERE goal_code = v_goal AND training_days = v_training_days
     LIMIT 1;
  END IF;

  IF v_template_key IS NULL THEN
    SELECT DISTINCT template_key INTO v_template_key
      FROM program_templates
     WHERE training_days = v_training_days
     LIMIT 1;
  END IF;

  IF v_template_key IS NULL THEN
     RETURN jsonb_build_object('status', 'error', 'message', 'No matching template found');
  END IF;

  -- Clear any existing relational workouts for this plan to cleanly rewrite
  DELETE FROM user_workout_days WHERE ai_plan_id = v_ai_plan_id;

  -- C. For each day (1 → training_days)
  FOR v_day_number IN 1 .. v_training_days LOOP
    
    INSERT INTO user_workout_days (user_id, ai_plan_id, day_number)
    VALUES (p_user_id, v_ai_plan_id, v_day_number)
    RETURNING id INTO v_workout_day_id;

    INSERT INTO user_workout_exercises (user_workout_day_id, exercise_id, exercise_order)
    SELECT 
      v_workout_day_id,
      e.id, 
      pt.exercise_order
    FROM program_templates pt
    JOIN exercises e ON e.id = pt.exercise_id
    WHERE pt.template_key = v_template_key
      AND pt.day_index = v_day_number
      AND pt.is_rest = false
      AND pt.exercise_id IS NOT NULL
      AND (pt.gender = v_gender OR pt.gender IS NULL)
    ORDER BY pt.exercise_order;
    
  END LOOP;

  -- D. Generate schedule_json for frontend compatibility
  DECLARE
    v_total_days int;
    v_duration_weeks int;
    v_global_day int;
    v_template_day int;
    v_week_num int;
    v_day_in_week int;
    v_is_rest bool;
    v_exercise_ids text[];
    v_plan_json jsonb;
    v_weeks_json jsonb := '{}'::jsonb;
    v_days_json jsonb;
    v_week_key text;
    v_day_key text;
  BEGIN
    SELECT duration_weeks INTO v_duration_weeks FROM user_preferences WHERE user_id = p_user_id LIMIT 1;
    IF v_duration_weeks IS NULL OR v_duration_weeks < 1 THEN v_duration_weeks := 4; END IF;
    v_total_days := v_duration_weeks * 7;

    FOR v_global_day IN 1 .. v_total_days LOOP
      v_week_num   := ((v_global_day - 1) / 7) + 1;
      v_day_in_week := ((v_global_day - 1) % 7) + 1;
      v_week_key   := v_week_num::text;
      v_day_key    := v_day_in_week::text;

      -- Determine rest or workout based on pattern
      v_is_rest := true;
      v_template_day := 0;

      IF v_training_days = 3 THEN
        IF v_day_in_week = 1 THEN v_is_rest := false; v_template_day := 1;
        ELSIF v_day_in_week = 3 THEN v_is_rest := false; v_template_day := 2;
        ELSIF v_day_in_week = 5 THEN v_is_rest := false; v_template_day := 3;
        END IF;
      ELSIF v_training_days = 4 THEN
        IF v_day_in_week = 1 THEN v_is_rest := false; v_template_day := 1;
        ELSIF v_day_in_week = 2 THEN v_is_rest := false; v_template_day := 2;
        ELSIF v_day_in_week = 4 THEN v_is_rest := false; v_template_day := 3;
        ELSIF v_day_in_week = 5 THEN v_is_rest := false; v_template_day := 4;
        END IF;
      ELSIF v_training_days = 5 THEN
        IF v_day_in_week = 1 THEN v_is_rest := false; v_template_day := 1;
        ELSIF v_day_in_week = 2 THEN v_is_rest := false; v_template_day := 2;
        ELSIF v_day_in_week = 3 THEN v_is_rest := false; v_template_day := 3;
        ELSIF v_day_in_week = 5 THEN v_is_rest := false; v_template_day := 4;
        ELSIF v_day_in_week = 6 THEN v_is_rest := false; v_template_day := 5;
        END IF;
      ELSIF v_training_days = 6 THEN
        IF v_day_in_week <= 6 THEN v_is_rest := false; v_template_day := v_day_in_week; END IF;
      ELSIF v_training_days = 7 THEN
        v_is_rest := false; v_template_day := v_day_in_week;
      ELSE 
        IF v_day_in_week <= v_training_days THEN
          v_is_rest := false; v_template_day := v_day_in_week;
        END IF;
      END IF;

      IF v_is_rest THEN
        v_days_json := jsonb_build_object(v_day_key, jsonb_build_object('type', 'rest', 'exercises', '[]'::jsonb));
      ELSE
        SELECT array_agg(e.id ORDER BY pt.exercise_order)
          INTO v_exercise_ids
          FROM program_templates pt
          JOIN exercises e ON e.id = pt.exercise_id
         WHERE pt.template_key = v_template_key
           AND pt.day_index = v_template_day
           AND pt.is_rest = false
           AND pt.exercise_id IS NOT NULL
           AND (pt.gender = v_gender OR pt.gender IS NULL);

        IF v_exercise_ids IS NULL THEN v_exercise_ids := ARRAY[]::text[]; END IF;
        v_days_json := jsonb_build_object(v_day_key, jsonb_build_object('type', 'workout', 'exercises', to_jsonb(v_exercise_ids)));
      END IF;

      IF v_weeks_json ? v_week_key THEN
        v_weeks_json := jsonb_set(v_weeks_json, ARRAY[v_week_key, 'days'], (v_weeks_json -> v_week_key -> 'days') || v_days_json);
      ELSE
        v_weeks_json := v_weeks_json || jsonb_build_object(v_week_key, jsonb_build_object('days', v_days_json));
      END IF;
    END LOOP;

    v_plan_json := jsonb_build_object(
      'plan_duration_days', v_total_days,
      'weeks_count', v_duration_weeks,
      'days_per_week', v_training_days,
      'training_days', v_training_days,
      'goal', v_goal,
      'location', v_location,
      'gender', v_gender,
      'template_key', v_template_key,
      'generated_at', now()::text,
      'weeks', v_weeks_json
    );

    UPDATE ai_plans SET schedule_json = v_plan_json, plan_json = v_plan_json WHERE id = v_ai_plan_id;
  END;

  -- E. Return created plan id
  RETURN jsonb_build_object(
    'status', 'success',
    'ai_plan_id', v_ai_plan_id,
    'template_key', v_template_key
  );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION generate_user_workout_plan(uuid) TO authenticated;
