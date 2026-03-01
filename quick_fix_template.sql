-- Quick Fix: Just add the missing template for the failed test
-- Run this in Supabase SQL Editor

INSERT INTO public.plan_templates (slug, template_json, is_active, created_at, updated_at)
VALUES (
  'female_fat_loss_home_6d',
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
  true,
  NOW(),
  NOW()
)
ON CONFLICT (slug) DO UPDATE
SET template_json = EXCLUDED.template_json,
    updated_at = NOW();

-- Verify it was created
SELECT slug, is_active FROM public.plan_templates WHERE slug = 'female_fat_loss_home_6d';
