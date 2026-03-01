const url = 'https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/rpc/generate_user_workout_plan';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws';

fetch(url, {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'apikey': anonKey,
        'Authorization': `Bearer ${anonKey}`
    },
    body: JSON.stringify({ p_user_id: '4093307f-0fad-4dd1-be93-8565801fdb6b' })
})
    .then(res => res.json())
    .then(json => console.log('RPC Result:', JSON.stringify(json, null, 2)))
    .catch(err => console.error(err));
