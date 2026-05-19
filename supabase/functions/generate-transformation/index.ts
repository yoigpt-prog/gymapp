// @ts-nocheck
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Auth ──────────────────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
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
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Parse request ─────────────────────────────────────────────────────────
    const { requestId, originalImageUrl, goal } = await req.json();
    if (!requestId || !originalImageUrl || !goal) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Check yearly usage limit ─────────────────────────────────────────────
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const currentYear = new Date().getFullYear();
    const { data: usageRow, error: usageError } = await serviceClient
      .from('ai_feature_usage')
      .select('usage_count')
      .eq('user_id', user.id)
      .eq('feature', 'ai_transformation')
      .eq('year', currentYear)
      .maybeSingle();

    if (usageError) {
      console.error('[generate-transformation] Error checking yearly usage:', usageError);
    }

    if (usageRow && usageRow.usage_count >= 3) {
      return new Response(
        JSON.stringify({
          error_code: 'limit_reached',
          message: "You’ve reached your  limit for AI Transformation Simulator. Please try again .",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // ── Build prompt based on goal ────────────────────────────────────────────
    const goalPrompts: Record<string, string> = {
      'Lose Weight': `Create a realistic healthy fitness progression of the SAME exact person from the uploaded image.

Preserve:
- identical face
- identical identity
- identical skin tone
- identical hairstyle
- identical room/background
- identical clothing
- identical camera angle
- identical pose
- identical lighting

Generate a visibly healthier and fitter version with:
- noticeably reduced belly fat
- slimmer waist
- reduced overall body volume
- toned but natural arms and legs
- improved posture
- flatter stomach WITHOUT six-pack abs
- realistic fat reduction across the whole body
- natural feminine/masculine proportions
- believable healthy progress

The transformation should look like:
"the same person after 8-12 months of realistic healthy fitness progress."

VERY IMPORTANT:
- Make the body change clearly visible.
- Prioritize realistic fat reduction instead of muscle gain.
- Keep soft natural body texture.
- Keep realistic skin folds and anatomy.
- Avoid exaggerated muscles.
- Avoid tiny waist.
- Avoid fitness model aesthetics.
- Avoid plastic AI skin.
- Avoid dramatic influencer-style transformation.

STYLE:
- ultra realistic smartphone photo
- authentic skin texture
- realistic indoor lighting
- realism over perfection
- believable human anatomy
- no CGI look`,
      'Build Muscle':
        'A photo of this exact same person after 1 year of dedicated weight training and clean eating. They now possess a noticeably more muscular and athletic physique with fuller arms, a broader chest, wider shoulders, and visible muscle mass throughout the body. The person\'s face, facial features, skin tone, hair, and hairstyle are 100% identical to the original photo. Keep the exact same background, lighting, and room. Only the body is more muscular and athletic — a believable 1-year natural muscle-building transformation.',
      'Lean Athletic':
        'A photo of this exact same person, but they now possess a lean, athletic, swimmer\'s physique. They have visible abs, a slim waist, and defined athletic muscles. The person\'s face, facial features, skin tone, hair, and hairstyle are 100% identical to the original photo. Keep the exact same background, lighting, and room. Only the body is lean and defined.',
      'Fat Loss':
        'A photo of this exact same person, but they now possess a very slim, highly conditioned endurance athlete physique. They have a completely flat stomach, very slim waist, and lean toned limbs. The person\'s face, facial features, skin tone, hair, and hairstyle are 100% identical to the original photo. Keep the exact same background, lighting, and room. Only the body is slim and conditioned.',
      'Shredded':
        'A photo of this exact same person, but they now possess an extremely shredded, professional fitness model physique. They have extreme muscle definition, ripped abs, and visible veins. The person\'s face, facial features, skin tone, hair, and hairstyle are 100% identical to the original photo. Keep the exact same background, lighting, and room. Only the body is shredded.',
      'Natural Fitness Model':
        'A photo of this exact same person, but they now possess a perfectly proportioned, lean fitness model physique. They have a toned stomach, slim waist, and highly aesthetic muscle definition. The person\'s face, facial features, skin tone, hair, and hairstyle are 100% identical to the original photo. Keep the exact same background, lighting, and room. Only the body is highly aesthetic and fit.',
      'Fit & Healthy':
        'A photo of this exact same person, but they now possess a vibrant, healthy, and toned athletic physique. They have a flat stomach and lean limbs with mild muscle tone. The person\'s face, facial features, skin tone, hair, and hairstyle are 100% identical to the original photo. Keep the exact same background, lighting, and room. Only the body is fit and healthy.',
    };

    const prompt = goalPrompts[goal] ?? goalPrompts['Build Muscle'];

    // ── Call OpenAI gpt-image-1 (img-to-img edit) ────────────────────────────
    const openaiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openaiKey) {
      throw new Error('OPENAI_API_KEY not set');
    }

    console.log('[generate-transformation] Starting gpt-image-1 edit with image:', originalImageUrl);

    // Download the original image so we can send it as a file to the edits endpoint
    const sourceResp = await fetch(originalImageUrl);
    if (!sourceResp.ok) {
      throw new Error(`Failed to download source image: ${sourceResp.status}`);
    }
    const sourceBuffer = await sourceResp.arrayBuffer();
    const sourceContentType = sourceResp.headers.get('content-type') ?? 'image/jpeg';
    const sourceExt = sourceContentType.includes('png') ? 'png' : 'jpeg';

    // Build multipart/form-data payload
    const formData = new FormData();
    formData.append(
      'image',
      new Blob([sourceBuffer], { type: sourceContentType }),
      `source.${sourceExt}`
    );
    formData.append('prompt', prompt);
    formData.append('model', 'gpt-image-1');
    formData.append('quality', 'medium');
    formData.append('size', 'auto');       // matches input image dimensions
    formData.append('n', '1');

    const openaiResponse = await fetch('https://api.openai.com/v1/images/edits', {
      method: 'POST',
      headers: { Authorization: `Bearer ${openaiKey}` },
      body: formData,
    });

    if (!openaiResponse.ok) {
      const err = await openaiResponse.text();
      throw new Error(`OpenAI API error: ${err}`);
    }

    const openaiData = await openaiResponse.json();
    const b64 = openaiData?.data?.[0]?.b64_json;
    if (!b64) {
      throw new Error('No image data returned from OpenAI');
    }

    // Decode base64 → ArrayBuffer for storage upload
    const binaryStr = atob(b64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) bytes[i] = binaryStr.charCodeAt(i);
    const resultBuffer = bytes.buffer;

    console.log('[generate-transformation] gpt-image-1 edit complete, storing result...');

    // ── Store result in Supabase Storage ──────────────────────────────────────
    const resultPath = `${user.id}/${requestId}_result.jpg`;

    const { error: uploadError } = await serviceClient.storage
      .from('transformation-results')
      .upload(resultPath, resultBuffer, {
        contentType: 'image/jpeg',
        upsert: true,
      });

    if (uploadError) throw new Error(`Storage upload error: ${uploadError.message}`);

    const storedUrl = serviceClient.storage
      .from('transformation-results')
      .getPublicUrl(resultPath).data.publicUrl;

    console.log('[generate-transformation] Stored at:', storedUrl);

    // ── Update request row ─────────────────────────────────────────────────────
    await serviceClient
      .from('transformation_requests')
      .update({ result_image_url: storedUrl, status: 'completed' })
      .eq('id', requestId);

    // ── Increment AI feature usage ───────────────────────────────────────────
    const { error: incrementError } = await serviceClient.rpc(
      'increment_ai_feature_usage',
      {
        p_user_id: user.id,
        p_feature: 'ai_transformation',
        p_year: currentYear,
      }
    );

    if (incrementError) {
      console.error('[generate-transformation] Failed to increment usage:', incrementError);
    }

    return new Response(
      JSON.stringify({ resultUrl: storedUrl }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('[generate-transformation] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message ?? 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
