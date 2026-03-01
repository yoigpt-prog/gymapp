import 'package:flutter/foundation.dart';

class QuizService {
  // Normalize quiz answers into the core 4 fields + duration
  Map<String, dynamic> normalizeQuizAnswers({required Map<String, dynamic> answersJson}) {
    print('DEBUG: QuizService normalizing answers...');
    
    // 1. Gender (male/female)
    String gender = (answersJson['gender'] ?? 'male').toString().toLowerCase();
    if (gender.contains('female')) gender = 'female';
    else gender = 'male';

    // 2. Goal Code (fat_loss / build_muscle)
    String goalInput = (answersJson['main_goal'] ?? 'build_muscle').toString().toLowerCase();
    String goalCode = 'build_muscle'; 
    
    if (goalInput.contains('fat') || goalInput.contains('weight') || goalInput.contains('lose')) {
      goalCode = 'fat_loss';
    } else if (goalInput.contains('muscle') || goalInput.contains('size') || goalInput.contains('build')) {
      goalCode = 'build_muscle';
    }

    // 3. Training Location (home/gym)
    String locInput = (answersJson['training_location'] ?? answersJson['workout_location'] ?? 'gym').toString().toLowerCase();
    String location = locInput.contains('home') ? 'home' : 'gym';

    // 4. Training Days (int 3..7)
    int days = 4;
    String daysInput = (answersJson['training_days'] ?? answersJson['workout_days'] ?? '4').toString();
    final daysMatch = RegExp(r'(\d+)').firstMatch(daysInput);
    if (daysMatch != null) {
      days = int.parse(daysMatch.group(1)!);
    }
    if (days < 3) days = 3;
    if (days > 7) days = 7;

    // 5. Plan Duration
    int duration = 28;
    String durInput = (answersJson['plan_duration'] ?? '28').toString();
    final weekMatch = RegExp(r'(\d+)\s*Weeks?', caseSensitive: false).firstMatch(durInput);
    
    if (weekMatch != null) {
       duration = int.parse(weekMatch.group(1)!) * 7;
    } else {
       final digitMatch = RegExp(r'(\d+)').firstMatch(durInput);
       if (digitMatch != null) {
          int val = int.parse(digitMatch.group(1)!);
          duration = (val < 14) ? val * 7 : val;
       }
    }

    // Build template_slug
    final templateSlug = '${goalCode}_${location}_${days}d_$gender';
    
    // 6. Meals per day
    int meals = 4;

    // 7. Diet Type
    String dietInput = (answersJson['diet_type'] ?? '').toString().toLowerCase();
    String diet = '';
    if (dietInput.contains('no preference') || dietInput.isEmpty) {
      diet = '';
    } else if (dietInput.contains('vegetarian')) {
      diet = 'vegetarian';
    } else if (dietInput.contains('vegan')) {
      diet = 'vegan';
    } else if (dietInput.contains('keto')) {
      diet = 'keto';
    } else if (dietInput.contains('low-carb') || dietInput.contains('low_carb')) {
      diet = 'low_carb';
    } else if (dietInput.contains('mediterranean')) {
      diet = 'mediterranean';
    } else if (dietInput.contains('gluten')) {
      diet = 'gluten_free';
    }

    // 8. Allergies
    String allergy = 'none';
    var allergyInput = answersJson['allergies'];
    if (allergyInput is List) {
       final realAllergies = allergyInput
          .map((a) => a.toString().toLowerCase().trim())
          .where((s) => s != 'none' && s.isNotEmpty)
          .toList();
       if (realAllergies.isNotEmpty) allergy = realAllergies.join(',');
    } else if (allergyInput is String) {
       String s = allergyInput.toLowerCase().trim();
       if (s != 'none' && s.isNotEmpty) allergy = s;
    }

    print('DEBUG: Meal Params -> Meals:$meals, Diet:$diet, Allergy:$allergy');

    return {
      'gender': gender,
      'goal_code': goalCode,
      'training_location': location,
      'training_days': days,
      'plan_duration_days': duration,
      'template_slug': templateSlug,
      'meals_per_day': meals,
      'diet_type': diet,
      'allergy': allergy,
    };
  }
}
