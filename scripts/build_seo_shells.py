import os
import re
import json
import urllib.request
import urllib.parse
from datetime import datetime

SUPABASE_URL = "https://wewztpamzhrzbbgyutyf.supabase.co"
SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0."
    "PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws"
)
BASE_URL = "https://www.gymguide.co"

import ssl

def fetch_all(table, select):
    results = []
    offset = 0
    limit = 1000
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    while True:
        url = f"{SUPABASE_URL}/rest/v1/{table}?select={urllib.parse.quote(select)}&limit={limit}&offset={offset}"
        req = urllib.request.Request(url)
        req.add_header("apikey", SUPABASE_ANON_KEY)
        req.add_header("Authorization", f"Bearer {SUPABASE_ANON_KEY}")
        try:
            response = urllib.request.urlopen(req, context=ctx)
            data = json.loads(response.read().decode('utf-8'))
            results.extend(data)
            if len(data) < limit:
                break
            offset += limit
        except Exception as e:
            print(f"Error fetching {table}: {e}")
            break
    return results

def get_blogs():
    try:
        with open("lib/data/blog_articles.dart", "r") as f:
            content = f.read()
        
        blogs = []
        blocks = re.findall(r'\{(.*?)\}', content, re.DOTALL)
        for block in blocks:
            if "'slug':" in block:
                blog = {}
                for key in ['title', 'slug', 'desc', 'image']:
                    match = re.search(f"'{key}':\\s*'([^']*)'", block)
                    if match:
                        blog[key] = match.group(1).replace("\\'", "'")
                if 'slug' in blog:
                    blogs.append(blog)
        return blogs
    except Exception as e:
        print(f"Error parsing blogs: {e}")
        return []

def generate_html(title, desc, path, canonical_url=None, schema=None, image=None, noindex=False, body_content=None):
    canonical = canonical_url if canonical_url else f"{BASE_URL}/{path}"
    robots = '<meta name="robots" content="noindex">' if noindex else '<meta name="robots" content="index, follow">'
    schema_script = f'<script type="application/ld+json">\n{json.dumps(schema, indent=2)}\n</script>' if schema else ''
    
    if image:
        if not image.startswith('http'):
            image = f"{BASE_URL}/{image}"
        og_image = f'<meta property="og:image" content="{image}">'
    else:
        og_image = f'<meta property="og:image" content="{BASE_URL}/icons/Icon-512.png">'
        
    body_injection = body_content if body_content else ''
    
    # Read base index.html template from the COMPILED build directory
    # so that $FLUTTER_BASE_HREF and other variables are already resolved by Flutter.
    with open("build/web/index.html", "r", encoding="utf-8") as f:
        base_html = f.read()
        
    # Strip existing default SEO tags to avoid duplicates
    base_html = re.sub(r'<title>.*?</title>', '', base_html, flags=re.DOTALL)
    base_html = re.sub(r'<meta name="description".*?>', '', base_html, flags=re.IGNORECASE)
    base_html = re.sub(r'<meta name="robots".*?>', '', base_html, flags=re.IGNORECASE)
    base_html = re.sub(r'<link rel="canonical".*?>', '', base_html, flags=re.IGNORECASE)
    
    seo_tags = f"""
  <title>{title}</title>
  <meta name="description" content="{desc}" class="dynamic-seo-tag">
  {robots}
  <link rel="canonical" href="{canonical}" class="dynamic-seo-tag">
  <!-- Open Graph -->
  <meta property="og:title" content="{title}" class="dynamic-seo-tag">
  <meta property="og:description" content="{desc}" class="dynamic-seo-tag">
  <meta property="og:type" content="website" class="dynamic-seo-tag">
  {og_image.replace('>', ' class="dynamic-seo-tag">')}
  <meta property="og:url" content="{canonical}" class="dynamic-seo-tag">
  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image" class="dynamic-seo-tag">
  {og_image.replace('property="og:image"', 'name="twitter:image"').replace('>', ' class="dynamic-seo-tag">')}
  {schema_script.replace('<script', '<script class="dynamic-seo-tag"')}
"""
    
    # Inject before </head>
    final_html = base_html.replace('</head>', f'{seo_tags}</head>')
    
    # Inject static HTML right after <body>
    if body_injection:
        final_html = final_html.replace('<body>', f'<body>\n  <div id="seo-static-content">\n{body_injection}\n  </div>')
    
    clean_path = path.strip('/')
    full_path = os.path.join("build/web", clean_path)
    os.makedirs(full_path, exist_ok=True)
    with open(os.path.join(full_path, "index.html"), "w", encoding="utf-8") as f:
        f.write(final_html)

