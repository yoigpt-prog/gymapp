import os
import time
import json
import random
import logging
import difflib
from datetime import datetime
from supabase import create_client, Client

# Setup Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("generation_progress.log"),
        logging.StreamHandler()
    ]
)

# Configuration
BATCH_SIZE = 50
MAX_RETRIES = 3

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

if not all([SUPABASE_URL, SUPABASE_KEY]):
    logging.error("Missing environment variables. Set SUPABASE_URL and SUPABASE_SERVICE_KEY.")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# State Management
COMPLETED_IDS_FILE = "completed_ids.json"
RETRY_QUEUE_FILE = "retry_queue.json"

def load_state(filename):
    if os.path.exists(filename):
        with open(filename, 'r') as f:
            return set(json.load(f))
    return set()

def save_state(filename, data_set):
    with open(filename, 'w') as f:
        json.dump(list(data_set), f)

completed_ids = load_state(COMPLETED_IDS_FILE)
retry_queue = load_state(RETRY_QUEUE_FILE)

# Memory Buffer for Anti-Duplicate System
recent_overviews = []
SIMILARITY_THRESHOLD = 0.85

def check_similarity(new_text, history_list):
    for old_text in history_list:
        ratio = difflib.SequenceMatcher(None, new_text, old_text).ratio()
        if ratio > SIMILARITY_THRESHOLD:
            return True, ratio
    return False, 0.0

# ---------------------------------------------------------
# LOCAL DETERMINISTIC TEMPLATING ENGINE
# ---------------------------------------------------------

OVERVIEW_TEMPLATES = [
    "The {name} is an incredibly effective {type} movement designed to fully engage the {target}. By utilizing {equip}, this exercise emphasizes a deep stretch and a powerful contraction, making it a cornerstone for anyone looking to optimize their {body_part} development.",
    "When programming for {target} growth, the {name} stands out as a highly efficient {type} choice. Performing this movement with {equip} forces your stabilizer muscles to work in tandem with the primary movers, translating to functional strength and enhanced muscular endurance.",
    "If you want to isolate and overload the {target}, the {name} is an excellent addition to your routine. The mechanics of this {type} exercise specifically bias the {body_part}, while the use of {equip} allows for a smooth, natural resistance curve.",
    "Athletic trainers and bodybuilding coaches frequently recommend the {name} because it challenges the {target} through a dynamic range of motion. By relying on {equip}, it reinforces proper movement patterns and builds robust strength in the {body_part} region.",
    "Focusing on the {name} allows you to target the {target} with precision. As a foundational {type} exercise, the integration of {equip} provides the necessary tension to trigger hypertrophy, while avoiding excessive joint strain."
]

BENEFIT_TEMPLATES = [
    "<li>Significantly enhances the structural integrity and power of the {target}.</li>",
    "<li>Utilizes {equip} to create sustained mechanical tension, forcing deep muscle adaptation.</li>",
    "<li>Improves overall {body_part} stability and proprioception during heavy loads.</li>",
    "<li>Acts as a highly scalable {type} movement, perfect for both beginners and elite athletes.</li>",
    "<li>Promotes balanced muscular development by effectively recruiting the {target} and associated synergists.</li>",
    "<li>Reduces the likelihood of {body_part} injuries by reinforcing connective tissue strength.</li>",
    "<li>Allows for a natural movement path that closely mimics functional daily activities.</li>"
]

MISTAKE_TEMPLATES = [
    "<li>Using excessive momentum to swing the {equip} rather than controlling the eccentric phase.</li>",
    "<li>Failing to achieve a full range of motion, which drastically limits {target} engagement.</li>",
    "<li>Losing core tension, leading to poor spinal alignment and reduced power output.</li>",
    "<li>Rushing the repetition tempo instead of focusing on the mind-muscle connection with the {body_part}.</li>",
    "<li>Shrugging the shoulders or compensating with secondary muscles rather than isolating the {target}.</li>"
]

PRO_TIPS_TEMPLATES = [
    "To maximize the {name}, actively squeeze the {target} at the peak of the contraction for a full second.",
    "Control the eccentric (lowering) phase of the {name} for 3-4 seconds to drastically increase time under tension.",
    "Think about pulling from your elbows rather than your hands to better isolate the {target} and minimize bicep/forearm takeover.",
    "Keep your breathing rhythmic: exhale sharply on the concentric push/pull, and inhale smoothly on the way down.",
    "If you feel this primarily in your joints rather than the {target}, instantly lower the weight and readjust your {equip} setup."
]

