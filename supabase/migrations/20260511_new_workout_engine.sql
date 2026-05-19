-- ============================================================
-- STAGING ONLY — New Workout Generation Engine
-- Project : gymguide-staging
-- Date    : 2026-05-11
-- Author  : Antigravity / GymGuide Dev
--
-- DO NOT apply to production.
--
-- What this migration does:
--   1. Creates resolve_weekly_split(goal, days) helper
--   2. Creates get_exercises_for_day(day_type, gender, location) helper
--   3. Replaces generate_user_workout_plan(user_id) main RPC
--
-- Architecture:
--   quiz answers → user_preferences → generate_user_workout_plan RPC
--     → resolve_weekly_split() → get_exercises_for_day() → ai_plans.schedule_json
--
-- CRITICAL:
--   exercise_id is TEXT — never cast to integer, never strip leading zeros.
-- ============================================================

-- ============================================================
-- HELPER 1: resolve_weekly_split
-- Returns a 7-element TEXT[] representing day types for a full
-- calendar week. Slots beyond training_days are 'rest'.
-- ============================================================
CREATE OR REPLACE FUNCTION resolve_weekly_split(
  p_goal TEXT,
  p_days INT
) RETURNS TEXT[] AS $$
DECLARE
  v_split TEXT[];
BEGIN
  -- Normalize
  p_goal := lower(trim(COALESCE(p_goal, 'build_muscle')));
  p_days := GREATEST(3, LEAST(7, COALESCE(p_days, 4)));

  -- ── BUILD MUSCLE ──────────────────────────────────────────
  IF p_goal IN ('build_muscle', 'muscle_gain') THEN
    CASE p_days
      WHEN 3 THEN
        v_split := ARRAY['push','pull','legs','rest','rest','rest','rest'];
      WHEN 4 THEN
        v_split := ARRAY['push','pull','rest','legs','upper','rest','rest'];
      WHEN 5 THEN
        v_split := ARRAY['push','pull','legs','upper','lower','rest','rest'];
      WHEN 6 THEN
        v_split := ARRAY['push','pull','legs','push','pull','legs','rest'];
      WHEN 7 THEN
        v_split := ARRAY['push','pull','legs','push','pull','legs','cardio'];
      ELSE
        v_split := ARRAY['push','pull','legs','rest','rest','rest','rest'];
    END CASE;

  -- ── FAT LOSS ──────────────────────────────────────────────
  ELSIF p_goal = 'fat_loss' THEN
    CASE p_days
      WHEN 3 THEN
        v_split := ARRAY['fullbody','rest','cardio','rest','fullbody','rest','rest'];
      WHEN 4 THEN
        v_split := ARRAY['upper','lower','rest','cardio','fullbody','rest','rest'];
      WHEN 5 THEN
        v_split := ARRAY['upper','lower','cardio','fullbody','cardio','rest','rest'];
      WHEN 6 THEN
        v_split := ARRAY['push','pull','legs','cardio','fullbody','cardio','rest'];
      WHEN 7 THEN
        v_split := ARRAY['upper','lower','cardio','fullbody','cardio','recovery','cardio'];
      ELSE
        v_split := ARRAY['upper','lower','rest','cardio','fullbody','rest','rest'];
    END CASE;

  -- ── DEFAULT fallback ──────────────────────────────────────
  ELSE
    v_split := ARRAY['push','pull','legs','rest','rest','rest','rest'];
  END IF;

  RETURN v_split;
END;
$$ LANGUAGE plpgsql STABLE;


-- ============================================================
-- HELPER 2: get_exercises_for_day
-- Selects ranked exercise_ids from exercise_rankings.
--
-- CRITICAL: exercise_id is TEXT — DO NOT cast to integer.
-- Returns TEXT[] ordered by muscle group priority, then rank ASC.
--
-- Muscle counts per day type:
--   PUSH:     chest×5, shoulders×3, triceps×3
--   PULL:     lats×5, biceps×3, traps×2, lowerback×2, forearms×2
--   LEGS:     quadriceps×4, hamstrings×4, hipsandglutes×2, calves×2
--   UPPER:    chest×3, lats×3, shoulders×2, biceps×2, triceps×2
--   LOWER:    quadriceps×3, hamstrings×3, hipsandglutes×2, calves×2
--   FULLBODY: chest×2, lats×2, quadriceps×2, hamstrings×2,
--             shoulders×1, biceps×1, triceps×1
--   CARDIO:   cardio×8
--   REST/RECOVERY: empty array
-- ============================================================
CREATE OR REPLACE FUNCTION get_exercises_for_day(
  p_day_type TEXT,
  p_gender   TEXT,
  p_location TEXT
) RETURNS TEXT[] AS $$
DECLARE
  v_ids   TEXT[] := ARRAY[]::TEXT[];
  v_batch TEXT[];