def main():
    print("🚀 Starting Static SEO Shell Generation...")
    os.makedirs("build/web", exist_ok=True)
    
    # 1. Generate Blogs
    blogs = get_blogs()
    for blog in blogs:
        schema = {
            "@context": "https://schema.org",
            "@type": "Article",
            "headline": blog['title'],
            "description": blog['desc'],
            "image": [f"{BASE_URL}/{blog.get('image', 'icons/Icon-512.png')}"],
            "author": {"@type": "Organization", "name": "Gym Guide"},
            "publisher": {
                "@type": "Organization",
                "name": "Gym Guide",
                "logo": {"@type": "ImageObject", "url": f"{BASE_URL}/icons/Icon-512.png"}
            }
        }
        generate_html(
            title=blog['title'],
            desc=blog['desc'],
            path=f"blog/{blog['slug']}",
            schema=schema,
            image=blog.get('image'),
            body_content=f"<h1>{blog['title']}</h1>\n<p>{blog['desc']}</p>"
        )
    print(f"✅ Generated {len(blogs)} Blog Shells")
    
    # 2. Generate Calculators
    calculators = [
        {
            "slug": "bmi",
            "title": "BMI Calculator – Check Your Body Mass Index Instantly",
            "desc": "Free BMI calculator. Check your body mass index instantly and get accurate results. Try it now."
        },
        {
            "slug": "calorie",
            "title": "Calorie Calculator – Daily Calories for Weight Loss & Muscle Gain",
            "desc": "Calculate your daily calorie needs for weight loss or muscle gain. Fast, accurate results."
        },
        {
            "slug": "macro",
            "title": "Macro Calculator – Protein, Carbs & Fat Intake Calculator",
            "desc": "Find your ideal macros for fat loss or muscle gain. Calculate protein, carbs, and fats."
        },
        {
            "slug": "body-fat",
            "title": "Body Fat Calculator – Estimate Your Body Fat Percentage",
            "desc": "Estimate your body fat percentage and track your fitness progress."
        },
        {
            "slug": "one-rm",
            "title": "1RM Calculator – One Rep Max Strength Calculator",
            "desc": "Calculate your one rep max and track your strength progress in the gym."
        }
    ]
    for calc in calculators:
        schema = {
            "@context": "https://schema.org",
            "@type": "SoftwareApplication",
            "name": calc['title'],
            "applicationCategory": "HealthApplication",
            "operatingSystem": "Web",
            "description": calc['desc'],
            "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}
        }
        generate_html(
            title=calc['title'],
            desc=calc['desc'],
            path=f"calculators/{calc['slug']}",
            schema=schema,
            body_content=f"<h1>{calc['title']}</h1>\n<p>{calc['desc']}</p>"
        )
    print(f"✅ Generated {len(calculators)} Calculator Shells")
    
    # 3. Generate Exercises
    print("Fetching exercises from Supabase...")
    exercises = fetch_all('exercises', 'id,exercise_slug,exercise_name,target_muscle,equipment,exercise_type,is_male,is_female,urls,instruction_1,instruction_2,instruction_3,instruction_4,difficulty_level')
    exercise_seo = fetch_all('exercise_seo', 'exercise_id,overview,seo_title,seo_description,benefits,common_mistakes,faq_1_question,faq_1_answer,faq_2_question,faq_2_answer,faq_3_question,faq_3_answer,faq_4_question,faq_4_answer,faq_5_question,faq_5_answer')
    
    # Create lookup map
    seo_map = {row['exercise_id']: row for row in exercise_seo}
    
    # Deduplicate by normalized name
    unique_exercises = {}
    for ex in exercises:
        name = ex.get('exercise_name', '').strip().lower()
        if not name:
            continue
        # If not in map, or if the current one is male (prioritize male as canonical base)
        if name not in unique_exercises:
            unique_exercises[name] = ex
        else:
            if ex.get('is_male') and not unique_exercises[name].get('is_male'):
                unique_exercises[name] = ex

    high_quality = 0
    low_quality = 0
    
    for ex in exercises:
        slug = ex.get('exercise_slug')
        if not slug:
            continue
            
        # Determine canonical slug using normalized base name
        name = ex.get('exercise_name', 'Exercise')
        norm_name = name.strip().lower()
        base_ex = unique_exercises.get(norm_name, ex)
        canonical_slug = base_ex.get('exercise_slug', slug)
        canonical_url = f"{BASE_URL}/exercise/{canonical_slug}"
            
        seo_data = seo_map.get(ex['id'], {})
        overview = seo_data.get('overview')
        
        is_high_quality = overview is not None and len(overview) > 20
        
        title = seo_data.get('seo_title') or f"{name} Form, Benefits & Muscles Worked"
        desc = seo_data.get('seo_description') or f"Learn how to perform the {name}. Discover the benefits, muscles worked, and common mistakes."
        
        schema = None
        body_html = ""
        if is_high_quality:
            high_quality += 1
            
            # Build body_content
            body_parts = [f"<h1>{name}</h1>", f"<p>{overview}</p>"]
            
            target = ex.get('target_muscle', '')
            if target: body_parts.append(f"<h2>Muscles Worked</h2>\n<p>{target}</p>")
            
            equip = ex.get('equipment', '')
            if equip: body_parts.append(f"<h2>Equipment</h2>\n<p>{equip}</p>")
            
            diff = ex.get('difficulty_level', '')
            if diff: body_parts.append(f"<h2>Difficulty</h2>\n<p>{diff}</p>")
            
            ex_type = ex.get('exercise_type', 'Strength')
            if ex_type: body_parts.append(f"<h2>Exercise Type</h2>\n<p>{ex_type}</p>")
            
            steps = []
            for i in range(1, 5):
                step = ex.get(f'instruction_{i}')
                if step and step.strip(): steps.append(step.strip())
            
            how_to_schema = []
            if steps:
                body_parts.append("<h2>How to Do...</h2>\n<ol>")
                for step in steps:
                    body_parts.append(f"<li>{step}</li>")
                    how_to_schema.append({"@type": "HowToStep", "text": step})
                body_parts.append("</ol>")
                
            benefits = seo_data.get('benefits', '')
            if benefits: body_parts.append(f"<h2>Benefits</h2>\n{benefits}")
            
            mistakes = seo_data.get('common_mistakes', '')
            if mistakes: body_parts.append(f"<h2>Common Mistakes</h2>\n{mistakes}")
            
            faq_schema = []
            faq_html = []
            for i in range(1, 6):
                q = seo_data.get(f'faq_{i}_question')
                a = seo_data.get(f'faq_{i}_answer')
                if q and a:
                    faq_html.append(f"<h3>{q}</h3>\n<p>{a}</p>")
                    faq_schema.append({
                        "@type": "Question",
                        "name": q,
                        "acceptedAnswer": {"@type": "Answer", "text": a}
                    })
            if faq_html:
                body_parts.append("<h2>Frequently Asked Questions</h2>\n" + "\n".join(faq_html))
                
            body_html = "\n".join(body_parts)

            schema = {
                "@context": "https://schema.org",
                "@graph": [
                    {
                        "@type": "ExerciseAction",
                        "name": name,
                        "description": desc,
                        "exerciseType": ex_type,
                        "muscleAction": target,
                        "equipment": equip
                    }
                ]
            }
            if how_to_schema:
                schema["@graph"].append({
                    "@type": "HowTo",
                    "name": f"How to do {name}",
                    "step": how_to_schema
                })
            if faq_schema:
                schema["@graph"].append({
                    "@type": "FAQPage",
                    "mainEntity": faq_schema
                })
        else:
            low_quality += 1
            
        raw_urls = ex.get('urls') or ''
        thumbnail_url = f"{BASE_URL}/icons/Icon-512.png"
        if raw_urls.lower().endswith('.mp4'):
            filename = raw_urls.split('/')[-1]
            # case insensitive replace .mp4 with .jpg
            filename = re.sub(r'\.mp4$', '.jpg', filename, flags=re.IGNORECASE)
            # keep only first 6 digits if it starts with 8 digits ending in 05
            filename = re.sub(r'^(\d{6})05', r'\1', filename)
            # remove _GREEN
            filename = re.sub(r'_GREEN', '', filename, flags=re.IGNORECASE)
            thumbnail_url = f"https://www.gymguide.co/exercise/{filename}"
        elif raw_urls.startswith('http'):
            thumbnail_url = raw_urls
            
        generate_html(
            title=title,
            desc=desc,
            path=f"exercise/{slug}",
            canonical_url=canonical_url,
            schema=schema,
            noindex=not is_high_quality,
            body_content=body_html,
            image=thumbnail_url
        )
        
    print(f"✅ Generated {high_quality + low_quality} Exercise Shells ({high_quality} High Quality, {low_quality} Low Quality/NoIndex)")
    
    trust_pages = [
        {"slug": "about", "title": "About Gym Guide", "desc": "Gym Guide is your personalized workout and meal plan app."},
        {"slug": "contact", "title": "Contact Us – Gym Guide", "desc": "Get in touch with Gym Guide support and team."},
        {"slug": "privacy", "title": "Privacy Policy – Gym Guide", "desc": "Read our privacy policy to understand how we protect your data."},
        {"slug": "terms", "title": "Terms of Service – Gym Guide", "desc": "Gym Guide terms of service and usage conditions."},
        {"slug": "disclaimer", "title": "Disclaimer – Gym Guide", "desc": "Educational fitness information only. Not medical advice."},
        {"slug": "faq", "title": "Frequently Asked Questions – Gym Guide", "desc": "Get answers to common questions about Gym Guide."},
        {"slug": "ai-transparency", "title": "AI Transparency – Gym Guide", "desc": "Learn how Gym Guide uses AI for personalized fitness plans."},
        {"slug": "subscription", "title": "Subscription & Pricing – Gym Guide", "desc": "Gym Guide subscription options, premium features, and pricing."},
        {"slug": "blog", "title": "Fitness Blog – Gym Guide", "desc": "Read the latest fitness tips, workout routines, and nutrition advice."},
        {"slug": "calculators", "title": "Fitness Calculators – Gym Guide", "desc": "Free fitness calculators for BMI, calories, macros, body fat, and 1RM."},
        {"slug": "download", "title": "Download Gym Guide", "desc": "Download Gym Guide to get your personalized workout and meal plan."}
    ]
    
    org_schema = {
        "@context": "https://schema.org",
        "@type": "Organization",
        "name": "GGUIDE Apps Solutions LLC",
        "brand": "GymGuide",
        "url": "https://www.gymguide.co",
        "logo": "https://www.gymguide.co/icons/Icon-512.png"
    }

    for tp in trust_pages:
        generate_html(
            title=tp['title'],
            desc=tp['desc'],
            path=tp['slug'],
            schema=org_schema,
            body_content=f"<h1>{tp['title']}</h1>\n<p>{tp['desc']}</p>\n<p>Educational fitness information only. Not medical advice.</p>"
        )
    print(f"✅ Generated {len(trust_pages)} Static Trust Pages")

    # Generate Homepage with schemas
    generate_html(
        title="Gym Guide – Personalized Workout & Meal Plan App",
        desc="Get your custom workout and meal plan in seconds. 1800+ exercises, fat loss & muscle gain programs. Download Gym Guide now.",
        path="",
        canonical_url="https://www.gymguide.co/",
        schema={
            "@context": "https://schema.org",
            "@graph": [
                org_schema,
                {
                    "@type": "WebSite",
                    "url": "https://www.gymguide.co",
                    "name": "Gym Guide"
                },
                {
                    "@type": "SoftwareApplication",
                    "name": "Gym Guide",
                    "operatingSystem": "iOS, Android",
                    "applicationCategory": "HealthApplication"
                }
            ]
        },
        body_content="<h1>Gym Guide – Personalized Workout & Meal Plan App</h1>\n<p>Get your custom workout and meal plan in seconds. Educational fitness information only. Not medical advice.</p>"
    )
    print("✅ Generated Homepage Shell")
    
    print("🎉 SEO Shell Generation Complete!")

if __name__ == "__main__":
    main()
