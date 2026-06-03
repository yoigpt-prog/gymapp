-- Create the new exercise_seo table for web-only content
CREATE TABLE IF NOT EXISTS public.exercise_seo (
    exercise_id TEXT PRIMARY KEY,
    
    -- Content Versioning and Auditing
    content_version INT DEFAULT 1,
    is_ai_generated BOOLEAN DEFAULT true,
    manually_edited BOOLEAN DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Meta tags and SEO
    seo_title TEXT,
    seo_description TEXT,

    -- Categorical Additions
    equipment_type TEXT,
    workout_category TEXT,
    variation_count INT,
    estimated_calories_burned TEXT,
    
    -- Content Sections
    overview TEXT,
    benefits TEXT,
    common_mistakes TEXT,
    pro_tips TEXT,
    muscle_anatomy TEXT,
    best_workout_splits TEXT,
    exercise_variations TEXT,
    beginner_tips TEXT,
    advanced_tips TEXT,
    breathing_technique TEXT,
    recommended_frequency TEXT,
    who_should_avoid TEXT,
    
    -- Mechanical Info
    stabilizer_muscles TEXT,
    movement_pattern TEXT,
    force_type TEXT,
    mechanics_type TEXT,
    
    -- FAQ Section
    faq_1_question TEXT,
    faq_1_answer TEXT,
    faq_2_question TEXT,
    faq_2_answer TEXT,
    faq_3_question TEXT,
    faq_3_answer TEXT,
    faq_4_question TEXT,
    faq_4_answer TEXT,
    faq_5_question TEXT,
    faq_5_answer TEXT
);

-- Indexing for fast web lookups and script queries
CREATE INDEX IF NOT EXISTS idx_exercise_seo_exercise_id ON public.exercise_seo(exercise_id);
CREATE INDEX IF NOT EXISTS idx_exercise_seo_seo_title ON public.exercise_seo(seo_title);
CREATE INDEX IF NOT EXISTS idx_exercise_seo_updated_at ON public.exercise_seo(updated_at);

-- Add trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_exercise_seo_updated_at()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_exercise_seo_updated_at ON public.exercise_seo;

CREATE TRIGGER trigger_exercise_seo_updated_at
BEFORE UPDATE ON public.exercise_seo
FOR EACH ROW
EXECUTE FUNCTION update_exercise_seo_updated_at();

-- Note: 
-- You must run this SQL block in your Supabase SQL Editor.
-- Once created, you may want to enable RLS (Row Level Security) depending on your setup.
-- ALTER TABLE public.exercise_seo ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Enable read access for all users" ON public.exercise_seo FOR SELECT USING (true);
