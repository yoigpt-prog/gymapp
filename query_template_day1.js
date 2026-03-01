const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws';

async function fetchExercisesInTemplate() {
    const url = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/program_templates?template_key=eq.fat_loss_gym_4d&day_index=eq.1&order=exercise_order.asc`;
    const res = await fetch(url, {
        headers: { 'apikey': anonKey, 'Authorization': `Bearer ${anonKey}` }
    });
    const data = await res.json();
    console.log("--- fat_loss_gym_4d Day 1 ---");
    console.log(JSON.stringify(data, null, 2));
}

fetchExercisesInTemplate();
