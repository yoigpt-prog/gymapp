-- ============================================================
-- File    : 2026052001_fix_workout_plan_duration.sql
-- Date    : 2026-05-20
-- CHANGE  : Removes hardcap of 52 weeks from generate_user_workout_plan
--           and reads timeline_weeks from user_quiz_profile.
-- ============================================================

CREATE OR REPLACE FUNCTION generate_user_workout_plan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_goal     TEXT;
  v_gender   TEXT;
  v_location TEXT;
  v_days     INT;
  v_weeks    INT;
  v_split    TEXT[];

  -- Main exercise ID arrays
  v_push_ids     TEXT[];
  v_pull_ids     TEXT[];
  v_legs_ids     TEXT[];
  v_upper_ids    TEXT[];
  v_lower_ids    TEXT[];
  v_fullbody_ids TEXT[];
  v_cardio_ids   TEXT[];

  -- Core exercise ID arrays (appended as optional)
  v_abs_ids      TEXT[];
  v_obliques_ids TEXT[];

  -- Schedule build
  v_weeks_json    JSONB := '{}'::JSONB;
  v_week_json     JSONB;
  v_day_type      TEXT;
  v_main_ids      TEXT[];
  v_core_ids      TEXT[];
  v_all_ids       TEXT[];
  v_opt_ids       TEXT[];
  v_total         INT;
  v_week_idx      INT;
  v_day_idx       INT;
  i               INT;  -- loop index for sets/reps builder
  v_experience    TEXT;
  v_duration      TEXT;
  v_duration_mins TEXT;
  v_exp_key       TEXT;
  v_base_sets     INT;
  v_base_reps     INT;
  v_ex_id         TEXT;
  v_ex_type       TEXT;
  v_sets          INT;
  v_reps          INT;
  v_all_objects   JSONB[];
  v_matrix_config JSONB := '{
    "beginner": {
      "30": {"sets":2,"reps":10},
      "45": {"sets":3,"reps":10},
      "60": {"sets":3,"reps":12},
      "90": {"sets":4,"reps":12}
    },
    "intermediate": {
      "30": {"sets":3,"reps":10},
      "45": {"sets":3,"reps":12},
      "60": {"sets":4,"reps":10},
      "90": {"sets":4,"reps":12}
    },
    "advanced": {
      "30": {"sets":4,"reps":10},
      "45": {"sets":4,"reps":12},
      "60": {"sets":5,"reps":10},
      "90": {"sets":5,"reps":12}
    }
  }'::JSONB;
  v_plan_id       UUID;
