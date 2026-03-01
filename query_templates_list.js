const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws';

async function fetchDistinctTemplates() {
    const url = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/program_templates?select=template_key,goal_code,training_location,training_days&limit=1000`;
    const res = await fetch(url, {
        headers: {
            'apikey': anonKey,
            'Authorization': `Bearer ${anonKey}`
        }
    });
    const data = await res.json();

    // Get distinct templates
    const distinct = {};
    for (const row of data) {
        distinct[row.template_key] = row;
    }

    console.log("--- Available Templates ---");
    for (const key in distinct) {
        console.log(JSON.stringify(distinct[key]));
    }
}
fetchDistinctTemplates();
