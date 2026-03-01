const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws';

async function fetchTable(table) {
    const url = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/${table}?limit=1`;
    const res = await fetch(url, {
        headers: {
            'apikey': anonKey,
            'Authorization': `Bearer ${anonKey}`,
            'Prefer': 'return=representation'
        }
    });
    console.log(`--- ${table} ---`);
    console.log(await res.text());
}

async function fetchColumns(table) {
    const url = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/${table}`;
    const res = await fetch(url, {
        method: 'OPTIONS',
        headers: {
            'apikey': anonKey,
            'Authorization': `Bearer ${anonKey}`
        }
    });
    console.log(`--- ${table} OPTIONS ---`);
    // Not 100% sure if OPTIONS returns column names, but worth a shot.
    console.log(res.headers.get('Allow'));
}

async function run() {
    await fetchTable('user_workout_days');
    await fetchTable('user_workout_exercises');
    await fetchTable('program_templates');
    await fetchTable('ai_plans');
}
run();
