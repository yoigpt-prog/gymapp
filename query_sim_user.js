const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws';

async function fetchUserPrefs() {
    const url = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/user_preferences?user_id=eq.cacc44fd-916a-42f7-80e0-72246184284c`;
    const res = await fetch(url, {
        headers: {
            'apikey': anonKey,
            'Authorization': `Bearer ${anonKey}`
        }
    });
    console.log(await res.text());
}
fetchUserPrefs();
