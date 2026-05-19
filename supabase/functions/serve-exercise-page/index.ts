// @ts-nocheck
// serve-exercise-page — Supabase Edge Function
// Returns a proper HTML page with OpenGraph meta tags for exercise sharing.
// Optimized for bots and crawlers (WhatsApp, Facebook, Twitter, Discord, etc.)

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

  const url = new URL(req.url);
  const slug = url.searchParams.get('slug');

  if (!slug) {
    return htmlResponse(notFoundPage('No exercise slug provided.'));
  }

  // Detect bots/scrapers
  const userAgent = req.headers.get('user-agent') || '';
  const isBot = /facebookexternalhit|twitterbot|whatsapp|telegrambot|slackbot|discordbot|applebot|linkedinbot|embedly|imessage/i.test(userAgent);

  const appUrl = `https://www.gymguide.co/exercise/${slug}`;

  // Log diagnostics
  console.log('[serve-exercise-page] Diagnostic Logs:', {
    userAgent,
    slug,
    selectedRenderer: isBot ? 'HTML Metadata Preview' : 'HTTP 307 Redirect',
    redirectTarget: !isBot ? appUrl : 'none',
  });

  // Real users bypass the Edge Function immediately to get served the Flutter SPA
  if (!isBot) {
    return Response.redirect(appUrl, 307);
  }

  // Initialize Supabase Client
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!
  );

  const { data, error } = await supabase
    .from('exercises')
    .select('*')
    .eq('exercise_slug', slug)
    .maybeSingle();

  if (error || !data) {
    console.log('[serve-exercise-page] Exercise not found for slug:', slug, error?.message);
    return htmlResponse(notFoundPage(`Exercise with slug "${slug}" not found.`));
  }

  const name = data.exercise_name || 'Exercise';
  const thumbnailUrl = data.thumbnail_url || 'https://www.gymguide.co/assets/logo.png';
  const target = data.target_muscle || data.body_part || 'General';
  const parentMuscle = data.parent_muscle || '';
  const difficulty = data.difficulty_level || 'Intermediate';
  const equipment = data.equipment || 'Body weight';

  // Gather steps
  const steps: string[] = [];
  for (let i = 1; i <= 4; i++) {
    const step = data[`instruction_${i}`];
    if (step && step.trim().length > 0) {
      steps.push(step.trim());
    }
  }

  const title = `${name} - Muscles Worked, Instructions & Form | GymGuide`;
  const description = `Learn how to do the ${name} exercise. Targets the ${target} (${difficulty} difficulty). View step-by-step instructions and proper form.`;

  console.log('[serve-exercise-page] Serving OG page for slug:', slug, 'name:', name);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escHtml(title)}</title>
  <meta name="description" content="${escHtml(description)}" />

  <!-- OpenGraph / Facebook -->
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${escHtml(title)}" />
  <meta property="og:description" content="${escHtml(description)}" />
  <meta property="og:image" content="${escHtml(thumbnailUrl)}" />
  <meta property="og:image:secure_url" content="${escHtml(thumbnailUrl)}" />
  <meta property="og:image:type" content="image/jpeg" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:url" content="${escHtml(appUrl)}" />
  <meta property="og:site_name" content="GymGuide" />

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escHtml(title)}" />
  <meta name="twitter:description" content="${escHtml(description)}" />
  <meta name="twitter:image" content="${escHtml(thumbnailUrl)}" />

  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0F0F0F;
      color: #fff;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .card {
      background: #1A1A1A;
      border: 1px solid #FF0000;
      border-radius: 20px;
      overflow: hidden;
      max-width: 480px;
      width: 100%;
      box-shadow: 0 12px 32px rgba(255, 0, 0, 0.15);
    }
    .image-wrap { width: 100%; aspect-ratio: 16/9; overflow: hidden; background: #000; position: relative; }
    .image-wrap img { width: 100%; height: 100%; object-fit: cover; }
    .badge {
      position: absolute;
      top: 12px;
      left: 12px;
      background: #FF0000;
      color: #fff;
      font-size: 11px;
      font-weight: 800;
      padding: 4px 10px;
      border-radius: 12px;
      letter-spacing: 0.5px;
    }
    .body { padding: 24px; }
    h1 { font-size: 24px; font-weight: 900; line-height: 1.2; margin-bottom: 16px; color: #fff; border-bottom: 2px solid #FF0000; padding-bottom: 8px; }
    
    .meta-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 12px;
      margin-bottom: 20px;
    }
    .meta-item {
      background: #252525;
      padding: 10px;
      border-radius: 8px;
      border: 1px solid #333;
    }
    .meta-label { font-size: 11px; color: #FF0000; font-weight: bold; text-transform: uppercase; margin-bottom: 2px; }
    .meta-value { font-size: 13px; color: #eee; font-weight: 600; }
    
    .section-title { font-size: 16px; font-weight: 800; margin-bottom: 12px; color: #fff; }
    .step-list { display: flex; flex-direction: column; gap: 12px; margin-bottom: 24px; }
    .step-item { display: flex; gap: 12px; align-items: flex-start; }
    .step-num {
      background: #FF0000;
      color: #fff;
      font-weight: bold;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 12px;
      flex-shrink: 0;
    }
    .step-text { font-size: 13px; color: #ccc; line-height: 1.4; }
    
    .cta {
      display: block;
      text-align: center;
      background: #FF0000;
      color: #fff;
      font-weight: 700;
      font-size: 15px;
      text-decoration: none;
      padding: 14px 20px;
      border-radius: 12px;
      transition: background 0.2s;
    }
    .branding {
      font-size: 12px;
      color: #444;
      text-align: center;
      margin-top: 24px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="image-wrap">
      <span class="badge">✦ EXERCISE FORM</span>
      <img src="${escHtml(thumbnailUrl)}" alt="${escHtml(name)}" />
    </div>
    <div class="body">
      <h1>${escHtml(name)}</h1>
      
      <div class="meta-grid">
        <div class="meta-item">
          <div class="meta-label">Target Muscle</div>
          <div class="meta-value">${escHtml(target)}</div>
        </div>
        <div class="meta-item">
          <div class="meta-label">Equipment</div>
          <div class="meta-value">${escHtml(equipment)}</div>
        </div>
        <div class="meta-item">
          <div class="meta-label">Difficulty</div>
          <div class="meta-value">${escHtml(difficulty)}</div>
        </div>
        <div class="meta-item">
          <div class="meta-label">Muscle Group</div>
          <div class="meta-value">${escHtml(parentMuscle || target)}</div>
        </div>
      </div>

      ${steps.length > 0 ? `
        <div class="section-title">Instructions</div>
        <div class="step-list">
          ${steps.map((step, idx) => `
            <div class="step-item">
              <div class="step-num">${idx + 1}</div>
              <div class="step-text">${escHtml(step)}</div>
            </div>
          `).join('')}
        </div>
      ` : ''}

      <a class="cta" href="https://www.gymguide.co/download" target="_blank">
        Open in GymGuide App →
      </a>
    </div>
  </div>
  <p class="branding">Generated with <strong>GymGuide AI</strong></p>
</body>
</html>`;

  return htmlResponse(html);
});

function htmlResponse(html: string): Response {
  return new Response(html, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=86400, s-maxage=86400', // Cache page for 1 day
    },
  });
}

function notFoundPage(message: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Not Found — GymGuide</title>
  <style>
    body { font-family: sans-serif; background:#0F0F0F; color:#fff;
           display:flex; align-items:center; justify-content:center;
           min-height:100vh; flex-direction:column; gap:16px; }
    h2 { font-size:22px; }
    p  { color:#888; font-size:14px; }
    a  { color:#FF0000; }
  </style>
</head>
<body>
  <h2>Exercise Not Found</h2>
  <p>${escHtml(message)}</p>
  <a href="https://www.gymguide.co/download">← Back to GymGuide</a>
</body>
</html>`;
}

function escHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