BEGIN
  -- Normalize inputs
  p_day_type := lower(trim(COALESCE(p_day_type, 'rest')));
  p_gender   := lower(trim(COALESCE(p_gender, 'male')));
  p_location := lower(trim(COALESCE(p_location, 'gym')));

  -- Macro: inline fetch for one muscle group
  -- Using subquery + array_agg to guarantee rank ordering

  -- ── PUSH ─────────────────────────────────────────────────
  IF p_day_type = 'push' THEN
    -- chest × 5
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'chest' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 5) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- shoulders × 3
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'shoulders' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 3) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- triceps × 3
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'triceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 3) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

  -- ── PULL ─────────────────────────────────────────────────
  ELSIF p_day_type = 'pull' THEN
    -- lats × 5
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'lats' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 5) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- biceps × 3
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'biceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 3) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- traps × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'traps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- lowerback × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'lowerback' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- forearms × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'forearms' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

  -- ── LEGS ─────────────────────────────────────────────────
  ELSIF p_day_type = 'legs' THEN
    -- quadriceps × 4
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'quadriceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 4) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- hamstrings × 4
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'hamstrings' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 4) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- hipsandglutes × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'hipsandglutes' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- calves × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'calves' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

  -- ── UPPER ────────────────────────────────────────────────
  ELSIF p_day_type = 'upper' THEN
    -- chest × 3
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'chest' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 3) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- lats × 3
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'lats' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 3) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- shoulders × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'shoulders' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- biceps × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'biceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- triceps × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'triceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

  -- ── LOWER ────────────────────────────────────────────────
  ELSIF p_day_type = 'lower' THEN
    -- quadriceps × 3
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'quadriceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 3) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- hamstrings × 3
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'hamstrings' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 3) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- hipsandglutes × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'hipsandglutes' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- calves × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'calves' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

  -- ── FULLBODY ─────────────────────────────────────────────
  ELSIF p_day_type = 'fullbody' THEN
    -- chest × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'chest' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- lats × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'lats' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- quadriceps × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'quadriceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- hamstrings × 2
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'hamstrings' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 2) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- shoulders × 1
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'shoulders' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 1) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- biceps × 1
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'biceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 1) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

    -- triceps × 1
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'triceps' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 1) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

  -- ── CARDIO ───────────────────────────────────────────────
  ELSIF p_day_type = 'cardio' THEN
    SELECT array_agg(exercise_id ORDER BY rank) INTO v_batch
    FROM (SELECT exercise_id, rank FROM exercise_rankings
          WHERE muscle = 'cardio' AND gender = p_gender AND location = p_location
          ORDER BY rank LIMIT 8) s;
    v_ids := v_ids || COALESCE(v_batch, ARRAY[]::TEXT[]);

  -- ── REST / RECOVERY ───────────────────────────────────────
  -- Returns empty array — UI will display rest day card
  ELSE
    v_ids := ARRAY[]::TEXT[];
  END IF;

  RETURN v_ids;
END;
$$ LANGUAGE plpgsql STABLE;


-- ============================================================
-- MAIN RPC: generate_user_workout_plan
--
-- Reads user_preferences, builds schedule_json, inserts a fresh
-- row into ai_plans. Does NOT delete existing rows — WorkoutPage
-- picks the latest via ORDER BY created_at DESC LIMIT 1.
--
-- Output schedule_json format:
-- {
--   "weeks_count": 4,
--   "days_per_week": 5,
--   "goal": "build_muscle",
--   "gender": "male",
--   "location": "gym",
--   "plan_duration_days": 28,
--   "generated_at": "...",
--   "engine_version": "2.0",
--   "weeks": {
--     "1": {
--       "1": { "type": "push",  "exercises": ["002512", "031912", ...] },
--       "2": { "type": "pull",  "exercises": [...] },
--       ...
--       "4": { "type": "rest",  "exercises": [] },
--       ...
--     },
--     ...
--   }
-- }
-- ============================================================
DROP FUNCTION IF EXISTS generate_user_workout_plan(uuid);

CREATE OR REPLACE FUNCTION generate_user_workout_plan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_goal       TEXT;
  v_gender     TEXT;
  v_location   TEXT;
  v_days       INT;
  v_weeks      INT;
  v_split      TEXT[];
  v_week_json  JSONB;
  v_weeks_json JSONB := '{}'::JSONB;
  v_day_type   TEXT;
  v_exercises  TEXT[];
  v_day_obj    JSONB;
  v_plan_id    UUID;
  v_schedule   JSONB;
  v_week_idx   INT;
  v_day_idx    INT;
