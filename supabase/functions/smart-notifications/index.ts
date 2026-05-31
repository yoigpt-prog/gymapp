import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "835968ac-39d8-4125-9246-fe243ba89e35";
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") || "";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function sendOneSignalPush(userId: string, heading: string, content: string, data: any) {
    if (!ONESIGNAL_REST_API_KEY) {
        console.warn("No OneSignal REST API Key provided, skipping push for", userId);
        return false;
    }

    const payload = {
        app_id: ONESIGNAL_APP_ID,
        target_channel: "push",
        include_aliases: {
            external_id: [userId]
        },
        headings: { en: heading },
        contents: { en: content },
        data: data,
        chrome_web_icon: "https://www.gymguide.co/favicon.png",
    };

    try {
        const response = await fetch("https://onesignal.com/api/v1/notifications", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`
            },
            body: JSON.stringify(payload)
        });
        const result = await response.json();
        console.log("OneSignal response:", result);
        return !result.errors;
    } catch (e) {
        console.error("Error sending push:", e);
        return false;
    }
}

async function getLocalHour(timezone: string): Promise<number> {
    try {
        const formatter = new Intl.DateTimeFormat('en-US', {
            timeZone: timezone,
            hour: 'numeric',
            hour12: false
        });
        const parts = formatter.formatToParts(new Date());
        const hourPart = parts.find(p => p.type === 'hour');
        return hourPart ? parseInt(hourPart.value) : 12;
    } catch (e) {
        console.error("Invalid timezone:", timezone);
        return 12; // default
    }
}

async function checkAntiSpam(userId: string, isPremium: boolean, type: string): Promise<boolean> {
    const today = new Date().toISOString().split('T')[0];
    
    // Check if THIS type was already sent today
    const { data: specificLog } = await supabase
        .from('notification_logs')
        .select('id')
        .eq('user_id', userId)
        .eq('notification_type', type)
        .eq('date', today)
        .maybeSingle();

    if (specificLog) return false; // Already sent today

    // Check max per day
    const { count } = await supabase
        .from('notification_logs')
        .select('id', { count: 'exact' })
        .eq('user_id', userId)
        .eq('date', today);
    
    const currentCount = count || 0;
    if (isPremium && currentCount >= 5) return false;
    if (!isPremium && currentCount >= 1) return false;

    // Free users 48h check
    if (!isPremium) {
        const twoDaysAgo = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
        const { data: recentLog } = await supabase
            .from('notification_logs')
            .select('id')
            .eq('user_id', userId)
            .gte('sent_at', twoDaysAgo)
            .limit(1);
        if (recentLog && recentLog.length > 0) return false;
    }

    return true;
}

async function trackMixpanelEvent(userId: string, eventName: string) {
    const MIXPANEL_TOKEN = Deno.env.get("MIXPANEL_TOKEN") || "a4c6fa788d6f31bf712bf5ed7cb87b2c";
    try {
        const payload = [{
            event: eventName,
            properties: {
                token: MIXPANEL_TOKEN,
                distinct_id: userId,
                time: Math.floor(Date.now() / 1000),
                $insert_id: crypto.randomUUID(),
                source: "edge_function_smart_notifications"
            }
        }];
        await fetch("https://api.mixpanel.com/track", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });
    } catch (e) {
        console.error("Mixpanel error:", e);
    }
}

async function logNotification(userId: string, type: string) {
    const today = new Date().toISOString().split('T')[0];
    await supabase.from('notification_logs').insert({
        user_id: userId,
        notification_type: type,
        date: today,
        status: 'sent'
    });
    
    // Track in Mixpanel
    let mixpanelEvent = "";
    if (type === "meal_breakfast" || type === "meal_lunch" || type === "meal_dinner") mixpanelEvent = "Meal Reminder Sent";
    if (type === "workout_reminder") mixpanelEvent = "Workout Reminder Sent";
    if (type === "missed_workout") mixpanelEvent = "Missed Workout Reminder Sent";
    if (type === "missed_meal") mixpanelEvent = "Missed Meal Reminder Sent";
    if (mixpanelEvent) {
        await trackMixpanelEvent(userId, mixpanelEvent);
    }
}

serve(async (req) => {
    try {
        console.log("Starting Smart Notifications Job");
        
        // 1. Fetch users and preferences
        const { data: users, error } = await supabase
            .from('user_preferences')
            .select('*');

        if (error) throw error;

        const { data: preferences, error: prefsError } = await supabase
            .from('notification_preferences')
            .select('*');

        if (prefsError) throw prefsError;

        console.log('Users:', users?.length || 0);
        console.log('Preferences:', preferences?.length || 0);

        const usersWithPrefs = (users || []).map(user => ({
            ...user,
            notification_preferences: (preferences || []).find(p => p.user_id === user.user_id) || {
                workout_reminders: true,
                meal_reminders: true,
                hydration_reminders: true,
                sleep_reminders: true,
                motivation_reminders: true
            }
        }));

        for (const user of usersWithPrefs) {
            const prefs = user.notification_preferences;

            const timezone = user.timezone || 'UTC';
            const localHour = await getLocalHour(timezone);

            // Never send during sleep (11 PM - 7 AM)
            if (localHour >= 23 || localHour < 7) continue;

            let pushSent = false;

            // Flow A: Did not start quiz
            if (!user.quiz_started) {
                if (await checkAntiSpam(user.user_id, user.premium, 'quiz_reminder')) {
                    const success = await sendOneSignalPush(
                        user.user_id,
                        "Your plan is waiting \uD83D\uDCAA",
                        "Start your quiz and unlock your transformation.",
                        { route: '/onboarding' }
                    );
                    if (success) await logNotification(user.user_id, 'quiz_reminder');
                }
                continue; // Stop processing other rules for this user
            }

            // Flow B: Started quiz but did not complete
            if (user.quiz_started && !user.quiz_completed) {
                if (await checkAntiSpam(user.user_id, user.premium, 'quiz_incomplete')) {
                    const success = await sendOneSignalPush(
                        user.user_id,
                        "Finish what you started \uD83D\uDD25",
                        "Complete your quiz to generate your AI plan.",
                        { route: '/onboarding' }
                    );
                    if (success) await logNotification(user.user_id, 'quiz_incomplete');
                }
                continue;
            }

            // Flow C: Completed quiz but not premium
            if (user.quiz_completed && !user.premium) {
                const freemiumOptions = [
                    { type: 'premium_upsell', heading: "Day 2 is ready ⭐", content: "Unlock your full personalized plan and start crushing goals.", route: '/paywall' },
                    { type: 'freemium_ai_transform', heading: "See your future body ✨", content: "Try the AI Transformation Simulator and preview your future body .", route: '/ai-transformation-simulator' },
                    { type: 'freemium_rate_body', heading: "Rate your physique 📸", content: "Get an AI body score and see what to improve next.", route: '/rate-your-body' }
                ];
                
                const dayIndex = Math.floor(Date.now() / (1000 * 60 * 60 * 24)) % freemiumOptions.length;
                const selected = freemiumOptions[dayIndex];

                if (await checkAntiSpam(user.user_id, user.premium, selected.type)) {
                    const success = await sendOneSignalPush(
                        user.user_id,
                        selected.heading,
                        selected.content,
                        { route: selected.route }
                    );
                    if (success) await logNotification(user.user_id, selected.type);
                }
                continue;
            }

            // ONLY PREMIUM USERS BELOW
            if (!user.premium) continue;

            // Example: Meal Reminders (if enabled)
            if (prefs.meal_reminders) {
                if (localHour >= 7 && localHour < 9 && await checkAntiSpam(user.user_id, true, 'meal_breakfast')) {
                    const success = await sendOneSignalPush(user.user_id, "Breakfast Time \uD83C\uDF73", "Fuel your body for the day ahead.", { route: '/meal-plan' });
                    if (success) await logNotification(user.user_id, 'meal_breakfast');
                } else if (localHour >= 12 && localHour < 14 && await checkAntiSpam(user.user_id, true, 'meal_lunch')) {
                    const success = await sendOneSignalPush(user.user_id, "Lunch Time 🥗", "Time for your mid-day refuel.", { route: '/meal-plan' });
                    if (success) await logNotification(user.user_id, 'meal_lunch');
                } else if (localHour >= 15 && localHour < 17 && await checkAntiSpam(user.user_id, true, 'meal_snack')) {
                    const success = await sendOneSignalPush(user.user_id, "Snack Time 🍎", "Keep your energy up with a healthy snack.", { route: '/meal-plan' });
                    if (success) await logNotification(user.user_id, 'meal_snack');
                } else if (localHour >= 19 && localHour < 21 && await checkAntiSpam(user.user_id, true, 'meal_dinner')) {
                    const success = await sendOneSignalPush(user.user_id, "Dinner Time 🍖", "Finish the day strong with a healthy meal.", { route: '/meal-plan' });
                    if (success) await logNotification(user.user_id, 'meal_dinner');
                }
            }

            // Example: Sleep Reminder
            if (prefs.sleep_reminders && localHour >= 21 && localHour < 23) {
                if (await checkAntiSpam(user.user_id, true, 'sleep_reminder')) {
                    const success = await sendOneSignalPush(user.user_id, "Time to Wind Down \uD83C\uDF19", "Good sleep is crucial for recovery. Get ready for bed.", { route: '/home' });
                    if (success) await logNotification(user.user_id, 'sleep_reminder');
                }
            }
            
            // Note: Workout and Missed Workout reminders would ideally check `workout_completed_today` 
            // from the synced app state or another table in the database.
            // ... (Additional rules implemented here)
        }

        return new Response(JSON.stringify({ success: true, message: "Notifications processed" }), {
            headers: { "Content-Type": "application/json" },
        });

    } catch (err: any) {
        console.error("Error processing notifications:", err);
        return new Response(JSON.stringify({ success: false, error: err.message }), {
            headers: { "Content-Type": "application/json" },
            status: 500
        });
    }
});
