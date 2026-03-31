-- =============================================================================
-- MIGRATION: Multi-Week Meal Plan Support
-- Adds week_number to user_meal_plan_meals and updates the generation RPC to
-- repeat the 7-day template for N weeks, giving each week isolated pivot rows.
-- =============================================================================

-- 1. Add week_number column to the pivot table (default 1 keeps existing data valid)
ALTER TABLE public.user_meal_plan_meals
  ADD COLUMN IF NOT EXISTS week_number INT NOT NULL DEFAULT 1;

-- 2. Add duration_weeks to user_meal_plans so we can remember the plan length
ALTER TABLE public.user_meal_plans
  ADD COLUMN IF NOT EXISTS duration_weeks INT NOT NULL DEFAULT 1;

-- Index for week-based lookups
CREATE INDEX IF NOT EXISTS idx_umpm_week_number ON public.user_meal_plan_meals(plan_id, week_number, day_number);

-- =============================================================================
-- 3. Drop & recreate generation function with duration_weeks parameter
-- =============================================================================
DROP FUNCTION IF EXISTS generate_user_meal_plan_from_template(UUID, TEXT);
DROP FUNCTION IF EXISTS generate_user_meal_plan_from_template(UUID, TEXT, INT);

CREATE OR REPLACE FUNCTION generate_user_meal_plan_from_template(
    p_user_id       UUID,
    p_template_key  TEXT,
    p_duration_weeks INT DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_plan_id       UUID;
    v_template      RECORD;
    v_b_id          UUID;
    v_l_id          UUID;
    v_s_id          UUID;
    v_d_id          UUID;
    v_inserted      INT := 0;
    v_week          INT;
BEGIN
    -- Clamp duration to a sane range
    p_duration_weeks := GREATEST(1, LEAST(p_duration_weeks, 52));

    -- 1. Upsert the user's plan header, storing the chosen duration
    INSERT INTO public.user_meal_plans (user_id, template_key, duration_weeks)
    VALUES (p_user_id, p_template_key, p_duration_weeks)
    ON CONFLICT (user_id) DO UPDATE
        SET template_key   = EXCLUDED.template_key,
            duration_weeks = EXCLUDED.duration_weeks,
            created_at     = NOW()
    RETURNING id INTO v_plan_id;

    -- 2. Wipe old pivot rows so regeneration is clean
    DELETE FROM public.user_meal_plan_meals WHERE plan_id = v_plan_id;

    -- 3. Pre-resolve meal UUIDs once from the template (they are the same every week)
    --    Then loop over weeks and insert a *new independent row* for every slot.
    FOR v_week IN 1..p_duration_weeks LOOP
        FOR v_template IN
            SELECT day_number, breakfast_meal_id, lunch_meal_id, snack_meal_id, dinner_meal_id
            FROM   public.meal_templates
            WHERE  template_key = p_template_key
            ORDER  BY day_number
        LOOP
            -- Resolve meal codes → real UUIDs
            SELECT id INTO v_b_id FROM public.meals WHERE meal_code = v_template.breakfast_meal_id LIMIT 1;
            SELECT id INTO v_l_id FROM public.meals WHERE meal_code = v_template.lunch_meal_id    LIMIT 1;
            SELECT id INTO v_s_id FROM public.meals WHERE meal_code = v_template.snack_meal_id    LIMIT 1;
            SELECT id INTO v_d_id FROM public.meals WHERE meal_code = v_template.dinner_meal_id   LIMIT 1;

            -- Insert breakfast
            IF v_b_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, week_number, day_number, meal_type)
                VALUES (v_plan_id, v_b_id, v_week, v_template.day_number, 'breakfast');
                v_inserted := v_inserted + 1;
            ELSE
                RAISE NOTICE 'Week % Day %: missing breakfast meal_code %', v_week, v_template.day_number, v_template.breakfast_meal_id;
            END IF;

            -- Insert lunch
            IF v_l_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, week_number, day_number, meal_type)
                VALUES (v_plan_id, v_l_id, v_week, v_template.day_number, 'lunch');
                v_inserted := v_inserted + 1;
            ELSE
                RAISE NOTICE 'Week % Day %: missing lunch meal_code %', v_week, v_template.day_number, v_template.lunch_meal_id;
            END IF;

            -- Insert snack
            IF v_s_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, week_number, day_number, meal_type)
                VALUES (v_plan_id, v_s_id, v_week, v_template.day_number, 'snack');
                v_inserted := v_inserted + 1;
            ELSE
                RAISE NOTICE 'Week % Day %: missing snack meal_code %', v_week, v_template.day_number, v_template.snack_meal_id;
            END IF;

            -- Insert dinner
            IF v_d_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, week_number, day_number, meal_type)
                VALUES (v_plan_id, v_d_id, v_week, v_template.day_number, 'dinner');
                v_inserted := v_inserted + 1;
            ELSE
                RAISE NOTICE 'Week % Day %: missing dinner meal_code %', v_week, v_template.day_number, v_template.dinner_meal_id;
            END IF;

        END LOOP; -- template rows
    END LOOP; -- weeks

    RAISE NOTICE 'Generated plan % for user % | % weeks | % pivot rows inserted.',
        v_plan_id, p_user_id, p_duration_weeks, v_inserted;
END;
$$;

SELECT 'MULTI-WEEK MEAL PLAN MIGRATION COMPLETE.' AS result;