BEGIN
  -- ── 1. Read user_preferences ───────────────────────────────
  SELECT
    COALESCE(goal, 'build_muscle'),
    COALESCE(gender, 'male'),
    COALESCE(training_location, 'gym'),
    COALESCE(training_days, 4),
    COALESCE(duration_weeks, 4)
  INTO v_goal, v_gender, v_location, v_days, v_weeks
  FROM user_preferences
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status',  'error',
      'message', 'No user_preferences found for user: ' || p_user_id::TEXT
    );
  END IF;

  -- Clamp to valid ranges
  v_days  := GREATEST(3, LEAST(7, v_days));
  v_weeks := GREATEST(1, LEAST(52, v_weeks));

  RAISE LOG '[workout_engine] Generating plan for user=%, goal=%, gender=%, location=%, days=%, weeks=%',
    p_user_id, v_goal, v_gender, v_location, v_days, v_weeks;

  -- ── 2. Resolve weekly split ────────────────────────────────
  v_split := resolve_weekly_split(v_goal, v_days);

  RAISE LOG '[workout_engine] Split resolved: %', v_split;

  -- ── 3. Build schedule week-by-week ────────────────────────
  FOR v_week_idx IN 1..v_weeks LOOP
    v_week_json := '{}'::JSONB;

    FOR v_day_idx IN 1..7 LOOP
      v_day_type := v_split[v_day_idx];

      IF v_day_type IN ('rest', 'recovery') THEN
        -- Rest / recovery: no exercises, type preserved for UI
        v_day_obj := jsonb_build_object(
          'type',      v_day_type,
          'exercises', '[]'::JSONB
        );
      ELSE
        -- Workout day: fetch ranked exercise IDs (TEXT — no int cast)
        v_exercises := get_exercises_for_day(v_day_type, v_gender, v_location);
        v_day_obj := jsonb_build_object(
          'type',      v_day_type,
          'exercises', to_jsonb(v_exercises)
        );
      END IF;

      -- Append day to week (key = day index as text: "1".."7")
      v_week_json := v_week_json || jsonb_build_object(v_day_idx::TEXT, v_day_obj);
    END LOOP;

    -- Append week (key = week index as text: "1".."N")
    v_weeks_json := v_weeks_json || jsonb_build_object(v_week_idx::TEXT, v_week_json);
  END LOOP;

  -- ── 4. Assemble final schedule_json ───────────────────────
  v_schedule := jsonb_build_object(
    'weeks_count',        v_weeks,
    'days_per_week',      v_days,
    'goal',               v_goal,
    'gender',             v_gender,
    'location',           v_location,
    'plan_duration_days', v_weeks * 7,
    'generated_at',       now()::TEXT,
    'engine_version',     '2.0',
    'weeks',              v_weeks_json
  );

  -- ── 5. Insert fresh plan row ───────────────────────────────
  -- Do NOT delete old rows. WorkoutPage picks latest by created_at DESC.
  INSERT INTO ai_plans (
    user_id,
    created_at,
    is_active,
    schedule_json,
    plan_duration_days,
    days_per_week,
    slug_used,
    gender
  ) VALUES (
    p_user_id,
    now(),
    true,
    v_schedule,
    v_weeks * 7,
    v_days,
    v_goal || '_' || v_location || '_' || v_days::TEXT || 'd_' || v_gender,
    v_gender
  )
  RETURNING id INTO v_plan_id;

  RAISE LOG '[workout_engine] Plan inserted: id=%', v_plan_id;

  RETURN jsonb_build_object(
    'status',   'success',
    'plan_id',  v_plan_id,
    'goal',     v_goal,
    'gender',   v_gender,
    'location', v_location,
    'days',     v_days,
    'weeks',    v_weeks
  );

EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[workout_engine] ERROR for user=%: %', p_user_id, SQLERRM;
  RETURN jsonb_build_object(
    'status',  'error',
    'message', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- VERIFICATION QUERIES (run these manually after applying)
-- ============================================================
-- Test 1: Split resolver
-- SELECT resolve_weekly_split('build_muscle', 3);   -- {push,pull,legs,rest,rest,rest,rest}
-- SELECT resolve_weekly_split('build_muscle', 5);   -- {push,pull,legs,upper,lower,rest,rest}
-- SELECT resolve_weekly_split('fat_loss', 5);       -- {upper,lower,cardio,fullbody,cardio,rest,rest}
-- SELECT resolve_weekly_split('fat_loss', 7);       -- {upper,lower,cardio,fullbody,cardio,recovery,cardio}
--
-- Test 2: Exercise selector (should return TEXT IDs with leading zeros)
-- SELECT get_exercises_for_day('push', 'male', 'gym');
-- SELECT get_exercises_for_day('legs', 'female', 'home');
-- SELECT get_exercises_for_day('cardio', 'male', 'gym');
-- SELECT get_exercises_for_day('rest', 'male', 'gym');  -- should be empty {}
--
-- Test 3: End-to-end generate for a staging test user
-- SELECT generate_user_workout_plan('<your-staging-test-user-uuid>');
-- SELECT schedule_json FROM ai_plans WHERE user_id = '<uuid>' ORDER BY created_at DESC LIMIT 1;
