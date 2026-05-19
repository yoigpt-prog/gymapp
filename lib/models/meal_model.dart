class Meal {
  final String id;
  final String type;
  final String icon;
  final String name;
  final String? imageUrl;
  final String? instructions; // From meals_v2
  int calories;
  final int protein;
  final int carbs;
  final int fats;
  bool eaten;
  String? planId;
  final List<MealIngredient> ingredients;

  Meal({
    required this.id,
    required this.type,
    required this.icon,
    required this.name,
    this.imageUrl,
    this.instructions,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.eaten = false,
    this.planId,
    required this.ingredients,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final type = json['meal_type'] as String? ?? 'Snack';

    // Parse ingredients — handle all possible key shapes from both old table and meals_v2
    // scaled_ingredients (v2): [{name, amount, kcal}] where kcal may be a string
    // ingredients_json (v2):   [{name, amount, kcal}]
    // meal_ingredients (old):  [{name, quantity, calories}]
    List<MealIngredient> ingredients = [];

    final rawList = (json['ingredients'] as List<dynamic>?)
        ?? (json['scaled_ingredients'] as List<dynamic>?)
        ?? (json['ingredients_json'] as List<dynamic>?)
        ?? <dynamic>[];

    ingredients = rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => MealIngredient(
              e['name'] as String? ?? '',
              // amount field — v2 uses 'amount', old uses 'quantity'
              e['amount'] as String?
                  ?? e['quantity'] as String?
                  ?? '',
              // kcal may be int or string — handle both
              _parseCalories(e['kcal'])
                  ?? _parseCalories(e['calories'])
                  ?? 0,
            ))
        .toList();

    // Meal-level calories:
    // 1. Use custom_calories (pre-scaled, from user_meal_plan_v2) — most accurate
    // 2. Fall back to 'calories' field
    // 3. Do NOT sum ingredient kcal from meals_v2 (they may not include per-ingredient cal)
    final customCal = _parseIntFromAny(json['custom_calories']);
    final storedCal = _parseIntFromAny(json['calories']);
    final ingredientSum = ingredients.fold<int>(0, (sum, i) => sum + i.calories);

    int resolvedCalories;
    if (customCal != null && customCal > 0) {
      resolvedCalories = customCal;
    } else if (storedCal != null && storedCal > 0) {
      resolvedCalories = storedCal;
    } else if (ingredientSum > 0) {
      resolvedCalories = ingredientSum;
    } else {
      resolvedCalories = 0;
    }

    // If ingredient kcal values are all 0 but the meal has total calories,
    // distribute them proportionally by gram weight (for direct meals_v2 reads
    // and swap sheet where raw ingredients_json is used without RPC preprocessing).
    final hasAnyKcal = ingredients.any((i) => i.calories > 0);
    if (!hasAnyKcal && resolvedCalories > 0 && ingredients.isNotEmpty) {
      // Extract numeric gram weight from each ingredient's amount string
      double totalGrams = 0;
      final gramWeights = ingredients.map((ing) {
        final match = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(ing.amount);
        final g = match != null ? double.tryParse(match.group(1)!) ?? 0.0 : 0.0;
        totalGrams += g;
        return g;
      }).toList();

      if (totalGrams > 0) {
        ingredients = List.generate(ingredients.length, (i) {
          final estimatedKcal = (gramWeights[i] / totalGrams * resolvedCalories).round();
          return MealIngredient(
            ingredients[i].name,
            ingredients[i].amount,
            estimatedKcal,
          );
        });
      }
    }

    return Meal(
      id: json['id'].toString(),
      type: type.toUpperCase(),
      icon: _getIconForType(type),
      name: json['meal_name'] as String?
          ?? json['name'] as String?
          ?? 'Unknown Meal',
      imageUrl: json['image_url'] as String?,
      instructions: json['instructions'] as String?,
      calories: resolvedCalories,
      protein: (_parseIntFromAny(json['custom_protein'])
              ?? _parseIntFromAny(json['protein_g'])) ?? 0,
      carbs:   (_parseIntFromAny(json['custom_carbs'])
              ?? _parseIntFromAny(json['carbs_g'])) ?? 0,
      fats:    (_parseIntFromAny(json['custom_fats'])
              ?? _parseIntFromAny(json['fats_g'])
              ?? _parseIntFromAny(json['fat_g'])) ?? 0,
      eaten: json['is_eaten'] as bool? ?? false,
      planId: json['plan_row_id']?.toString(),
      ingredients: ingredients,
    );
  }

  static int? _parseCalories(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round();
    return null;
  }

  static int? _parseIntFromAny(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round();
    return null;
  }

  static String _getIconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('breakfast')) return '🥣';
    if (t.contains('lunch')) return '🥙';
    if (t.contains('dinner')) return '🍗';
    if (t.contains('snack')) return '🍎';
    return '🍽️';
  }
}

class MealIngredient {
  final String name;
  final String amount;
  final int calories;

  MealIngredient(this.name, this.amount, this.calories);

  factory MealIngredient.fromJson(Map<String, dynamic> json) {
    return MealIngredient(
      json['name'] as String? ?? '',
      json['amount'] as String? ?? json['quantity'] as String? ?? '',
      Meal._parseCalories(json['kcal'])
          ?? Meal._parseCalories(json['calories'])
          ?? 0,
    );
  }
}
