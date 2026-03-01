-- FORCE MEAL PLAN GENERATION FUNCTION
-- This function is designed to be called explicitly after the quiz.
-- It strictly deletes old plans and generates a new one.

CREATE OR REPLACE FUNCTION force_generate_meal_plan_after_quiz(
    p_user_id uuid, -- Included for signature compatibility, but we use auth.uid() for security
    p_goal text,
    p_duration_weeks int,
    p_diet text,
    p_allergies text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_auth_id uuid;
    v_result jsonb;
BEGIN
    -- 1. Security Check
    v_auth_id := auth.uid();
    IF v_auth_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    -- Optional: Enforce that p_user_id matches auth.uid() if strictly needed, 
    -- but usually we just trust auth.uid().
    -- IF p_user_id IS DISTINCT FROM v_auth_id THEN ... END IF;

    -- 2. Call the core generation logic
    -- We reuse the existing powerful logic but wrapped in this "Force" entry point.
    -- This ensures we don't have duplicate logic code.
    
    RAISE NOTICE 'FORCE GENERATING meal plan for % (Fixed 4 meals)', v_auth_id;
    
    -- The core function 'generate_meal_plan_for_user' handles deletion and creation.
    -- Note: Now uses fixed 4-meal structure internally
    v_result := generate_meal_plan_for_user(
        p_goal,
        p_duration_weeks,
        p_diet,
        p_allergies
    );

    RETURN v_result;
END;
$$;
