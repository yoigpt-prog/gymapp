import 'package:flutter/material.dart';

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  final List<Meal> _meals = [
    Meal(
      id: 1,
      type: 'BREAKFAST',
      icon: '🥣',
      name: 'Oatmeal with banana & almonds',
      calories: 410,
      eaten: false,
      ingredients: [
        MealIngredient('Rolled oats', '½ cup (40g)', 150),
        MealIngredient('Low-fat milk', '1 cup (240ml)', 100),
        MealIngredient('Banana', '1 medium (120g)', 100),
        MealIngredient('Almonds', '6 pieces (10g)', 60),
      ],
    ),
    Meal(
      id: 2,
      type: 'MORNING SNACK',
      icon: '🍎',
      name: 'Greek yogurt & honey',
      calories: 150,
      eaten: false,
      ingredients: [
        MealIngredient('Greek yogurt (low-fat)', '½ cup (100g)', 80),
        MealIngredient('Honey', '1 tsp (7g)', 25),
        MealIngredient('Blueberries', '½ cup (75g)', 45),
      ],
    ),
    Meal(
      id: 3,
      type: 'LUNCH',
      icon: '🥙',
      name: 'Grilled chicken salad',
      calories: 535,
      eaten: true,
      ingredients: [
        MealIngredient('Grilled chicken breast', '150g', 250),
        MealIngredient('Mixed greens', '2 cups', 20),
        MealIngredient('Cherry tomatoes', '1 cup', 30),
        MealIngredient('Cucumber', '½ cup', 15),
        MealIngredient('Feta cheese', '30g', 80),
        MealIngredient('Olive oil', '1 tbsp (10g)', 120),
        MealIngredient('Balsamic vinegar', '1 tbsp', 20),
      ],
    ),
    Meal(
      id: 4,
      type: 'AFTERNOON SNACK',
      icon: '🥜',
      name: 'Apple with peanut butter',
      calories: 200,
      eaten: false,
      ingredients: [
        MealIngredient('Apple', '1 medium', 95),
        MealIngredient('Peanut butter', '1 tbsp', 105),
      ],
    ),
    Meal(
      id: 5,
      type: 'DINNER',
      icon: '🍗',
      name: 'Baked salmon with vegetables',
      calories: 600,
      eaten: false,
      ingredients: [
        MealIngredient('Salmon fillet', '200g', 350),
        MealIngredient('Broccoli', '1 cup', 55),
        MealIngredient('Sweet potato', '1 medium', 130),
        MealIngredient('Olive oil', '½ tbsp', 60),
        MealIngredient('Lemon', '1 wedge', 5),
      ],
    ),
  ];

  int get _totalMeals => _meals.length;
  int get _eatenMeals => _meals.where((m) => m.eaten).length;
  int get _totalCalories =>
      _meals.fold<int>(0, (sum, meal) => sum + meal.calories);

  @override
  Widget build(BuildContext context) {
    final progress =
        _totalMeals == 0 ? 0.0 : _eatenMeals / _totalMeals.toDouble();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildStatsCard(progress, isDarkMode),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _meals.length,
                itemBuilder: (context, index) {
                  return _buildMealCard(_meals[index], isDarkMode);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI SECTIONS ----------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF4444), Color(0xFFFF6666)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Day 1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your Meal Plan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '↑',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(double progress, bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Macros row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroItem(
                value: '$_totalCalories',
                label: 'Calories',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              _macroItem(
                value: '120g',
                label: 'Protein',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              _macroItem(
                value: '190g',
                label: 'Carbs',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              _macroItem(
                value: '70g',
                label: 'Fat',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Progress",
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_eatenMeals/$_totalMeals meals',
                style: TextStyle(
                  fontSize: 14,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: const Color(0xFFF0F0F0),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  color: const Color(0xFFFF4444),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroItem({
    required String value,
    required String label,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF4444),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: subTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(Meal meal, bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    meal.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    meal.type,
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${meal.calories} kcal',
                    style: const TextStyle(
                      color: Color(0xFFFF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: subTextColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            meal.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          // Ingredients
          Column(
            children: meal.ingredients
                .map(
                  (ing) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFF0F0F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ing.name,
                          style: TextStyle(color: subTextColor),
                        ),
                        Row(
                          children: [
                            Text(
                              ing.amount,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white38 : Colors.black38,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${ing.calories} kcal',
                              style: const TextStyle(
                                color: Color(0xFFFF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          // Mark as eaten button
          GestureDetector(
            onTap: () => _toggleEaten(meal),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: meal.eaten ? const Color(0xFFFF4444) : cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF4444), width: 2),
              ),
              child: Center(
                child: Text(
                  meal.eaten ? '✓ Eaten' : 'Mark as Eaten',
                  style: TextStyle(
                    color: meal.eaten ? Colors.white : const Color(0xFFFF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleEaten(Meal meal) {
    setState(() {
      meal.eaten = !meal.eaten;
    });
  }
}

// ---------- DATA MODELS ----------

class Meal {
  final int id;
  final String type;
  final String icon;
  final String name;
  int calories;
  bool eaten;
  final List<MealIngredient> ingredients;

  Meal({
    required this.id,
    required this.type,
    required this.icon,
    required this.name,
    required this.calories,
    this.eaten = false,
    required this.ingredients,
  });
}

class MealIngredient {
  final String name;
  final String amount;
  final int calories;

  MealIngredient(this.name, this.amount, this.calories);
}
