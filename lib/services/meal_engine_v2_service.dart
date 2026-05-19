// lib/services/meal_engine_v2_service.dart
//
// STAGING ONLY — Dynamic Meal Engine v2 service layer.
// All methods in this file target user_quiz_profile + user_meal_plan_v2 + meals_v2.
// Production code paths are untouched.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

class MealEngineV2Service {
  final SupabaseClient _client = Supabase.instance.client;

  // ──────────────────────────────────────────────────────────────
  // Save extended quiz inputs → user_quiz_profile
  // Called from the quiz after saveUserPreferences().
  // ──────────────────────────────────────────────────────────────
  Future<void> saveUserQuizProfile({
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    double? targetWeightKg,
    required String goal,           // 'fat_loss' | 'build_muscle'
    required String activityLevel,  // 'sedentary' | 'lightly_active' | ...
    required String dietType,       // 'no_preference' | 'vegetarian' | ...
    required List<String> excludedFoods,
    required String macroPreference, // 'balanced' | 'higher_protein' | ...
    required int timelineWeeks,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final Map<String, dynamic> payload = {
      'user_id':          user.id,
      'gender':           _normalizeGender(gender),
      'age':              age.clamp(10, 100),
      'height_cm':        heightCm,
      'weight_kg':        weightKg,
      'goal':             _normalizeGoal(goal),
      'activity_level':   _normalizeActivity(activityLevel),
      'diet_type':        _normalizeDiet(dietType),
      'excluded_foods':   _cleanList(excludedFoods),
      'macro_preference': _normalizeMacro(macroPreference),
      'timeline_weeks':   timelineWeeks.clamp(1, 104),
      'updated_at':       DateTime.now().toUtc().toIso8601String(),
    };
    if (targetWeightKg != null) payload['target_weight_kg'] = targetWeightKg;

    await _client
        .from('user_quiz_profile')
        .upsert(payload, onConflict: 'user_id');

    debugPrint('[MealV2] user_quiz_profile saved: goal=${payload['goal']} '
        'diet=${payload['diet_type']} macro=${payload['macro_preference']} '
        'weeks=$timelineWeeks');
  }

  // ──────────────────────────────────────────────────────────────
  // Trigger generate_meal_plan_v2 RPC
  // ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> generateMealPlan({bool forceRegen = true}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    debugPrint('[MealV2] Calling generate_meal_plan_v2 RPC...');
    final response = await _client.rpc(
      'generate_meal_plan_v2',
      params: {
        'p_user_id':     user.id,
        'p_force_regen': forceRegen,
      },
    );

    final result = response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{'status': 'success'};

    debugPrint('[MealV2] RPC result: $result');

    if (result['status'] == 'error') {
      throw Exception('[MealV2] Generation failed: ${result['message']}');
    }

    return result;
  }

  // ──────────────────────────────────────────────────────────────
  // Fetch user's meal plan from user_meal_plan_v2 + meals_v2
  // Returns the same enriched-map shape used by MealPlanPage.
  // ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUserMealPlan({
    int? week,
    int? day,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    var query = _client
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
        .eq('user_id', user.id);

    if (week != null) query = query.eq('week_number', week);
    if (day  != null) query = query.eq('day_number',  day);

    final rows = await query
        .order('week_number', ascending: true)
        .order('day_number',  ascending: true)
        .order('meal_type',   ascending: true) as List<dynamic>;

    if (rows.isEmpty) return [];

    final List<Map<String, dynamic>> enriched = [];

