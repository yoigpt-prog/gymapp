-- ============================================================
-- STAGING ONLY — Dynamic Meal Engine v1.0
-- File    : 20260515_meal_engine_v2.sql
-- Date    : 2026-05-15
-- Tables  : user_quiz_profile, user_meal_plan_v2
-- RPC     : generate_meal_plan_v2(p_user_id UUID)
-- Helper  : delete_meal_plan_v2(p_user_id UUID)
-- Source  : meals_v2 (597 meals, already in staging)
-- DO NOT apply to production.
-- ============================================================

-- ============================================================
-- TABLE 1: user_quiz_profile
-- Stores all extended quiz inputs + calculated calories.
-- One row per user (UPSERT on conflict).
-- ============================================================

CREATE TABLE IF NOT EXISTS user_quiz_profile (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Physical stats
  gender               TEXT,                   -- 'male' | 'female'
  age                  INT,
  height_cm            NUMERIC(6,2),
  weight_kg            NUMERIC(6,2),
  target_weight_kg     NUMERIC(6,2),

  -- Goal + activity
  goal                 TEXT,                   -- 'fat_loss' | 'build_muscle'
  activity_level       TEXT,                   -- 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active' | 'extra_active'

  -- Diet preferences
  diet_type            TEXT,                   -- 'no_preference' | 'vegetarian' | 'vegan' | 'mediterranean' | 'keto' | 'low_carb' | ...
  excluded_foods       TEXT[]   DEFAULT '{}',  -- ['gluten','dairy','nuts','eggs', ...]
  macro_preference     TEXT,                   -- 'balanced' | 'higher_protein' | 'lower_carb' | 'higher_carb'

  -- Timeline
  timeline_weeks       INT      DEFAULT 4,

  -- Computed calories (written back by RPC)
  maintenance_calories INT,
  target_calories      INT,
  calorie_adjustment   INT,                    -- actual delta applied (negative=deficit, positive=surplus)

  -- Metadata
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now(),

  UNIQUE (user_id)
);

-- RLS
ALTER TABLE user_quiz_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_quiz_profile_self" ON user_quiz_profile;
CREATE POLICY "user_quiz_profile_self" ON user_quiz_profile
  FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- TABLE 2: user_meal_plan_v2
-- Flat denormalized plan — one row per (user, week, day, slot).
-- All macros pre-scaled and snapshotted at generation time.
-- ============================================================

