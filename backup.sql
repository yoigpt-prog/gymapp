


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."delete_current_user"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- We use auth.uid() to ensure the user can only delete themselves.
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete the user from auth.users
  -- (Assuming foreign keys in public schema have ON DELETE CASCADE. If not, we might need to delete them explicitly here)
  DELETE FROM auth.users WHERE id = auth.uid();

END;
$$;


ALTER FUNCTION "public"."delete_current_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- clear old plan if any
  delete from public.user_meal_plan
  where user_id = p_user_id;

  -- generate 7 days × 4 meals
  for d in 1..7 loop
    insert into public.user_meal_plan (
      user_id,
      day_number,
      meal_order,
      meal_type,
      meal_id
    )
    select
      p_user_id,
      d,
      row_number() over (),
      m.meal_type,
      m.id
    from public.meals m
    where (m.goal is null or m.goal = p_goal)
      and (m.diet is null or m.diet = p_diet)
    order by random()
    limit 4;
  end loop;
end;
$$;


ALTER FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN generate_meal_plan_for_user(p_goal, p_duration_weeks, p_diet, p_allergies);
END;
$$;


ALTER FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_meal_plan_for_user"("p_duration_weeks" integer DEFAULT 4) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- get authenticated user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- remove old plan
  DELETE FROM public.user_meal_plan
  WHERE user_id = v_user_id;

  -- insert meals
  INSERT INTO public.user_meal_plan (
    user_id,
    duration_weeks,
    global_day,
    week_number,
    day_number,
    meal_type,
    meal_id,
    calories
  )
  SELECT
    v_user_id,
    p_duration_weeks,
    ((w - 1) * 7) + d,
    w,
    d,
    m.meal_type,
    m.id,
    COALESCE(m.calories, 0)
  FROM generate_series(1, p_duration_weeks) w
  CROSS JOIN generate_series(1, 7) d
  JOIN public.meals m
    ON m.meal_type IN ('breakfast', 'lunch', 'dinner');
END;
$$;


