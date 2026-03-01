-- ============================================
-- DIAGNOSTIC & SEED: Ensure Meals Exist
-- ============================================

-- 1. Check current status
SELECT COUNT(*) as total_meals FROM public.meals;

-- 2. IF empty, seed with basic data
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM public.meals) = 0 THEN
        RAISE NOTICE 'Meals table is EMPTY. Seeding basic data...';
        
        INSERT INTO public.meals (meal_type, name, calories, protein_g, carbs_g, fats_g, allergens, diet_tags, primary_goal)
        VALUES 
        ('breakfast', 'Oatmeal', 300, 10, 45, 5, '[]', '["vegan", "vegetarian"]', 'maintain'),
        ('breakfast', 'Eggs & Toast', 400, 20, 30, 20, '["eggs", "gluten"]', '[]', 'build_muscle'),
        ('lunch', 'Chicken Salad', 500, 40, 10, 30, '[]', '["paleo"]', 'fat_loss'),
        ('lunch', 'Quinoa Bowl', 450, 15, 60, 15, '[]', '["vegan"]', 'maintain'),
        ('snack', 'Apple & Nuts', 200, 5, 20, 15, '["nuts"]', '["vegan"]', 'maintain'),
        ('snack', 'Protein Shake', 150, 30, 5, 2, '["dairy"]', '[]', 'build_muscle'),
        ('dinner', 'Salmon & Veggies', 600, 45, 10, 40, '["fish"]', '["paleo", "ketogenic"]', 'fat_loss'),
        ('dinner', 'Beef Stir Fry', 700, 50, 60, 25, '["soy"]', '[]', 'build_muscle');

        RAISE NOTICE 'Done Seeding.';
    ELSE
        RAISE NOTICE 'Meals table already has % rows.', (SELECT COUNT(*) FROM public.meals);
    END IF;
END $$;

-- 3. Show sample data to verify column types
SELECT id, name, meal_type, (primary_goal) as goal FROM public.meals LIMIT 5;
