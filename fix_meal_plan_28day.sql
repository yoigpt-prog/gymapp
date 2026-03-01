-- =============================================================================
-- FIX: Meal Plan 28-Day Generation with Template Lookup
-- Deploy this file in Supabase SQL Editor
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- TASK 1: Add UNIQUE constraint on user_meal_plan (idempotent)
-- Fixes: ON CONFLICT 42P10 error
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.user_meal_plan
  ADD COLUMN IF NOT EXISTS meal_order int;

ALTER TABLE public.user_meal_plan
  DROP CONSTRAINT IF EXISTS user_meal_plan_unique;

ALTER TABLE public.user_meal_plan
  ADD CONSTRAINT user_meal_plan_unique
  UNIQUE (user_id, day_number, meal_order);

-- ─────────────────────────────────────────────────────────────────────────────
-- TASK 2 & 3: Create / Replace the RPC function
-- Function: generate_user_meal_plan(p_user_id uuid) → integer
--
-- Logic:
--   1. Read goal_type + diet_group from user_preferences
--   2. Lookup template_key from mealsplan_templates (exact match)
--   3. Fallback: any template for the same goal_type
--   4. Loop 28 days; map template_day = ((day-1) % 7) + 1
--   5. For each day pull 4 meals (breakfast/lunch/snack/dinner) from meal_templates
--   6. UPSERT into user_meal_plan ON CONFLICT (user_id, day_number, meal_order)
--   7. Return total inserted/updated row count
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop old overloaded signatures to avoid conflicts
DROP FUNCTION IF EXISTS public.generate_user_meal_plan(uuid);
DROP FUNCTION IF EXISTS public.generate_user_meal_plan(uuid, text, int, text, text[]);

CREATE OR REPLACE FUNCTION public.generate_user_meal_plan(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_goal         text;
  v_diet         text;
  v_template     text;
  v_day          int;
  v_template_day int;
  v_count        int := 0;
BEGIN

  -- ── Step 1: Fetch user preferences ─────────────────────────────────────────
  SELECT goal_type, diet_group
  INTO   v_goal, v_diet
  FROM   public.user_preferences
  WHERE  user_id = p_user_id
  LIMIT  1;

  IF v_goal IS NULL THEN
    RAISE WARNING '[MealPlan] No preferences found for user %', p_user_id;
    RETURN 0;
  END IF;

  RAISE NOTICE '[MealPlan] User % → goal=%, diet=%', p_user_id, v_goal, v_diet;

  -- ── Step 2: Exact match on goal_type + diet_group ──────────────────────────
  SELECT template_key
  INTO   v_template
  FROM   public.mealsplan_templates
  WHERE  goal_type  = v_goal
    AND  diet_group = v_diet
  LIMIT  1;

  -- ── Step 3: Fallback – any template for goal_type ──────────────────────────
  IF v_template IS NULL THEN
    RAISE WARNING '[MealPlan] No exact template for (%, %), trying goal_type fallback', v_goal, v_diet;

    SELECT template_key
    INTO   v_template
    FROM   public.mealsplan_templates
    WHERE  goal_type = v_goal
    LIMIT  1;
  END IF;

  IF v_template IS NULL THEN
    RAISE WARNING '[MealPlan] No template found at all for goal_type=%, aborting', v_goal;
    RETURN 0;
  END IF;

  RAISE NOTICE '[MealPlan] Using template_key=%', v_template;

  -- ── Step 4: Generate 28 days ────────────────────────────────────────────────
  FOR v_day IN 1..28 LOOP

    -- Map global day → template day (1-7)
    v_template_day := ((v_day - 1) % 7) + 1;

    -- ── Step 5 & 6: Insert 4 meals; UPSERT on conflict ──────────────────────
    INSERT INTO public.user_meal_plan (
      user_id,
      day_number,
      meal_order,
      meal_type,
      meal_id
    )
    SELECT
      p_user_id,
      v_day,
      CASE meal_type
        WHEN 'breakfast' THEN 1
        WHEN 'lunch'     THEN 2
        WHEN 'snack'     THEN 3
        WHEN 'dinner'    THEN 4
        ELSE                  5
      END   AS meal_order,
      meal_type,
      meal_id
    FROM public.meal_templates
    WHERE template_key = v_template
      AND day          = v_template_day
    ON CONFLICT (user_id, day_number, meal_order)
    DO UPDATE SET meal_id = EXCLUDED.meal_id;

    -- Count rows affected for this day
    GET DIAGNOSTICS v_count = ROW_COUNT;

  END LOOP;

  -- ── Step 7: Return total row count ──────────────────────────────────────────
  -- Re-count actual rows for this user to get accurate total
  SELECT COUNT(*)
  INTO   v_count
  FROM   public.user_meal_plan
  WHERE  user_id = p_user_id;

  RAISE NOTICE '[MealPlan] Done. Total rows for user %: %', p_user_id, v_count;

  RETURN v_count;

END;
$$;

-- Grant RPC access to authenticated users
GRANT EXECUTE ON FUNCTION public.generate_user_meal_plan(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFY (replace 'USER_ID' with a real UUID to test)
-- Expected: 112  (28 days × 4 meals)
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT generate_user_meal_plan('USER_ID');

SELECT 'fix_meal_plan_28day.sql deployed successfully ✓' AS status;