ALTER FUNCTION "public"."generate_meal_plan_for_user"("p_duration_weeks" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  DELETE FROM public.user_meal_plan
  WHERE user_id = p_user_id;

  INSERT INTO public.user_meal_plan (
    user_id,
    duration_weeks,
    plan_week,
    plan_day,          -- ✅ FIX
    global_day,
    week_number,
    day_number,
    meal_type,
    meal_slot_order,
    meal_id,
    calories
  )
  SELECT
    p_user_id,
    p_duration_weeks,
    w AS plan_week,
    d AS plan_day,                              -- ✅ FIX
    ((w - 1) * 7 + d) AS global_day,
    w AS week_number,
    d AS day_number,
    m.meal_type,
    CASE m.meal_type
      WHEN 'breakfast' THEN 1
      WHEN 'snack'     THEN 2
      WHEN 'lunch'     THEN 3
      WHEN 'dinner'    THEN 4
    END AS meal_slot_order,
    m.id,
    COALESCE(m.calories, 0)
  FROM generate_series(1, p_duration_weeks) w
  CROSS JOIN generate_series(1, 7) d
  JOIN public.meals m
    ON m.meal_type IN ('breakfast','snack','lunch','dinner');
END;
$$;


ALTER FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer, "p_target_calories" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- 🔥 Always reset old plan
  DELETE FROM public.user_meal_plan
  WHERE user_id = p_user_id;

  INSERT INTO public.user_meal_plan (
    user_id,
    duration_weeks,
    plan_week,
    plan_day,
    global_day,
    week_number,
    day_number,
    meal_type,
    meal_slot_order,
    meal_id,
    calories,
    target_calories
  )
  SELECT
    p_user_id,
    p_duration_weeks,
    w,
    d,
    ((w - 1) * 7 + d),
    w,
    d,
    m.meal_type,
    CASE m.meal_type
      WHEN 'breakfast' THEN 1
      WHEN 'snack' THEN 2
      WHEN 'lunch' THEN 3
      WHEN 'dinner' THEN 4
    END,
    m.id,
    COALESCE(m.calories, 0),
    p_target_calories
  FROM generate_series(1, p_duration_weeks) w
  CROSS JOIN generate_series(1, 7) d
  JOIN public.meals m
    ON m.meal_type IN ('breakfast','snack','lunch','dinner');

END;
$$;


ALTER FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer, "p_target_calories" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_meal_plan_for_user"("p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid;
    v_total_days int;
    v_global_day int;
    v_week_num int;
    v_day_num int;
    
    -- Normalized inputs
    v_allergy_norm text;
    v_diet_norm text;
    v_goal_norm text;
    
    -- Template variables
    v_template_key text;
    v_templates_found int := 0;
    v_template_row record;
    
    -- Loop / Resolve variables
    v_real_meal record;
    v_meals_resolved int := 0;
    v_inserted_count int := 0;
    v_meal_order int;
    
    -- Results
    v_plan_json jsonb;
BEGIN
    -- [Auth Check]
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'Duration weeks must be >= 1';
    END IF;

    v_total_days := p_duration_weeks * 7;

    -------------------------------------------------------------------
    -- STEP 1: Detect Template Key
    -------------------------------------------------------------------
    v_allergy_norm := lower(trim(coalesce(p_allergies, 'none')));
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_goal_norm := lower(trim(coalesce(p_goal, '')));

    -- Map User Goal
    IF v_goal_norm = 'build_muscle' THEN
        v_goal_norm := 'muscle_gain';
    ELSIF v_goal_norm = 'fat_loss' THEN
        v_goal_norm := 'weight_loss';
    ELSIF v_goal_norm IN ('', 'maintain') THEN
        v_goal_norm := 'weight_loss'; -- Defaulting
    END IF;

    -- Map User Diet
    IF v_diet_norm IN ('', 'no_preference', 'none', 'any') THEN
        v_diet_norm := 'balanced';
    ELSIF v_diet_norm IN ('vegetarian', 'vegan') THEN
        v_diet_norm := 'plant_based';
    END IF;

    -- Construct the Template Key
    v_template_key := v_goal_norm || '_' || v_diet_norm;

    -------------------------------------------------------------------
    -- DEBUG LOGS: Template Detection
    -------------------------------------------------------------------
    RAISE NOTICE '[MealPlan] Template key detected: %', v_template_key;

    -------------------------------------------------------------------
    -- STEP 2: Get Template Meals
    -------------------------------------------------------------------
    SELECT COUNT(*) INTO v_templates_found 
    FROM public.meal_templates 
    WHERE template_key = v_template_key;
    
    RAISE NOTICE '[MealPlan] Templates found: % rows', v_templates_found;

    -- Fallback strategy if template not found
    IF v_templates_found = 0 THEN
        RAISE WARNING '[MealPlan] No template found for %, using fallback', v_template_key;
        v_template_key := 'muscle_gain_balanced';
        SELECT COUNT(*) INTO v_templates_found 
        FROM public.meal_templates 
        WHERE template_key = v_template_key;
        
        -- If still 0, we can't generate
        IF v_templates_found = 0 THEN
            RAISE EXCEPTION 'Critical: Even fallback template % is missing!', v_template_key;
        END IF;
    END IF;

    -------------------------------------------------------------------
    -- PREPARE: Plan replacement
    -------------------------------------------------------------------
    DELETE FROM public.user_meal_plan WHERE user_id = v_user_id;

    -------------------------------------------------------------------
    -- STEP 3 & 4: Resolve Real Meals and Insert User Meal Plan
    -------------------------------------------------------------------
    -- Generate for full program duration (ex: 4 weeks)
    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        
        -- Repeat template days (1-7)
        v_day_num := ((v_global_day - 1) % 7) + 1; 

        -- For each template row in this day
        FOR v_template_row IN 
            SELECT * 
            FROM public.meal_templates 
            WHERE template_key = v_template_key 
              AND day = v_day_num
            ORDER BY 
              CASE meal_type 
                WHEN 'breakfast' THEN 1 
                WHEN 'lunch' THEN 2 
                WHEN 'snack' THEN 3 
                WHEN 'dinner' THEN 4 
                ELSE 5 
              END
        LOOP
            -- Check meal validity in `meals` table
            SELECT * INTO v_real_meal 
            FROM public.meals 
            WHERE id = v_template_row.meal_id::uuid;
            
            IF FOUND THEN
                -- Validate allergies (Exclude if meal contains allergy)
                IF v_allergy_norm <> 'none' AND v_real_meal.allergens ILIKE '%' || v_allergy_norm || '%' THEN
                    RAISE WARNING '[MealPlan] Meal % contains allergy %, skipping', v_real_meal.id, v_allergy_norm;
                    CONTINUE;
                END IF;
                
                -- Meal is valid
                v_meals_resolved := v_meals_resolved + 1;
                
                -- Determine order
                IF v_template_row.meal_type = 'breakfast' THEN v_meal_order := 1;
                ELSIF v_template_row.meal_type = 'lunch' THEN v_meal_order := 2;
                ELSIF v_template_row.meal_type = 'snack' THEN v_meal_order := 3;
                ELSIF v_template_row.meal_type = 'dinner' THEN v_meal_order := 4;
                ELSE v_meal_order := 5; END IF;

                -- Insert into user_meal_plan
                -- Do NOT insert duplicates (ON CONFLICT DO NOTHING)
                BEGIN
                    INSERT INTO public.user_meal_plan (
                        user_id,
                        duration_weeks,
                        global_day,
                        week_number,
                        day_number,
                        meal_type,
                        meal_id,
                        template_key,
                        is_eaten,
                        meal_order
                    ) VALUES (
                        v_user_id,
                        p_duration_weeks,
                        v_global_day,
                        v_week_num,
                        v_day_num,
                        v_template_row.meal_type,
                        v_template_row.meal_id::text,
                        v_template_key,
                        false,
                        v_meal_order
                    )
                    ON CONFLICT (user_id, week_number, day_number, meal_type) DO NOTHING;
                    
                    IF FOUND THEN
                        v_inserted_count := v_inserted_count + 1;
                    END IF;
                END;
            ELSE
                -- Meal missing
                RAISE WARNING '[MealPlan] Meal missing: %', v_template_row.meal_id;
            END IF;
        END LOOP;
    END LOOP;

    RAISE NOTICE '[MealPlan] Meals resolved: %', v_meals_resolved;
    RAISE NOTICE '[MealPlan] Plan inserted successfully';
    
    -------------------------------------------------------------------
    -- RETURN JSON (Required by frontend RPC)
    -------------------------------------------------------------------
    RETURN jsonb_build_object(
        'status', 'success',
        'inserted_count', v_inserted_count,
        'template_key', v_template_key,
        'meals_resolved', v_meals_resolved
    );
END;
$$;


ALTER FUNCTION "public"."generate_meal_plan_for_user"("p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_total_days int;
    v_global_day int;
    v_week_num int;
    v_day_num int;
    
    -- Normalized inputs
    v_allergy_norm text;
    v_diet_norm text;
    v_goal_norm text;
    
    -- Template variables
    v_template_key text;
    v_templates_found int := 0;
    v_template_row record;
    
    -- Loop / Resolve variables
    v_real_meal record;
    v_meals_resolved int := 0;
    v_inserted_count int := 0;
    v_meal_order int;
    v_allergy_check text;
    
    -- Results
    v_plan_json jsonb;
BEGIN
    -- [Validate Inputs]
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id cannot be null';
        RETURN jsonb_build_object('status', 'error', 'message', 'Missing user ID');
    END IF;

    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        p_duration_weeks := 4; -- Default
    END IF;

    v_total_days := p_duration_weeks * 7;

    -------------------------------------------------------------------
    -- STEP 1: Detect Template Key
    -------------------------------------------------------------------
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_goal_norm := lower(trim(coalesce(p_goal, '')));

    -- Map User Goal
    IF v_goal_norm = 'build_muscle' THEN
        v_goal_norm := 'muscle_gain';
    ELSIF v_goal_norm = 'fat_loss' THEN
        v_goal_norm := 'weight_loss';
    ELSIF v_goal_norm IN ('', 'maintain') THEN
        v_goal_norm := 'weight_loss'; -- Defaulting
    END IF;

    -- Map User Diet
    IF v_diet_norm IN ('', 'no_preference', 'none', 'any') THEN
        v_diet_norm := 'balanced';
    ELSIF v_diet_norm IN ('vegetarian', 'vegan') THEN
        v_diet_norm := 'plant_based';
    END IF;

    -- Construct the Template Key
    v_template_key := v_goal_norm || '_' || v_diet_norm;

    -------------------------------------------------------------------
    -- DEBUG LOGS: Template Detection
    -------------------------------------------------------------------
    RAISE NOTICE '[MealPlan] Template key detected: %', v_template_key;

    -------------------------------------------------------------------
    -- STEP 2: Get Template Meals
    -------------------------------------------------------------------
    SELECT COUNT(*) INTO v_templates_found 
    FROM public.meal_templates 
    WHERE template_key = v_template_key;
    
    RAISE NOTICE '[MealPlan] Templates found: % rows', v_templates_found;

    -- Fallback strategy if template not found
    IF v_templates_found = 0 THEN
        RAISE WARNING '[MealPlan] No template found for %, using fallback', v_template_key;
        v_template_key := 'muscle_gain_balanced';
        SELECT COUNT(*) INTO v_templates_found 
        FROM public.meal_templates 
        WHERE template_key = v_template_key;
        
        -- If still 0, we can't generate
        IF v_templates_found = 0 THEN
            RAISE EXCEPTION 'Critical: Even fallback template % is missing!', v_template_key;
            RETURN jsonb_build_object('status', 'error', 'message', 'No meal templates found');
        END IF;
    END IF;

    -------------------------------------------------------------------
    -- PREPARE: Plan replacement
    -------------------------------------------------------------------
    DELETE FROM public.user_meal_plan WHERE user_id = p_user_id;

    -------------------------------------------------------------------
    -- STEP 3 & 4: Resolve Real Meals and Insert User Meal Plan
    -------------------------------------------------------------------
    -- Generate for full program duration (ex: 4 weeks)
    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        
        -- Repeat template days (1-7)
        v_day_num := ((v_global_day - 1) % 7) + 1; 

        -- For each template row in this day
        FOR v_template_row IN 
            SELECT * 
            FROM public.meal_templates 
            WHERE template_key = v_template_key 
              AND day = v_day_num
            ORDER BY 
              CASE meal_type 
                WHEN 'breakfast' THEN 1 
                WHEN 'lunch' THEN 2 
                WHEN 'snack' THEN 3 
                WHEN 'dinner' THEN 4 
                ELSE 5 
              END
        LOOP
            -- Check meal validity in `meals` table
            SELECT * INTO v_real_meal 
            FROM public.meals 
            WHERE id = v_template_row.meal_id::uuid;
            
            IF FOUND THEN
                -- Validate allergies checking against array
                IF p_allergies IS NOT NULL AND array_length(p_allergies, 1) > 0 THEN
                    DECLARE
                        v_skip_meal boolean := false;
                    BEGIN
                        FOREACH v_allergy_check IN ARRAY p_allergies LOOP
                            IF v_allergy_check <> 'none' AND v_real_meal.allergens ILIKE '%' || v_allergy_check || '%' THEN
                                RAISE WARNING '[MealPlan] Meal % contains allergy %, skipping', v_real_meal.id, v_allergy_check;
                                v_skip_meal := true;
                                EXIT;
                            END IF;
                        END LOOP;
                        
                        IF v_skip_meal THEN
                             CONTINUE;
                        END IF;
                    END;
                END IF;
                
                -- Meal is valid
                v_meals_resolved := v_meals_resolved + 1;
                
                -- Determine order
                IF v_template_row.meal_type = 'breakfast' THEN v_meal_order := 1;
                ELSIF v_template_row.meal_type = 'lunch' THEN v_meal_order := 2;
                ELSIF v_template_row.meal_type = 'snack' THEN v_meal_order := 3;
                ELSIF v_template_row.meal_type = 'dinner' THEN v_meal_order := 4;
                ELSE v_meal_order := 5; END IF;

                -- Insert into user_meal_plan
                -- Do NOT insert duplicates (ON CONFLICT DO NOTHING)
                BEGIN
                    INSERT INTO public.user_meal_plan (
                        user_id,
                        duration_weeks,
                        global_day,
                        week_number,
                        day_number,
                        meal_type,
                        meal_id,
                        template_key,
                        is_eaten,
                        meal_order
                    ) VALUES (
                        p_user_id,
                        p_duration_weeks,
                        v_global_day,
                        v_week_num,
                        v_day_num,
                        v_template_row.meal_type,
                        v_template_row.meal_id::text,
                        v_template_key,
                        false,
                        v_meal_order
                    )
                    ON CONFLICT (user_id, week_number, day_number, meal_type) DO NOTHING;
                    
                    IF FOUND THEN
                        v_inserted_count := v_inserted_count + 1;
                    END IF;
                END;
            ELSE
                -- Meal missing
                RAISE WARNING '[MealPlan] Meal missing: %', v_template_row.meal_id;
            END IF;
        END LOOP;
    END LOOP;

    RAISE NOTICE '[MealPlan] Meals resolved: %', v_meals_resolved;
    RAISE NOTICE '[MealPlan] Rows inserted: %', v_inserted_count;
    
    -------------------------------------------------------------------
    -- RETURN JSON (Required by frontend RPC)
    -------------------------------------------------------------------
    RETURN jsonb_build_object(
        'status', 'success',
        'inserted_count', v_inserted_count,
        'template_key', v_template_key,
        'meals_resolved', v_meals_resolved
    );
END;
$$;


ALTER FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_duration_weeks" integer, "p_meals_per_day" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- 1. Clear old plan for this user
  delete from public.user_meal_plan
  where user_id = p_user_id;

  -- 2. Generate deterministic meal plan (INCLUDING SNACK)
  insert into public.user_meal_plan (
    user_id,
    day_number,
    meal_order,
    meal_type,
    meal_id
  )
  select
    p_user_id,
    d.day_number,
    s.meal_order,
    s.meal_type,
    m.id
  from generate_series(1, p_duration_weeks * 7) as d(day_number)
  join (
    select 1 as meal_order, 'breakfast' as meal_type
    union all
    select 2, 'snack'
    union all
    select 3, 'lunch'
    union all
    select 4, 'dinner'
  ) s
    on s.meal_order <= p_meals_per_day
  join public.meals m
    on m.meal_type = s.meal_type
   and m.goal = p_goal
   and (p_diet = 'no_preference' or m.diet = p_diet)
  order by
    d.day_number,
    s.meal_order,
    m.calories desc;

end;
$$;


ALTER FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_duration_weeks" integer, "p_meals_per_day" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_macro" "text", "p_allergies" "text"[], "p_days" integer, "p_meals_per_day" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  if exists (
    select 1 from user_meal_plan where user_id = p_user_id
  ) then
    return;
  end if;

  insert into user_meal_plan (
    user_id,
    global_day,
    day_number,
    week_number,
    duration_weeks,
    meal_order,
    meal_type,
    meal_id
  )
  select
    p_user_id,
    d.day,
    d.day,
    ((d.day - 1) / 7) + 1,
    ceil(p_days / 7.0),
    m,
    meal.meal_type,
    meal.id
  from generate_series(1, p_days) d
  cross join generate_series(1, p_meals_per_day) m
  join lateral (
    select *
    from meals
    where
      (p_goal is null or goal_tags is null or goal_tags::jsonb ? p_goal)
      and (p_macro is null or p_macro = 'balanced' or macro_profile = p_macro)
      and (p_diet is null or p_diet = 'no_preference' or diet_tags::jsonb ? p_diet)
    order by random()
    limit 1
  ) meal on true;
end;
$$;


ALTER FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_macro" "text", "p_allergies" "text"[], "p_days" integer, "p_meals_per_day" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_simple_meal_plan"("p_user_id" "uuid", "p_duration_weeks" integer, "p_goal" "text" DEFAULT 'maintain'::"text", "p_diet" "text" DEFAULT ''::"text", "p_allergies" "text" DEFAULT 'none'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN generate_meal_plan_for_user(p_goal, p_duration_weeks, p_diet, p_allergies);
END;
$$;


ALTER FUNCTION "public"."generate_simple_meal_plan"("p_user_id" "uuid", "p_duration_weeks" integer, "p_goal" "text", "p_diet" "text", "p_allergies" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_user_meal_plan"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."generate_user_meal_plan"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_day int;
  v_meal_type text;
  v_meal record;
  v_meal_types text[] := ARRAY['breakfast','lunch','snack','dinner'];
  v_meal_order int;
begin
  -- clear old plan
  delete from public.user_meal_plan
  where user_id = p_user_id;

  for v_day in 1..7 loop
    v_meal_order := 1;

    foreach v_meal_type in array v_meal_types loop

      select *
      into v_meal
      from public.meals
      where meal_type = v_meal_type
      order by random()
      limit 1;

      if v_meal.id is not null then
        insert into public.user_meal_plan (
          user_id,
          day_number,
          meal_type,
          meal_order,
          meal_id
        ) values (
          p_user_id,
          v_day,
          v_meal_type,
          v_meal_order,
          v_meal.id
        );

        v_meal_order := v_meal_order + 1;
      end if;

    end loop;
  end loop;
end;
$$;


ALTER FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_day int;
  v_meal_type text;
  v_meal record;
  v_meal_types text[] := ARRAY['breakfast','lunch','snack','dinner'];
begin
  -- clean old plan
  delete from public.user_meal_plan
  where user_id = p_user_id;

  for v_day in 1..7 loop
    foreach v_meal_type in array v_meal_types loop

      select *
      into v_meal
      from public.meals
      where
        meal_type = v_meal_type
        and (goal is null or goal = p_goal)
        and (diet is null or diet = p_diet)
      order by id
      limit 1;

      if v_meal.id is not null then
        insert into public.user_meal_plan (
          user_id,
          day_number,
          meal_type,
          meal_id
        ) values (
          p_user_id,
          v_day,
          v_meal_type,
          v_meal.id
        );
      end if;

    end loop;
  end loop;
end;
$$;


ALTER FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_user_workout_plan"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."generate_user_workout_plan"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_exercises_by_muscle"("p_muscle" "text", "p_is_male" boolean, "p_is_female" boolean, "p_equipment" "text"[] DEFAULT NULL::"text"[], "p_difficulties" "text"[] DEFAULT NULL::"text"[], "p_workout_types" "text"[] DEFAULT NULL::"text"[], "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("is_male" boolean, "is_female" boolean, "group_path" "text", "exercise_name" "text", "target_muscle" "text", "synergist" "text", "difficulty_level" "text", "instruction_1" "text", "instruction_2" "text", "instruction_3" "text", "instruction_4" "text", "urls" "text", "exercise_type" "text", "equipment" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
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
    e.equipment
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
    AND (p_workout_types IS NULL OR e.exercise_type = ANY(p_workout_types))

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


ALTER FUNCTION "public"."get_exercises_by_muscle"("p_muscle" "text", "p_is_male" boolean, "p_is_female" boolean, "p_equipment" "text"[], "p_difficulties" "text"[], "p_workout_types" "text"[], "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_meal_slot_order"("p_meal_type" "text") RETURNS integer
    LANGUAGE "sql" IMMUTABLE
    AS $$
SELECT CASE p_meal_type
    WHEN 'breakfast'       THEN 1
    WHEN 'morning_snack'   THEN 2
    WHEN 'lunch'           THEN 3
    WHEN 'evening_snack'   THEN 4
    WHEN 'dinner'          THEN 5
END;
$$;


ALTER FUNCTION "public"."get_meal_slot_order"("p_meal_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_generate_meal_plan"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  perform generate_user_meal_plan(new.user_id);
  return new;
end;
$$;


ALTER FUNCTION "public"."trigger_generate_meal_plan"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_generate_meal_plan_after_quiz"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Only generate on NEW insert or if preferences changed
    v_result := generate_user_meal_plan(NEW.user_id);
    RAISE NOTICE '[MealPlan] Trigger result for user %: %', NEW.user_id, v_result;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_generate_meal_plan_after_quiz"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."ai_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "plan_duration_days" integer DEFAULT 28 NOT NULL,
    "training_days" integer DEFAULT 3 NOT NULL,
    "meals_per_day" integer DEFAULT 3 NOT NULL,
    "goal_code" "text",
    "training_location" "text",
    "gender" "text",
    "plan_json" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "schedule_json" "jsonb",
    "template_key" "text",
    "slug_used" "text",
    "days_per_week" integer
);


ALTER TABLE "public"."ai_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."contact_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text",
    "email" "text",
    "subject" "text",
    "message" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."contact_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."exercises" (
    "id" "text",
    "exercise_name" "text",
    "urls" "text",
    "is_male" boolean,
    "is_female" boolean,
    "group_path" "text",
    "exercise_type" "text",
    "equipment" "text",
    "body_part" "text",
    "target_muscle" "text",
    "synergist" "text",
    "parent_muscle" "text",
    "instruction_1" "text",
    "instruction_2" "text",
    "instruction_3" "text",
    "instruction_4" "text",
    "param_sets" "text",
    "param_reps" "text",
    "param_work_time" "text",
    "param_rest" "text",
    "param_calories" "text",
    "difficulty_level" "text",
    "location" "text",
    "contraindications" "text",
    "fitness_goals" "text",
    "exercise_pk" bigint NOT NULL
);


ALTER TABLE "public"."exercises" OWNER TO "postgres";


ALTER TABLE "public"."exercises" ALTER COLUMN "exercise_pk" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."exercises_exercise_pk_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."meal_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid",
    "meal_id" "uuid" NOT NULL,
    "day_index" integer NOT NULL,
    "meal_name" "text" NOT NULL,
    "calories" integer DEFAULT 0,
    "protein" integer DEFAULT 0,
    "carbs" integer DEFAULT 0,
    "fat" integer DEFAULT 0,
    "ingredients" "jsonb",
    "eaten_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."meal_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meal_templates" (
    "id" bigint NOT NULL,
    "template_key" "text" NOT NULL,
    "template_name" "text",
    "goal_type" "text",
    "diet_group" "text",
    "day_number" integer NOT NULL,
    "breakfast_meal_id" "text",
    "lunch_meal_id" "text",
    "snack_meal_id" "text",
    "dinner_meal_id" "text"
);


ALTER TABLE "public"."meal_templates" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."meal_templates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."meal_templates_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."meal_templates_id_seq" OWNED BY "public"."meal_templates"."id";



CREATE TABLE IF NOT EXISTS "public"."meals" (
    "id" "text" NOT NULL,
    "name" "text",
    "meal_type" "text",
    "calories" numeric,
    "protein_g" numeric,
    "carbs_g" numeric,
    "fat_g" numeric,
    "goal_tags" "jsonb",
    "diet_tags" "jsonb",
    "image_key" "text",
    "image_url" "text",
    "base_id" "text",
    "macro_profile" "text",
    "ingredients_json" "jsonb",
    "namevariations" "jsonb",
    "fiber_g" numeric,
    "sugar_g" numeric,
    "net_carbs_g" numeric,
    "protein_ratio" numeric,
    "fat_ratio" numeric,
    "carb_ratio" numeric,
    "protein_per_100kcal" numeric,
    "contains_gluten" boolean,
    "contains_dairy" boolean,
    "contains_eggs" boolean,
    "contains_nuts" boolean,
    "contains_fish" boolean,
    "contains_shellfish" boolean,
    "is_vegan" boolean,
    "is_vegetarian" boolean,
    "is_gluten_free" boolean,
    "is_pescatarian" boolean,
    "is_mediterranean" boolean,
    "is_low_carb" boolean,
    "is_keto" boolean,
    "is_male" boolean DEFAULT true,
    "is_female" boolean DEFAULT true,
    "variant_tag" "text",
    "primary_goal" "text" NOT NULL,
    "allergens" "jsonb" DEFAULT '[]'::"jsonb",
    "prep_time_min" integer,
    "difficulty" "text",
    "contains_soy" boolean DEFAULT false
);

ALTER TABLE ONLY "public"."meals" REPLICA IDENTITY FULL;


ALTER TABLE "public"."meals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."program_templates" (
    "id" bigint NOT NULL,
    "template_key" "text" NOT NULL,
    "goal_code" "text" NOT NULL,
    "training_location" "text",
    "training_days" integer,
    "day_index" integer,
    "is_rest" boolean,
    "gender" "text",
    "exercise_id" "text",
    "exercise_order" integer
);


ALTER TABLE "public"."program_templates" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."program_templates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."program_templates_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."program_templates_id_seq" OWNED BY "public"."program_templates"."id";



CREATE TABLE IF NOT EXISTS "public"."user_favorites" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "exercise_name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."user_favorites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_meal_plan" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "day" integer NOT NULL,
    "meal_type" "text" NOT NULL,
    "meal_id" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "is_eaten" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."user_meal_plan" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."user_meal_plan_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."user_meal_plan_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."user_meal_plan_id_seq" OWNED BY "public"."user_meal_plan"."id";



CREATE TABLE IF NOT EXISTS "public"."user_preferences" (
    "user_id" "uuid" NOT NULL,
    "goal" "text",
    "diet" "text",
    "allergies" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "duration_weeks" integer,
    "gender" "text" DEFAULT 'male'::"text",
    "training_location" "text" DEFAULT 'gym'::"text",
    "training_days" integer DEFAULT 4,
    "height_cm" numeric,
    "weight_kg" numeric,
    "age" integer
);


ALTER TABLE "public"."user_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_weekly_weights" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "week_number" integer NOT NULL,
    "weight_kg" numeric(6,2) NOT NULL,
    "logged_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_weekly_weights_week_number_check" CHECK (("week_number" >= 1))
);


ALTER TABLE "public"."user_weekly_weights" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_workout_days" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "ai_plan_id" "uuid" NOT NULL,
    "day_number" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_workout_days" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_workout_exercises" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_workout_day_id" "uuid" NOT NULL,
    "exercise_id" "text" NOT NULL,
    "exercise_order" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_workout_exercises" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_workout_progress" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date" "date" NOT NULL,
    "completed_exercises" "text"[] DEFAULT '{}'::"text"[],
    "is_completed_day" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."user_workout_progress" OWNER TO "postgres";


ALTER TABLE ONLY "public"."meal_templates" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."meal_templates_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."program_templates" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."program_templates_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."user_meal_plan" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."user_meal_plan_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."ai_plans"
    ADD CONSTRAINT "ai_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."contact_messages"
    ADD CONSTRAINT "contact_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."exercises"
    ADD CONSTRAINT "exercises_pk" PRIMARY KEY ("exercise_pk");



ALTER TABLE ONLY "public"."meal_logs"
    ADD CONSTRAINT "meal_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meal_logs"
    ADD CONSTRAINT "meal_logs_user_id_meal_id_day_index_key" UNIQUE ("user_id", "meal_id", "day_index");



ALTER TABLE ONLY "public"."meal_templates"
    ADD CONSTRAINT "meal_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."program_templates"
    ADD CONSTRAINT "program_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_favorites"
    ADD CONSTRAINT "user_favorites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_favorites"
    ADD CONSTRAINT "user_favorites_user_id_exercise_name_key" UNIQUE ("user_id", "exercise_name");



ALTER TABLE ONLY "public"."user_meal_plan"
    ADD CONSTRAINT "user_meal_plan_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_preferences"
    ADD CONSTRAINT "user_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_weekly_weights"
    ADD CONSTRAINT "user_weekly_weights_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_weekly_weights"
    ADD CONSTRAINT "user_weekly_weights_user_id_week_number_key" UNIQUE ("user_id", "week_number");



ALTER TABLE ONLY "public"."user_workout_days"
    ADD CONSTRAINT "user_workout_days_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_workout_exercises"
    ADD CONSTRAINT "user_workout_exercises_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_workout_progress"
    ADD CONSTRAINT "user_workout_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_workout_progress"
    ADD CONSTRAINT "user_workout_progress_user_id_date_key" UNIQUE ("user_id", "date");



CREATE INDEX "idx_ai_plans_active" ON "public"."ai_plans" USING "btree" ("user_id", "is_active");



CREATE INDEX "idx_ai_plans_user_active" ON "public"."ai_plans" USING "btree" ("user_id", "is_active");



CREATE INDEX "idx_ai_plans_user_id" ON "public"."ai_plans" USING "btree" ("user_id");



CREATE INDEX "idx_meal_logs_user_day" ON "public"."meal_logs" USING "btree" ("user_id", "day_index");



CREATE INDEX "idx_meals_calories" ON "public"."meals" USING "btree" ("calories");



CREATE INDEX "idx_meals_dairy" ON "public"."meals" USING "btree" ("contains_dairy");



CREATE INDEX "idx_meals_filters" ON "public"."meals" USING "btree" ("meal_type", "primary_goal", "is_vegan", "is_gluten_free");



CREATE INDEX "idx_meals_gluten" ON "public"."meals" USING "btree" ("contains_gluten");



CREATE INDEX "idx_meals_glutenfree" ON "public"."meals" USING "btree" ("is_gluten_free");



CREATE INDEX "idx_meals_goal" ON "public"."meals" USING "btree" ("primary_goal");



CREATE INDEX "idx_meals_keto" ON "public"."meals" USING "btree" ("is_keto");



CREATE INDEX "idx_meals_low_carb" ON "public"."meals" USING "btree" ("is_low_carb");



CREATE INDEX "idx_meals_lowcarb" ON "public"."meals" USING "btree" ("is_low_carb");



CREATE INDEX "idx_meals_meal_type" ON "public"."meals" USING "btree" ("meal_type");



CREATE INDEX "idx_meals_veg" ON "public"."meals" USING "btree" ("is_vegetarian");



CREATE INDEX "idx_meals_vegan" ON "public"."meals" USING "btree" ("is_vegan");



CREATE INDEX "idx_user_workout_days_plan" ON "public"."user_workout_days" USING "btree" ("ai_plan_id");



CREATE INDEX "idx_user_workout_exercises_day" ON "public"."user_workout_exercises" USING "btree" ("user_workout_day_id");



CREATE UNIQUE INDEX "ux_ai_plans_one_active_per_user" ON "public"."ai_plans" USING "btree" ("user_id") WHERE ("is_active" = true);



CREATE OR REPLACE TRIGGER "trg_ai_plans_updated_at" BEFORE UPDATE ON "public"."ai_plans" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."ai_plans"
    ADD CONSTRAINT "ai_plans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_logs"
    ADD CONSTRAINT "meal_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_favorites"
    ADD CONSTRAINT "user_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_weekly_weights"
    ADD CONSTRAINT "user_weekly_weights_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_workout_days"
    ADD CONSTRAINT "user_workout_days_ai_plan_id_fkey" FOREIGN KEY ("ai_plan_id") REFERENCES "public"."ai_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_workout_days"
    ADD CONSTRAINT "user_workout_days_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_workout_exercises"
    ADD CONSTRAINT "user_workout_exercises_user_workout_day_id_fkey" FOREIGN KEY ("user_workout_day_id") REFERENCES "public"."user_workout_days"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_workout_progress"
    ADD CONSTRAINT "user_workout_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Allow public insert" ON "public"."contact_messages" FOR INSERT WITH CHECK (true);



CREATE POLICY "Allow select for authenticated" ON "public"."contact_messages" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."meals" FOR SELECT USING (true);



CREATE POLICY "Users can delete own weekly weights" ON "public"."user_weekly_weights" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own meal logs" ON "public"."meal_logs" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own weekly weights" ON "public"."user_weekly_weights" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own meal logs" ON "public"."meal_logs" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage their own favorites" ON "public"."user_favorites" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage their own weekly weights" ON "public"."user_weekly_weights" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage their own workout progress" ON "public"."user_workout_progress" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own weekly weights" ON "public"."user_weekly_weights" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own weekly weights" ON "public"."user_weekly_weights" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "ai_insert_own" ON "public"."ai_plans" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."ai_plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ai_read_own" ON "public"."ai_plans" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "ai_update_own" ON "public"."ai_plans" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."contact_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "delete_own_ai_plans" ON "public"."ai_plans" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "exercises_read_all" ON "public"."exercises" FOR SELECT USING (true);



CREATE POLICY "insert_own_ai_plans" ON "public"."ai_plans" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."meal_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "select_own_ai_plans" ON "public"."ai_plans" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "update_own_ai_plans" ON "public"."ai_plans" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."user_favorites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_weekly_weights" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_workout_progress" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."exercises";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."meals";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."delete_current_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_current_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_current_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."force_generate_meal_plan_after_quiz"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_duration_weeks" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_duration_weeks" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_duration_weeks" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer, "p_target_calories" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer, "p_target_calories" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_duration_weeks" integer, "p_target_calories" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_duration_weeks" integer, "p_diet" "text", "p_allergies" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_duration_weeks" integer, "p_meals_per_day" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_duration_weeks" integer, "p_meals_per_day" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_duration_weeks" integer, "p_meals_per_day" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_macro" "text", "p_allergies" "text"[], "p_days" integer, "p_meals_per_day" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_macro" "text", "p_allergies" "text"[], "p_days" integer, "p_meals_per_day" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_meal_plan_for_user"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text", "p_macro" "text", "p_allergies" "text"[], "p_days" integer, "p_meals_per_day" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_simple_meal_plan"("p_user_id" "uuid", "p_duration_weeks" integer, "p_goal" "text", "p_diet" "text", "p_allergies" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_simple_meal_plan"("p_user_id" "uuid", "p_duration_weeks" integer, "p_goal" "text", "p_diet" "text", "p_allergies" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_simple_meal_plan"("p_user_id" "uuid", "p_duration_weeks" integer, "p_goal" "text", "p_diet" "text", "p_allergies" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_user_meal_plan"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_user_meal_plan"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_user_meal_plan"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_user_meal_plan_test"("p_user_id" "uuid", "p_goal" "text", "p_diet" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_user_workout_plan"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_user_workout_plan"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_user_workout_plan"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_exercises_by_muscle"("p_muscle" "text", "p_is_male" boolean, "p_is_female" boolean, "p_equipment" "text"[], "p_difficulties" "text"[], "p_workout_types" "text"[], "p_search" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_exercises_by_muscle"("p_muscle" "text", "p_is_male" boolean, "p_is_female" boolean, "p_equipment" "text"[], "p_difficulties" "text"[], "p_workout_types" "text"[], "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_exercises_by_muscle"("p_muscle" "text", "p_is_male" boolean, "p_is_female" boolean, "p_equipment" "text"[], "p_difficulties" "text"[], "p_workout_types" "text"[], "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_meal_slot_order"("p_meal_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_meal_slot_order"("p_meal_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_meal_slot_order"("p_meal_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_generate_meal_plan"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_generate_meal_plan"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_generate_meal_plan"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_generate_meal_plan_after_quiz"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_generate_meal_plan_after_quiz"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_generate_meal_plan_after_quiz"() TO "service_role";


















GRANT ALL ON TABLE "public"."ai_plans" TO "anon";
GRANT ALL ON TABLE "public"."ai_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_plans" TO "service_role";



GRANT ALL ON TABLE "public"."contact_messages" TO "anon";
GRANT ALL ON TABLE "public"."contact_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."contact_messages" TO "service_role";



GRANT ALL ON TABLE "public"."exercises" TO "anon";
GRANT ALL ON TABLE "public"."exercises" TO "authenticated";
GRANT ALL ON TABLE "public"."exercises" TO "service_role";



GRANT ALL ON SEQUENCE "public"."exercises_exercise_pk_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."exercises_exercise_pk_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."exercises_exercise_pk_seq" TO "service_role";



GRANT ALL ON TABLE "public"."meal_logs" TO "anon";
GRANT ALL ON TABLE "public"."meal_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."meal_logs" TO "service_role";



GRANT ALL ON TABLE "public"."meal_templates" TO "anon";
GRANT ALL ON TABLE "public"."meal_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."meal_templates" TO "service_role";



GRANT ALL ON SEQUENCE "public"."meal_templates_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."meal_templates_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."meal_templates_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."meals" TO "anon";
GRANT ALL ON TABLE "public"."meals" TO "authenticated";
GRANT ALL ON TABLE "public"."meals" TO "service_role";



GRANT ALL ON TABLE "public"."program_templates" TO "anon";
GRANT ALL ON TABLE "public"."program_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."program_templates" TO "service_role";



GRANT ALL ON SEQUENCE "public"."program_templates_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."program_templates_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."program_templates_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_favorites" TO "anon";
GRANT ALL ON TABLE "public"."user_favorites" TO "authenticated";
GRANT ALL ON TABLE "public"."user_favorites" TO "service_role";



GRANT ALL ON TABLE "public"."user_meal_plan" TO "anon";
GRANT ALL ON TABLE "public"."user_meal_plan" TO "authenticated";
GRANT ALL ON TABLE "public"."user_meal_plan" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_meal_plan_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_meal_plan_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_meal_plan_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_preferences" TO "anon";
GRANT ALL ON TABLE "public"."user_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."user_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."user_weekly_weights" TO "anon";
GRANT ALL ON TABLE "public"."user_weekly_weights" TO "authenticated";
GRANT ALL ON TABLE "public"."user_weekly_weights" TO "service_role";



GRANT ALL ON TABLE "public"."user_workout_days" TO "anon";
GRANT ALL ON TABLE "public"."user_workout_days" TO "authenticated";
GRANT ALL ON TABLE "public"."user_workout_days" TO "service_role";



GRANT ALL ON TABLE "public"."user_workout_exercises" TO "anon";
GRANT ALL ON TABLE "public"."user_workout_exercises" TO "authenticated";
GRANT ALL ON TABLE "public"."user_workout_exercises" TO "service_role";



GRANT ALL ON TABLE "public"."user_workout_progress" TO "anon";
GRANT ALL ON TABLE "public"."user_workout_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."user_workout_progress" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































