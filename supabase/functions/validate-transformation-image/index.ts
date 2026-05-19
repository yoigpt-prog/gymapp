// @ts-nocheck
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SYSTEM_PROMPT = `You are an AI image validator for a fitness app.
Your task is to analyze an uploaded photo to determine if it is suitable for an AI body transformation.
This system is for realistic body transformation previews for normal people, not bodybuilding competition photos.

ACCEPT the image if ALL the following are true:
- It contains exactly ONE real human
- The person is facing mostly toward the camera
- The person is standing or mostly standing
- The upper body, waist, and legs are visible
- The image is reasonably clear and body shape can generally be understood
- It is suitable for AI body transformation generation

IMPORTANT - DO NOT REJECT FOR THESE REASONS:
- DO NOT require visible abs or visible muscle definition.
- DO NOT require gym clothing or tight clothing.
- DO NOT require athletic pose, perfect lighting, perfectly visible feet, or a professional fitness photo.
- DO NOT require a fully uncovered body.
- YOU MUST ACCEPT overweight people, obese people, sweatpants, hoodies, crop sweaters, loose clothing, indoor home photos, slightly cropped feet, and casual posture.

ONLY REJECT IF:
- There is no person, or multiple people
- The person is back-facing or side-facing only
- The image is blurry beyond recognition or extremely dark
- The body is mostly hidden
- It is a close-up selfie only
- It is an object, landscape, pet, or screenshot
- The person is sitting or lying in a way body shape cannot be analyzed

You MUST return ONLY valid JSON matching this exact structure:
{
  "valid": true|false,
  "reason": "<reason_code>"
}

Possible <reason_code> values:

If valid:
- "valid"

If invalid:
- "invalid_no_person" (landscapes, objects, waterfalls, screenshots, pets, etc.)
- "invalid_wrong_content" (not a photo of a person)
- "invalid_not_front_facing" (back turned, side profile only)
- "invalid_not_full_body" (close-up selfie, severely cropped head/legs, sitting/lying such that body cannot be analyzed)
- "invalid_multiple_people" (more than one person)
- "invalid_blurry"
- "invalid_dark"
- "invalid_hidden_body" (body mostly hidden)

Return ONLY the JSON object. No markdown, no code fences, no extra text.`;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Auth
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

    // Parse request
    const { imageBase64 } = await req.json();
    if (!imageBase64) {
      return new Response(JSON.stringify({ error: 'Missing required field: imageBase64' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Call GPT-4o Vision
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
        max_tokens: 300,
        temperature: 0.1, // Low temperature for consistent validation
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
                text: 'Please validate this image and return the JSON.',
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${imageBase64}`,
                  detail: 'low', // 'low' is usually sufficient for full body validation and saves tokens/time
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

    let resultJson: Record<string, unknown>;
    try {
      const cleaned = rawContent.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
      resultJson = JSON.parse(cleaned);
    } catch (parseErr) {
      throw new Error(`Failed to parse GPT-4o JSON response: ${rawContent}`);
    }

    return new Response(
      JSON.stringify(resultJson),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[validate-transformation-image] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message ?? 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
