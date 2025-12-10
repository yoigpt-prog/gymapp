import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'meal_plan_modal.dart' hide Meal; // Hide Meal to avoid conflict
import 'edit_meal_modal.dart';
import 'custom_plan_quiz.dart';
import 'main_scaffold.dart';
import '../models/meal_model.dart';
import '../services/supabase_service.dart';
import '../widgets/red_header.dart';

class MealPlanPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MealPlanPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  // Use widget.isDarkMode or Theme brightness for dark mode check
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, Map<String, Meal>> _mealsByDay = {}; // Map of date string -> Map of slot -> Meal
  bool _isLoading = true;
  String? _errorMessage;

  // Scroll controller for hiding header
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  double _lastScrollOffset = 0;

  // Week navigation
  int _weekOffset = 0;
  DateTime _selectedDay = DateTime.now();
  bool _showingDayGrid = true; // Toggle between grid view and detail view (mobile only)

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMeals();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentScrollOffset = _scrollController.offset;
    
    if (currentScrollOffset > _lastScrollOffset && currentScrollOffset > 50) {
      if (_showHeader) {
        setState(() => _showHeader = false);
      }
    } else if (currentScrollOffset < _lastScrollOffset) {
      if (!_showHeader) {
        setState(() => _showHeader = true);
      }
    }
    
    _lastScrollOffset = currentScrollOffset;
  }

  Future<void> _loadMeals() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final allMeals = await _supabaseService.getMeals();
      
      if (!mounted) return;
      
      final Map<String, Map<String, Meal>> organizedMeals = {};
      
      // Seed the map with data for the current 2 weeks
      final now = DateTime.now();
      final planStartDate = now.subtract(Duration(days: now.weekday - 1));
      
      for (int i = 0; i < 14; i++) {
        final date = planStartDate.add(Duration(days: i));
        final dateKey = _getDateKey(date);
        
        organizedMeals[dateKey] = {};
        for (final meal in allMeals) {
          // Simplistic distribution
          organizedMeals[dateKey]![meal.type] = meal;
        }
      }

      setState(() {
        _mealsByDay = organizedMeals;
        _isLoading = false;
      });
      
      // Load eaten status from SharedPreferences
      _loadEatenStatus();
      
    } catch (e) {
      print('Error loading meals: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        // Fallback to empty
        // _mealsByDay = {}; // Keep previous data if error
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEatenStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _mealsByDay.forEach((dateKey, dayMeals) {
        dayMeals.forEach((mealType, meal) {
          final key = 'meal_eaten_${dateKey}_${meal.type}'; // Key by date and type/slot
          final isEaten = prefs.getBool(key) ?? false;
          
          if (isEaten) {
            final updatedMeal = Meal(
              id: meal.id,
              type: meal.type,
              icon: meal.icon,
              name: meal.name,
              imageUrl: meal.imageUrl,
              calories: meal.calories,
              protein: meal.protein,
              carbs: meal.carbs,
              fats: meal.fats,
              eaten: true,
              ingredients: meal.ingredients,
            );
            dayMeals[mealType] = updatedMeal;
          }
        });
      });
    });
  }

  Future<void> _saveMealStatus(String dateKey, String mealType, bool isEaten) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'meal_eaten_${dateKey}_${mealType}';
    await prefs.setBool(key, isEaten);
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildMobilePlannerContent(isDarkMode),
    );
  }

  Widget _buildMobilePlannerContent(bool isDarkMode) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF0000)));
    }

    return Column(
      children: [
        // Header
        AnimatedContainer(
          duration: Duration.zero,
          height: _showHeader ? null : 0,
          child: AnimatedOpacity(
            duration: Duration.zero,
            opacity: _showHeader ? 1.0 : 0.0,
            child: RedHeader(
              title: 'Fri : Day 26',
              subtitle: 'Your Meal Plan',
              onToggleTheme: widget.toggleTheme,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: _showingDayGrid ? _buildGridView(isDarkMode) : _buildDetailView(isDarkMode),
          ),
        ),
      ],
    );
  }

  // Grid view: 14-day selection
  Widget _buildGridView(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Column(
      children: [
        // 14-Day Meal Plan Grid
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 30),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode ? Colors.white : Colors.black,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Title
              Text(
                '14-Day Meal Plan',
                style: TextStyle(
                  fontSize: isSmallScreen ? 22 : 28,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF333333),
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 10),
              Text(
                'Select a day to view your meals',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 16 : 30),
              
              // Week 1
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Week 1',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF0000),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _build14DayGrid(1, 7, isDarkMode),
                ],
              ),
              
              SizedBox(height: isSmallScreen ? 16 : 30),
              
              // Week 2
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Week 2',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF0000),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _build14DayGrid(8, 14, isDarkMode),
                ],
              ),
              
              SizedBox(height: isSmallScreen ? 16 : 30),
              
              // Statistics Summary
              _buildStatsSummary(isDarkMode),
            ],
          ),
        ),
      ],
    );
  }

  // Detail view: Selected day's meals
  Widget _buildDetailView(bool isDarkMode) {
    final dateKey = _getDateKey(_selectedDay);
    final mealsMap = _mealsByDay[dateKey];
    final meals = mealsMap?.values.toList() ?? [];
    
    // Sort meals if needed, e.g., Breakfast, Lunch, Dinner
    final order = ['BREAKFAST', 'MORNING SNACK', 'LUNCH', 'AFTERNOON SNACK', 'DINNER'];
    meals.sort((a, b) {
      final indexA = order.indexOf(a.type);
      final indexB = order.indexOf(b.type);
      return (indexA == -1 ? 999 : indexA).compareTo(indexB == -1 ? 999 : indexB);
    });

    // Calculate progress for this day locally
    final totalMeals = meals.length;
    final eatenMeals = meals.where((m) => m.eaten).length;
    final progressPercent = totalMeals == 0 ? 0 : ((eatenMeals / totalMeals) * 100).round();

    return Column(
      children: [
        // Back to Days Button
        GestureDetector(
          onTap: () {
            setState(() {
              _showingDayGrid = true;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.white : Colors.black,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 20, color: isDarkMode ? Colors.white : Colors.black),
                const SizedBox(width: 8),
                Text(
                  'Back to Days',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Day Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white : Colors.black,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Day ${_getSelectedDayNumber()}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF0000),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$progressPercent% Complete',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Nutrition Summary Card (reusing updated logic)
        _buildStatsCard(totalMeals == 0 ? 0 : eatenMeals/totalMeals, isDarkMode, eatenMeals, totalMeals),
        
        const SizedBox(height: 16),
        
        // Meal List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: meals.length,
          itemBuilder: (context, index) {
            return _buildMealCard(meals[index], isDarkMode);
          },
        ),
      ],
    );
  }

  Widget _buildStatsCard(double progress, bool isDarkMode, int eaten, int total) {
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Calculate totals
    final dateKey = _getDateKey(_selectedDay);
    final meals = _mealsByDay[dateKey]?.values.toList() ?? [];
    
    // Target values (Mock targets - normally these would come from user profile/settings)
    const targetCalories = 2038;
    const targetProtein = 150;
    const targetCarbs = 200;
    const targetFat = 60;
    
    // Actual values
    int currentCalories = 0;
    int currentProtein = 0;
    int currentCarbs = 0;
    int currentFat = 0;
    
    for (var m in meals) {
      if (m.eaten) {
        currentCalories += m.calories;
        currentProtein += m.protein;
        currentCarbs += m.carbs;
        currentFat += m.fats;
      }
    }
    
    final remainingCalories = targetCalories - currentCalories;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Colors.white : Colors.black,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Calorie Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: currentCalories / targetCalories,
                  strokeWidth: 12,
                  backgroundColor: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green), // Or calculated color
                ),
              ),
              Column(
                children: [
                  Text(
                    'Remaining',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$remainingCalories',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total $targetCalories kcal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Macros
          _buildMacroRow('Carbs', currentCarbs, targetCarbs, Colors.blue, isDarkMode),
          const SizedBox(height: 16),
          _buildMacroRow('Protein', currentProtein, targetProtein, Colors.red, isDarkMode),
          const SizedBox(height: 16),
          _buildMacroRow('Fat', currentFat, targetFat, Colors.orange, isDarkMode),
          
          const SizedBox(height: 24),
          Divider(color: isDarkMode ? Colors.white12 : Colors.grey[200]),
          const SizedBox(height: 16),
          
          // Today's Progress Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Progress",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                '$eaten/5 meals', // Assuming 5 meals standard
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMealTimeline(eaten, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, int current, int target, Color color, bool isDarkMode) {
    final remaining = target - current;
    final progress = (current / target).clamp(0.0, 1.0);
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54),
                children: [
                  TextSpan(
                    text: '${current}g',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: isDarkMode ? Colors.white : Colors.black87
                    )
                  ),
                  TextSpan(text: ' / ${target}g '),
                  TextSpan(
                    text: '${remaining > 0 ? remaining : 0}g left',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMealTimeline(int eatenCount, bool isDarkMode) {
    // Simplistic timeline: 5 dots with lines
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (index) {
        final label = ['Breakfast', 'Morning\nSnack', 'Lunch', 'Afternoon\nSnack', 'Dinner'][index];
        final isCompleted = index < eatenCount;
        
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Container(height: 2, color: index == 0 ? Colors.transparent : Colors.grey[300])),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.red : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Container(height: 2, color: index == 4 ? Colors.transparent : Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMealCard(Meal meal, bool isDarkMode, {bool isMobile = true}) {
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white : Colors.black,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image first - Mobile Only with eaten badge overlay
          if (isMobile && meal.imageUrl != null && meal.imageUrl!.isNotEmpty) ...[
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      meal.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (meal.eaten)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Eaten',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meal.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          meal.type,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: subTextColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meal.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Row(
                    children: [
                       Text(
                        '${meal.calories} kcal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF0000),
                        ),
                      ),
                      const SizedBox(width: 8),
                       GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => EditMealModal(
                                meal: meal,
                                onSave: (updatedMeal) {
                                  setState(() {
                                    // Update the meal in the state map
                                    final dateKey = _getDateKey(_selectedDay);
                                    if (_mealsByDay.containsKey(dateKey)) {
                                      _mealsByDay[dateKey]![updatedMeal.type] = updatedMeal;
                                    }
                                  });
                                },
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                             child: Icon(
                               Icons.edit_outlined,
                               size: 20,
                               color: subTextColor,
                             ),
                          ),
                       ),
                    ],
                   ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 1),
          
          const SizedBox(height: 16),
          
          // Ingredients
          ...meal.ingredients.map((ingredient) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${ingredient.amount} • ${ingredient.calories} kcal',
                  style: TextStyle(
                    fontSize: 14,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          )).toList(),

          const SizedBox(height: 16),

          // Action Button - Eaten Toggle
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  // Toggle eaten status
                  final newStatus = !meal.eaten;
                  final newMeal = Meal(
                    id: meal.id,
                    type: meal.type,
                    icon: meal.icon,
                    name: meal.name,
                    imageUrl: meal.imageUrl,
                    calories: meal.calories,
                    protein: meal.protein,
                    carbs: meal.carbs,
                    fats: meal.fats,
                    eaten: newStatus,
                    ingredients: meal.ingredients,
                  );
                  
                  final dateKey = _getDateKey(_selectedDay);
                  if (_mealsByDay.containsKey(dateKey)) {
                    _mealsByDay[dateKey]![meal.type] = newMeal;
                    _saveMealStatus(dateKey, meal.type, newStatus);
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: meal.eaten 
                    ? (isDarkMode ? Colors.white12 : Colors.grey[200])
                    : const Color(0xFFFF0000),
                foregroundColor: meal.eaten 
                    ? (isDarkMode ? Colors.white : Colors.black87)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                meal.eaten ? 'Mark as Not Eaten' : 'Mark as Eaten',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for 14-day grid layout
  Widget _build14DayGrid(int startDay, int endDay, bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        crossAxisSpacing: isSmallScreen ? 10 : 18,
        mainAxisSpacing: isSmallScreen ? 10 : 18,
      ),
      itemCount: endDay - startDay + 1,
      itemBuilder: (context, index) {
        final dayNumber = startDay + index;
        return _buildCircularDayIndicator(dayNumber, isDarkMode);
      },
    );
  }
  
  Widget _buildCircularDayIndicator(int dayNumber, bool isDarkMode) {
    // Calculate if this day is selected
    final now = DateTime.now();
    final planStartDate = now.subtract(Duration(days: now.weekday - 1));
    final dayDate = planStartDate.add(Duration(days: dayNumber - 1));
    final isSelected = dayDate.day == _selectedDay.day && 
                      dayDate.month == _selectedDay.month && 
                      dayDate.year == _selectedDay.year;
    
    // Get progress for this day
    final dateKey = _getDateKey(dayDate);
    final dayMeals = _mealsByDay[dateKey];
    
    final totalMeals = dayMeals?.length ?? 0;
    final eatenMeals = dayMeals?.values.where((m) => m.eaten).length ?? 0;
    final progressPercent = totalMeals == 0 ? 0 : ((eatenMeals / totalMeals) * 100).round();
    final isCompleted = progressPercent == 100 && totalMeals > 0;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = dayDate;
          _showingDayGrid = false; // Switch to detail view
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isCompleted 
            ? const Color(0xFF4CAF50) 
            : (isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8)),
          borderRadius: BorderRadius.circular(16), // Rounded square
          border: Border.all(
            color: isDarkMode ? Colors.white : Colors.black,
            width: 3,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFFF0000).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 24, // Slightly reduced base size
                    fontWeight: FontWeight.w700,
                    color: isCompleted 
                      ? Colors.white 
                      : (isDarkMode ? Colors.white : const Color(0xFF333333)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2), // Reduced spacing
            Flexible(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontSize: 12, // Reduced base size
                    color: isCompleted 
                      ? Colors.white 
                      : (isDarkMode ? Colors.white54 : const Color(0xFF666666)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to get the selected day number (1-14)
  int _getSelectedDayNumber() {
    final now = DateTime.now();
    final planStartDate = now.subtract(Duration(days: now.weekday - 1));
    final difference = _selectedDay.difference(planStartDate).inDays;
    return (difference % 14) + 1;
  }
  
  Widget _buildStatsSummary(bool isDarkMode) {
    final stats = _calculateOverallStats();
    
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '${stats['daysComplete']}',
            'Days Complete',
            isDarkMode,
          ),
          _buildStatItem(
            '${stats['mealsLogged']}',
            'Meals Logged',
            isDarkMode,
          ),
          _buildStatItem(
            '${stats['overall']}%',
            'Overall',
            isDarkMode,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label, bool isDarkMode) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFF0000),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
          ),
        ),
      ],
    );
  }
  
  Map<String, int> _calculateOverallStats() {
    int daysComplete = 0;
    int mealsLogged = 0;
    int totalExpectedMeals = 0;
    
    final now = DateTime.now();
    final planStartDate = now.subtract(Duration(days: now.weekday - 1));
    
    for (int day = 1; day <= 14; day++) {
      final dayDate = planStartDate.add(Duration(days: day - 1));
      final dateKey = _getDateKey(dayDate);
      final dayMeals = _mealsByDay[dateKey];
      
      final dayTotalMeals = dayMeals?.length ?? 0;
      final dayEatenCount = dayMeals?.values.where((m) => m.eaten).length ?? 0;
      
      // Assume 5 meals per day as standard for calculation if no meals loaded yet, 
      // or use actual if present. For accurate stats we use actuals or non-zero.
      // If dayMeals is empty, we might skip it or count as 0/5.
      // Let's count as 0/5 if standard plan implies 5 meals.
      final expectedMeals = dayTotalMeals > 0 ? dayTotalMeals : 5;
      
      totalExpectedMeals += expectedMeals;
      mealsLogged += dayEatenCount;
      
      if (dayEatenCount >= expectedMeals && expectedMeals > 0) {
        daysComplete++;
      }
    }
    
    final overallPercent = totalExpectedMeals == 0 ? 0 : ((mealsLogged / totalExpectedMeals) * 100).round();
    
    return {
      'daysComplete': daysComplete,
      'mealsLogged': mealsLogged,
      'overall': overallPercent,
    };
  }
}
