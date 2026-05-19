// @ts-nocheck
// analyze-physique/index.ts
// Supabase Edge Function — calls GPT-4o Vision for physique analysis
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ── GPT-4o system prompt ───────────────────────────────────────────────────
const SYSTEM_PROMPT = `You are a professional fitness coach and physique analyst. 
Analyze the user's physique from the uploaded photo.

FIRST, validate the photo. It must be a photo of exactly one real person, mostly front-facing and standing, where the upper body, waist, and legs are visible, and the body shape can generally be understood.
If the photo is clearly invalid (e.g., no person, multiple people, back-facing, blurry beyond recognition, extremely dark, body mostly hidden, close-up selfie only, object/landscape/pet), return exactly this JSON:
{
  "success": false,
  "error_code": "invalid_physique_photo",
  "message": "<a polite, brief reason why the photo was rejected>"
}

IMPORTANT VALIDATION RULES (DO NOT REJECT FOR THESE REASONS):
- DO NOT require visible abs or visible muscle definition.
- DO NOT require gym clothing or tight clothing.
- DO NOT require athletic pose, perfect lighting, perfectly visible feet, or a professional fitness photo.
- DO NOT require a fully uncovered body.
- YOU MUST ACCEPT overweight people, obese people, sweatpants, hoodies, crop sweaters, loose clothing, indoor home photos, slightly cropped feet, and casual posture.
- This system is for realistic analysis for normal people, not bodybuilding competition photos.

If the photo is valid, return a structured, fitness-focused assessment.

STRICT RULES for assessment:
- Be positive, motivational, and realistic
- Focus ONLY on fitness metrics — body composition, proportions, muscle development
- NEVER mention attractiveness, beauty, or compare to celebrities
- NEVER shame body fat or use negative language
- NEVER give medical advice
- NEVER mention specific body weight estimates
- Keep tone encouraging — like a supportive personal trainer

You MUST return ONLY valid JSON matching this exact structure:
{
  "success": true,
  "overall_score": <number 1.0–10.0 with one decimal>,
  "score_label": "<short label like 'Lean Foundation' or 'Athletic Build' or 'Solid Base'>",
  "physique_breakdown": {
    "symmetry": <number 1.0–10.0>,
    "v_taper": <number 1.0–10.0>,
    "muscularity": <number 1.0–10.0>,
    "body_fat": <number 1.0–10.0, higher = leaner>,
    "proportions": <number 1.0–10.0>,
    "shoulder_width": <number 1.0-10.0>,
    "chest_development": <number 1.0-10.0>,
    "arm_development": <number 1.0-10.0>,
    "leg_balance": <number 1.0-10.0>
  },
  "strengths": [<2–4 short strength strings>],
  "focus_areas": [<2–4 short area strings>],
  "body_type": "<descriptive body type label>",
  "ai_summary": "<2–3 motivational sentences focusing on potential and next steps>"
}

Return ONLY the JSON object. No markdown, no code fences, no extra text.`;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Auth ─────────────────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Parse request ────────────────────────────────────────────────────────
    const { analysisId, imageBase64 } = await req.json();

    if (!analysisId || !imageBase64) {
      return new Response(JSON.stringify({ error: 'Missing required fields: analysisId, imageBase64' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Validate analysisId belongs to authenticated user ────────────────────
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: existingRow, error: rowError } = await serviceClient
      .from('physique_analyses')
      .select('id, user_id, status')
      .eq('id', analysisId)
      .eq('user_id', user.id)
      .single();

    if (rowError || !existingRow) {
      return new Response(JSON.stringify({ error: 'Analysis record not found or access denied' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // If already completed, return existing result
    if (existingRow.status === 'completed') {
      const { data: completedRow } = await serviceClient
        .from('physique_analyses')
        .select('result_json')
        .eq('id', analysisId)
        .single();

      return new Response(JSON.stringify({ result: completedRow?.result_json }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Check yearly usage limit ─────────────────────────────────────────────
    const currentYear = new Date().getFullYear();
    const { data: usageRow, error: usageError } = await serviceClient
      .from('ai_feature_usage')
      .select('usage_count')
      .eq('user_id', user.id)
      .eq('feature', 'rate_my_physique')
      .eq('year', currentYear)
      .maybeSingle();

    if (usageError) {
      console.error('[analyze-physique] Error checking yearly usage:', usageError);
    }

    if (usageRow && usageRow.usage_count >= 3) {
      return new Response(
        JSON.stringify({
          error_code: 'limit_reached',
          message: "You’ve reached your  limit for Rate My Physique AI. Please try again .",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // ── Call GPT-4o Vision ───────────────────────────────────────────────────
    const openaiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openaiKey) {
      throw new Error('OPENAI_API_KEY environment variable not set');
    }

    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        max_tokens: 1200,
        temperature: 0.4,
        messages: [
          {
            role: 'system',
            content: SYSTEM_PROMPT,
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Please analyze my physique from this photo and return the structured JSON assessment.',
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${imageBase64}`,
                  detail: 'high',
                },
              },
            ],
          },
        ],
      }),
    });

    if (!openaiResponse.ok) {
      const errText = await openaiResponse.text();
      throw new Error(`OpenAI API error (${openaiResponse.status}): ${errText}`);
    }

    const openaiData = await openaiResponse.json();
    const rawContent = openaiData.choices?.[0]?.message?.content;

    if (!rawContent) {
      throw new Error('GPT-4o returned empty response');
    }

    // ── Parse and validate JSON ──────────────────────────────────────────────
    let resultJson: Record<string, unknown>;
    try {
      // Strip any accidental markdown fences
      const cleaned = rawContent.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
      resultJson = JSON.parse(cleaned);
    } catch (parseErr) {
      throw new Error(`Failed to parse GPT-4o JSON response: ${rawContent}`);
    }

    if (resultJson.success === false) {
      // Photo rejected by GPT-4o
      // We return this exactly as-is so the client catches it
      await serviceClient
        .from('physique_analyses')
        .update({ status: 'failed', error_message: resultJson.message || 'Validation failed' })
        .eq('id', analysisId);
        
      return new Response(JSON.stringify(resultJson), {
        status: 200, // Important: 200 so the client parses the JSON instead of throwing generic error
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Basic validation — ensure required fields exist for valid assessment
    const requiredFields = ['overall_score', 'score_label', 'physique_breakdown', 'strengths', 'focus_areas', 'body_type', 'ai_summary'];
    for (const field of requiredFields) {
      if (!(field in resultJson)) {
        throw new Error(`GPT-4o response missing required field: ${field}`);
      }
    }

    // ── Store result in Supabase ─────────────────────────────────────────────
    const { error: updateError } = await serviceClient
      .from('physique_analyses')
      .update({
        result_json: resultJson,
        status: 'completed',
        updated_at: new Date().toISOString(),
      })
      .eq('id', analysisId);

    if (updateError) {
      throw new Error(`Failed to store result: ${updateError.message}`);
    }

    // ── Increment AI feature usage ───────────────────────────────────────────
    const { error: incrementError } = await serviceClient.rpc(
      'increment_ai_feature_usage',
      {
        p_user_id: user.id,
        p_feature: 'rate_my_physique',
        p_year: currentYear,
      }
    );

    if (incrementError) {
      console.error('[analyze-physique] Failed to increment usage:', incrementError);
    }

    return new Response(
      JSON.stringify({ result: resultJson }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[analyze-physique] Error:', error);

    // Try to mark the analysis as failed if we have the analysisId
    try {
      const body = await (req.clone()).json().catch(() => ({}));
      if (body.analysisId) {
        const serviceClient = createClient(
          Deno.env.get('SUPABASE_URL')!,
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        );
        await serviceClient
          .from('physique_analyses')
          .update({ status: 'failed', error_message: error.message })
          .eq('id', body.analysisId);
      }
    } catch (_) {}

    return new Response(
      JSON.stringify({ error: error.message ?? 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
