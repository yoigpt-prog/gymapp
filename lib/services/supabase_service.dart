import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_model.dart';
import 'meal_engine_v2_service.dart';
import '../config/env_config.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  SupabaseClient get client => _client;

  Future<void> addMeal(Map<String, dynamic> mealData) async {
    try {
      await _client.from('meals').insert(mealData);
    } catch (e) {
      print('Error adding meal: $e');
      throw e;
    }
  }

  Future<void> sendContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      await _client.from('contact_messages').insert({
        'name': name.trim(),
        'email': email.trim(),
        'subject': subject.trim(),
        'message': message.trim(),
      });
      print('DEBUG: Successfully inserted contact message to Supabase');
    } catch (e) {
      print('ERROR: Failed to send contact message: $e');
      throw e;
    }
  }

  Future<List<Meal>> getMeals() async {
    try {
      // Fetch meals by category in parallel to ensure we get a mix of all types
      // regardless of the API default row limit (usually 1000).
      // We fetch a random selection or just the first N of each type.
      
      final futures = [
        _fetchMealsByType('breakfast', 200),
        _fetchMealsByType('lunch', 200),
        _fetchMealsByType('dinner', 200),
        _fetchMealsByType('snack', 300), // More snacks for morning/afternoon slots
      ];

      final results = await Future.wait(futures);
      
      final allMeals = results.expand((x) => x).toList();
      print('DEBUG: Fetched total ${allMeals.length} meals across all categories');
      
      return allMeals;
    } catch (e) {
      print('Error fetching meals: $e');
      throw e;
    }
  }

  Future<List<Meal>> _fetchMealsByType(String type, int limit) async {
    try {
      final response = await _client
          .from('meals')
          .select()
          .ilike('meal_type', '%$type%') // Handle 'Breakfast', 'breakfast', etc.
          .limit(limit)
          .order('id', ascending: true); // Or random if possible, but consistent sort is safer for pagination

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Meal.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching $type meals: $e');
      return [];
    }
  }

  /// Fetch a random meal by meal_type from the database
  Future<Meal?> getRandomMealByType(String mealType) async {
    try {
      print('Fetching random meal for type: $mealType'); // DEBUG
      
      // Fetch all meals of this type
      final response = await _client
          .from('meals')
          .select()
          .eq('meal_type', mealType);

      print('Response for $mealType: $response'); // DEBUG

      if (response == null || (response as List).isEmpty) {
        print('No meals found for type: $mealType');
        return null;
      }

      final List<dynamic> data = response as List<dynamic>;
      
      // Pick a random meal from the results
      final random = Random();
      final randomIndex = random.nextInt(data.length);
      
      print('Found ${data.length} meals for $mealType, selected index $randomIndex'); // DEBUG
      
      return Meal.fromJson(data[randomIndex]);
    } catch (e) {
      print('Error fetching meal by type $mealType: $e');
      return null;
    }
  }

  /// Map UI slot name to database meal_type value
  static String mapSlotToMealType(String slotName) {
    switch (slotName) {
      case 'Breakfast':
        return 'breakfast';
      case 'Morning Snack':
        return 'snack';
      case 'Afternoon Snack':
        return 'snack';
      case 'Lunch':
        return 'lunch';
      case 'Dinner':
        return 'dinner';
      default:
        return 'breakfast';
    }
  }
  Future<List<Map<String, dynamic>>> getUserMealPlan({int? week, int? day}) async {
    try {
      return await MealEngineV2Service().getUserMealPlan(week: week, day: day);
    } catch (e) {
      print('ERROR: [SupabaseService] getUserMealPlan (v2) failed: $e');
      return [];
    }
  }

  // Log eaten status with full snapshot to meal_logs
  // Does NOT update meals table to allow templates to remain untouched if reused.
  Future<void> toggleMealStatus(Meal meal, bool isEaten) async {
      try {
          final user = _client.auth.currentUser;
          if (user == null) throw Exception('User not logged in');

          if (meal.planId != null) {
              await MealEngineV2Service().toggleMealEaten(meal.planId!, isEaten);
          }

          if (!isEaten && meal.planId != null) {
              // If un-marking, delete from meal_logs (taking the most recent for this meal UUID)
              final logs = await _client.from('meal_logs')
                  .select('id')
                  .eq('meal_id', meal.planId!)
                  .eq('user_id', user.id)
                  .order('eaten_at', ascending: false)
                  .limit(1);
                  
              if (logs.isNotEmpty) {
                  await _client.from('meal_logs').delete().eq('id', logs.first['id']);
                  print('DEBUG: Removed from meal_logs for ${meal.planId}');
              }
          }
      } catch (e) {
          print('ERROR updating meal status: $e');
          throw e;
      }
  }

  // Save edits natively by updating the custom fields in user_meal_plan_v2.
  Future<void> saveMealOverrides(String originalMealId, Meal meal) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final payload = {
        'custom_calories': meal.calories,
        'custom_protein': meal.protein,
        'custom_carbs': meal.carbs,
        'custom_fats': meal.fats,
        'scaled_ingredients': meal.ingredients.map((ing) => {
          'name': ing.name,
          'amount': ing.amount,
          'kcal': ing.calories,
        }).toList(),
        'is_custom': true,
      };

      await _client
          .from('user_meal_plan_v2')
          .update(payload)
          .eq('id', originalMealId);
      
      print('DEBUG: [SupabaseService] V2 saved overrides on user_meal_plan_v2: $payload');
    } catch (e) {
      print('ERROR: [SupabaseService] V2 failed to save overrides: $e');
      throw e;
    }
  }

  // ---------------------------------------------------------------
  // Save quiz results to user_preferences table
  // ---------------------------------------------------------------
  Future<void> saveUserPreferences({
    required String mainGoal,        // raw quiz value e.g. "Lose Weight"
    required String dietType,        // raw quiz value e.g. "Plant-Based"
    required List<String> allergies, // raw list e.g. ["Gluten", "None"]
    int durationWeeks = 4,           // number of weeks selected in quiz
    // Workout fields (read by generate_user_workout_plan RPC)
    String? trainingLocation,        // 'gym' or 'home'
    String? gender,                  // 'male' or 'female'
    int? trainingDays,               // 3..7
    // Profile Fields
    double? height,
    double? weight,
    int? age,
    double? targetWeight,
    String? experienceLevel,
    String? sessionDuration,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Map goal → enum
    final goalLower = mainGoal.toLowerCase();
    String goalType;
    if (goalLower.contains('fat') ||
        goalLower.contains('lose') ||
        goalLower.contains('weight')) {
      goalType = 'fat_loss';
    } else {
      goalType = 'muscle_gain';
    }

    // Map diet → enum (balanced / plant_based / low_carb / special)
    final dietLower = dietType.toLowerCase();
    String dietGroup;
    if (dietLower.contains('plant') || dietLower.contains('vegan') || dietLower.contains('vegetarian')) {
      dietGroup = 'plant_based';
    } else if (dietLower.contains('keto') || dietLower.contains('low') || dietLower.contains('paleo')) {
      dietGroup = 'low_carb';
    } else if (dietLower.contains('halal') || dietLower.contains('kosher') || dietLower.contains('gluten')) {
      dietGroup = 'special';
    } else {
      dietGroup = 'balanced'; // covers 'No Preference', 'Mediterranean', etc.
    }

    // Clean allergies: remove 'None', deduplicate, lowercase
    final cleanAllergies = allergies
        .map((a) => a.toLowerCase().trim())
        .where((a) => a.isNotEmpty && a != 'none')
        .toSet()
        .toList();

    print('DEBUG: Saving user_preferences: goal=$goalType, diet=$dietGroup, '
        'allergies=$cleanAllergies, duration=${durationWeeks}w, '
        'location=$trainingLocation, gender=$gender, trainingDays=$trainingDays');

    final Map<String, dynamic> upsertData = {
      'user_id': user.id,
      'goal': goalType,
      'diet': dietGroup,
      'duration_weeks': durationWeeks,
      'allergies': cleanAllergies,
    };
    if (trainingLocation != null) upsertData['training_location'] = trainingLocation;
    if (gender != null) upsertData['gender'] = gender;
    if (trainingDays != null) upsertData['training_days'] = trainingDays;
    // Physical stats — included in the SAME upsert so they are never skipped
    if (height != null) upsertData['height_cm'] = height;
    if (weight != null) upsertData['weight_kg'] = weight;
    if (age != null) upsertData['age'] = age;
    if (targetWeight != null) upsertData['target_weight_kg'] = targetWeight;
    if (experienceLevel != null) upsertData['experience_level'] = experienceLevel;
    if (sessionDuration != null) upsertData['session_duration'] = sessionDuration;

    // Single atomic upsert — all fields together
    await _client.from('user_preferences').upsert(upsertData, onConflict: 'user_id');
    print('DEBUG: user_preferences saved successfully (single upsert).');
  }

  // ---------------------------------------------------------------
  // NEW CLOUD MIGRATION: Favorites
  // ---------------------------------------------------------------
  Future<List<String>> getFavorites() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getStringList('local_favorites') ?? [];
      }
      
      final response = await _client
          .from('user_favorites')
          .select('exercise_name')
          .eq('user_id', user.id);
          
      final rows = response as List<dynamic>;
      return rows.map((e) => e['exercise_name'].toString()).toList();
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting favorites: $e');
      return [];
    }
  }

  Future<void> toggleFavorite(String exerciseName, bool isFavorite) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        final prefs = await SharedPreferences.getInstance();
        List<String> favs = prefs.getStringList('local_favorites') ?? [];
        if (isFavorite && !favs.contains(exerciseName)) {
          favs.add(exerciseName);
        } else if (!isFavorite && favs.contains(exerciseName)) {
          favs.remove(exerciseName);
        }
        await prefs.setStringList('local_favorites', favs);
        return;
      }

      if (isFavorite) {
        await _client.from('user_favorites').upsert({
          'user_id': user.id,
          'exercise_name': exerciseName,
        }, onConflict: 'user_id, exercise_name');
      } else {
        await _client
            .from('user_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('exercise_name', exerciseName);
      }
    } catch (e) {
      print('DEBUG: [SupabaseService] Error toggling favorite: $e');
    }
  }

  // ---------------------------------------------------------------
  // NEW CLOUD MIGRATION: Workout Progress
  // ---------------------------------------------------------------
  Future<List<String>> getCompletedExercises(String dateYMD) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('user_workout_progress')
          .select('completed_exercises')
          .eq('user_id', user.id)
          .eq('date', dateYMD)
          .maybeSingle();

      if (response != null && response['completed_exercises'] != null) {
        return List<String>.from(response['completed_exercises']);
      }
      return [];
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting completed exercises: $e');
      return [];
    }
  }

  Future<void> updateCompletedExercises(String dateYMD, List<String> exercises, bool isCompletedDay) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('user_workout_progress').upsert({
        'user_id': user.id,
        'date': dateYMD,
        'completed_exercises': exercises,
        'is_completed_day': isCompletedDay,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, date');
    } catch (e) {
      print('DEBUG: [SupabaseService] Error updating workout progress: $e');
    }
  }

  Future<List<String>> getCompletedWorkoutDays() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('user_workout_progress')
          .select('date')
          .eq('user_id', user.id)
          .eq('is_completed_day', true);

      final rows = response as List<dynamic>;
      return rows.map((e) => e['date'].toString()).toList();
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting completed workout days: $e');
      return [];
    }
  }

  Future<Map<String, List<String>>> getAllCompletedExercises() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {};

      final response = await _client
          .from('user_workout_progress')
          .select('date, completed_exercises')
          .eq('user_id', user.id);

      final Map<String, List<String>> result = {};
      final rows = response as List<dynamic>;
      for (var row in rows) {
        if (row['completed_exercises'] != null) {
          result[row['date'].toString()] = List<String>.from(row['completed_exercises']);
        }
      }
      return result;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting all completed exercises: $e');
      return {};
    }
  }

  Future<Map<String, Map<String, List<String>>>> getAllWorkoutCustomizations() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {};

      final response = await _client
          .from('user_workout_progress')
          .select('date, added_exercises, removed_exercises')
          .eq('user_id', user.id);

      final Map<String, Map<String, List<String>>> result = {};
      final rows = response as List<dynamic>;
      for (var row in rows) {
        final added = row['added_exercises'] != null ? List<String>.from(row['added_exercises']) : <String>[];
        final removed = row['removed_exercises'] != null ? List<String>.from(row['removed_exercises']) : <String>[];
        result[row['date'].toString()] = {
          'added': added,
          'removed': removed,
        };
      }
      return result;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting all customizations: $e');
      return {};
    }
  }

  Future<void> updateDayCustomizations(String dateYMD, List<String> added, List<String> removed) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('user_workout_progress').upsert({
        'user_id': user.id,
        'date': dateYMD,
        'added_exercises': added,
        'removed_exercises': removed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, date');
    } catch (e) {
      print('DEBUG: [SupabaseService] Error updating day customizations: $e');
    }
  }

  Future<List<dynamic>> getFavoriteExercisesDetails() async {
    try {
      final user = _client.auth.currentUser;
      List<String> favoriteNames = [];

      if (user == null) {
        final prefs = await SharedPreferences.getInstance();
        favoriteNames = prefs.getStringList('local_favorites') ?? [];
      } else {
        final response = await _client
            .from('user_favorites')
            .select('exercise_name')
            .eq('user_id', user.id);
        final rows = response as List<dynamic>;
        favoriteNames = rows.map((e) => e['exercise_name'].toString()).toList();
      }

      if (favoriteNames.isEmpty) return [];

      final detailsResponse = await _client
          .from('exercises')
          .select('id, exercise_name, target_muscle, synergist, difficulty_level, '
                'instruction_1, instruction_2, instruction_3, instruction_4, '
                'urls, exercise_type, equipment, is_male, is_female, group_path')
          .inFilter('exercise_name', favoriteNames);

      return detailsResponse as List<dynamic>;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting favorite exercise details: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------
  // NEW CLOUD MIGRATION: Profile Stats
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>?> getProfileStats() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('user_preferences')
          .select('height_cm, weight_kg, target_weight_kg, age, gender, goal')
          .eq('user_id', user.id)
          .maybeSingle();

      return response;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting profile stats: $e');
      return null;
    }
  }

  Future<void> updateProfileStats({
    double? height, 
    double? weight, 
    double? targetWeight,
    int? age, 
    String? name, 
    String? gender, 
    String? goal
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Update basic table fields
      final Map<String, dynamic> updates = {};
      if (height != null) updates['height_cm'] = height;
      if (weight != null) updates['weight_kg'] = weight;
      if (targetWeight != null) updates['target_weight_kg'] = targetWeight;
      if (age != null) updates['age'] = age;
      if (gender != null) updates['gender'] = gender;
      if (goal != null) updates['goal'] = goal;

      if (updates.isNotEmpty) {
        updates['user_id'] = user.id; // required for upsert
        await _client.from('user_preferences').upsert(updates, onConflict: 'user_id');
      }

      // Update auth userMetadata for 'name'
      if (name != null && name.trim().isNotEmpty) {
        await _client.auth.updateUser(
          UserAttributes(data: {'full_name': name.trim()}),
        );
      }
    } catch (e) {
      print('DEBUG: [SupabaseService] Error updating profile stats: $e');
    }
  }

  // ---------------------------------------------------------------
  // NEW MEAL PLAN BACKEND METHODS
  // ---------------------------------------------------------------
  
  Future<Map<String, dynamic>?> createMealPlan(String userId) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != userId) return null;
    
    try {
      final response = await _client.from('meal_plans').insert({
        'user_id': user.id,
        'name': 'My Meal Plan',
      }).select().single();
      return response;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error creating meal plan: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMealPlan(String userId) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != userId) return null;
    
    try {
      final response = await _client
          .from('meal_plans')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting meal plan: $e');
      return null;
    }
  }

  Future<List<dynamic>> getMealsByDay(String planId, int dayIndex) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    
    try {
      final response = await _client
          .from('meals')
          .select('*, meal_ingredients(*)')
          .eq('plan_id', planId)
          .eq('day_index', dayIndex);
      return response;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting meals by day: $e');
      return [];
    }
  }

  Future<void> updateMeal(String mealId, Map<String, dynamic> mealData) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    try {
      await _client.from('meals').update(mealData).eq('id', mealId);
      print('DEBUG: [SupabaseService] Updated meal macros for $mealId');
    } catch (e) {
      print('DEBUG: [SupabaseService] Error updating meal: $e');
      throw e;
    }
  }

  Future<void> deleteIngredients(String mealId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    try {
      await _client.from('meal_ingredients').delete().eq('meal_id', mealId);
      print('DEBUG: [SupabaseService] Deleted old ingredients for meal $mealId');
    } catch (e) {
      print('DEBUG: [SupabaseService] Error deleting ingredients: $e');
      throw e;
    }
  }

  Future<void> insertIngredients(String mealId, List<Map<String, dynamic>> ingredients) async {
    final user = _client.auth.currentUser;
    if (user == null || ingredients.isEmpty) return;
    
    try {
      final insertData = ingredients.map((i) => {
        ...i,
        'meal_id': mealId,
      }).toList();
      
      await _client.from('meal_ingredients').insert(insertData);
      print('DEBUG: [SupabaseService] Inserted ${ingredients.length} ingredients for $mealId');
    } catch (e) {
      print('DEBUG: [SupabaseService] Error inserting ingredients: $e');
      throw e;
    }
  }

  // ---------------------------------------------------------------
  // NEW MEAL HISTORY BACKEND METHODS (Immutable Snapshots)
  // ---------------------------------------------------------------

  Future<void> logMealEaten(Meal meal, int dayIndex) async {
    final user = _client.auth.currentUser;
    final mealPlanId = meal.planId;
    if (user == null || mealPlanId == null) return;

    try {
      final ingredientsJson = meal.ingredients.map((i) => {
        'name': i.name,
        'quantity': i.amount,
        'calories': i.calories,
      }).toList();

      // Delete any existing log for this meal + day combination first,
      // then insert fresh. This avoids needing a unique DB constraint.
      await _client
          .from('meal_logs')
          .delete()
          .eq('user_id', user.id)
          .eq('meal_id', mealPlanId)
          .eq('day_index', dayIndex);

      await _client.from('meal_logs').insert({
        'user_id': user.id,
        'meal_id': mealPlanId,
        'day_index': dayIndex,
        'meal_name': meal.name,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fats,
        'ingredients': ingredientsJson,
        'eaten_at': DateTime.now().toUtc().toIso8601String(),
      });
      print('DEBUG: [SupabaseService] Logged meal snapshot for $mealPlanId on day $dayIndex');
    } catch (e) {
      print('DEBUG: [SupabaseService] Error logging meal eaten: $e');
      rethrow; // Surface error so the calling page can react
    }
  }

  Future<List<dynamic>> getMealsHistoryByDay(String userId, int dayIndex) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != userId) return [];

    try {
      final response = await _client
          .from('meal_logs')
          .select()
          .eq('user_id', user.id)
          .eq('day_index', dayIndex)
          .order('eaten_at', ascending: false);
      return response;
    } catch (e) {
      print('DEBUG: [SupabaseService] Error getting meal history: $e');
      return [];
    }
  }
}

