import re

with open('supabase/migrations/20260512_simple_workout_engine.sql', 'r') as f:
    sql = f.read()

# 1. Add DECLARE variables
declare_additions = """  v_experience    TEXT;
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
"""
sql = sql.replace("  v_plan_id       UUID;\nBEGIN", declare_additions + "  v_plan_id       UUID;\nBEGIN")

# 2. Add preferences parsing
prefs_sql_old = """    lower(trim(COALESCE(training_location, 'gym'))),
    COALESCE(training_days, 3),
    COALESCE(duration_weeks, 4)
  INTO v_goal, v_gender, v_location, v_days, v_weeks"""
prefs_sql_new = """    lower(trim(COALESCE(training_location, 'gym'))),
    COALESCE(training_days, 3),
    COALESCE(duration_weeks, 4),
    lower(trim(COALESCE(experience_level, 'beginner'))),
    COALESCE(session_duration, '45 min')
  INTO v_goal, v_gender, v_location, v_days, v_weeks, v_experience, v_duration"""
sql = sql.replace(prefs_sql_old, prefs_sql_new)

# 3. Add derivation logic
exp_logic = """
  v_duration_mins := COALESCE(NULLIF(regexp_replace(v_duration, '\D', '', 'g'), ''), '45');
  v_exp_key := v_experience;
  IF v_matrix_config->v_exp_key IS NULL THEN v_exp_key := 'beginner'; END IF;
  
  -- Default fallback if duration key missing
  IF v_matrix_config->v_exp_key->v_duration_mins IS NULL THEN
    v_duration_mins := '45';
  END IF;

  v_base_sets := (v_matrix_config->v_exp_key->v_duration_mins->>'sets')::INT;
  v_base_reps := (v_matrix_config->v_exp_key->v_duration_mins->>'reps')::INT;
  
  RAISE LOG '[ENGINE] STEP1 PREFS: exp=% dur=% base=%x%', v_exp_key, v_duration_mins, v_base_sets, v_base_reps;
"""
sql = sql.replace("v_weeks := GREATEST(1, LEAST(52, v_weeks));", "v_weeks := GREATEST(1, LEAST(52, v_weeks));\n" + exp_logic)

# 4. Modify STEP 4 loop logic
loop_logic_old = """      -- optional_exercise_ids = IDs that are core (abs/obliques)
      v_opt_ids := v_core_ids;

      v_week_json := v_week_json || jsonb_build_object(
        v_day_idx::TEXT,
        jsonb_build_object(
          'type',                  v_day_type,
          'exercises',             to_jsonb(v_all_ids),
          'optional_exercise_ids', to_jsonb(v_opt_ids)
        )
      );"""

loop_logic_new = """      -- BUILD OBJECTS WITH SETS/REPS
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
      );"""
sql = sql.replace(loop_logic_old, loop_logic_new)

# For cardio days, we also need to build objects.
cardio_loop_old = """        v_week_json := v_week_json || jsonb_build_object(
          v_day_idx::TEXT,
          jsonb_build_object(
            'type',                 v_day_type,
            'exercises',            to_jsonb(v_all_ids),
            'optional_exercise_ids', to_jsonb(v_opt_ids)
          )
        );"""

cardio_loop_new = """        v_all_objects := ARRAY[]::JSONB[];
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
        );"""
sql = sql.replace(cardio_loop_old, cardio_loop_new)

with open('supabase/migrations/20260512_simple_workout_engine.sql', 'w') as f:
    f.write(sql)
print("Patcher completed.")
