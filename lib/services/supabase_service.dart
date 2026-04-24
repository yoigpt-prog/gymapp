import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_model.dart';
import 'dart:math';

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
      final user = _client.auth.currentUser;
      print('DEBUG: [SupabaseService] getUserMealPlan called. AUTH USER ID = ${user?.id}');
      
      if (user == null) {
          print('ERROR: User is null in getUserMealPlan!');
          throw Exception('User not logged in');
      }

      // 1. Fetch the user's active meal plan ID
      print("Fetching from meal_plans, NOT ai_plans");
      final planResponse = await _client
          .from('user_meal_plans')
          .select('id')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (planResponse == null) {
          print('DEBUG: User has 0 rows in meal_plans table. Auto-creating a shell plan.');
          final insertResponse = await _client.from('user_meal_plans').insert({
              'user_id': user.id,
              'template_key': 'custom',
          }).select('id').single();
          
          final newPlanId = insertResponse['id'].toString();
          return []; // Return empty meals (no crash)
      }
      
      final String activePlanId = planResponse['id'].toString();

      // 2. Fetch meals for this plan using the pivot table
      var query = _client
          .from('user_meal_plan_meals')
          .select('''
            id,
            week_number,
            day_number,
            meal_type,
            is_eaten,
            meals (
              id,
              meal_code,
              name,
              image_url,
              calories,
              protein_g,
              carbs_g,
              fat_g,
              ingredients_json,
              meal_ingredients (*)
            )
          ''')
          .eq('plan_id', activePlanId);

      if (week != null) {
        query = query.eq('week_number', week);
      }
      if (day != null) {
        query = query.eq('day_number', day);
      }
      
      final pivotData = await query.order('day_number', ascending: true) as List<dynamic>;
      
      if (pivotData.isEmpty) return [];

      // 4. Map them back to the enriched plan format expected by UI
      final List<Map<String, dynamic>> enrichedPlan = [];

      for (var pivotRow in pivotData) {
        final mealObj = pivotRow['meals'];
        if (mealObj == null) continue;

        final mealId = mealObj['id'].toString();
        final merged = <String, dynamic>{};
        
        // Use week_number directly from DB
        final int weekNum = (pivotRow['week_number'] as int?) ?? 1;
        final int dayOfWeek = (pivotRow['day_number'] as int?) ?? 1;
        final int globalDay = (weekNum - 1) * 7 + dayOfWeek;
        
        merged['plan_week'] = weekNum;
        merged['plan_day'] = dayOfWeek;
        merged['plan_global_day'] = globalDay;
        merged['plan_meal_type'] = pivotRow['meal_type'];
        merged['meal_type'] = pivotRow['meal_type']; // Pass the explicit type for Meal.fromJson
        
        merged['plan_row_id'] = pivotRow['id']; // Important: Use the pivot UUID
        merged['id'] = mealId; // The real global meal UUID
        merged['is_eaten'] = pivotRow['is_eaten'] ?? false;
        merged['name'] = mealObj['name'];
        merged['image_url'] = mealObj['image_url'];
        merged['calories'] = mealObj['calories'];
        merged['protein_g'] = mealObj['protein_g'];
        merged['carbs_g'] = mealObj['carbs_g'];
        merged['fats_g'] = mealObj['fat_g'];
        
        // Attach DB ingredients 
        final List<dynamic> mealIngs = mealObj['meal_ingredients'] ?? [];
        final List<dynamic> jsonIngs = mealObj['ingredients_json'] ?? [];
        merged['ingredients'] = mealIngs.isNotEmpty ? mealIngs : jsonIngs;
        
        enrichedPlan.add(merged);
      }
      
      print('DEBUG: Fetched ${enrichedPlan.length} isolated meals from active plan.');
      return enrichedPlan;

    } catch (e) {
      print('Error fetching isolated user meal plan: $e');
      return [];
    }
  }

  // Log eaten status with full snapshot to meal_logs
  // Does NOT update meals table to allow templates to remain untouched if reused.
  Future<void> toggleMealStatus(Meal meal, bool isEaten) async {
      try {
          final user = _client.auth.currentUser;
          if (user == null) throw Exception('User not logged in');

          // Persist the toggled state to DB tables depending on architecture
          if (meal.planId != null) {
              try {
                  await _client
                      .from('user_meal_plan_meals')
                      .update({'is_eaten': isEaten})
                      .eq('id', meal.planId!);
              } catch (_) {}
          }

          if (isEaten) {
              // Create a JSON snapshot of ingredients
              final ingredientsJson = meal.ingredients.map((i) => {
                  'name': i.name,
                  'quantity': i.amount,
                  'calories': i.calories,
              }).toList();

              await _client.from('meal_logs').insert({
                  'user_id': user.id,
                  'meal_id': meal.id,  // the isolated user meal UUID
                  'meal_name': meal.name,
                  'total_calories': meal.calories,
                  'total_protein': meal.protein,
                  'total_carbs': meal.carbs,
                  'total_fat': meal.fats,
                  'ingredients_json': ingredientsJson,
                  'eaten_at': DateTime.now().toIso8601String(),
              });
              print('DEBUG: Inserted full snapshot into meal_logs for ${meal.id}');
          } else {
              // If un-marking, delete from meal_logs (taking the most recent for this meal)
              final logs = await _client.from('meal_logs')
                  .select('id')
                  .eq('meal_id', meal.id)
                  .eq('user_id', user.id)
                  .order('eaten_at', ascending: false)
                  .limit(1);
                  
              if (logs.isNotEmpty) {
                  await _client.from('meal_logs').delete().eq('id', logs.first['id']);
                  print('DEBUG: Removed from meal_logs for ${meal.id}');
              }
          }
      } catch (e) {
          print('ERROR updating meal status: $e');
          throw e;
      }
  }

  // Save edits natively by cloning the meal and attaching it to the pivot.
  // Replaces the old approach since meals are now global and static.
  Future<void> saveMealOverrides(String originalMealId, Meal meal) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (meal.planId == null) {
      print('Error: Cannot edit meal without a pivot planId');
      return;
    }

    try {
      final String safeMealCode = DateTime.now().millisecondsSinceEpoch.toString() + '_custom';
      
      // 1. Fetch original meal row to clone all properties (like primary_goal)
      final originalMealRow = await _client.from('meals').select().eq('id', meal.id).maybeSingle();
      
      final Map<String, dynamic> cloneData = originalMealRow != null 
          ? Map<String, dynamic>.from(originalMealRow as Map<String, dynamic>) 
          : {};
          
      cloneData.remove('id');
      cloneData.remove('created_at');

      // Overlay with custom edits
      cloneData['name'] = meal.name;
      cloneData['calories'] = meal.calories;
      cloneData['protein_g'] = meal.protein;
      cloneData['carbs_g'] = meal.carbs;
      cloneData['fat_g'] = meal.fats;
      cloneData['meal_code'] = safeMealCode;
      cloneData['user_id'] = user.id;
      cloneData['is_custom'] = true;
      // Force keep the original image_url, never overwrite it with the potentially missing UI value
      cloneData['ingredients_json'] = meal.ingredients.map((ing) => {
        'name': ing.name,
        'quantity': ing.amount,
        'kcal': ing.calories,
      }).toList();

      // Create a brand new custom meal in the global table
      final newMealRaw = await _client.from('meals').insert(cloneData).select('id').single();

      final String newMealId = newMealRaw['id'].toString();

      // 2. Link this new custom meal to the user's pivot row
      await _client.from('user_meal_plan_meals').update({
        'meal_id': newMealId,
      }).eq('id', meal.planId!);

      // 3. Insert new ingredients linked to the newly cloned meal
      if (meal.ingredients.isNotEmpty) {
        final List<Map<String, dynamic>> ingPayload = meal.ingredients.map((ing) {
          return {
            'meal_id': newMealId,
            'name': ing.name,
            'quantity': ing.amount,
            'calories': ing.calories,
          };
        }).toList();

        await _client.from('meal_ingredients').insert(ingPayload);
      }
      
      print('DEBUG: Cloned customized meal and assigned to pivot row ${meal.planId}');
    } catch (e) {
      print('Error saving meal edits natively: $e');
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
      if (user == null) return [];
      
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
      if (user == null) return;

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
    if (user == null || meal.id == null) return;

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
          .eq('meal_id', meal.id!)
          .eq('day_index', dayIndex);

      await _client.from('meal_logs').insert({
        'user_id': user.id,
        'meal_id': meal.id,
        'day_index': dayIndex,
        'meal_name': meal.name,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fats,
        'ingredients': ingredientsJson,
        'eaten_at': DateTime.now().toUtc().toIso8601String(),
      });
      print('DEBUG: [SupabaseService] Logged meal snapshot for ${meal.id} on day $dayIndex');
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

