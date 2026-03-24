import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'meal_plan_modal.dart' hide Meal; // Hide Meal to avoid conflict
import 'edit_meal_modal.dart';
import 'custom_plan_quiz.dart';
import 'main_scaffold.dart';
import '../models/meal_model.dart';
import '../services/supabase_service.dart';
import '../services/plan_service.dart';
import '../widgets/red_header.dart';

import '../widgets/polygon_border.dart';

class MealPlanPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MealPlanPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<MealPlanPage> createState() => MealPlanPageState();
}

class MealPlanPageState extends State<MealPlanPage> {
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
  
  // Public refresh method
  Future<void> refresh() async {
    await _loadMeals(clearData: true);
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

  // Dynamic plan duration
  int _planDurationWeeks = 2; // Default, will update from DB
  DateTime? _planCreationDate; // Store the actual plan start date

  // ---------------------------------------------------------------
  // Cache helpers
  // ---------------------------------------------------------------
  static const String _cachePrefix = 'meal_plan_cache_';
  final SupabaseService _cacheSupabaseService = SupabaseService();

  String? _getCacheKey() {
    final user = _cacheSupabaseService.client.auth.currentUser;
    return user != null ? '$_cachePrefix${user.id}' : null;
  }

  Future<void> _savePlanToCache(Map<String, dynamic> data) async {
    try {
      final key = _getCacheKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      print('DEBUG: [Cache] Meal plan cached with key $key');
    } catch (e) {
      print('DEBUG: [Cache] Failed to save cache: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadPlanFromCache() async {
    try {
      final key = _getCacheKey();
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      print('DEBUG: [Cache] Loaded meal plan from cache key $key');
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: [Cache] Failed to load cache: $e');
      return null;
    }
  }

  // Restore organised meals from cache payload
  void _applyCachedData(Map<String, dynamic> cached) {
    try {
      final rawDays = cached['days'] as Map<String, dynamic>?;
      if (rawDays == null) return;
      final Map<String, Map<String, Meal>> restored = {};
      rawDays.forEach((dateKey, slotMap) {
        final slots = slotMap as Map<String, dynamic>;
        restored[dateKey] = {};
        slots.forEach((slotName, mealJson) {
          restored[dateKey]![slotName] =
              Meal.fromJson(mealJson as Map<String, dynamic>);
        });
      });
      if (cached['planDurationWeeks'] is int) {
        _planDurationWeeks = cached['planDurationWeeks'] as int;
      }
      setState(() {
        _mealsByDay = restored;
        _isLoading = false;
      });
      print('DEBUG: [Cache] Applied cached data: ${restored.length} days');
    } catch (e) {
      print('DEBUG: [Cache] Failed to apply cached data: $e');
    }
  }

  // Build cache payload from current state
  Map<String, dynamic> _buildCachePayload() {
    final Map<String, Map<String, dynamic>> days = {};
    _mealsByDay.forEach((dateKey, slotMap) {
      days[dateKey] = {};
      slotMap.forEach((slotName, meal) {
        days[dateKey]![slotName] = {
          'id': meal.id,
          'meal_type': meal.type,
          'name': meal.name,
          'image_url': meal.imageUrl,
          'calories': meal.calories,
          'protein_g': meal.protein,
          'carbs_g': meal.carbs,
          'fats_g': meal.fats,
          'is_eaten': meal.eaten,
          'plan_row_id': meal.planId,
          'ingredients': meal.ingredients
              .map((i) => {'name': i.name, 'amount': i.amount, 'calories': i.calories})
              .toList(),
        };
      });
    });
    return {'days': days, 'planDurationWeeks': _planDurationWeeks};
  }

  // ---------------------------------------------------------------
  // Load meals (with cache-first strategy)
  // ---------------------------------------------------------------
  Future<void> _loadMeals({int? week, int? day, bool clearData = false}) async {
    try {
      if (!mounted) return;

      // For a full fetch with no filters, try showing cached data instantly
      bool usedCache = false;
      if (week == null && day == null && !clearData) {
        final cached = await _loadPlanFromCache();
        if (cached != null && mounted) {
          _applyCachedData(cached);
          usedCache = true;
        }
      }

      if (!usedCache) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          if (clearData) _mealsByDay.clear();
        });
      }

      print('DEBUG: [MealPlanPage] Loading meals (week: $week, day: $day)...');

      // Pass the filters to the service
      List<Map<String, dynamic>> userPlan = await _supabaseService.getUserMealPlan(week: week, day: day);
      print('DEBUG: [MealPlanPage] Fetched ${userPlan.length} rows.');

      // If empty and doing a full fetch, log it — generation only happens after quiz
      if (userPlan.isEmpty && week == null && day == null) {
        print('DEBUG: [MealPlanPage] No plan found. Complete the quiz to generate one.');
      }

      if (!mounted) return;
      
      // If fetching all (week==null), update duration
      if (week == null && day == null) {
          if (userPlan.isEmpty) {
             print('DEBUG: [MealPlanPage] No generated plan found.');
             setState(() => _isLoading = false);
             return;
          }
          // DYNAMIC DURATION CALCULATION
          // Use MAX day_number to determine weeks (e.g. Day 21 -> 3 weeks)
          int maxDay = 0;
          if (userPlan.isNotEmpty) {
             final days = userPlan.map((m) => m['plan_global_day'] as int? ?? 0);
             if (days.isNotEmpty) {
                maxDay = days.reduce(max);
             }
          }
          
          // 2. Convert to weeks (ceil)
          final totalWeeks = (maxDay / 7).ceil();
          
          // 3. Update state
          _planDurationWeeks = totalWeeks > 0 ? totalWeeks : 2; // Default to 2 if 0
          
          print('DEBUG: [MealPlanPage] Dynamic Duration: Max Day $maxDay -> $totalWeeks weeks');
           
          // CAPTURE CREATION DATE from the first row if available
          if (userPlan.isNotEmpty && userPlan.first['created_at'] != null) {
              final createdAt = DateTime.parse(userPlan.first['created_at']);
              _planCreationDate = DateTime(createdAt.year, createdAt.month, createdAt.day); // Normalize
              print('DEBUG: [MealPlanPage] Plan creation date set to: $_planCreationDate');
          }

      }

      final Map<String, Map<String, Meal>> organizedMeals = {};
      
      
      // 2. Calculate Dates
      // Use the actual plan creation date if available to ensure keys match UI logic
      DateTime planStartDate;
      if (_planCreationDate != null) {
          planStartDate = _planCreationDate!;
      } else {
          final now = DateTime.now();
          final currentMonday = now.subtract(Duration(days: now.weekday - 1));
          planStartDate = DateTime(currentMonday.year, currentMonday.month, currentMonday.day);
      }
      
      // 3. Group by Global Day
      final Map<int, List<Map<String, dynamic>>> deepGrouped = {};
      
      // Debug first item to inspect structure
      if (userPlan.isNotEmpty) {
         print('DEBUG: [MealPlanPage] First row sample keys: ${userPlan.first.keys.toList()}');
         print('DEBUG: [MealPlanPage] First row sample values: ${userPlan.first}');
      }

      for (var item in userPlan) {
          // SAFE CAST: plan_global_day
          // This should now be populated by the fixes in SupabaseService
          final gDayRaw = item['plan_global_day'];
          final int gDay;
          if (gDayRaw is int) {
             gDay = gDayRaw;
          } else if (gDayRaw is String) {
             gDay = int.tryParse(gDayRaw) ?? 1;
          } else {
             // Fallback logic if null: calculate from week/day
             final w = item['plan_week'] as int? ?? 1;
             final d = item['plan_day'] as int? ?? 1;
             gDay = ((w - 1) * 7) + d;
          }
          
          if (!deepGrouped.containsKey(gDay)) deepGrouped[gDay] = [];
          deepGrouped[gDay]!.add(item);
      }
      
      // 4. Map to UI Slots
      deepGrouped.forEach((gDay, dayItems) {
          // Sort meals in correct order: breakfast → lunch → snack → dinner
          dayItems.sort((a, b) {
              int score(String t) {
                  t = t.toLowerCase();
                  if (t.contains('breakfast')) return 1;
                  if (t.contains('lunch'))     return 2;
                  if (t.contains('snack'))     return 3;
                  if (t.contains('dinner'))    return 4;
                  return 5;
              }
              final sa = score(a['plan_meal_type'] as String? ?? '');
              final sb = score(b['plan_meal_type'] as String? ?? '');
              if (sa == sb) return 0;
              return sa.compareTo(sb);
          });

          // Assign slots based on meal type from database
          // Simply use the meal_type as-is to ensure all meals appear
          for (var item in dayItems) {
              final typeStr = (item['plan_meal_type'] as String? ?? '').toLowerCase();
              
              // Use the meal type directly from database
              // This ensures all meals appear regardless of their type
              String slotName = typeStr.toUpperCase();

              final date = planStartDate.add(Duration(days: gDay - 1));
              final dateKey = _getDateKey(date);
              
              if (!organizedMeals.containsKey(dateKey)) {
                organizedMeals[dateKey] = {};
              }

              final meal = Meal.fromJson(item);
              // Override mapped properties with plan specific ones
              final targetCals = item['target_calories'];
              if (targetCals != null) {
                  if (targetCals is int) {
                      meal.calories = targetCals;
                  } else if (targetCals is num) {
                      meal.calories = targetCals.toInt();
                  } else if (targetCals is String) {
                      meal.calories = int.tryParse(targetCals) ?? 0;
                  }
              }
              // Ensure eaten status is pulled
              // Meal.fromJson now handles 'is_eaten', but let's be explicitly sure
              // item['is_eaten'] comes from SupabaseService join
              
              print('DEBUG: [MealPlanPage] Adding meal to $dateKey / $slotName: ${meal.name} (eaten: ${meal.eaten})');
              organizedMeals[dateKey]![slotName] = meal;
          }
      });

      print('DEBUG: [MealPlanPage] Organized ${organizedMeals.length} days with meals');
      organizedMeals.forEach((date, meals) {
          print('DEBUG: [MealPlanPage]   $date: ${meals.length} meals');
      });

      setState(() {
        if (week != null || day != null) {
            // Merging specific day fetch: override existing keys
            organizedMeals.forEach((key, value) {
                _mealsByDay[key] = value;
            });
        } else {
            // Full fetch: replace all
            _mealsByDay = organizedMeals;
        }
        _isLoading = false;
      });

      // Persist to cache for fast next load (only on full fetches)
      if (week == null && day == null && _mealsByDay.isNotEmpty) {
        _savePlanToCache(_buildCachePayload());
      }
      
    } catch (e) {
      print('ERROR loading meals: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Helper: Format Date Key
  String _getDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Save Meal Status to DB
  Future<void> _saveMealStatus(String dateKey, String mealType, bool newStatus) async {
    try {
      final meal = _mealsByDay[dateKey]?[mealType];
      if (meal == null || meal.planId == null) {
          print('ERROR: Cannot update status, missing meal or planId for $mealType');
          return;
      }

      // Sync to DB
      await _supabaseService.toggleMealStatus(meal.planId!, newStatus);
      print('Status updated for plan row ${meal.planId}');

    } catch (e) {
      print('Error saving meal status: $e');
    }
  }

  // Legacy/No-op as loading happens in main flow
  Future<void> _loadEatenStatus() async {
    // Eaten status is now loaded directly in _loadMeals via updated SupabaseService
    // So this can be empty.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          bottom: false,
          child: _buildMobilePlannerContent(isDarkMode),
        ),
      ),
    );
  }

