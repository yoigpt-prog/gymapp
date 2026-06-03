import os
import math
import logging
from datetime import datetime
from supabase import create_client, Client

# Setup Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    logging.error("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

BASE_URL = "https://www.gymguide.co"
MAX_URLS_PER_SITEMAP = 45000  # Safe limit below 50k

def generate_sitemap():
    logging.info("Fetching exercises...")
    
    # We fetch all active exercises
    res = supabase.table('exercises').select('exercise_slug, exercise_name, is_male, updated_at').execute()
    exercises = res.data
    
    unique_exercises = {}
    for ex in exercises:
        name = (ex.get('exercise_name') or '').strip().lower()
        if not name:
            continue
        if name not in unique_exercises:
            unique_exercises[name] = ex
        else:
            if ex.get('is_male') and not unique_exercises[name].get('is_male'):
                unique_exercises[name] = ex
    
    urls = []
    
    # Base URLs
    urls.append({"loc": f"{BASE_URL}/", "priority": "1.0", "changefreq": "daily"})
    urls.append({"loc": f"{BASE_URL}/blog", "priority": "0.8", "changefreq": "weekly"})
    urls.append({"loc": f"{BASE_URL}/download", "priority": "0.9", "changefreq": "monthly"})
    urls.append({"loc": f"{BASE_URL}/calculators", "priority": "0.8", "changefreq": "monthly"})
    
    # Example Indexes
    indexes = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core', 'cardio']
    for idx in indexes:
        urls.append({
            "loc": f"{BASE_URL}/exercises/body-part/{idx}",
            "priority": "0.8",
            "changefreq": "weekly"
        })
        
    equipment = ['barbell', 'dumbbell', 'cable', 'machine', 'bodyweight']
    for eq in equipment:
        urls.append({
            "loc": f"{BASE_URL}/exercises/equipment/{eq}",
            "priority": "0.8",
            "changefreq": "weekly"
        })

    # Add all exercises
    today = datetime.utcnow().strftime('%Y-%m-%d')
    for ex in unique_exercises.values():
        slug = ex.get('exercise_slug')
        if slug:
            urls.append({
                "loc": f"{BASE_URL}/exercise/{slug}",
                "priority": "0.7",
                "changefreq": "monthly",
                "lastmod": today # In a real scenario, use actual updated_at
            })
            
    total_urls = len(urls)
    logging.info(f"Found {total_urls} URLs to map.")
    
    num_sitemaps = math.ceil(total_urls / MAX_URLS_PER_SITEMAP)
    
    sitemap_files = []
    
    for i in range(num_sitemaps):
        chunk = urls[i * MAX_URLS_PER_SITEMAP : (i+1) * MAX_URLS_PER_SITEMAP]
        filename = f"sitemap_{i+1}.xml" if num_sitemaps > 1 else "sitemap.xml"
        sitemap_files.append(filename)
        
        xml_content = ['<?xml version="1.0" encoding="UTF-8"?>']
        xml_content.append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
        
        for url in chunk:
            xml_content.append("  <url>")
            xml_content.append(f"    <loc>{url['loc']}</loc>")
            if 'lastmod' in url:
                xml_content.append(f"    <lastmod>{url['lastmod']}</lastmod>")
            if 'changefreq' in url:
                xml_content.append(f"    <changefreq>{url['changefreq']}</changefreq>")
            if 'priority' in url:
                xml_content.append(f"    <priority>{url['priority']}</priority>")
            xml_content.append("  </url>")
            
        xml_content.append('</urlset>')
        
        out_path = os.path.join(os.getcwd(), 'web', filename)
        with open(out_path, 'w') as f:
            f.write("\n".join(xml_content))
            
        logging.info(f"Generated {out_path} with {len(chunk)} URLs.")
        
    # Generate index if multiple
    if num_sitemaps > 1:
        idx_content = ['<?xml version="1.0" encoding="UTF-8"?>']
        idx_content.append('<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
        for sf in sitemap_files:
            idx_content.append("  <sitemap>")
            idx_content.append(f"    <loc>{BASE_URL}/{sf}</loc>")
            idx_content.append(f"    <lastmod>{today}</lastmod>")
            idx_content.append("  </sitemap>")
        idx_content.append('</sitemapindex>')
        
        with open(os.path.join(os.getcwd(), 'web', 'sitemap.xml'), 'w') as f:
            f.write("\n".join(idx_content))
            
        logging.info(f"Generated sitemap index sitemap.xml linking to {num_sitemaps} sub-sitemaps.")
        
    # Generate robots.txt
    robots = f"""User-agent: *
Allow: /

Sitemap: {BASE_URL}/sitemap.xml
"""
    with open(os.path.join(os.getcwd(), 'web', 'robots.txt'), 'w') as f:
        f.write(robots)
        
    logging.info("Generated robots.txt")

if __name__ == "__main__":
    generate_sitemap()
