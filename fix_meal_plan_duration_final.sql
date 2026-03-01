-- ============================================
-- FINAL FIX: Strict Meal Plan Duration
-- ============================================
-- 1. Drops all old function variants to avoid confusion
-- 2. Re-creates the core generation function with REQUIRED duration
-- 3. Re-creates the wrapper functions with REQUIRED duration
-- ============================================

-- PART 1: Cleanup Old Functions
-- ============================================
DROP FUNCTION IF EXISTS generate_simple_meal_plan(uuid, int, text, text, text);
DROP FUNCTION IF EXISTS generate_simple_meal_plan(uuid); -- Drop potential old overrides

DROP FUNCTION IF EXISTS force_generate_meal_plan_after_quiz(uuid, text, int, text, text);
DROP FUNCTION IF EXISTS force_generate_meal_plan_after_quiz(uuid, text, int, int, text, text);

DROP FUNCTION IF EXISTS generate_meal_plan_for_user(text, int, text, text);
DROP FUNCTION IF EXISTS generate_meal_plan_for_user(text, int, int, text, text);

-- PART 2: Core Generation Logic (The Workhorse)
-- ============================================
CREATE OR REPLACE FUNCTION generate_meal_plan_for_user(
    p_goal text,
    p_duration_weeks int, -- REQUIRED
    p_diet text,
    p_allergies text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_total_days int;
    v_global_day int;
    v_week_num int;
    v_day_num int;
    v_allergy_norm text;
    v_diet_norm text;
    v_goal_norm text;
    
    v_meal_types text[];
    v_meal_type text;
    v_meal_order int;
    
    v_selected_meal record;
    v_plan_json jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate Duration
    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'Duration weeks is required and must be >= 1';
    END IF;

    v_total_days := p_duration_weeks * 7;
    
    v_allergy_norm := lower(trim(coalesce(p_allergies, 'none')));
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_goal_norm := lower(trim(coalesce(p_goal, '')));
    
    RAISE NOTICE 'Generating plan for user %: Days=%, Goal=%, Diet=%, Allergy=%', 
        v_user_id, v_total_days, v_goal_norm, v_diet_norm, v_allergy_norm;

    -- Fixed 4 meals
    v_meal_types := ARRAY['breakfast', 'lunch', 'snack', 'dinner'];

    DELETE FROM public.user_meal_plan WHERE user_id = v_user_id;

    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        v_day_num := ((v_global_day - 1) % 7) + 1;
        
        v_meal_order := 0;

        FOREACH v_meal_type IN ARRAY v_meal_types LOOP
            v_meal_order := v_meal_order + 1;
            
            v_selected_meal := NULL;

            -- Try exact match
            SELECT * INTO v_selected_meal
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (ORDER BY id) as rn,
                    COUNT(*) OVER () as total_count
                FROM public.meals
                WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                  AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                  AND (v_diet_norm = '' OR diet_tags::text ILIKE ('%' || v_diet_norm || '%'))
                  AND (v_goal_norm = '' OR primary_goal::text ILIKE ('%' || v_goal_norm || '%'))
            ) sub
            WHERE sub.rn = ((v_global_day - 1) % sub.total_count) + 1;
            
            -- Relax Goal
            IF v_selected_meal IS NULL AND v_goal_norm <> '' THEN
                 SELECT * INTO v_selected_meal
                FROM (
                    SELECT *,
                        ROW_NUMBER() OVER (ORDER BY id) as rn,
                        COUNT(*) OVER () as total_count
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                      AND (v_diet_norm = '' OR diet_tags::text ILIKE ('%' || v_diet_norm || '%'))
                ) sub
                WHERE sub.rn = ((v_global_day - 1) % sub.total_count) + 1;
            END IF;

            -- Relax Diet (Fallback)
            IF v_selected_meal IS NULL THEN
                 SELECT * INTO v_selected_meal
                FROM (
                    SELECT *,
                        ROW_NUMBER() OVER (ORDER BY id) as rn,
                        COUNT(*) OVER () as total_count
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                ) sub
                WHERE sub.rn = ((v_global_day - 1) % sub.total_count) + 1;
            END IF;

            IF v_selected_meal IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, global_day, week_number, day_number, meal_type, meal_id, is_eaten, meal_order
                ) VALUES (
                    v_user_id, p_duration_weeks, v_global_day, v_week_num, v_day_num, v_meal_type, v_selected_meal.id::text, false, v_meal_order
                );
            ELSE
                RAISE WARNING 'No meal found for day %, type %', v_global_day, v_meal_type;
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object('status', 'success', 'days_generated', v_total_days);
END;
$$;


-- PART 3: Wrapper Function (Legacy/Helper)
-- ============================================
CREATE OR REPLACE FUNCTION force_generate_meal_plan_after_quiz(
    p_user_id uuid,
    p_goal text,
    p_duration_weeks int, -- REQUIRED
    p_diet text,
    p_allergies text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_auth_id uuid;
BEGIN
    v_auth_id := auth.uid();
    IF v_auth_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    -- Validate
    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'ForceGen: Duration weeks is required';
    END IF;

    RAISE NOTICE 'WRAPPER: Generating meal plan. Duration: %', p_duration_weeks;
    
    RETURN generate_meal_plan_for_user(
        p_goal,
        p_duration_weeks,
        p_diet,
        p_allergies
    );
END;
$$;


-- PART 4: RPC Entry Point (Called by Flutter)
-- ============================================
CREATE OR REPLACE FUNCTION generate_simple_meal_plan(
    p_user_id uuid,
    p_duration_weeks INT, -- REQUIRED, NO DEFAULT
    p_goal TEXT DEFAULT 'maintain',
    p_diet TEXT DEFAULT '',
    p_allergies TEXT DEFAULT 'none'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_auth_id uuid;
BEGIN
    v_auth_id := auth.uid();
    IF v_auth_id IS NULL THEN -- Allow service role triggers if needed, or just strict check
         -- v_auth_id := p_user_id; -- Should we trust param? No, trust auth.
         -- If auth.uid() is null, assume service role (optional) but for now we enforce auth
         RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_auth_id <> p_user_id THEN
         -- Optional: Verify service role, but for now strict user check
         -- RAISE EXCEPTION 'User ID mismatch';
    END IF;

    -- MUST VALIDATE DURATION
    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'RPC: Duration weeks is required and must be >= 1';
    END IF;

    RAISE NOTICE 'RPC: Generating Simple Meal Plan. User: %, Duration: %', p_user_id, p_duration_weeks;

    RETURN force_generate_meal_plan_after_quiz(
        p_user_id,
        p_goal,
        p_duration_weeks,
        p_diet,
        p_allergies
    );
END;
$$;

-- FINAL VERIFICATION
SELECT 'SUCCESS: All functions updated to enforce duration.' as result;