  Widget _buildMobilePlannerContent(bool isDarkMode) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF0000)));
    }

    return Column(
      children: [
        // Header
        if (kIsWeb)
          AnimatedContainer(
          duration: Duration.zero,
          height: _showHeader ? null : 0,
          child: AnimatedOpacity(
            duration: Duration.zero,
            opacity: _showHeader ? 1.0 : 0.0,
            child: RedHeader(
              title: '${_getDayName(_selectedDay.weekday)} : Day ${_getSelectedDayNumber()}',
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

  // Grid view: Dynamic Week Generation
  Widget _buildGridView(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Column(
      children: [
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
               )
            ],
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$_planDurationWeeks-Week Meal Plan',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 22 : 28,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
                  ),
                  maxLines: 1,
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
              
              // Dynamic Weeks Generator
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _planDurationWeeks,
                itemBuilder: (context, index) {
                   final weekNum = index + 1;
                   final startDay = (index * 7) + 1;
                   final endDay = startDay + 6;
                   
                   return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                            'Week $weekNum',
                            style: const TextStyle(
                               fontSize: 18,
                               fontWeight: FontWeight.w700,
                               color: Color(0xFFFF0000),
                            ),
                         ),
                         const SizedBox(height: 15),
                         _build14DayGrid(startDay, endDay, isDarkMode), // Reusing method name but works for 7 days
                         const SizedBox(height: 30),
                      ],
                   );
                },
              ),

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
    final order = ['BREAKFAST', 'MORNING SNACK', 'LUNCH', 'SNACK', 'AFTERNOON SNACK', 'DINNER'];
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
            // _loadMeals(); // REMOVED: Rely on local state to avoid race condition with DB write
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
    
    // Calculate totals dynamically from the current day's meals
    final dateKey = _getDateKey(_selectedDay);
    final meals = _mealsByDay[dateKey]?.values.toList() ?? [];
    
    int targetCalories = 0;
    int targetProtein = 0;
    int targetCarbs = 0;
    int targetFat = 0;
    
    int currentCalories = 0;
    int currentProtein = 0;
    int currentCarbs = 0;
    int currentFat = 0;
    
    for (var m in meals) {
      targetCalories += m.calories;
      targetProtein += m.protein;
      targetCarbs += m.carbs;
      targetFat += m.fats;
      
      if (m.eaten) {
        currentCalories += m.calories;
        currentProtein += m.protein;
        currentCarbs += m.carbs;
        currentFat += m.fats;
      }
    }
    
    final remainingCalories = (targetCalories - currentCalories).clamp(0, 99999);

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
                  value: targetCalories > 0 ? (currentCalories / targetCalories).clamp(0.0, 1.0) : 0.0,
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
                '$eaten/$total meals', // Dynamic meal count
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: total > 0 ? eaten / total : 0.0,
              backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, int current, int target, Color color, bool isDarkMode) {
    final remaining = target - current;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    
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
                                onSave: (updatedMeal) async {
                                  // Persist change
                                  if (updatedMeal.planId != null) {
                                      await _supabaseService.replaceMealInPlan(updatedMeal.planId!, updatedMeal);
                                      // Refresh from DB to confirm IDs and new calories
                                      // Calculate w/d from selected day
                                      final diff = _selectedDay.difference(DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1))).inDays;
                                      final gDay = diff + 1; // Approx
                                      // Actually, easier to just reload the current view's data
                                      // or let the optimistic local map update hold (but we need new meal_id for next edits)
                                      
                                      // Better to reload
                                      // We need strict week/day.
                                      // Let's rely on the fact that _loadMeals without args does a full refresh which is safer but slower?
                                      // Or just update local state if we trust it.
                                      // "When user edits... immediately recompute... and refresh UI"
                                      
                                      setState(() {
                                        final dateKey = _getDateKey(_selectedDay);
                                        if (_mealsByDay.containsKey(dateKey)) {
                                          _mealsByDay[dateKey]![updatedMeal.type] = updatedMeal;
                                        }
                                      });
                                  }
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
                Text(
                  ingredient.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '.' * 100,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white30 : Colors.black26,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                 RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '${ingredient.amount} • ',
                        style: const TextStyle(color: Colors.blue),
                      ),
                      TextSpan(
                        text: '${ingredient.calories} kcal',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
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
                    planId: meal.planId, // Copied planId
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
                    ? const Color(0xFF4CAF50)
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: meal.eaten
                  ? Row(
                      key: const ValueKey('eaten'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Eaten',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Mark as Eaten',
                      key: ValueKey('not_eaten'),
                      style: TextStyle(
                        fontSize: 16,
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
    // Calculate if this day is selected
    DateTime planStartDate;
    if (_planCreationDate != null) {
        planStartDate = _planCreationDate!;
    } else {
        final now = DateTime.now();
        planStartDate = now.subtract(Duration(days: now.weekday - 1));
        planStartDate = DateTime(planStartDate.year, planStartDate.month, planStartDate.day);
    }
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
        // Calculate Week and Day
        final globalDay = dayNumber;
        final week = ((globalDay - 1) ~/ 7) + 1;
        final day = ((globalDay - 1) % 7) + 1;
        
        print('Selected Day: $dayNumber -> Week $week, Day $day');
        
        setState(() {
          _selectedDay = dayDate;
          _showingDayGrid = false; // Switch to detail view
        });
        
        // Fetch specific day's meals
        _loadMeals(week: week, day: day, clearData: false); 
      },
      child: Container(
        decoration: ShapeDecoration(
          color: isCompleted 
            ? const Color(0xFF4CAF50) 
            : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8)),
          shape: PolygonBorder(
            sides: 16,
            borderRadius: 5.0,
            rotate: 11.25,
            side: BorderSide(
              color: isDarkMode ? Colors.white : Colors.black,
              width: 2.5,
            ),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double circleWidth = constraints.maxWidth;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Day $dayNumber',
                    style: TextStyle(
                      fontSize: circleWidth * 0.30, // 30% responsive scaling
                      fontWeight: FontWeight.w900,
                      color: isCompleted 
                        ? Colors.white 
                        : (isDarkMode ? Colors.white : const Color(0xFF333333)),
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
                SizedBox(height: circleWidth * 0.05),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: circleWidth * 0.18,
                      fontWeight: FontWeight.bold,
                      color: isCompleted 
                        ? Colors.white 
                        : const Color(0xFF4CAF50), // Green for percentage
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  // Helper method to get the selected day number (Global)
  int _getSelectedDayNumber() {
    DateTime planStartDate;
    if (_planCreationDate != null) {
        planStartDate = _planCreationDate!;
    } else {
        final now = DateTime.now();
        planStartDate = now.subtract(Duration(days: now.weekday - 1));
        planStartDate = DateTime(planStartDate.year, planStartDate.month, planStartDate.day);
    }
    
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    
    final difference = selectedDate.difference(planStartDate).inDays;
    return difference + 1; // Global day index
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
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
    
    DateTime planStartDate;
    if (_planCreationDate != null) {
        planStartDate = _planCreationDate!;
    } else {
        final now = DateTime.now();
        planStartDate = now.subtract(Duration(days: now.weekday - 1));
        planStartDate = DateTime(planStartDate.year, planStartDate.month, planStartDate.day);
    }
    
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
