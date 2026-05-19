// @ts-nocheck
// serve-share-page — Supabase Edge Function
// Returns a proper HTML page with OpenGraph meta tags for social sharing.
// Works without authentication. Safe: only exposes result_image_url, goal, share_token.

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
  const token = url.searchParams.get('token');

  if (!token) {
    return htmlResponse(notFoundPage('No token provided.'));
  }

  // Detect bots/scrapers
  const userAgent = req.headers.get('user-agent') || '';
  const isBot = /facebookexternalhit|twitterbot|whatsapp|telegrambot|slackbot|discordbot|applebot|linkedinbot|embedly|imessage/i.test(userAgent);

  const appUrl = `https://www.gymguide.co/transformation/share/${token}`;

  // Log diagnostics
  console.log('[serve-share-page] Diagnostic Logs:', {
    userAgent,
    token,
    selectedRenderer: isBot ? 'HTML Metadata Preview' : 'HTTP 307 Redirect',
    redirectTarget: !isBot ? appUrl : 'none',
  });

  if (!isBot) {
    return Response.redirect(appUrl, 307);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!
  );

  const { data, error } = await supabase
    .from('transformation_requests')
    .select('result_image_url, thumbnail_url, goal, share_token, created_at')
    .eq('share_token', token)
    .eq('status', 'completed')
    .maybeSingle();

  if (error || !data) {
    console.log('[serve-share-page] Not found for token:', token, error?.message);
    return htmlResponse(notFoundPage('Transformation not found or has been removed.'));
  }

  const resultUrl = data.result_image_url ?? '';
  const goal = data.goal ?? 'Fitness';
  const appUrl = `https://www.gymguide.co/transformation/share/${token}`;
  
  // Exact tags requested
  const title = 'AI Body Transformation | GymGuide';
  const description = 'See this AI-powered body transformation created with GymGuide.';

  console.log('[serve-share-page] Serving OG page for token:', token, 'goal:', goal);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escHtml(title)}</title>
  <meta name="description" content="${escHtml(description)}" />

  <!-- OpenGraph -->
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${escHtml(title)}" />
  <meta property="og:description" content="${escHtml(description)}" />
  <meta property="og:image" content="${escHtml(resultUrl)}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:url" content="${escHtml(appUrl)}" />
  <meta property="og:site_name" content="GymGuide" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escHtml(title)}" />
  <meta name="twitter:description" content="${escHtml(description)}" />
  <meta name="twitter:image" content="${escHtml(resultUrl)}" />

  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
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
      border: 1px solid #333;
      border-radius: 20px;
      overflow: hidden;
      max-width: 440px;
      width: 100%;
    }
    .image-wrap { width: 100%; aspect-ratio: 3/4; overflow: hidden; }
    .image-wrap img { width: 100%; height: 100%; object-fit: cover; }
    .body { padding: 20px; }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(255,0,0,0.12);
      border: 1px solid rgba(255,0,0,0.3);
      border-radius: 20px;
      padding: 4px 12px;
      font-size: 12px;
      font-weight: 700;
      color: #FF0000;
      letter-spacing: 0.5px;
      margin-bottom: 12px;
    }
    h1 { font-size: 22px; font-weight: 900; line-height: 1.2; margin-bottom: 8px; }
    .goal { font-size: 14px; color: #aaa; margin-bottom: 20px; }
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
      margin-bottom: 12px;
    }
    .disclaimer {
      font-size: 11px;
      color: #555;
      line-height: 1.5;
      margin-top: 16px;
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
      <img src="${escHtml(resultUrl)}" alt="AI Transformation Result" />
    </div>
    <div class="body">
      <div class="badge">✦ AI POWERED</div>
      <h1>AI Body Transformation</h1>
      <p class="goal">Goal: ${escHtml(goal)}</p>
      <a class="cta" href="https://www.gymguide.co/download" target="_blank">
        Try GymGuide AI Free →
      </a>
      <p class="disclaimer">
        AI previews are estimates only. Results vary depending on training,
        nutrition, genetics, and consistency. Not a medical claim.
      </p>
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
    headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
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
  <h2>Transformation Not Found</h2>
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
