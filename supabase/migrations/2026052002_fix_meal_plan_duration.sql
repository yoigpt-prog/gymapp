-- ============================================================
-- FIX: Remove 52-week hard cap in generate_meal_plan_v2
-- File: 2026052002_fix_meal_plan_duration.sql
-- Date: 2026-05-20
-- Change: LEAST(52, v_timeline_weeks) → GREATEST(1, v_timeline_weeks)
-- All column names kept identical to original engine v1.0
-- ============================================================

DROP FUNCTION IF EXISTS generate_meal_plan_v2(UUID, BOOLEAN);

CREATE OR REPLACE FUNCTION generate_meal_plan_v2(
  p_user_id       UUID,
  p_force_regen   BOOLEAN DEFAULT TRUE
)
RETURNS JSONB AS $$
DECLARE
  -- Profile
  v_gender             TEXT;
  v_age                INT;
  v_height_cm          NUMERIC;
  v_weight_kg          NUMERIC;
  v_target_weight_kg   NUMERIC;
  v_goal               TEXT;
  v_activity_level     TEXT;
  v_diet_type          TEXT;
  v_excluded_foods     TEXT[];
  v_macro_preference   TEXT;
  v_timeline_weeks     INT;

  -- Calorie calc
  v_bmr                NUMERIC;
  v_activity_mult      NUMERIC;
  v_maintenance        INT;
  v_adjustment         INT;
  v_target_cal         INT;
  v_safe_min           INT;

  -- Slot targets
  v_cal_breakfast      INT;
  v_cal_lunch          INT;
  v_cal_snack          INT;
  v_cal_dinner         INT;

  -- Filters
  v_diet_filter        TEXT[];
  v_goal_filter        TEXT[];
  v_macro_filter       TEXT[];

  -- Meal selection
  v_meal_types         TEXT[] := ARRAY['breakfast','lunch','snack','dinner'];
  v_slot_cal           INT;
  v_meal_id            BIGINT;
  v_meal_base_cal      INT;
  v_meal_protein       NUMERIC;
  v_meal_carbs         NUMERIC;
  v_meal_fat           NUMERIC;
  v_meal_ingredients   JSONB;
  v_scaling            NUMERIC;
  v_scaled_cal         INT;
  v_scaled_protein     NUMERIC;
  v_scaled_carbs       NUMERIC;
  v_scaled_fat         NUMERIC;
  v_scaled_ingredients JSONB;

  -- Week tracking (prevent within-week repeats per slot)
  v_used_breakfast     BIGINT[];
  v_used_lunch         BIGINT[];
  v_used_snack         BIGINT[];
  v_used_dinner        BIGINT[];

  -- Counters
  v_week_idx           INT;
  v_day_idx            INT;
  v_slot               TEXT;
  v_rows_inserted      INT := 0;

  -- Fallback flag
  v_used_fallback      BOOLEAN := FALSE;