FAQ_TEMPLATES = [
    (
        "Why do I feel the {name} more in my joints than my {target}?",
        "This usually indicates poor setup or using {equip} that is too heavy. Ensure your joints are stacked, lower the resistance, and focus purely on contracting the {target}."
    ),
    (
        "Can I perform the {name} every day?",
        "It's highly recommended to give your {target} at least 48 hours of recovery between heavy {type} sessions to allow for optimal muscle repair."
    ),
    (
        "How do I prevent momentum from taking over during the {name}?",
        "Pause for one second at the absolute bottom of the movement. This eliminates the stretch reflex and forces the {target} to do 100% of the work."
    ),
    (
        "Is the {name} suitable if I have previous {body_part} issues?",
        "If you have acute injuries, always consult a physical therapist first. However, starting with very light {equip} and focusing on slow tempos can actually aid in rehabilitation."
    ),
    (
        "What is the optimal rep range for the {name}?",
        "For pure hypertrophy of the {target}, aim for 8-15 controlled repetitions. For strength, 4-6 reps with heavier {equip} is ideal."
    )
]

def generate_local_content(ex):
    name = ex.get('exercise_name') or 'Exercise'
    target = ex.get('target_muscle') or 'primary muscle'
    equip = ex.get('equipment') or 'resistance'
    body_part = ex.get('body_part') or 'muscle group'
    diff = ex.get('difficulty_level') or 'Beginner'
    ex_type = ex.get('exercise_type') or 'Strength'
    
    # Randomize until we find a unique overview
    max_gen_attempts = 10
    overview_text = ""
    for _ in range(max_gen_attempts):
        t = random.choice(OVERVIEW_TEMPLATES)
        overview_text = t.format(name=name, target=target, equip=equip, body_part=body_part, type=ex_type)
        is_sim, _ = check_similarity(overview_text, recent_overviews)
        if not is_sim:
            break
            
    recent_overviews.append(overview_text)
    if len(recent_overviews) > 50:
        recent_overviews.pop(0)
        
    # Benefits
    b_count = random.randint(3, 5)
    b_list = random.sample(BENEFIT_TEMPLATES, b_count)
    b_text = "<ul>\n" + "\n".join([b.format(name=name, target=target, equip=equip, body_part=body_part, type=ex_type) for b in b_list]) + "\n</ul>"
    
    # Mistakes
    m_count = random.randint(3, 4)
    m_list = random.sample(MISTAKE_TEMPLATES, m_count)
    m_text = "<ul>\n" + "\n".join([m.format(name=name, target=target, equip=equip, body_part=body_part, type=ex_type) for m in m_list]) + "\n</ul>"
    
    # Pro Tips
    p_text = random.choice(PRO_TIPS_TEMPLATES).format(name=name, target=target, equip=equip, body_part=body_part, type=ex_type)
    
    # FAQs
    faqs = random.sample(FAQ_TEMPLATES, 5)
    faq_data = {}
    for i, (q, a) in enumerate(faqs):
        faq_data[f"faq_{i+1}_question"] = q.format(name=name, target=target, equip=equip, body_part=body_part, type=ex_type)
        faq_data[f"faq_{i+1}_answer"] = a.format(name=name, target=target, equip=equip, body_part=body_part, type=ex_type)
        
    # Optional Omission Logic (Keep UI dynamic)
    OPTIONAL_CARDS = [
        "pro_tips", "advanced_tips", "common_mistakes", "exercise_variations",
        "muscle_anatomy", "best_workout_splits", "beginner_tips"
    ]
    
    data = {
        "overview": overview_text,
        "benefits": b_text,
        "common_mistakes": m_text,
        "pro_tips": p_text,
        "advanced_tips": f"To make the {name} more advanced, try adding a 3-second pause at the point of maximum tension for the {target}.",
        "beginner_tips": f"If you are new to the {name}, focus on mastering the movement pattern with zero weight before adding {equip}.",
        "muscle_anatomy": f"The primary driver is the {target}. However, the movement also recruits {ex.get('synergist') or 'secondary stabilizers'} to maintain control of the {equip}.",
        "exercise_variations": f"<ul><li>Dumbbell {name}</li><li>Cable {name}</li><li>Banded {name}</li></ul>",
        "best_workout_splits": f"The {name} fits perfectly into a {body_part}-focused day, Push/Pull/Legs split, or full-body functional routine.",
        "seo_title": f"{name} Form, Benefits & Muscles Worked",
        "seo_description": f"Learn how to perform the {name}. Discover the benefits, muscles worked ({target}), and common mistakes.",
        "equipment_type": equip,
        "workout_category": ex_type,
        "movement_pattern": "Dynamic",
        "force_type": "Variable",
        "mechanics_type": "Compound" if "Compound" in ex_type else "Isolation",
        **faq_data
    }
    
    # Omit 1-2 random optional cards
    cards_to_omit = random.sample(OPTIONAL_CARDS, random.randint(1, 2))
    for c in cards_to_omit:
        if c in data:
            del data[c]
            
    return data

