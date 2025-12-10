class Meal {
  final String id;
  final String type;
  final String icon;
  final String name;
  final String? imageUrl; // New field
  int calories;
  final int protein;
  final int carbs;
  final int fats;
  bool eaten;
  final List<MealIngredient> ingredients;

  Meal({
    required this.id,
    required this.type,
    required this.icon,
    required this.name,
    this.imageUrl,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.eaten = false,
    required this.ingredients,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final type = json['meal_type'] as String? ?? 'Snack';
    
    return Meal(
      id: json['id'].toString(),
      type: type.toUpperCase(),
      icon: _getIconForType(type),
      name: json['name'] as String? ?? 'Unknown Meal',
      imageUrl: json['image_url'] as String?, // Map from image_url
      calories: json['calories'] as int? ?? 0,
      protein: json['protein_g'] as int? ?? 0,
      carbs: json['carbs_g'] as int? ?? 0,
      fats: (json['fats_g'] ?? json['fat_g']) as int? ?? 0,
      eaten: false,
      ingredients: (json['ingredients_json'] as List<dynamic>?)
              ?.map((e) => MealIngredient(
                    e['name'] as String? ?? '',
                    e['quantity'] as String? ?? '', // Map from 'quantity'
                    int.tryParse(e['kcal']?.toString() ?? '0') ?? 0, // Map from 'kcal' string
                  ))
              .toList() ??
          <MealIngredient>[],
    );
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
}
