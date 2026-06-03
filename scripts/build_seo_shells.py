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

def generate_html(title, desc, path, schema=None, image=None, noindex=False, h1=None):
    canonical = f"{BASE_URL}/{path}"
    robots = '<meta name="robots" content="noindex">' if noindex else '<meta name="robots" content="index, follow">'
    schema_script = f'<script type="application/ld+json">\n{json.dumps(schema, indent=2)}\n</script>' if schema else ''
    
    if image:
        if not image.startswith('http'):
            image = f"{BASE_URL}/{image}"
        og_image = f'<meta property="og:image" content="{image}">'
    else:
        og_image = f'<meta property="og:image" content="{BASE_URL}/icons/Icon-512.png">'
        
    h1_tag = f'<h1 style="display:none;">{h1}</h1>' if h1 else ''
    
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
  {og_image.replace('>', ' class="dynamic-seo-tag">')}
  <meta property="og:url" content="{canonical}" class="dynamic-seo-tag">
  {schema_script.replace('<script', '<script class="dynamic-seo-tag"')}
"""
    
    # Inject before </head>
    final_html = base_html.replace('</head>', f'{seo_tags}</head>')
    
    # Inject H1 right after <body>
    if h1_tag:
        final_html = final_html.replace('<body>', f'<body>\n  {h1_tag}')
    
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
            h1=blog['title']
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
            h1=calc['title']
        )
    print(f"✅ Generated {len(calculators)} Calculator Shells")
    
    # 3. Generate Exercises
    print("Fetching exercises from Supabase...")
    exercises = fetch_all('exercises', 'id,exercise_slug,exercise_name,target_muscle,equipment,exercise_type,is_male,is_female')
    exercise_seo = fetch_all('exercise_seo', 'exercise_id,overview,seo_title,seo_description')
    
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
    
    for ex in unique_exercises.values():
        slug = ex.get('exercise_slug')
        if not slug:
            continue
            
        seo_data = seo_map.get(ex['id'], {})
        overview = seo_data.get('overview')
        
        is_high_quality = overview is not None and len(overview) > 20
        
        name = ex.get('exercise_name', 'Exercise')
        title = seo_data.get('seo_title') or f"{name} Form, Benefits & Muscles Worked"
        desc = seo_data.get('seo_description') or f"Learn how to perform the {name}. Discover the benefits, muscles worked, and common mistakes."
        
        schema = None
        if is_high_quality:
            high_quality += 1
            schema = {
                "@context": "https://schema.org",
                "@type": "ExerciseAction",
                "name": name,
                "description": desc,
                "exerciseType": ex.get('exercise_type', 'Strength'),
                "muscleAction": ex.get('target_muscle', ''),
                "equipment": ex.get('equipment', '')
            }
        else:
            low_quality += 1
            
        generate_html(
            title=title,
            desc=desc,
            path=f"exercise/{slug}",
            schema=schema,
            noindex=not is_high_quality,
            h1=name,
            image=f"https://www.gymguide.co/exercise/{slug}.jpg" # The image path in nginx conf supports /exercise/{slug}.jpg
        )
        
    print(f"✅ Generated {high_quality + low_quality} Exercise Shells ({high_quality} High Quality, {low_quality} Low Quality/NoIndex)")
    print("🎉 SEO Shell Generation Complete!")

if __name__ == "__main__":
    main()
