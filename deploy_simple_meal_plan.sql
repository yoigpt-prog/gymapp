-- ============================================
-- DEPLOY THIS FILE TO SUPABASE SQL EDITOR
-- ============================================
-- We use a safer delimiter ($function$) to avoid syntax errors
-- in some SQL editors.
-- ============================================

DROP FUNCTION IF EXISTS generate_simple_meal_plan(uuid);

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
AS $function$
DECLARE
    v_result jsonb;
    v_auth_id uuid;
BEGIN
    -- 1. Security Check: Ensure the caller matches the user_id (or is admin/service role)
    v_auth_id := auth.uid();
    
    -- Relaxed check: Allow if p_user_id matches auth.uid() OR if auth.uid() is null (e.g. server-side/service_role calls)
    -- But explicitly check if authenticated user tries to gen for someone else
    IF v_auth_id IS NOT NULL AND (v_auth_id <> p_user_id) THEN
        RAISE EXCEPTION 'Not authorized to generate meal plan for this user';
    END IF;

    -- 2. Validate Duration
    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'Duration weeks is required and must be >= 1';
    END IF;

    RAISE NOTICE 'Generating SIMPLE meal plan for user % (Duration: %, Goal: %, Diet: %, Allergies: %)', 
                 p_user_id, p_duration_weeks, p_goal, p_diet, p_allergies;

    -- 3. Call the main generation function with passed parameters
    v_result := force_generate_meal_plan_after_quiz(
        p_user_id,
        p_goal,
        p_duration_weeks,
        p_diet,
        p_allergies
    );

    RETURN v_result;
END;
$function$;