def fetch_target_batch(size):
    all_exercises = []
    offset = 0
    while True:
        ex_res = supabase.table('exercises').select('*').range(offset, offset + 999).execute()
        all_exercises.extend(ex_res.data)
        if len(ex_res.data) < 1000:
            break
        offset += 1000
    
    seo_data = {}
    offset = 0
    while True:
        seo_res = supabase.table('exercise_seo').select('exercise_id, overview, manually_edited').range(offset, offset + 999).execute()
        for row in seo_res.data:
            seo_data[row['exercise_id']] = row
        if len(seo_res.data) < 1000:
            break
        offset += 1000
    
    targets = []
    for ex in all_exercises:
        ex_id = ex['id']
        
        seo_record = seo_data.get(ex_id)
        if seo_record and seo_record.get('manually_edited') is True:
            continue
            
        if ex_id in completed_ids:
            continue
            
        if not seo_record or not seo_record.get('overview'):
            targets.append(ex)
            if len(targets) == size:
                break
                
    return targets

def run_batch():
    global completed_ids, retry_queue
    
    targets = fetch_target_batch(BATCH_SIZE)
    if not targets:
        return False
        
    logging.info(f"Starting batch of {len(targets)} exercises...")
    
    for ex in targets:
        ex_id = ex['id']
        name = ex.get('exercise_name', 'Unknown')
        
        start_time = time.time()
        
        # Local Deterministic Generation
        generated_json = generate_local_content(ex)
        
        payload = {
            "exercise_id": ex_id,
            "content_version": 1,
            "is_ai_generated": True,
            "manually_edited": False,
            "updated_at": datetime.utcnow().isoformat(),
            **generated_json
        }
        
        attempt_count = 0
        success = False
        
        for attempt in range(MAX_RETRIES):
            attempt_count += 1
            try:
                supabase.table('exercise_seo').upsert(payload).execute()
                success = True
                break
            except Exception as e:
                wait_time = 2 ** attempt
                logging.warning(f"DB Error for {name}: {e}. Retrying in {wait_time}s...")
                time.sleep(wait_time)
                
        duration = time.time() - start_time
        
        if success:
            completed_ids.add(ex_id)
            save_state(COMPLETED_IDS_FILE, completed_ids)
            if ex_id in retry_queue:
                retry_queue.remove(ex_id)
                save_state(RETRY_QUEUE_FILE, retry_queue)
            logging.info(f"Successfully saved {name}. Duration: {duration:.2f}s")
        else:
            logging.error(f"Failed to save {name} after {MAX_RETRIES} retries.")
            retry_queue.add(ex_id)
            save_state(RETRY_QUEUE_FILE, retry_queue)
            
    return True

if __name__ == "__main__":
    logging.info("Starting LOCAL DETERMINISTIC BATCH MODE...")
    total_completed_start = len(completed_ids)
    start_time = time.time()
    
    while True:
        has_more = run_batch()
        if not has_more:
            break
            
    elapsed = time.time() - start_time
    newly_completed = len(completed_ids) - total_completed_start
    
    logging.info("=================================")
    logging.info("BATCH GENERATION COMPLETE")
    logging.info(f"Total Newly Generated: {newly_completed}")
    logging.info(f"Total Skipped (Already Done): {total_completed_start}")
    logging.info(f"Total Failed (Retry Queue): {len(retry_queue)}")
    logging.info(f"Total Elapsed Time: {elapsed:.1f}s")
    logging.info("=================================")
