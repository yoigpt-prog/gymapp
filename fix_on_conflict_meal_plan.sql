ALTER TABLE user_meal_plan
ADD CONSTRAINT user_meal_unique
UNIQUE (user_id, week_number, day_number, meal_type);
