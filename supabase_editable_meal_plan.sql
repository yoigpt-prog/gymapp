-- Complete Supabase Backend for Editable User Meal Plans

-- 1. Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create the Tables
CREATE TABLE public.meal_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.meals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  plan_id UUID REFERENCES public.meal_plans(id) ON DELETE CASCADE,
  day_index INTEGER NOT NULL,
  meal_type TEXT NOT NULL, -- e.g. breakfast, lunch, dinner, snack
  name TEXT NOT NULL,
  calories INTEGER DEFAULT 0,
  protein INTEGER DEFAULT 0,
  carbs INTEGER DEFAULT 0,
  fat INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.meal_ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meal_id UUID REFERENCES public.meals(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  quantity TEXT NOT NULL,
  calories INTEGER DEFAULT 0
);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_ingredients ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies

-- MEAL PLANS: Users can strictly access and modify their own meal plans
CREATE POLICY "Users can manage their own meal plans" ON public.meal_plans
  FOR ALL USING (auth.uid() = user_id);

-- MEALS: Users can manage meals that belong to their personal meal plans
CREATE POLICY "Users can manage their own meals" ON public.meals
  FOR ALL USING (
    plan_id IN (SELECT id FROM public.meal_plans WHERE user_id = auth.uid())
  );

-- MEAL INGREDIENTS: Users can manage ingredients for their securely owned meals
CREATE POLICY "Users can manage their own meal ingredients" ON public.meal_ingredients
  FOR ALL USING (
    meal_id IN (
      SELECT m.id FROM public.meals m
      JOIN public.meal_plans p ON m.plan_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

-- 5. Helpful Indexes for Performance
CREATE INDEX idx_meal_plans_user_id ON public.meal_plans(user_id);
CREATE INDEX idx_meals_plan_id_day_index ON public.meals(plan_id, day_index);
CREATE INDEX idx_meal_ingredients_meal_id ON public.meal_ingredients(meal_id);