BEGIN

  -- ── STEP 1: Read user_preferences & user_quiz_profile ─────
  SELECT
    lower(trim(COALESCE(p.goal, 'build_muscle'))),
    lower(trim(COALESCE(p.gender, 'male'))),
    lower(trim(COALESCE(p.training_location, 'gym'))),
    COALESCE(p.training_days, 3),
    COALESCE(q.timeline_weeks, p.duration_weeks, 4),
    lower(trim(COALESCE(p.experience_level, 'beginner'))),
    COALESCE(p.session_duration, '45 min')
  INTO v_goal, v_gender, v_location, v_days, v_weeks, v_experience, v_duration
  FROM user_preferences p
  LEFT JOIN user_quiz_profile q ON q.user_id = p.user_id
  WHERE p.user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE LOG '[ENGINE] STEP1 ERROR: No user_preferences for user=%', p_user_id;
    RETURN jsonb_build_object('status', 'error',
      'message', 'No user_preferences found for user: ' || p_user_id::TEXT);
  END IF;

  v_days  := GREATEST(3, LEAST(7, v_days));
  v_weeks := GREATEST(1, v_weeks);

  v_duration_mins := COALESCE(NULLIF(regexp_replace(v_duration, '[^0-9]', '', 'g'), ''), '45');
  v_exp_key := v_experience;
  IF v_matrix_config->v_exp_key IS NULL THEN v_exp_key := 'beginner'; END IF;
  
  -- Default fallback if duration key missing
  IF v_matrix_config->v_exp_key->v_duration_mins IS NULL THEN
    v_duration_mins := '45';
  END IF;

  v_base_sets := (v_matrix_config->v_exp_key->v_duration_mins->>'sets')::INT;
  v_base_reps := (v_matrix_config->v_exp_key->v_duration_mins->>'reps')::INT;
  
  RAISE LOG '[ENGINE] STEP1 PREFS: exp=% dur=% base=%x%', v_exp_key, v_duration_mins, v_base_sets, v_base_reps;

  IF v_goal = 'muscle_gain' THEN v_goal := 'build_muscle'; END IF;

  RAISE LOG '[ENGINE] STEP1 PREFS: user=% goal=% gender=% location=% days=% weeks=%',
    p_user_id, v_goal, v_gender, v_location, v_days, v_weeks;

  -- ── STEP 2: Resolve weekly split ──────────────────────────
  IF v_goal = 'build_muscle' THEN
    IF    v_days = 3 THEN v_split := ARRAY['push','rest','pull','rest','legs','rest','rest'];
    ELSIF v_days = 4 THEN v_split := ARRAY['upper','lower','rest','upper','lower','rest','rest'];
    ELSIF v_days = 5 THEN v_split := ARRAY['push','pull','rest','legs','upper','fullbody','rest'];
    ELSIF v_days = 6 THEN v_split := ARRAY['push','pull','legs','rest','push','pull','legs'];
    ELSE                  v_split := ARRAY['push','pull','legs','push','pull','legs','cardio'];
    END IF;
  ELSIF v_goal = 'fat_loss' THEN
    IF    v_days = 3 THEN v_split := ARRAY['fullbody','rest','cardio','rest','fullbody','rest','rest'];
    ELSIF v_days = 4 THEN v_split := ARRAY['upper','lower','rest','cardio','fullbody','rest','rest'];
    ELSIF v_days = 5 THEN v_split := ARRAY['upper','lower','rest','cardio','fullbody','cardio','rest'];
    ELSIF v_days = 6 THEN v_split := ARRAY['push','pull','legs','rest','cardio','fullbody','cardio'];
    ELSE                  v_split := ARRAY['upper','lower','cardio','fullbody','cardio','recovery','cardio'];
    END IF;
  ELSE
    v_split := ARRAY['push','rest','pull','rest','legs','rest','rest'];
  END IF;

  RAISE LOG '[ENGINE] STEP2 SPLIT: %', v_split;

  -- ── STEP 3: Pre-fetch main exercise ID arrays ─────────────
  -- Each UNION ALL branch wrapped in () — PostgreSQL requirement
  -- for per-branch ORDER BY ... LIMIT.

  -- PUSH: chest×5, shoulders×3, triceps×3 = 11
  SELECT array_agg(exercise_id ORDER BY grp, rnk) INTO v_push_ids FROM (
    (SELECT exercise_id, rank AS rnk, 1 AS grp FROM exercise_rankings
     WHERE muscle='chest'     AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 5)
    UNION ALL
    (SELECT exercise_id, rank, 2 FROM exercise_rankings
     WHERE muscle='shoulders' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3)
    UNION ALL
    (SELECT exercise_id, rank, 3 FROM exercise_rankings
     WHERE muscle='triceps'   AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3)
  ) t;
  RAISE LOG '[ENGINE] STEP3 PUSH: count=%', array_length(v_push_ids,1);

  -- PULL: lats×5, biceps×3, traps×2, lowerback×2, forearms×2 = 14
  SELECT array_agg(exercise_id ORDER BY grp, rnk) INTO v_pull_ids FROM (
    (SELECT exercise_id, rank AS rnk, 1 AS grp FROM exercise_rankings
     WHERE muscle='lats'      AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 5)
    UNION ALL
    (SELECT exercise_id, rank, 2 FROM exercise_rankings
     WHERE muscle='biceps'    AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3)
    UNION ALL
    (SELECT exercise_id, rank, 3 FROM exercise_rankings
     WHERE muscle='traps'     AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 4 FROM exercise_rankings
     WHERE muscle='lowerback' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 5 FROM exercise_rankings
     WHERE muscle='forearms'  AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
  ) t;
  RAISE LOG '[ENGINE] STEP3 PULL: count=%', array_length(v_pull_ids,1);

  -- LEGS: quadriceps×4, hamstrings×4, hipsandglutes×2, calves×2 = 12
  SELECT array_agg(exercise_id ORDER BY grp, rnk) INTO v_legs_ids FROM (
    (SELECT exercise_id, rank AS rnk, 1 AS grp FROM exercise_rankings
     WHERE muscle='quadriceps'    AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 4)
    UNION ALL
    (SELECT exercise_id, rank, 2 FROM exercise_rankings
     WHERE muscle='hamstrings'    AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 4)
    UNION ALL
    (SELECT exercise_id, rank, 3 FROM exercise_rankings
     WHERE muscle='hipsandglutes' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 4 FROM exercise_rankings
     WHERE muscle='calves'        AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
  ) t;
  RAISE LOG '[ENGINE] STEP3 LEGS: count=%', array_length(v_legs_ids,1);

  -- UPPER: chest×3, lats×3, shoulders×2, biceps×2, triceps×2 = 12
  SELECT array_agg(exercise_id ORDER BY grp, rnk) INTO v_upper_ids FROM (
    (SELECT exercise_id, rank AS rnk, 1 AS grp FROM exercise_rankings
     WHERE muscle='chest'     AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3)
    UNION ALL
    (SELECT exercise_id, rank, 2 FROM exercise_rankings
     WHERE muscle='lats'      AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3)
    UNION ALL
    (SELECT exercise_id, rank, 3 FROM exercise_rankings
     WHERE muscle='shoulders' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 4 FROM exercise_rankings
     WHERE muscle='biceps'    AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 5 FROM exercise_rankings
     WHERE muscle='triceps'   AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
  ) t;
  RAISE LOG '[ENGINE] STEP3 UPPER: count=%', array_length(v_upper_ids,1);

  -- LOWER: quadriceps×3, hamstrings×3, hipsandglutes×2, calves×2 = 10
  SELECT array_agg(exercise_id ORDER BY grp, rnk) INTO v_lower_ids FROM (
    (SELECT exercise_id, rank AS rnk, 1 AS grp FROM exercise_rankings
     WHERE muscle='quadriceps'    AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3)
    UNION ALL
    (SELECT exercise_id, rank, 2 FROM exercise_rankings
     WHERE muscle='hamstrings'    AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3)
    UNION ALL
    (SELECT exercise_id, rank, 3 FROM exercise_rankings
     WHERE muscle='hipsandglutes' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 4 FROM exercise_rankings
     WHERE muscle='calves'        AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
  ) t;
  RAISE LOG '[ENGINE] STEP3 LOWER: count=%', array_length(v_lower_ids,1);

  -- FULLBODY: chest×2, lats×2, quad×2, hamstrings×2, shoulders×1, biceps×1, triceps×1 = 11
  SELECT array_agg(exercise_id ORDER BY grp, rnk) INTO v_fullbody_ids FROM (
    (SELECT exercise_id, rank AS rnk, 1 AS grp FROM exercise_rankings
     WHERE muscle='chest'      AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 2 FROM exercise_rankings
     WHERE muscle='lats'       AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 3 FROM exercise_rankings
     WHERE muscle='quadriceps' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 4 FROM exercise_rankings
     WHERE muscle='hamstrings' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2)
    UNION ALL
    (SELECT exercise_id, rank, 5 FROM exercise_rankings
     WHERE muscle='shoulders'  AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 1)
    UNION ALL
    (SELECT exercise_id, rank, 6 FROM exercise_rankings
     WHERE muscle='biceps'     AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 1)
    UNION ALL
    (SELECT exercise_id, rank, 7 FROM exercise_rankings
     WHERE muscle='triceps'    AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 1)
  ) t;
  RAISE LOG '[ENGINE] STEP3 FULLBODY: count=%', array_length(v_fullbody_ids,1);

  -- CARDIO: cardio×8
  SELECT array_agg(exercise_id ORDER BY rank) INTO v_cardio_ids FROM (
    SELECT exercise_id, rank FROM exercise_rankings
    WHERE muscle='cardio' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 8
  ) t;
  RAISE LOG '[ENGINE] STEP3 CARDIO: count=%', array_length(v_cardio_ids,1);

  -- CORE — fetched once, appended to all non-cardio days
  -- abs×2, obliques×1 = 3 core exercises (adjustable for even total)
  SELECT array_agg(exercise_id ORDER BY rank) INTO v_abs_ids FROM (
    SELECT exercise_id, rank FROM exercise_rankings
    WHERE muscle='abs' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 3
  ) t;

  SELECT array_agg(exercise_id ORDER BY rank) INTO v_obliques_ids FROM (
    SELECT exercise_id, rank FROM exercise_rankings
    WHERE muscle='obliques' AND gender=v_gender AND location=v_location ORDER BY floor(rank / 3), random() LIMIT 2
  ) t;

  -- Null-safety for all arrays
  v_push_ids     := COALESCE(v_push_ids,     ARRAY[]::TEXT[]);
  v_pull_ids     := COALESCE(v_pull_ids,     ARRAY[]::TEXT[]);
  v_legs_ids     := COALESCE(v_legs_ids,     ARRAY[]::TEXT[]);
  v_upper_ids    := COALESCE(v_upper_ids,    ARRAY[]::TEXT[]);
  v_lower_ids    := COALESCE(v_lower_ids,    ARRAY[]::TEXT[]);
  v_fullbody_ids := COALESCE(v_fullbody_ids, ARRAY[]::TEXT[]);
  v_cardio_ids   := COALESCE(v_cardio_ids,   ARRAY[]::TEXT[]);
  v_abs_ids      := COALESCE(v_abs_ids,      ARRAY[]::TEXT[]);
  v_obliques_ids := COALESCE(v_obliques_ids, ARRAY[]::TEXT[]);

  RAISE LOG '[ENGINE] STEP3 CORE: abs=% obliques=%',
    array_length(v_abs_ids,1), array_length(v_obliques_ids,1);

  -- ── STEP 4: Build schedule_json ───────────────────────────
  FOR v_week_idx IN 1..v_weeks LOOP
    v_week_json := '{}'::JSONB;

    FOR v_day_idx IN 1..7 LOOP
      v_day_type := v_split[v_day_idx];

      -- Select main exercise IDs for this day type
      CASE v_day_type
        WHEN 'push'     THEN v_main_ids := v_push_ids;
        WHEN 'pull'     THEN v_main_ids := v_pull_ids;
        WHEN 'legs'     THEN v_main_ids := v_legs_ids;
        WHEN 'upper'    THEN v_main_ids := v_upper_ids;
        WHEN 'lower'    THEN v_main_ids := v_lower_ids;
        WHEN 'fullbody' THEN v_main_ids := v_fullbody_ids;
        WHEN 'cardio'   THEN v_main_ids := v_cardio_ids;
        ELSE                 v_main_ids := ARRAY[]::TEXT[];
      END CASE;

      -- Cardio and rest days: no core appended
      IF v_day_type IN ('cardio', 'rest', 'recovery') THEN
        v_all_ids := v_main_ids;
        v_opt_ids := ARRAY[]::TEXT[];

        v_all_objects := ARRAY[]::JSONB[];
        FOR i IN 1..COALESCE(array_length(v_all_ids, 1), 0) LOOP
          v_ex_id := v_all_ids[i];
          v_all_objects := v_all_objects || jsonb_build_object('id', v_ex_id, 'sets', v_base_sets, 'reps', v_base_reps);
        END LOOP;
        
        v_week_json := v_week_json || jsonb_build_object(
          v_day_idx::TEXT,
          jsonb_build_object(
            'type',                 v_day_type,
            'exercises',            to_jsonb(v_all_objects),
            'optional_exercise_ids', to_jsonb(v_opt_ids)
          )
        );
        CONTINUE;
      END IF;

      -- Workout days: build core = abs×2 + obliques×1 = 3 (candidate)
      -- Start with abs×2
      v_core_ids := ARRAY[]::TEXT[];
      IF array_length(v_abs_ids, 1) >= 2 THEN
        v_core_ids := v_core_ids || v_abs_ids[1:2];
      ELSIF array_length(v_abs_ids, 1) >= 1 THEN
        v_core_ids := v_core_ids || v_abs_ids[1:1];
      END IF;
      -- Add obliques×1
      IF array_length(v_obliques_ids, 1) >= 1 THEN
        v_core_ids := v_core_ids || v_obliques_ids[1:1];
      END IF;

      -- Combine main + core
      v_all_ids := v_main_ids || v_core_ids;
      v_total   := array_length(v_all_ids, 1);

      RAISE LOG '[ENGINE] STEP4 week=% day=% type=% main=% core=% total=%',
        v_week_idx, v_day_idx, v_day_type,
        array_length(v_main_ids,1), array_length(v_core_ids,1), v_total;

      -- Ensure EVEN total
      IF v_total % 2 != 0 THEN
        -- Total is ODD → add one more core exercise to make EVEN
        -- Try abs[3] first, then obliques[2]
        IF array_length(v_abs_ids, 1) >= 3 THEN
          v_core_ids := v_core_ids || v_abs_ids[3:3];
          v_all_ids  := v_main_ids || v_core_ids;
        ELSIF array_length(v_obliques_ids, 1) >= 2 THEN
          v_core_ids := v_core_ids || v_obliques_ids[2:2];
          v_all_ids  := v_main_ids || v_core_ids;
        END IF;
        -- If still odd (not enough core data), accept as-is
        RAISE LOG '[ENGINE] STEP4 total was odd → adjusted to % (even=%)',
          array_length(v_all_ids,1), (array_length(v_all_ids,1) % 2 = 0);
      END IF;

      -- BUILD OBJECTS WITH SETS/REPS
      v_all_objects := ARRAY[]::JSONB[];
      FOR i IN 1..array_length(v_all_ids, 1) LOOP
        v_ex_id := v_all_ids[i];
        v_sets := v_base_sets;
        v_reps := v_base_reps;
        
        IF v_ex_id = ANY(v_core_ids) THEN
          v_reps := 20; -- Core exercises
        ELSE
          SELECT exercise_type INTO v_ex_type FROM exercises WHERE id = v_ex_id LIMIT 1;
          IF v_ex_type = 'compound' THEN
            v_reps := GREATEST(1, v_reps - 2); -- Reduce reps
          END IF;
          -- isolation keeps normal reps
        END IF;
        
        v_all_objects := v_all_objects || jsonb_build_object('id', v_ex_id, 'sets', v_sets, 'reps', v_reps);
      END LOOP;

      -- optional_exercise_ids = IDs that are core (abs/obliques)
      v_opt_ids := v_core_ids;

      v_week_json := v_week_json || jsonb_build_object(
        v_day_idx::TEXT,
        jsonb_build_object(
          'type',                  v_day_type,
          'exercises',             to_jsonb(v_all_objects),
          'optional_exercise_ids', to_jsonb(v_opt_ids)
        )
      );
    END LOOP;

    v_weeks_json := v_weeks_json || jsonb_build_object(v_week_idx::TEXT, v_week_json);
  END LOOP;

  RAISE LOG '[ENGINE] STEP4 SCHEDULE BUILT: % weeks', v_weeks;

  -- ── STEP 5: Insert into ai_plans ──────────────────────────
  UPDATE ai_plans SET is_active = false WHERE user_id = p_user_id AND is_active = true;

  INSERT INTO ai_plans (
    user_id, created_at, is_active, schedule_json,
    plan_duration_days, days_per_week, slug_used, gender
  ) VALUES (
    p_user_id,
    now(),
    true,
    jsonb_build_object(
      'engine_version',     '2.3',
      'goal',               v_goal,
      'gender',             v_gender,
      'location',           v_location,
      'days_per_week',      v_days,
      'weeks_count',        v_weeks,
      'plan_duration_days', v_weeks * 7,
      'generated_at',       now()::TEXT,
      'weeks',              v_weeks_json
    ),
    v_weeks * 7,
    v_days,
    v_goal || '_' || v_location || '_' || v_days::TEXT || 'd_' || v_gender,
    v_gender
  )
  RETURNING id INTO v_plan_id;

  RAISE LOG '[ENGINE] STEP5 INSERTED: plan_id=%', v_plan_id;

  RETURN jsonb_build_object(
    'status',  'success',
    'plan_id', v_plan_id,
    'goal',    v_goal,
    'gender',  v_gender,
    'location',v_location,
    'days',    v_days,
    'weeks',   v_weeks
  );

EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[ENGINE] FATAL ERROR for user=%: %', p_user_id, SQLERRM;
  RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
