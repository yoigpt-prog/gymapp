const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws';

const userId = "cacc44fd-916a-42f7-80e0-72246184284c";

async function generatePlan() {
    const url = 'https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/rpc/generate_user_workout_plan';
    const res = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'apikey': anonKey,
            'Authorization': `Bearer ${anonKey}`
        },
        body: JSON.stringify({ p_user_id: userId })
    });
    const data = await res.json();
    console.log("--- RPC Result ---");
    console.log(JSON.stringify(data, null, 2));

    if (data.ai_plan_id) {
        const planId = data.ai_plan_id;

        // Fetch the plan JSON
        const url2 = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/ai_plans?id=eq.${planId}&select=schedule_json`;
        const res2 = await fetch(url2, {
            headers: { 'apikey': anonKey, 'Authorization': `Bearer ${anonKey}` }
        });
        const aiPlan = await res2.json();
        console.log("--- Schedule JSON ---");
        console.log(JSON.stringify(aiPlan[0], null, 2));

        // Fetch the relational exercises for day 1
        // First get the day 1 id
        const url3 = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/user_workout_days?ai_plan_id=eq.${planId}&day_number=eq.1&select=id`;
        const res3 = await fetch(url3, {
            headers: { 'apikey': anonKey, 'Authorization': `Bearer ${anonKey}` }
        });
        const day1 = await res3.json();
        if (day1.length > 0) {
            const url4 = `https://wewztpamzhrzbbgyutyf.supabase.co/rest/v1/user_workout_exercises?user_workout_day_id=eq.${day1[0].id}&select=exercise_id,exercise_order&order=exercise_order.asc`;
            const res4 = await fetch(url4, {
                headers: { 'apikey': anonKey, 'Authorization': `Bearer ${anonKey}` }
            });
            const exercisesDay1 = await res4.json();
            console.log("--- Relational Exercises (Day 1) ---");
            console.log(JSON.stringify(exercisesDay1, null, 2));
        }
    }
}

generatePlan();
