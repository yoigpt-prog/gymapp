import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://wewztpamzhrzbbgyutyf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws',
  );

  try {
    print('Signing in anonymously...');
    final res = await supabase.auth.signInAnonymously();
    final userId = res.user?.id;
    
    print('Inserting mock user_quiz_profile...');
    await supabase.from('user_quiz_profile').insert({
      'user_id': userId,
      'gender': 'male',
      'age': 25,
      'height_cm': 180,
      'weight_kg': 80,
      'target_weight_kg': 75,
      'goal': 'fat_loss',
      'activity_level': 'moderately_active',
      'diet_type': 'no_preference',
      'macro_preference': 'balanced',
      'timeline_weeks': 4
    });

    print('Calling generate_meal_plan_v2...');
    await supabase.rpc('generate_meal_plan_v2', params: {
      'p_user_id': userId,
      'p_force_regen': true,
    });

    print('Fetching meal plan...');
    final List<dynamic> rows = await supabase
        .from('user_meal_plan_v2')
        .select('''
          id,
          week_number,
          day_number,
          meal_type,
          meal_id,
          scaling_factor,
          target_slot_calories,
          custom_calories,
          custom_protein,
          custom_carbs,
          custom_fats,
          scaled_ingredients,
          is_eaten,
          is_custom,
          generated_at,
          created_at,
          meals_v2 (
            id,
            meal_name,
            image_url,
            meal_type,
            base_calories,
            protein_g,
            carbs_g,
            fat_g,
            diet_tags,
            allergens,
            goal_tags,
            macro_tags,
            ingredients_json,
            instructions
          )
        ''')
        .eq('user_id', userId as String)
        .limit(1);

    if (rows.isEmpty) {
      print('No rows returned.');
      return;
    }

    final row = rows.first;
    final meal = row['meals_v2'] as Map<String, dynamic>?;

    final enriched = {
        'plan_week':        row['week_number'],
        'plan_day':         row['day_number'],
        'plan_global_day':  1,
        'plan_meal_type':   row['meal_type'],
        'plan_row_id':      row['id'],
        
        'id':               meal!['id'],
        'meal_name':        meal['meal_name'],
        'image_url':        meal['image_url'],
        'instructions':     meal['instructions'],
        
        'calories':         row['custom_calories'] ?? row['target_slot_calories'] ?? meal['base_calories'],
        'protein_g':        row['custom_protein']  ?? meal['protein_g'],
        'carbs_g':          row['custom_carbs']    ?? meal['carbs_g'],
        'fat_g':            row['custom_fats']     ?? meal['fat_g'],
        
        'diet_tags':        meal['diet_tags'],
        'allergens':        meal['allergens'],
        'goal_tags':        meal['goal_tags'],
        'macro_tags':       meal['macro_tags'],
        
        'ingredients_json':   meal['ingredients_json'],
        'scaled_ingredients': row['scaled_ingredients'],
        
        'is_eaten':         row['is_eaten'] ?? false,
        'is_custom':        row['is_custom'] ?? false,
        'generated_at':     row['generated_at'],
        'created_at':       row['created_at'],
      };

    print('Enriched row: $enriched');
    
    print('Testing pseudo Meal.fromJson...');
    final customCal = enriched['custom_calories'];
    print('custom_calories: $customCal (${customCal.runtimeType})');
    
    // Simulate what Meal.fromJson does
    final rawList = (enriched['ingredients'] as List<dynamic>?)
        ?? (enriched['scaled_ingredients'] as List<dynamic>?)
        ?? (enriched['ingredients_json'] as List<dynamic>?)
        ?? <dynamic>[];
        
    print('Raw ingredients length: ${rawList.length}');
    for (var e in rawList) {
        if (e is Map<String, dynamic>) {
            final name = e['name'] as String? ?? '';
            final amount = e['amount']?.toString() ?? e['quantity']?.toString() ?? '';
            print('Ingredient parsed: name=$name, amount=$amount');
        } else {
            print('Ingredient is not a map: $e');
        }
    }

  } catch (e) {
    print('Error: $e');
  }
}