CREATE TABLE IF NOT EXISTS user_meal_plan_v2 (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Position
  week_number          INT         NOT NULL,
  day_number           INT         NOT NULL,   -- 1..7
  meal_type            TEXT        NOT NULL,   -- 'breakfast' | 'lunch' | 'snack' | 'dinner'

  -- Meal reference
  meal_id              BIGINT      NOT NULL REFERENCES meals_v2(id),

  -- Scaling
  scaling_factor       NUMERIC(5,4) NOT NULL DEFAULT 1.0,
  target_slot_calories INT,                    -- planned calories for this slot

  -- Scaled macro snapshot (never re-derived from base; copy-on-write safe)
  custom_calories      INT,
  custom_protein       NUMERIC(7,2),
  custom_carbs         NUMERIC(7,2),
  custom_fats          NUMERIC(7,2),

  -- Scaled ingredients snapshot (JSONB array, amounts scaled)
  scaled_ingredients   JSONB,

  -- Status
  is_eaten             BOOLEAN     NOT NULL DEFAULT false,
  is_custom            BOOLEAN     NOT NULL DEFAULT false,  -- true if user manually edited

  -- Timestamps
  generated_at         TIMESTAMPTZ DEFAULT now(),
  created_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ump_v2_user_week_day
  ON user_meal_plan_v2 (user_id, week_number, day_number);

CREATE INDEX IF NOT EXISTS idx_ump_v2_user_meal_type
  ON user_meal_plan_v2 (user_id, week_number, meal_type);

-- RLS
ALTER TABLE user_meal_plan_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_meal_plan_v2_self" ON user_meal_plan_v2;
CREATE POLICY "user_meal_plan_v2_self" ON user_meal_plan_v2
  FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- HELPER: delete_meal_plan_v2
-- Wipes existing plan rows for a user before regeneration.
-- Only called by the generation RPC or explicit user action.
-- ============================================================

DROP FUNCTION IF EXISTS delete_meal_plan_v2(UUID);

CREATE OR REPLACE FUNCTION delete_meal_plan_v2(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM user_meal_plan_v2 WHERE user_id = p_user_id;
  RAISE LOG '[MEAL_V2] Deleted existing plan for user=%', p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- CORE RPC: generate_meal_plan_v2
-- Full dynamic meal plan generation from meals_v2.
-- ============================================================

DROP FUNCTION IF EXISTS generate_meal_plan_v2(UUID);
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

  v_timeline_weeks := GREATEST(1, LEAST(52, v_timeline_weeks));

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

  -- Dynamic safe deficit/surplus based on goal
  IF v_goal = 'fat_loss' THEN
    -- Scale deficit with body weight. Heavier users can sustain larger deficits.
    -- Range: -400 to -700, proportional to weight above 60kg
    v_adjustment := -1 * GREATEST(400, LEAST(700,
      ROUND(400 + ((v_weight_kg - 60.0) / 40.0) * 300)
    ));
    v_target_cal := GREATEST(v_safe_min, v_maintenance + v_adjustment);
    -- Recalculate actual adjustment after safe floor
    v_adjustment := v_target_cal - v_maintenance;
  ELSIF v_goal = 'build_muscle' THEN
    -- Lean bulk: +400 to +750, scaled by activity
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
  -- breakfast 25% | lunch 35% | snack 15% | dinner 25%
  v_cal_breakfast := ROUND(v_target_cal * 0.25);
  v_cal_lunch     := ROUND(v_target_cal * 0.35);
  v_cal_snack     := ROUND(v_target_cal * 0.15);
  v_cal_dinner    := ROUND(v_target_cal * 0.25);

  RAISE LOG '[MEAL_V2] STEP3: breakfast=% lunch=% snack=% dinner=%',
    v_cal_breakfast, v_cal_lunch, v_cal_snack, v_cal_dinner;

  -- ── STEP 4: Build Filter Arrays ──────────────────────────────────────────
  -- Diet tags
  v_diet_filter := CASE v_diet_type
    WHEN 'vegetarian'   THEN ARRAY['vegetarian']
    WHEN 'vegan'        THEN ARRAY['vegan']
    WHEN 'mediterranean' THEN ARRAY['mediterranean']
    WHEN 'keto'         THEN ARRAY['keto']
    WHEN 'low_carb'     THEN ARRAY['low_carb']
    WHEN 'paleo'        THEN ARRAY['paleo']
    WHEN 'gluten_free'  THEN ARRAY['gluten_free']
    ELSE                     ARRAY[]::TEXT[]  -- no_preference = no filter
  END;

  -- Goal tags
  v_goal_filter := CASE v_goal
    WHEN 'fat_loss'     THEN ARRAY['fat_loss']
    WHEN 'build_muscle' THEN ARRAY['build_muscle']
    ELSE                     ARRAY[]::TEXT[]
  END;

  -- Macro preference tags
  v_macro_filter := CASE v_macro_preference
    WHEN 'higher_protein' THEN ARRAY['higher_protein']
    WHEN 'lower_carb'     THEN ARRAY['lower_carb']
    WHEN 'higher_carb'    THEN ARRAY['higher_carb']
    ELSE                       ARRAY[]::TEXT[]  -- balanced = no filter
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

    -- Reset weekly used-meal trackers (allow repeats across weeks)
    v_used_breakfast := ARRAY[]::BIGINT[];
    v_used_lunch     := ARRAY[]::BIGINT[];
    v_used_snack     := ARRAY[]::BIGINT[];
    v_used_dinner    := ARRAY[]::BIGINT[];

    FOR v_day_idx IN 1..7 LOOP
      FOREACH v_slot IN ARRAY v_meal_types LOOP

        -- Determine slot calorie target
        v_slot_cal := CASE v_slot
          WHEN 'breakfast' THEN v_cal_breakfast
          WHEN 'lunch'     THEN v_cal_lunch
          WHEN 'snack'     THEN v_cal_snack
          WHEN 'dinner'    THEN v_cal_dinner
          ELSE v_cal_lunch
        END;

        -- ── Meal Selection ─────────────────────────────────────────────────
        -- Priority: allergen safety → diet → goal → macro → diversity → random
        v_used_fallback := FALSE;

        SELECT m.id, m.base_calories, m.protein_g, m.carbs_g, m.fat_g, m.ingredients_json
        INTO v_meal_id, v_meal_base_cal, v_meal_protein, v_meal_carbs, v_meal_fat, v_meal_ingredients
        FROM meals_v2 m
        WHERE
          m.meal_type = v_slot

          -- PRIORITY 1: Allergen safety (hard exclude)
          AND (
            cardinality(v_excluded_foods) = 0
            OR NOT (m.allergens && v_excluded_foods)
          )

          -- PRIORITY 2: Diet compatibility (soft — tries with filter, falls back without)
          AND (
            cardinality(v_diet_filter) = 0
            OR m.diet_tags @> v_diet_filter
          )

          -- PRIORITY 3: Goal compatibility (soft)
          AND (
            cardinality(v_goal_filter) = 0
            OR m.goal_tags && v_goal_filter
          )

          -- PRIORITY 4: Macro preference (soft)
          AND (
            cardinality(v_macro_filter) = 0
            OR m.macro_tags && v_macro_filter
          )

          -- PRIORITY 5: No within-week repeat
          AND (
            CASE v_slot
              WHEN 'breakfast' THEN NOT (m.id = ANY(v_used_breakfast))
              WHEN 'lunch'     THEN NOT (m.id = ANY(v_used_lunch))
              WHEN 'snack'     THEN NOT (m.id = ANY(v_used_snack))
              WHEN 'dinner'    THEN NOT (m.id = ANY(v_used_dinner))
              ELSE TRUE
            END
          )
        ORDER BY random()
        LIMIT 1;

        -- Fallback 1: relax macro filter, keep diet + allergen
        IF v_meal_id IS NULL THEN
          v_used_fallback := TRUE;
          SELECT m.id, m.base_calories, m.protein_g, m.carbs_g, m.fat_g, m.ingredients_json
          INTO v_meal_id, v_meal_base_cal, v_meal_protein, v_meal_carbs, v_meal_fat, v_meal_ingredients
          FROM meals_v2 m
          WHERE
            m.meal_type = v_slot
            AND (cardinality(v_excluded_foods) = 0 OR NOT (m.allergens && v_excluded_foods))
            AND (cardinality(v_diet_filter) = 0 OR m.diet_tags @> v_diet_filter)
            AND (
              CASE v_slot
                WHEN 'breakfast' THEN NOT (m.id = ANY(v_used_breakfast))
                WHEN 'lunch'     THEN NOT (m.id = ANY(v_used_lunch))
                WHEN 'snack'     THEN NOT (m.id = ANY(v_used_snack))
                WHEN 'dinner'    THEN NOT (m.id = ANY(v_used_dinner))
                ELSE TRUE
              END
            )
          ORDER BY random()
          LIMIT 1;
        END IF;

        -- Fallback 2: relax diet filter, keep allergen only
        IF v_meal_id IS NULL THEN
          SELECT m.id, m.base_calories, m.protein_g, m.carbs_g, m.fat_g, m.ingredients_json
          INTO v_meal_id, v_meal_base_cal, v_meal_protein, v_meal_carbs, v_meal_fat, v_meal_ingredients
          FROM meals_v2 m
          WHERE
            m.meal_type = v_slot
            AND (cardinality(v_excluded_foods) = 0 OR NOT (m.allergens && v_excluded_foods))
            AND (
              CASE v_slot
                WHEN 'breakfast' THEN NOT (m.id = ANY(v_used_breakfast))
                WHEN 'lunch'     THEN NOT (m.id = ANY(v_used_lunch))
                WHEN 'snack'     THEN NOT (m.id = ANY(v_used_snack))
                WHEN 'dinner'    THEN NOT (m.id = ANY(v_used_dinner))
                ELSE TRUE
              END
            )
          ORDER BY random()
          LIMIT 1;
        END IF;

        -- Fallback 3: allow repeats, allergen safety only
        IF v_meal_id IS NULL THEN
          SELECT m.id, m.base_calories, m.protein_g, m.carbs_g, m.fat_g, m.ingredients_json
          INTO v_meal_id, v_meal_base_cal, v_meal_protein, v_meal_carbs, v_meal_fat, v_meal_ingredients
          FROM meals_v2 m
          WHERE
            m.meal_type = v_slot
            AND (cardinality(v_excluded_foods) = 0 OR NOT (m.allergens && v_excluded_foods))
          ORDER BY random()
          LIMIT 1;
        END IF;

        -- Absolute fallback: any meal of this type
        IF v_meal_id IS NULL THEN
          SELECT m.id, m.base_calories, m.protein_g, m.carbs_g, m.fat_g, m.ingredients_json
          INTO v_meal_id, v_meal_base_cal, v_meal_protein, v_meal_carbs, v_meal_fat, v_meal_ingredients
          FROM meals_v2 m
          WHERE m.meal_type = v_slot
          ORDER BY random()
          LIMIT 1;
        END IF;

        -- Still nothing — skip this slot (shouldn't happen with 597 meals)
        IF v_meal_id IS NULL THEN
          RAISE LOG '[MEAL_V2] WARNING: No meal found for slot=% week=% day=%', v_slot, v_week_idx, v_day_idx;
          CONTINUE;
        END IF;

        -- ── Track used meals for this week ─────────────────────────────────
        CASE v_slot
          WHEN 'breakfast' THEN v_used_breakfast := v_used_breakfast || v_meal_id;
          WHEN 'lunch'     THEN v_used_lunch     := v_used_lunch     || v_meal_id;
          WHEN 'snack'     THEN v_used_snack     := v_used_snack     || v_meal_id;
          WHEN 'dinner'    THEN v_used_dinner    := v_used_dinner    || v_meal_id;
          ELSE NULL;
        END CASE;

        -- ── Compute Scaling Factor ─────────────────────────────────────────
        IF v_meal_base_cal IS NULL OR v_meal_base_cal <= 0 THEN
          v_scaling := 1.0;
        ELSE
          v_scaling := GREATEST(0.75, LEAST(1.35,
            v_slot_cal::NUMERIC / v_meal_base_cal::NUMERIC
          ));
        END IF;

        -- ── Scale Macros ───────────────────────────────────────────────────
        v_scaled_cal     := ROUND(COALESCE(v_meal_base_cal, 0) * v_scaling);
        v_scaled_protein := ROUND(COALESCE(v_meal_protein, 0) * v_scaling, 1);
        v_scaled_carbs   := ROUND(COALESCE(v_meal_carbs,   0) * v_scaling, 1);
        v_scaled_fat     := ROUND(COALESCE(v_meal_fat,     0) * v_scaling, 1);

        -- ── Scale Ingredients (amounts + kcal) ────────────────────────────
        -- ingredients_json: [{name, amount, kcal}, ...]
        -- If individual kcal > 0: scale directly.
        -- If kcal is null/0: distribute total scaled meal calories proportionally by gram weight.
        IF v_meal_ingredients IS NOT NULL AND jsonb_array_length(v_meal_ingredients) > 0 THEN
          DECLARE
            v_total_grams  NUMERIC := 0;
            v_ing_sum_kcal NUMERIC := 0;
          BEGIN
            -- Sum ingredient weights and any existing kcal values
            SELECT
              COALESCE(SUM(
                CASE WHEN (ing->>'amount') ~ '^[0-9]+(\.[0-9]+)?'
                  THEN (regexp_replace(ing->>'amount', '[^0-9.]','','g'))::NUMERIC
                  ELSE 0 END
              ), 0),
              COALESCE(SUM(
                CASE WHEN COALESCE(ing->>'kcal','0') ~ '^[0-9]+(\.[0-9]+)?'
                     AND (COALESCE(ing->>'kcal','0'))::NUMERIC > 0
                  THEN (ing->>'kcal')::NUMERIC
                  ELSE 0 END
              ), 0)
            INTO v_total_grams, v_ing_sum_kcal
            FROM jsonb_array_elements(v_meal_ingredients) AS ing;

            SELECT jsonb_agg(
              jsonb_build_object(
                'name', ing->>'name',

                -- Scale numeric prefix of amount, keep unit
                'amount', CASE
                  WHEN (ing->>'amount') ~ '^[0-9]+(\.[0-9]+)?'
                    THEN CONCAT(
                      ROUND((regexp_replace(ing->>'amount','[^0-9.]','','g'))::NUMERIC * v_scaling),
                      regexp_replace(ing->>'amount', '^[0-9]+(\.[0-9]+)?', '')
                    )
                  ELSE ing->>'amount'
                END,

                -- Kcal: scale existing OR distribute proportionally by weight
                'kcal', CASE
                  WHEN COALESCE(ing->>'kcal','0') ~ '^[0-9]+(\.[0-9]+)?'
                       AND (COALESCE(ing->>'kcal','0'))::NUMERIC > 0
                    THEN ROUND((ing->>'kcal')::NUMERIC * v_scaling)
                  WHEN (ing->>'amount') ~ '^[0-9]+(\.[0-9]+)?'
                       AND v_total_grams > 0 AND v_scaled_cal > 0
                    THEN ROUND(
                      ((regexp_replace(ing->>'amount','[^0-9.]','','g'))::NUMERIC / v_total_grams)
                      * v_scaled_cal
                    )
                  ELSE 0
                END
              )
            )
            INTO v_scaled_ingredients
            FROM jsonb_array_elements(v_meal_ingredients) AS ing;
          END;
        ELSE
          v_scaled_ingredients := v_meal_ingredients;
        END IF;


        -- ── Insert Plan Row ────────────────────────────────────────────────
        INSERT INTO user_meal_plan_v2 (
          user_id, week_number, day_number, meal_type, meal_id,
          scaling_factor, target_slot_calories,
          custom_calories, custom_protein, custom_carbs, custom_fats,
          scaled_ingredients, generated_at
        ) VALUES (
          p_user_id, v_week_idx, v_day_idx, v_slot, v_meal_id,
          ROUND(v_scaling, 4), v_slot_cal,
          v_scaled_cal, v_scaled_protein, v_scaled_carbs, v_scaled_fat,
          v_scaled_ingredients, now()
        );

        v_rows_inserted := v_rows_inserted + 1;

      END LOOP; -- slots
    END LOOP;   -- days
  END LOOP;     -- weeks

  RAISE LOG '[MEAL_V2] STEP6 COMPLETE: inserted=% rows for % weeks', v_rows_inserted, v_timeline_weeks;

  -- ── STEP 7: Return summary ────────────────────────────────────────────────
  RETURN jsonb_build_object(
    'status',               'success',
    'engine_version',       '1.0',
    'user_id',              p_user_id,
    'goal',                 v_goal,
    'diet_type',            v_diet_type,
    'macro_preference',     v_macro_preference,
    'maintenance_calories', v_maintenance,
    'target_calories',      v_target_cal,
    'calorie_adjustment',   v_adjustment,
    'timeline_weeks',       v_timeline_weeks,
    'rows_inserted',        v_rows_inserted,
    'slot_targets', jsonb_build_object(
      'breakfast', v_cal_breakfast,
      'lunch',     v_cal_lunch,
      'snack',     v_cal_snack,
      'dinner',    v_cal_dinner
    )
  );

EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[MEAL_V2] FATAL ERROR for user=%: %', p_user_id, SQLERRM;
  RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- VERIFICATION QUERIES (run in staging SQL editor)
-- ============================================================

-- 1. Check both tables exist
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND table_name IN ('user_quiz_profile','user_meal_plan_v2');

-- 2. Run generation (replace UUID)
-- SELECT generate_meal_plan_v2('<staging-user-uuid>');

-- 3. Check row count (expect 4 slots × 7 days × N weeks)
-- SELECT count(*), week_number FROM user_meal_plan_v2
-- WHERE user_id = '<staging-user-uuid>'
-- GROUP BY week_number ORDER BY week_number;

-- 4. Verify no within-week repeats per slot
-- SELECT week_number, meal_type, meal_id, count(*)
-- FROM user_meal_plan_v2 WHERE user_id = '<staging-user-uuid>'
-- GROUP BY week_number, meal_type, meal_id
-- HAVING count(*) > 1;

-- 5. Calorie distribution check
-- SELECT meal_type,
--   avg(custom_calories)::INT AS avg_cal,
--   avg(scaling_factor)::NUMERIC(4,2) AS avg_scale
-- FROM user_meal_plan_v2 WHERE user_id = '<staging-user-uuid>'
-- GROUP BY meal_type ORDER BY meal_type;

-- 6. Inspect scaled ingredients for one row
-- SELECT meal_type, custom_calories, scaling_factor, scaled_ingredients
-- FROM user_meal_plan_v2 WHERE user_id = '<staging-user-uuid>'
-- LIMIT 4;
