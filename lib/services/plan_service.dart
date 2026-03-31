import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';


class PlanService {
  SupabaseClient get _supabase => Supabase.instance.client;

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  String normalizeExerciseId(dynamic id) {
    if (id == null) return '';
    return id.toString().trim().padLeft(6, '0');
  }

  String buildSlug({
    required String goal,
    required String location,
    required int daysPerWeek,
    required String gender,
  }) {
    return '${goal}_${location}_${daysPerWeek}d_$gender'.toLowerCase();
  }

  // ------------------------------------------------------------
  // WORKOUT PLAN LOGIC
  // ------------------------------------------------------------

  /// Calls the generate_user_workout_plan RPC which reads user_preferences
  /// (goal, training_location, gender, training_days, duration_weeks) and
  /// writes the full plan JSON into ai_plans.schedule_json.
  Future<Map<String, dynamic>> generateWorkoutPlan() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    print('DEBUG: Calling generate_user_workout_plan RPC for user ${user.id}...');
    final response = await _supabase.rpc(
      'generate_user_workout_plan',
      params: {'p_user_id': user.id},
    );
    print('DEBUG: generate_user_workout_plan response: $response');
    if (response is Map) return Map<String, dynamic>.from(response);
    return {'status': 'success'};
  }

  Map<String, dynamic> expandPlan(
    Map<String, dynamic> templateJson,
    int durationWeeks,
  ) {
    Map<String, dynamic>? baseWeek;

    if (templateJson.containsKey('week')) {
      final weekObj = templateJson['week'];
      if (weekObj is Map && weekObj.containsKey('1')) {
        final sub = weekObj['1'];
        if (sub is Map && (sub.containsKey('1') || sub.containsKey('2'))) {
          baseWeek = sub.cast<String, dynamic>();
        }
      }
    }

    if (baseWeek == null) {
      throw Exception('Invalid template JSON: base week not found');
    }

    final Map<String, dynamic> weeks = {};
    for (int w = 1; w <= durationWeeks; w++) {
      weeks[w.toString()] = {
        'days': json.decode(json.encode(baseWeek)),
      };
    }

    int daysPerWeek = 0;
    baseWeek.forEach((_, v) {
      if (v['type'] == 'workout') daysPerWeek++;
    });

    return {
      'weeks_count': durationWeeks,
      'days_per_week': daysPerWeek,
      'weeks': weeks,
      'metadata': {
        'expanded_at': DateTime.now().toIso8601String(),
        'duration_weeks': durationWeeks,
      },
    };
  }

  Future<Map<String, dynamic>?> generatePlan({
    required String gender,
    required String goalCode,
    required String trainingLocation,
    required int trainingDays,
    required int planDurationDays,
  }) async {
    // NOTE: plan_templates table has been removed.
    // Workout plans are no longer generated from templates.
    // Returns a stub plan so the quiz flow completes without error.
    print('DEBUG: generatePlan called — returning stub (plan_templates removed).');
    return {
      'generated_slug': buildSlug(
        goal: goalCode,
        location: trainingLocation,
        daysPerWeek: trainingDays,
        gender: gender,
      ),
      'plan_duration_days': planDurationDays,
      'training_days': trainingDays,
      'gender': gender,
      'goal': goalCode,
      'location': trainingLocation,
      'weeks_count': (planDurationDays / 7).ceil().clamp(1, 52),
      'days_per_week': trainingDays,
      'weeks': {},
      'metadata': {'note': 'plan_templates removed'},
    };
  }

  Future<Map<String, dynamic>> savePlan(
    Map<String, dynamic> scheduleJson,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _supabase
        .from('ai_plans')
        .update({'is_active': false})
        .eq('user_id', user.id);

    final response = await _supabase.from('ai_plans').insert({
      'user_id': user.id,
      'created_at': DateTime.now().toIso8601String(),
      'is_active': true,
      'schedule_json': scheduleJson,
      'plan_duration_days': scheduleJson['plan_duration_days'],
      'days_per_week': scheduleJson['training_days'],
      'slug_used': scheduleJson['generated_slug'],
      'gender': scheduleJson['gender'],
    }).select().single();

    return response;
  }

  // ------------------------------------------------------------
  // ✅ MEAL PLAN (FINAL FIXED VERSION)
  // ------------------------------------------------------------

  // ------------------------------------------------------------
  // ✅ MEAL PLAN (NEW SIMPLE LOGIC)
  // ------------------------------------------------------------

  /// Check if plan exists, if not generate it using the simple RPC.
  /// This replaces all complex generation logic.
  Future<Map<String, dynamic>> generateMealPlan({
    String? goal,
    int? durationWeeks,
    String? diet,
    String? allergy,
    bool forceRegenerate = false,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. CHECK IF PLAN EXISTS
    final existing = await _supabase
        .from('user_meal_plans')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);

    // 2. GENERATE IF EMPTY OR FORCED
    if (existing.isEmpty || forceRegenerate) {
      print('DEBUG: Generating meal plan via new pivot RPC...');
      
      // Fetch user preferences to build the template key
      final prefs = await _supabase
          .from('user_preferences')
          .select('goal, diet_type, duration_weeks')
          .eq('user_id', user.id)
          .maybeSingle();
          
      String diet = 'balanced';
      String g = 'fat_loss';
      int weeks = 1;
      
      if (prefs != null) {
          diet = prefs['diet_type'] ?? 'balanced';
          g = prefs['goal'] ?? 'fat_loss';
          weeks = (prefs['duration_weeks'] as int?) ?? 1;
      }
      
      final String templateKey = resolveTemplateKey(goal: g, diet: diet);

      final response = await _supabase.rpc(
        'generate_user_meal_plan_from_template',
        params: {
            'p_user_id': user.id,
            'p_template_key': templateKey,
            'p_duration_weeks': weeks,
        },
      );
      print('DEBUG: generate_user_meal_plan_from_template ($templateKey) response: $response');
    } else {
      print('DEBUG: Meal plan already exists. Skipping generation.');
    }

    // 3. RETURN DUMMY MAP (Quiz expects a Map, but ignores content)
    return {'status': 'success', 'message': 'Plan ensured'}; 
  }

  // ----------------------------------------------------------------
  // ✅ NEW FLOW: Save preferences + call generate_user_meal_plan RPC
  // ----------------------------------------------------------------

  /// Saves quiz results to user_preferences then triggers the
  /// generate_user_meal_plan RPC which reads those preferences
  /// automatically from the DB.
  Future<void> savePreferencesAndGenerateMealPlan({
    required String mainGoal,
    required String dietType,
    required List<String> allergies,
    int durationWeeks = 4,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Save quiz answers to user_preferences (including duration_weeks)
    final supabaseService = SupabaseService();
    await supabaseService.saveUserPreferences(
      mainGoal: mainGoal,
      dietType: dietType,
      allergies: allergies,
      durationWeeks: durationWeeks,
    );

    // 2. Call RPC – using the new pivot function
    final String templateKey = resolveTemplateKey(goal: mainGoal, diet: dietType);
    print('DEBUG: Calling generate_user_meal_plan_from_template ($templateKey) RPC for user ${user.id}');
    
    final response = await _supabase.rpc(
      'generate_user_meal_plan_from_template',
      params: {
          'p_user_id': user.id,
          'p_template_key': templateKey,
          'p_duration_weeks': durationWeeks,
      },
    );
    print('DEBUG: generate_user_meal_plan response: $response');
  }

  // ----------------------------------------------------------------
  // ✅ TEMPLATE KEY RESOLVER
  // ----------------------------------------------------------------
  
  /// Generates a valid template_key matching the `meal_templates` DB table.
  /// Enforces safe fallbacks to guarantee the RPC will never fail due to
  /// a missing key configuration.
  String resolveTemplateKey({
    required String goal,
    required String diet,
  }) {
    // 1. Normalize
    String nGoal = goal.toLowerCase().trim();
    String nDiet = diet.toLowerCase().trim();

    // Normalize unknown goals to default
    if (nGoal != 'fat_loss' && nGoal != 'muscle_gain') {
      nGoal = 'fat_loss';
    }

    // Normalize unknown diets to default
    final validDiets = {'balanced', 'plant_based', 'low_carb', 'special'};
    if (!validDiets.contains(nDiet)) {
      nDiet = 'balanced';
    }

    // 2. Build key (goal_diet)
    String key = '${nGoal}_$nDiet';

    // 3. Final safety check against hardcoded DB list
    const allowedKeys = [
      'fat_loss_balanced',
      'fat_loss_plant_based',
      'fat_loss_low_carb',
      'fat_loss_special',
      'muscle_gain_balanced',
      'muscle_gain_plant_based',
      'muscle_gain_low_carb',
      'muscle_gain_special',
    ];

    if (!allowedKeys.contains(key)) {
      key = '${nGoal}_balanced';
      
      // Ultimate fallback
      if (!allowedKeys.contains(key)) {
        key = 'fat_loss_balanced';
      }
    }

    print('TEMPLATE KEY SELECTED: $key');
    return key;
  }
}