BEGIN

  -- ── STEP 1: Read user_quiz_profile ───────────────────────────────────────
  SELECT
    LOWER(TRIM(COALESCE(gender, 'male'))),
    COALESCE(age, 25),
    COALESCE(height_cm, 175),
    COALESCE(weight_kg, 75),
    target_weight_kg,
    LOWER(TRIM(COALESCE(goal, 'fat_loss'))),
    LOWER(TRIM(COALESCE(activity_level, 'moderately_active'))),
    LOWER(TRIM(COALESCE(diet_type, 'no_preference'))),
    COALESCE(excluded_foods, '{}'),
    LOWER(TRIM(COALESCE(macro_preference, 'balanced'))),
    COALESCE(timeline_weeks, 4)
  INTO
    v_gender, v_age, v_height_cm, v_weight_kg, v_target_weight_kg,
    v_goal, v_activity_level, v_diet_type, v_excluded_foods,
    v_macro_preference, v_timeline_weeks
  FROM user_quiz_profile
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE LOG '[MEAL_V2] ERROR: No user_quiz_profile for user=%', p_user_id;
    RETURN jsonb_build_object('status','error','message','No user_quiz_profile found. Complete the quiz first.');
  END IF;

  -- FIX: Removed LEAST(52, ...) hard-cap — use actual selected duration
  v_timeline_weeks := GREATEST(1, v_timeline_weeks);

  RAISE LOG '[MEAL_V2] STEP1: user=% goal=% diet=% macro=% weeks=%',
    p_user_id, v_goal, v_diet_type, v_macro_preference, v_timeline_weeks;

  -- ── STEP 2: Calculate Calories (Mifflin-St Jeor) ─────────────────────────
  IF v_gender = 'female' THEN
    v_bmr := (10.0 * v_weight_kg) + (6.25 * v_height_cm) - (5.0 * v_age) - 161.0;
    v_safe_min := 1350;
  ELSE
    v_bmr := (10.0 * v_weight_kg) + (6.25 * v_height_cm) - (5.0 * v_age) + 5.0;
    v_safe_min := 1750;
  END IF;

  -- Activity multiplier
  v_activity_mult := CASE v_activity_level
    WHEN 'sedentary'          THEN 1.20
    WHEN 'lightly_active'     THEN 1.375
    WHEN 'moderately_active'  THEN 1.55
    WHEN 'very_active'        THEN 1.725
    WHEN 'extra_active'       THEN 1.90
    ELSE                           1.55
  END;

  v_maintenance := ROUND(v_bmr * v_activity_mult);

  IF v_goal = 'fat_loss' THEN
    v_adjustment := -1 * GREATEST(400, LEAST(700,
      ROUND(400 + ((v_weight_kg - 60.0) / 40.0) * 300)
    ));
    v_target_cal := GREATEST(v_safe_min, v_maintenance + v_adjustment);
    v_adjustment := v_target_cal - v_maintenance;
  ELSIF v_goal = 'build_muscle' THEN
    v_adjustment := GREATEST(400, LEAST(750,
      ROUND(400 + (v_activity_mult - 1.2) / 0.7 * 350)
    ));
    v_target_cal := v_maintenance + v_adjustment;
  ELSE
    v_adjustment := 0;
    v_target_cal := v_maintenance;
  END IF;

  RAISE LOG '[MEAL_V2] STEP2: bmr=% maintenance=% adjustment=% target=%',
    ROUND(v_bmr), v_maintenance, v_adjustment, v_target_cal;

  -- Write calories back to user_quiz_profile
  UPDATE user_quiz_profile SET
    maintenance_calories = v_maintenance,
    target_calories      = v_target_cal,
    calorie_adjustment   = v_adjustment,
    updated_at           = now()
  WHERE user_id = p_user_id;

  -- ── STEP 3: Slot Calorie Targets ──────────────────────────────────────────
  v_cal_breakfast := ROUND(v_target_cal * 0.25);
  v_cal_lunch     := ROUND(v_target_cal * 0.35);
  v_cal_snack     := ROUND(v_target_cal * 0.15);
  v_cal_dinner    := ROUND(v_target_cal * 0.25);

  RAISE LOG '[MEAL_V2] STEP3: breakfast=% lunch=% snack=% dinner=%',
    v_cal_breakfast, v_cal_lunch, v_cal_snack, v_cal_dinner;

  -- ── STEP 4: Build Filter Arrays ──────────────────────────────────────────
  v_diet_filter := CASE v_diet_type
    WHEN 'vegetarian'    THEN ARRAY['vegetarian']
    WHEN 'vegan'         THEN ARRAY['vegan']
    WHEN 'mediterranean' THEN ARRAY['mediterranean']
    WHEN 'keto'          THEN ARRAY['keto']
    WHEN 'low_carb'      THEN ARRAY['low_carb']
    WHEN 'paleo'         THEN ARRAY['paleo']
    WHEN 'gluten_free'   THEN ARRAY['gluten_free']
    ELSE                      ARRAY[]::TEXT[]
  END;

  v_goal_filter := CASE v_goal
    WHEN 'fat_loss'     THEN ARRAY['fat_loss']
    WHEN 'build_muscle' THEN ARRAY['build_muscle']
    ELSE                     ARRAY[]::TEXT[]
  END;

  v_macro_filter := CASE v_macro_preference
    WHEN 'higher_protein' THEN ARRAY['higher_protein']
    WHEN 'lower_carb'     THEN ARRAY['lower_carb']
    WHEN 'higher_carb'    THEN ARRAY['higher_carb']
    ELSE                       ARRAY[]::TEXT[]
  END;

  RAISE LOG '[MEAL_V2] STEP4: diet_filter=% goal_filter=% macro_filter=% excluded=%',
    v_diet_filter, v_goal_filter, v_macro_filter, v_excluded_foods;

  -- ── STEP 5: Clear existing plan if force regen ────────────────────────────
  IF p_force_regen THEN
    DELETE FROM user_meal_plan_v2 WHERE user_id = p_user_id;
    RAISE LOG '[MEAL_V2] STEP5: Cleared existing plan rows';
  END IF;

  -- ── STEP 6: Generate plan — week × day × slot ────────────────────────────
  FOR v_week_idx IN 1..v_timeline_weeks LOOP

    -- Reset weekly used-meal trackers
    v_used_breakfast := ARRAY[]::BIGINT[];
    v_used_lunch     := ARRAY[]::BIGINT[];
    v_used_snack     := ARRAY[]::BIGINT[];
    v_used_dinner    := ARRAY[]::BIGINT[];

    FOR v_day_idx IN 1..7 LOOP
      FOREACH v_slot IN ARRAY v_meal_types LOOP

        v_slot_cal := CASE v_slot
          WHEN 'breakfast' THEN v_cal_breakfast
          WHEN 'lunch'     THEN v_cal_lunch
          WHEN 'snack'     THEN v_cal_snack
          WHEN 'dinner'    THEN v_cal_dinner
          ELSE v_cal_lunch
        END;

        v_used_fallback := FALSE;

        -- Primary selection: all filters + no weekly repeat
        SELECT m.id, m.base_calories, m.protein_g, m.carbs_g, m.fat_g, m.ingredients_json
        INTO v_meal_id, v_meal_base_cal, v_meal_protein, v_meal_carbs, v_meal_fat, v_meal_ingredients
        FROM meals_v2 m
        WHERE
          m.meal_type = v_slot
          AND (cardinality(v_excluded_foods) = 0 OR NOT (m.allergens && v_excluded_foods))
          AND (cardinality(v_diet_filter) = 0 OR m.diet_tags @> v_diet_filter)
          AND (cardinality(v_goal_filter) = 0 OR m.goal_tags && v_goal_filter)
          AND (cardinality(v_macro_filter) = 0 OR m.macro_tags && v_macro_filter)
          AND (
            CASE v_slot
              WHEN 'breakfast' THEN NOT (m.id = ANY(v_used_breakfast))
              WHEN 'lunch'     THEN NOT (m.id = ANY(v_used_lunch))
              WHEN 'snack'     THEN NOT (m.id = ANY(v_used_snack))
              WHEN 'dinner'    THEN NOT (m.id = ANY(v_used_dinner))
              ELSE TRUE
            END
          )
          ORDER BY ABS(v_meal_base_cal - v_slot_cal) + random()
          LIMIT 1;

        IF v_meal_id IS NULL THEN
          -- Fallback: allow repeat meals if none found
          SELECT id, base_calories, protein_g, carbs_g, fat_g, ingredients_json
              INTO v_meal_id, v_meal_base_cal, v_meal_protein, v_meal_carbs, v_meal_fat, v_meal_ingredients
            FROM meals_v2
            WHERE meal_type = v_slot
              AND (v_excluded_foods IS NULL OR NOT (v_meal_ingredients ?| v_excluded_foods))
            ORDER BY ABS(v_meal_base_cal - v_slot_cal) + random()
            LIMIT 1;
          v_used_fallback := TRUE;
        END IF;

        -- Scaling factor to match target calories
        IF v_meal_base_cal > 0 THEN
          v_scaling := v_slot_cal::NUMERIC / v_meal_base_cal::NUMERIC;
        ELSE
          v_scaling := 1.0;
        END IF;
        v_scaled_cal := ROUND(v_meal_base_cal * v_scaling);
        v_scaled_protein := ROUND(v_meal_protein * v_scaling, 2);
        v_scaled_carbs   := ROUND(v_meal_carbs * v_scaling, 2);
        v_scaled_fat     := ROUND(v_meal_fat * v_scaling, 2);
        v_scaled_ingredients := (SELECT jsonb_agg(jsonb_build_object('ingredient', elem->>'ingredient', 'amount', (regexp_replace(elem->>'amount', '[^0-9\.]+', '', 'g'))::NUMERIC * v_scaling))
                                 FROM jsonb_array_elements(v_meal_ingredients) AS elem);

        -- Insert row
        INSERT INTO user_meal_plan_v2 (
          user_id, week_number, day_number, meal_type,
          meal_id, scaling_factor, target_slot_calories,
          custom_calories, custom_protein, custom_carbs, custom_fats,
          scaled_ingredients
        ) VALUES (
          p_user_id, v_week_idx, v_day_idx, v_slot,
          v_meal_id, v_scaling, v_slot_cal,
          v_scaled_cal, v_scaled_protein, v_scaled_carbs, v_scaled_fat,
          v_scaled_ingredients
        );
        v_rows_inserted := v_rows_inserted + 1;

        -- Track used meals per slot for the week
        CASE v_slot
          WHEN 'breakfast' THEN v_used_breakfast := array_append(v_used_breakfast, v_meal_id);
          WHEN 'lunch'     THEN v_used_lunch := array_append(v_used_lunch, v_meal_id);
          WHEN 'snack'     THEN v_used_snack := array_append(v_used_snack, v_meal_id);
          WHEN 'dinner'    THEN v_used_dinner := array_append(v_used_dinner, v_meal_id);
        END CASE;
      END LOOP;
    END LOOP;
    -- Reset weekly trackers for next week
    v_used_breakfast := ARRAY[]::BIGINT[];
    v_used_lunch     := ARRAY[]::BIGINT[];
    v_used_snack     := ARRAY[]::BIGINT[];
    v_used_dinner    := ARRAY[]::BIGINT[];
  END LOOP;

  RAISE LOG '[MEAL_V2] INSERTED rows=% for user=% weeks=% fallback=%', v_rows_inserted, p_user_id, v_timeline_weeks, v_used_fallback;

  RETURN jsonb_build_object(
    'status', 'success',
    'user_id', p_user_id,
    'weeks', v_timeline_weeks,
    'rows_inserted', v_rows_inserted,
    'fallback_used', v_used_fallback
  );
EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[MEAL_V2] ERROR for user=%: %', p_user_id, SQLERRM;
  RETURN jsonb_build_object('status','error','message',SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
