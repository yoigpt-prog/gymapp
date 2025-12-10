-- First, let's check what breakfast looks like to match the format
-- SELECT * FROM meals WHERE meal_type ILIKE '%breakfast%';

-- Add meal data for the remaining 4 meal slots
-- IMPORTANT: Delete old attempts first to avoid duplicates
DELETE FROM meals WHERE meal_type IN ('morning snack', 'Morning Snack', 'lunch', 'Lunch', 'afternoon snack', 'Afternoon Snack', 'dinner', 'Dinner');

-- Morning Snack: Greek Yogurt Parfait
INSERT INTO meals (meal_type, name, image_url, calories, protein_g, carbs_g, fats_g, ingredients_json)
VALUES (
  'Morning Snack',
  'Greek Yogurt Parfait',
  'https://images.unsplash.com/photo-1488477304112-4944851de03d?w=800&h=800&fit=crop',
  320,
  24,
  34,
  8,
  '[
    {"name": "greek yogurt", "quantity": "200g", "kcal": "140"},
    {"name": "granola", "quantity": "34g", "kcal": "130"},
    {"name": "blueberries", "quantity": "85g", "kcal": "40"},
    {"name": "honey", "quantity": "15g", "kcal": "50"}
  ]'::jsonb
);

-- Lunch: Grilled Chicken & Quinoa Bowl
INSERT INTO meals (meal_type, name, image_url, calories, protein_g, carbs_g, fats_g, ingredients_json)
VALUES (
  'Lunch',
  'Grilled Chicken & Quinoa Bowl',
  'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&h=800&fit=crop',
  690,
  59,
  55,
  18,
  '[
    {"name": "grilled chicken breast", "quantity": "180g", "kcal": "297"},
    {"name": "quinoa", "quantity": "185g", "kcal": "222"},
    {"name": "sweet potato, roasted", "quantity": "100g", "kcal": "90"},
    {"name": "broccoli, steamed", "quantity": "85g", "kcal": "31"},
    {"name": "avocado", "quantity": "35g", "kcal": "56"}
  ]'::jsonb
);

-- Afternoon Snack: Green Protein Smoothie
INSERT INTO meals (meal_type, name, image_url, calories, protein_g, carbs_g, fats_g, ingredients_json)
VALUES (
  'Afternoon Snack',
  'Green Protein Smoothie',
  'https://images.unsplash.com/photo-1610970881699-44a5587cabec?w=800&h=800&fit=crop',
  280,
  25,
  31,
  7,
  '[
    {"name": "protein powder", "quantity": "30g", "kcal": "120"},
    {"name": "spinach", "quantity": "30g", "kcal": "7"},
    {"name": "banana", "quantity": "118g", "kcal": "105"},
    {"name": "almond milk, unsweetened", "quantity": "240ml", "kcal": "30"},
    {"name": "chia seeds", "quantity": "12g", "kcal": "58"}
  ]'::jsonb
);

-- Dinner: Baked Salmon with Vegetables
INSERT INTO meals (meal_type, name, image_url, calories, protein_g, carbs_g, fats_g, ingredients_json)
VALUES (
  'Dinner',
  'Baked Salmon with Vegetables',
  'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800&h=800&fit=crop',
  650,
  48,
  42,
  28,
  '[
    {"name": "salmon fillet", "quantity": "170g", "kcal": "367"},
    {"name": "sweet potato, mashed", "quantity": "200g", "kcal": "180"},
    {"name": "asparagus, roasted", "quantity": "134g", "kcal": "27"},
    {"name": "olive oil", "quantity": "10ml", "kcal": "88"}
  ]'::jsonb
);

-- Verify the data was inserted correctly
SELECT * FROM meals ORDER BY 
  CASE meal_type
    WHEN 'breakfast' THEN 1
    WHEN 'morning snack' THEN 2
    WHEN 'lunch' THEN 3
    WHEN 'afternoon snack' THEN 4
    WHEN 'dinner' THEN 5
  END;
