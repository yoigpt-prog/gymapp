-- Sample Plan Templates for Workout Plan Generation
-- This script creates sample templates for testing the quiz-based plan generation

-- Template JSON Structure:
-- {
--   "week": {
--     "1": { "type": "workout", "exercises": ["000001", "000002", ...] },
--     "2": { "type": "rest" },
--     ...
--   }
-- }

-- 1. Female Fat Loss Home 6 Days/Week
INSERT INTO public.plan_templates (slug, title, template_json, is_active)
VALUES (
  'female_fat_loss_home_6d',
  'Female Fat Loss - Home - 6 Days/Week',
  '{
    "week": {
      "1": {
        "type": "workout",
        "exercises": ["000001", "000002", "000003", "000004", "000005", "000006"]
      },
      "2": {
        "type": "workout",
        "exercises": ["000007", "000008", "000009", "000010", "000011", "000012"]
      },
      "3": {
        "type": "workout",
        "exercises": ["000013", "000014", "000015", "000016", "000017", "000018"]
      },
      "4": {
        "type": "workout",
        "exercises": ["000019", "000020", "000021", "000022", "000023", "000024"]
      },
      "5": {
        "type": "workout",
        "exercises": ["000025", "000026", "000027", "000028", "000029", "000030"]
      },
      "6": {
        "type": "workout",
        "exercises": ["000031", "000032", "000033", "000034", "000035", "000036"]
      },
      "7": {
        "type": "rest"
      }
    }
  }'::jsonb,
  true
)
ON CONFLICT (slug) DO UPDATE
SET template_json = EXCLUDED.template_json,
    title = EXCLUDED.title;

-- 2. Female Build Muscle Gym 5 Days/Week
INSERT INTO public.plan_templates (slug, title, template_json, is_active)
VALUES (
  'female_build_muscle_gym_5d',
  'Female Build Muscle - Gym - 5 Days/Week',
  '{
    "week": {
      "1": {
        "type": "workout",
        "exercises": ["000037", "000038", "000039", "000040", "000041"]
      },
      "2": {
        "type": "workout",
        "exercises": ["000042", "000043", "000044", "000045", "000046"]
      },
      "3": {
        "type": "rest"
      },
      "4": {
        "type": "workout",
        "exercises": ["000047", "000048", "000049", "000050", "000051"]
      },
      "5": {
        "type": "workout",
        "exercises": ["000052", "000053", "000054", "000055", "000056"]
      },
      "6": {
        "type": "workout",
        "exercises": ["000057", "000058", "000059", "000060", "000061"]
      },
      "7": {
        "type": "rest"
      }
    }
  }'::jsonb,
  true
)
ON CONFLICT (slug) DO UPDATE
SET template_json = EXCLUDED.template_json,
    title = EXCLUDED.title;

-- 3. Male Build Muscle Gym 5 Days/Week  
INSERT INTO public.plan_templates (slug, title, template_json, is_active)
VALUES (
  'male_build_muscle_gym_5d',
  'Male Build Muscle - Gym - 5 Days/Week',
  '{
    "week": {
      "1": {
        "type": "workout",
        "exercises": ["000062", "000063", "000064", "000065", "000066"]
      },
      "2": {
        "type": "workout",
        "exercises": ["000067", "000068", "000069", "000070", "000071"]
      },
      "3": {
        "type": "rest"
      },
      "4": {
        "type": "workout",
        "exercises": ["000072", "000073", "000074", "000075", "000076"]
      },
      "5": {
        "type": "workout",
        "exercises": ["000077", "000078", "000079", "000080", "000081"]
      },
      "6": {
        "type": "workout",
        "exercises": ["000082", "000083", "000084", "000085", "000086"]
      },
      "7": {
        "type": "rest"
      }
    }
  }'::jsonb,
  true
)
ON CONFLICT (slug) DO UPDATE
SET template_json = EXCLUDED.template_json,
    title = EXCLUDED.title;

-- 4. Male Fat Loss Home 4 Days/Week
INSERT INTO public.plan_templates (slug, title, template_json, is_active)
VALUES (
  'male_fat_loss_home_4d',
  'Male Fat Loss - Home - 4 Days/Week',
  '{
    "week": {
      "1": {
        "type": "workout",
        "exercises": ["000087", "000088", "000089", "000090", "000091", "000092"]
      },
      "2": {
        "type": "rest"
      },
      "3": {
        "type": "workout",
        "exercises": ["000093", "000094", "000095", "000096", "000097", "000098"]
      },
      "4": {
        "type": "rest"
      },
      "5": {
        "type": "workout",
        "exercises": ["000099", "000100", "000101", "000102", "000103", "000104"]
      },
      "6": {
        "type": "rest"
      },
      "7": {
        "type": "workout",
        "exercises": ["000105", "000106", "000107", "000108", "000109", "000110"]
      }
    }
  }'::jsonb,
  true
)
ON CONFLICT (slug) DO UPDATE
SET template_json = EXCLUDED.template_json,
    title = EXCLUDED.title;

-- 5. Female Fat Loss Gym 3 Days/Week
INSERT INTO public.plan_templates (slug, title, template_json, is_active)
VALUES (
  'female_fat_loss_gym_3d',
  'Female Fat Loss - Gym - 3 Days/Week',
  '{
    "week": {
      "1": {
        "type": "workout",
        "exercises": ["000111", "000112", "000113", "000114", "000115", "000116"]
      },
      "2": {
        "type": "rest"
      },
      "3": {
        "type": "workout",
        "exercises": ["000117", "000118", "000119", "000120", "000121", "000122"]
      },
      "4": {
        "type": "rest"
      },
      "5": {
        "type": "workout",
        "exercises": ["000123", "000124", "000125", "000126", "000127", "000128"]
      },
      "6": {
        "type": "rest"
      },
      "7": {
        "type": "rest"
      }
    }
  }'::jsonb,
  true
)
ON CONFLICT (slug) DO UPDATE
SET template_json = EXCLUDED.template_json,
    title = EXCLUDED.title;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload config';

-- Verification: Check what templates were created
SELECT slug, is_active, created_at FROM public.plan_templates ORDER BY slug;
