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

      // 1. Fetch the Plan Rows ordered by sequential day
      var query = _client
          .from('user_meal_plan')
          .select()
          .eq('user_id', user.id);

      if (day != null) {
        print('QUERY day = $day');
        query = query.eq('day', day);
      }
      
      final planResponse = await query.order('day', ascending: true);
      
      final planRows = planResponse as List<dynamic>;
      if (planRows.isEmpty) {
          print('DEBUG: No meals found for day $day. Checking if ANY meals exist for user ${user.id}...');
          final anyRows = await _client
              .from('user_meal_plan')
              .select('day')
              .eq('user_id', user.id)
              .limit(10);
          if (anyRows.isEmpty) {
             print('DEBUG: User has 0 rows in user_meal_plan table.');
          } else {
             print('DEBUG: User HAS rows. Sample days: ${anyRows.map((e) => e['day']).toList()}');
          }
          return [];
      }

      // 2. Collect Meal IDs
      final Set<String> mealIds = {};
      for (var row in planRows) {
        if (row['meal_id'] != null) {
          mealIds.add(row['meal_id'].toString());
        }
      }

      // 3. Fetch Meal Details
      if (mealIds.isEmpty) return [];
      
      final mealsResponse = await _client
          .from('meals')
          .select()
          .inFilter('id', mealIds.toList());
          
      final mealsData = mealsResponse as List<dynamic>;
      final mealsMap = {for (var m in mealsData) m['id'].toString(): m};

      // 4. Merge Data — enrich plan rows with meal details
      final List<Map<String, dynamic>> enrichedPlan = [];

      for (var row in planRows) {
        final mealId = row['meal_id'].toString();
        final mealDetail = mealsMap[mealId];
        
        if (mealDetail != null) {
           final merged = Map<String, dynamic>.from(mealDetail);
           // 'day' is the sequential day number (1 → total_days)
           final int globalDay = (row['day'] as int?) ?? 1;
           final int weekNum = ((globalDay - 1) ~/ 7) + 1;
           final int dayOfWeek = ((globalDay - 1) % 7) + 1;
           merged['plan_week'] = weekNum;
           merged['plan_day'] = dayOfWeek;
           merged['plan_global_day'] = globalDay;
           merged['plan_meal_type'] = row['meal_type'];
           merged['is_eaten'] = row['is_eaten'] ?? false;
           merged['plan_row_id'] = row['id'];
           merged['created_at'] = row['created_at'];
           
           enrichedPlan.add(merged);
        }
      }
      
      print('DEBUG: Fetched ${enrichedPlan.length} meals from user plan (week=$week, day=$day).');
      return enrichedPlan;

    } catch (e) {
      print('Error fetching user meal plan: $e');
      return [];
    }
  }

  // Update eaten status using the unique plan row ID
  Future<void> toggleMealStatus(String planRowId, bool isEaten) async {
      try {
          await _client
             .from('user_meal_plan')
             .update({'is_eaten': isEaten})
             .eq('id', planRowId);
          print('DEBUG: Updated plan row $planRowId status to $isEaten');
      } catch (e) {
          print('ERROR updating meal status: $e');
          throw e; // Rethrow to let UI handle/revert
      }
  }

  // Replace a meal in the plan (e.g. after editing)
  // This inserts a NEW meal row into 'meals' (custom meal) and points the plan row to it.
  Future<void> replaceMealInPlan(String planRowId, Meal newMeal) async {
      try {
          // 1. Insert the new meal definition
          // We don't check for duplicates for custom meals usually, or we just insert.
          // IMPORTANT: we need to handle ingredients json properly if your DB expects it.
          // The Meal model uses 'ingredients' List<MealIngredient>.
          // The table is 'meals'. It likely has 'ingredients' column (JSONB) or text?
          // Based on previous logs, it uses `ingredients` as JSONB.
          
          final ingredientsJson = newMeal.ingredients.map((i) => {
             'name': i.name,
             'quantity': i.amount,
             'kcal': i.calories 
          }).toList();

          final mealData = {
              'name': newMeal.name,
              'meal_type': newMeal.type.toLowerCase(), // Store broadly
              'calories': newMeal.calories,
              'protein_g': newMeal.protein,
              'carbs_g': newMeal.carbs,
              'fats_g': newMeal.fats,
              'ingredients': ingredientsJson,
              // 'created_by': userId ?? // If you have this column
          };
          
          print('DEBUG: Creating new custom meal for replacement: ${newMeal.name}');
          final insertedMeal = await _client
              .from('meals')
              .insert(mealData)
              .select('id')
              .single();
          
          final newMealId = insertedMeal['id'];
          
          // 2. Update the plan row to point to this new meal
          // We also update the 'calories' override column in user_meal_plan just in case
          await _client
              .from('user_meal_plan')
              .update({
                  'meal_id': newMealId,
                  'calories': newMeal.calories, // Update target calories
                  'is_eaten': newMeal.eaten // Preserve/Update eaten status? Assuming edit keeps current state or user sets it.
              })
              .eq('id', planRowId);
              
          print('DEBUG: Updated plan row $planRowId to use new meal $newMealId');

      } catch (e) {
          print('ERROR replacing meal in plan: $e');
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

    await _client.from('user_preferences').upsert(upsertData, onConflict: 'user_id');

    print('DEBUG: user_preferences saved successfully.');
  }
}

