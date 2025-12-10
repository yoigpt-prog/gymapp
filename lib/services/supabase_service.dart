import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_model.dart';
import 'dart:math';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> addMeal(Map<String, dynamic> mealData) async {
    try {
      await _client.from('meals').insert(mealData);
    } catch (e) {
      print('Error adding meal: $e');
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
}