    for (final row in rows) {
      final meal = row['meals_v2'] as Map<String, dynamic>?;
      if (meal == null) continue;

      final int weekNum    = (row['week_number'] as int?) ?? 1;
      final int dayOfWeek  = (row['day_number']  as int?) ?? 1;
      final int globalDay  = (weekNum - 1) * 7 + dayOfWeek;

      // Use pre-scaled ingredients if available, else fall back to meals_v2 raw
      final scaledIngs    = row['scaled_ingredients'];
      final rawIngs       = meal['ingredients_json'];
      final ingredients   = scaledIngs ?? rawIngs;

      enriched.add({
        // Plan position
        'plan_week':        weekNum,
        'plan_day':         dayOfWeek,
        'plan_global_day':  globalDay,
        'plan_meal_type':   row['meal_type'],

        // Pivot identifiers
        'plan_row_id': row['id'].toString(),  // UUID of user_meal_plan_v2 row
        'id':          meal['id'].toString(), // meals_v2 bigint id → string

        // Status
        'is_eaten':    row['is_eaten'] ?? false,
        'is_custom':   row['is_custom'] ?? false,
        'created_at':  row['created_at'] ?? row['generated_at'],

        // Meal identity
        'meal_type':   row['meal_type'],
        'name':        meal['meal_name'],
        'image_url':   meal['image_url'],

        // Macros (pre-scaled)
        'calories':    row['custom_calories'] ?? meal['base_calories'],
        'protein_g':   row['custom_protein']  ?? meal['protein_g'],
        'carbs_g':     row['custom_carbs']    ?? meal['carbs_g'],
        'fat_g':       row['custom_fats']     ?? meal['fat_g'],
        'fats_g':      row['custom_fats']     ?? meal['fat_g'], // alias

        // Scaling meta
        'scaling_factor':       row['scaling_factor'],
        'target_slot_calories': row['target_slot_calories'],

        // Ingredients (scaled)
        'ingredients_json': ingredients,
        'ingredients':      ingredients,

        // Instructions from meals_v2
        'instructions': meal['instructions'],

        // Tags (for future AI/swap features)
        'diet_tags':    meal['diet_tags'],
        'goal_tags':    meal['goal_tags'],
        'macro_tags':   meal['macro_tags'],
        'allergens':    meal['allergens'],
      });
    }

    debugPrint('[MealV2] Fetched ${enriched.length} plan rows '
        '(week=$week, day=$day)');
    return enriched;
  }

  // ──────────────────────────────────────────────────────────────
  // Toggle eaten status — updates user_meal_plan_v2
  // ──────────────────────────────────────────────────────────────
  Future<void> toggleMealEaten(String planRowId, bool isEaten) async {
    await _client
        .from('user_meal_plan_v2')
        .update({'is_eaten': isEaten})
        .eq('id', planRowId);
    debugPrint('[MealV2] toggled is_eaten=$isEaten for row=$planRowId');
  }

  // ──────────────────────────────────────────────────────────────
  // Fetch user_quiz_profile (for display / debugging)
  // ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getQuizProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('user_quiz_profile')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return row;
  }

  // ──────────────────────────────────────────────────────────────
  // Normalization helpers
  // ──────────────────────────────────────────────────────────────

  String _normalizeGender(String g) {
    final v = g.toLowerCase().trim();
    return v.contains('female') ? 'female' : 'male';
  }

  String _normalizeGoal(String g) {
    final v = g.toLowerCase().trim();
    if (v.contains('fat') || v.contains('lose') || v.contains('weight')) {
      return 'fat_loss';
    }
    return 'build_muscle';
  }

  String _normalizeActivity(String a) {
    final v = a.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').trim();
    const valid = {
      'sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extra_active',
    };
    if (valid.contains(v)) return v;
    // Map common quiz labels
    if (v.contains('light'))    return 'lightly_active';
    if (v.contains('moderate')) return 'moderately_active';
    if (v.contains('very'))     return 'very_active';
    if (v.contains('extra') || v.contains('extreme')) return 'extra_active';
    return 'moderately_active';
  }

  String _normalizeDiet(String d) {
    final v = d.toLowerCase().trim();
    if (v.contains('vegan'))          return 'vegan';
    if (v.contains('vegetarian'))     return 'vegetarian';
    if (v.contains('mediterranean'))  return 'mediterranean';
    if (v.contains('keto'))           return 'keto';
    if (v.contains('low') && v.contains('carb')) return 'low_carb';
    if (v.contains('paleo'))          return 'paleo';
    if (v.contains('gluten'))         return 'gluten_free';
    return 'no_preference';
  }

  String _normalizeMacro(String m) {
    final v = m.toLowerCase().trim();
    if (v.contains('protein'))    return 'higher_protein';
    if (v.contains('low') && v.contains('carb')) return 'lower_carb';
    if (v.contains('high') && v.contains('carb')) return 'higher_carb';
    return 'balanced';
  }

  List<String> _cleanList(List<String> items) {
    return items
        .map((s) => s.toLowerCase().trim())
        .where((s) => s.isNotEmpty && s != 'none')
        .toList();
  }
}
