-- =============================================================================
-- MEAL SYSTEM ARCHITECTURE FIX
-- Removes dynamic mutations from global static tables and introduces a clean
-- user-specific pivot architecture.
-- =============================================================================

-- 1. Create `user_meal_plans` table
-- This serves as the container for a user's active meal plan.
CREATE TABLE IF NOT EXISTS public.user_meal_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    template_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Enforce one active plan per user (or remove if users can have history)
    UNIQUE(user_id) 
);

-- 2. Create `user_meal_plan_meals` pivot table
-- This connects the user's plan to the global static meals.
-- If the user wants to customize a meal later, they can either link to a 
-- new custom row in `meals` or add override columns to this table.
CREATE TABLE IF NOT EXISTS public.user_meal_plan_meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES public.user_meal_plans(id) ON DELETE CASCADE,
    meal_id UUID NOT NULL REFERENCES public.meals(id) ON DELETE CASCADE,
    day_number INT NOT NULL,
    meal_type TEXT NOT NULL, -- e.g., 'breakfast', 'lunch', 'snack', 'dinner'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast lookups and joins
CREATE INDEX IF NOT EXISTS idx_ump_user_id ON public.user_meal_plans(user_id);
CREATE INDEX IF NOT EXISTS idx_umpm_plan_id ON public.user_meal_plan_meals(plan_id);
CREATE INDEX IF NOT EXISTS idx_umpm_meal_id ON public.user_meal_plan_meals(meal_id);
CREATE INDEX IF NOT EXISTS idx_umpm_day_number ON public.user_meal_plan_meals(day_number);

-- 3. Row Level Security
ALTER TABLE public.user_meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_meal_plan_meals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their own plans" ON public.user_meal_plans;
CREATE POLICY "Users manage their own plans" ON public.user_meal_plans
    FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage their plan meals" ON public.user_meal_plan_meals;
CREATE POLICY "Users manage their plan meals" ON public.user_meal_plan_meals
    FOR ALL USING (plan_id IN (SELECT id FROM public.user_meal_plans WHERE user_id = auth.uid()));

-- 4. Safe Generation Function
DROP FUNCTION IF EXISTS generate_user_meal_plan_from_template(UUID, TEXT);

CREATE OR REPLACE FUNCTION generate_user_meal_plan_from_template(
    p_user_id UUID,
    p_template_key TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_plan_id UUID;
    v_template RECORD;
    v_b_id UUID;
    v_l_id UUID;
    v_s_id UUID;
    v_d_id UUID;
    v_inserted INT := 0;
BEGIN
    -- 1. Ensure user has a plan (Upsert)
    INSERT INTO public.user_meal_plans (user_id, template_key)
    VALUES (p_user_id, p_template_key)
    ON CONFLICT (user_id) DO UPDATE 
    SET template_key = EXCLUDED.template_key, created_at = NOW()
    RETURNING id INTO v_plan_id;

    -- 2. Clear old meals for this plan to prevent duplicates
    DELETE FROM public.user_meal_plan_meals WHERE plan_id = v_plan_id;

    -- 3. Iterate over the global templates
    FOR v_template IN 
        SELECT day_number, breakfast_meal_id, lunch_meal_id, snack_meal_id, dinner_meal_id
        FROM public.meal_templates
        WHERE template_key = p_template_key
    LOOP
        -- Resolve real meal UUIDs using the string meal_codes
        SELECT id INTO v_b_id FROM public.meals WHERE meal_code = v_template.breakfast_meal_id LIMIT 1;
        SELECT id INTO v_l_id FROM public.meals WHERE meal_code = v_template.lunch_meal_id LIMIT 1;
        SELECT id INTO v_s_id FROM public.meals WHERE meal_code = v_template.snack_meal_id LIMIT 1;
        SELECT id INTO v_d_id FROM public.meals WHERE meal_code = v_template.dinner_meal_id LIMIT 1;

        -- 4. Insert Pivot Rows (safely skipping NULLs)
        IF v_b_id IS NOT NULL THEN
            INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, day_number, meal_type) 
            VALUES (v_plan_id, v_b_id, v_template.day_number, 'breakfast');
            v_inserted := v_inserted + 1;
        ELSE RAISE NOTICE 'Missing breakfast meal_code: %', v_template.breakfast_meal_id; END IF;

        IF v_l_id IS NOT NULL THEN
            INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, day_number, meal_type) 
            VALUES (v_plan_id, v_l_id, v_template.day_number, 'lunch');
            v_inserted := v_inserted + 1;
        ELSE RAISE NOTICE 'Missing lunch meal_code: %', v_template.lunch_meal_id; END IF;

        IF v_s_id IS NOT NULL THEN
            INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, day_number, meal_type) 
            VALUES (v_plan_id, v_s_id, v_template.day_number, 'snack');
            v_inserted := v_inserted + 1;
        ELSE RAISE NOTICE 'Missing snack meal_code: %', v_template.snack_meal_id; END IF;

        IF v_d_id IS NOT NULL THEN
            INSERT INTO public.user_meal_plan_meals (plan_id, meal_id, day_number, meal_type) 
            VALUES (v_plan_id, v_d_id, v_template.day_number, 'dinner');
            v_inserted := v_inserted + 1;
        ELSE RAISE NOTICE 'Missing dinner meal_code: %', v_template.dinner_meal_id; END IF;

    END LOOP;

    RAISE NOTICE 'Successfully generated plan % for user %. Inserted % pivot meals.', v_plan_id, p_user_id, v_inserted;
END;
$$;
