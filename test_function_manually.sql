-- TEST: Manually call the meal plan generation function
-- This will show us if the function works or if there's an error
-- ==================================================

-- 🔴 IMPORTANT: Set a valid User ID here for testing in SQL Editor
-- You can copy one from the Authentication > Users table
-- The one below is from your screenshot (yw9yrcaa11@lnovic.com)
\set test_user_id 'a097950f-f737-4c3f-adbc-8be6c08f06fb'

-- Mock Authentication for SQL Editor context
SET local role authenticated;
SET local "request.jwt.claim.sub" = :'test_user_id';

-- Verify it worked
SELECT auth.uid() as current_auth_user;

-- TEST 1: Test Core Function (Optional)
-- SELECT generate_meal_plan_for_user(
--     'build_mass', 
--     1,            
--     '',           
--     'none'        
-- );


-- TEST 2: Test Simple Meal Plan Generation
-- ========================================
-- Example: Generate for 3 weeks, vegan diet
SELECT generate_simple_meal_plan(
    :'test_user_id'::uuid,
    3,              -- Duration: 3 weeks
    'maintain',     -- Goal
    'vegan',        -- Diet
    'none'          -- Allergies
);

-- Check results
SELECT day_number, meal_type, meal_order, meal_id
FROM public.user_meal_plan
WHERE user_id = :'test_user_id'::uuid
  AND day_number = 1
ORDER BY meal_order;
