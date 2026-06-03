import os
import time
from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

if not all([SUPABASE_URL, SUPABASE_KEY]):
    print("Missing environment variables. Set SUPABASE_URL and SUPABASE_SERVICE_KEY.")
    exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

print("Fetching exercises to sync calories...")
all_ex = []
offset = 0
while True:
    res = supabase.table('exercises').select('id, param_calories').range(offset, offset + 999).execute()
    all_ex.extend(res.data)
    if len(res.data) < 1000:
        break
    offset += 1000

print(f"Found {len(all_ex)} total exercises. Syncing calories into SEO table...")
success = 0
for ex in all_ex:
    cal = ex.get('param_calories')
    if cal and str(cal).strip() != "0":
        try:
            supabase.table('exercise_seo').update({'estimated_calories_burned': str(cal)}).eq('exercise_id', ex['id']).execute()
            success += 1
        except Exception as e:
            pass

print(f"DONE! Successfully synced calories for {success} exercises.")
