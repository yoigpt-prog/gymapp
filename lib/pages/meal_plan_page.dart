import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth/auth_modal.dart';
import 'dart:ui'; // For ImageFilter (blur)
import 'meal_plan_modal.dart' hide Meal; // Hide Meal to avoid conflict
import 'edit_meal_modal.dart';
import 'custom_plan_quiz.dart';
import 'main_scaffold.dart';
import '../models/meal_model.dart';
import '../services/supabase_service.dart';
import '../services/plan_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/analytics_service.dart';
import '../services/subscription_state.dart';
import '../widgets/red_header.dart';
import '../widgets/promo_banner.dart';

import '../widgets/meal_image_widget.dart';
import '../services/plan_duration_service.dart';

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
  bool _isLoadingOfferings = true;
  bool _hasOfferings = false;

  // Meal tab selection — null means 'all'; auto-set to first available meal type
  String? _selectedMealTab;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Load preferred duration FIRST (fast DB query) so the title/grid are
    // correct before the full meal list arrives.
    _loadPrefDuration();
    _loadMeals();

    // Refresh subscription status for freemium gating
    SubscriptionState().addListener(_onSubscriptionChanged);
    SubscriptionState().refresh();
    
    _checkOfferings();
  }

  Future<void> _checkOfferings() async {
    final ready = await RevenueCatService().checkOfferingsReady();
    if (mounted) {
      setState(() {
        _hasOfferings = ready;
        _isLoadingOfferings = false;
      });
    }
  }

  /// Fetches duration_weeks from user_preferences so _planDurationWeeks is
  /// populated immediately — avoids showing "2-Week" before meals load.
  Future<void> _loadPrefDuration() async {
    try {
      final duration = await PlanDurationService().getPreferredDurationWeeks();
      if (mounted) setState(() => _planDurationWeeks = duration);
    } catch (e) {
      debugPrint('[MealPlanPage] _loadPrefDuration error: $e');
    }
  }

  void _onSubscriptionChanged() {
    if (mounted) setState(() {});
  }

  // Public refresh method
  Future<void> refresh() async {
    // Re-read duration preference in parallel so the correct week count
    // is shown immediately (avoids "2-Week" default after quiz completes).
    await Future.wait([
      _loadPrefDuration(),
      _loadMeals(clearData: true),
    ]);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    SubscriptionState().removeListener(_onSubscriptionChanged);
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
  int _planDurationWeeks = 4; // Default, will update from DB
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

  Future<void> _invalidateCache() async {
    try {
      final key = _getCacheKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      print('DEBUG: [Cache] Meal plan cache invalidated due to user edit');
    } catch (e) {
      // Ignored
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
      // We DO NOT override _planDurationWeeks from cache because it can conflict
      // with the _loadPrefDuration which runs concurrently. Rely solely on the DB.
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

      // ── DB-first strategy for cross-device sync ──
      // We always fetch from Supabase so edits made on another device
      // are picked up immediately. The cache is only used as a fast-path
      // for the FIRST render while the DB query is in-flight.
      bool usedCache = false;
      if (week == null && day == null && !clearData) {
        final cached = await _loadPlanFromCache();
        if (cached != null && mounted) {
          // Apply cache for instant display, but still fetch DB below
          _applyCachedData(cached);
          usedCache = true;
        }
      }

      // Always fire a DB fetch to get the latest state
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
          // Do not override _planDurationWeeks if it was correctly loaded from preferences!
          // We only fallback if it's 0.
          if (_planDurationWeeks <= 0) {
             int maxDay = 0;
             if (userPlan.isNotEmpty) {
                final days = userPlan.map((m) => m['plan_global_day'] as int? ?? 0);
                if (days.isNotEmpty) {
                   maxDay = days.reduce(max);
                }
             }
             final totalWeeks = (maxDay / 7).ceil();
             _planDurationWeeks = totalWeeks > 0 ? totalWeeks : 4;
          }
          
          print('DEBUG: [MealPlanPage] Selected Duration: $_planDurationWeeks weeks');
           
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
      
      // 3b. Loop template data if duration is longer than the fetched meals
      int maxDayInTemplate = 0;
      if (deepGrouped.isNotEmpty) {
          maxDayInTemplate = deepGrouped.keys.reduce(max);
      }
      
      if (maxDayInTemplate > 0) {
          int targetDays = _planDurationWeeks * 7;
          for (int gDay = 1; gDay <= targetDays; gDay++) {
              if (!deepGrouped.containsKey(gDay)) {
                  int srcDay = ((gDay - 1) % maxDayInTemplate) + 1;
                  if (deepGrouped.containsKey(srcDay)) {
                      deepGrouped[gDay] = deepGrouped[srcDay]!.map((item) {
                          final cloned = Map<String, dynamic>.from(item);
                          cloned['plan_global_day'] = gDay; // update for any inner usage
                          cloned['is_eaten'] = false; // Cloned days should not copy eaten status!
                          return cloned;
                      }).toList();
                  }
              }
          }
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
      await _supabaseService.toggleMealStatus(meal, newStatus);
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _showingDayGrid
                ? KeyedSubtree(
                    key: const ValueKey('meal_grid'),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: _buildGridView(isDarkMode),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('meal_detail'),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: _buildDetailView(isDarkMode),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // Grid view: Dynamic Week Generation
  // Adaptive timeline state
  final Set<int> _expandedMealWeeks = {};

  Widget _buildGridView(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isPro = SubscriptionState().isPro;

    // Determine current week from plan creation date
    DateTime planStart;
    if (_planCreationDate != null) {
      planStart = _planCreationDate!;
    } else {
      final now = DateTime.now();
      final currentMonday = now.subtract(Duration(days: now.weekday - 1));
      planStart = DateTime(currentMonday.year, currentMonday.month, currentMonday.day);
    }
    final elapsedDays = DateTime.now().difference(planStart).inDays;
    final currentWeek = (elapsedDays ~/ 7).clamp(0, _planDurationWeeks - 1) + 1;

    // Use collapsible month-grouped timeline for all plan durations
    return _buildAdaptiveMealTimeline(
      isPro: isPro,
      isDarkMode: isDarkMode,
      isSmallScreen: isSmallScreen,
      currentWeek: currentWeek,
      planStart: planStart,
    );
  }

  Widget _buildFlatMealWeekGrid({
    required bool isPro,
    required bool isDarkMode,
    required bool isSmallScreen,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 30),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode ? Colors.white : Colors.black,
              width: 1.0,
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
                isPro
                    ? 'Select a day to view your meals'
                    : 'Enjoy free workouts · Unlock full plan with Premium',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int index = 0; index < _planDurationWeeks; index++) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Week ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF0000),
                              ),
                            ),
                            if (!isPro && index > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.lock, size: 14, color: Color(0xFFFF0000)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 15),
                        _build14DayGrid((index * 7) + 1, (index * 7) + 7, isDarkMode),
                      ],
                    ),
                    if (index < _planDurationWeeks - 1) ...[
                      if (!isPro)
                        PromoBanner(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          source: 'meal_week_${index + 1}',
                        )
                      else
                        SizedBox(height: isSmallScreen ? 16 : 30),
                    ] else
                      SizedBox(height: isSmallScreen ? 8 : 16),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdaptiveMealTimeline({
    required bool isPro,
    required bool isDarkMode,
    required bool isSmallScreen,
    required int currentWeek,
    required DateTime planStart,
  }) {
    final totalWeeks = _planDurationWeeks;
    final int totalMonths = (totalWeeks / 4).ceil();
    final bgCard = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final borderCol = isDarkMode ? Colors.white : Colors.black;
    double totalMealProgress = 0.0;
    for (int dayNumber = 1; dayNumber <= totalWeeks * 7; dayNumber++) {
      final dayDate = planStart.add(Duration(days: dayNumber - 1));
      final dateKey = _getDateKey(dayDate);
      final dayMeals = _mealsByDay[dateKey];
      final totalMeals = dayMeals?.length ?? 0;
      if (totalMeals > 0) {
        final eatenMeals = dayMeals?.values.where((m) => m.eaten).length ?? 0;
        totalMealProgress += eatenMeals / totalMeals;
      }
    }
    final double overallProgress = totalWeeks > 0 ? (totalMealProgress / (totalWeeks * 7)) : 0.0;
    print('DEBUG_PROGRESS: totalWeeks=$totalWeeks, mealsByDayLength=${_mealsByDay.length}, totalMealProgress=$totalMealProgress, overallProgress=$overallProgress');
    final elapsedDays = DateTime.now().difference(planStart).inDays.clamp(0, totalWeeks * 7);


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol, width: 1),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.10),
                blurRadius: 16, offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Meal Plan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode ? Colors.white : const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Week $currentWeek of $totalWeeks',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFF0000),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPro ? 'Keep going — consistency is key!' : 'Unlock full plan with Premium',
                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : const Color(0xFF888888)),
                  ),
                  Text('${(overallProgress * 100).round()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF0000))),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overallProgress.clamp(0.0, 1.0),
                  backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Month groups
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalMonths,
          itemBuilder: (context, monthIndex) {
            final monthNum = monthIndex + 1;
            final firstWeek = monthIndex * 4 + 1;
            final lastWeek = (firstWeek + 3).clamp(1, totalWeeks);
            final weekCount = lastWeek - firstWeek + 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(12)),
                          child: Text('Month $monthNum',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                        ),
                        const SizedBox(width: 10),
                        Text('Weeks $firstWeek–$lastWeek',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white54 : const Color(0xFF888888))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: weekCount,
                    itemBuilder: (ctx, wi) {
                      final weekNum = firstWeek + wi;
                      final isCurrentWeek = weekNum == currentWeek;
                      final isNextWeek = weekNum == currentWeek + 1;
                      final isExpanded = isCurrentWeek || isNextWeek || _expandedMealWeeks.contains(weekNum);
                      final isLocked = !isPro && weekNum > 1;
                      final isPast = weekNum < currentWeek;
                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              if (!isCurrentWeek && !isNextWeek) {
                                setState(() {
                                  if (_expandedMealWeeks.contains(weekNum)) {
                                    _expandedMealWeeks.remove(weekNum);
                                  } else {
                                    _expandedMealWeeks.add(weekNum);
                                  }
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  if (!isCurrentWeek && !isNextWeek)
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.25 : 0,
                                      duration: const Duration(milliseconds: 180),
                                      child: Icon(Icons.play_arrow_rounded, size: 16,
                                          color: isDarkMode ? Colors.white38 : const Color(0xFFBBBBBB)),
                                    )
                                  else
                                    const SizedBox(width: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Week $weekNum',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isCurrentWeek ? FontWeight.w800 : FontWeight.w600,
                                      color: isCurrentWeek
                                          ? const Color(0xFFFF0000)
                                          : isPast
                                              ? (isDarkMode ? Colors.white38 : const Color(0xFFBBBBBB))
                                              : (isDarkMode ? Colors.white : const Color(0xFF1A1A1A)),
                                    ),
                                  ),
                                  if (isCurrentWeek) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(10)),
                                      child: const Text('Now', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                                    ),
                                  ],
                                  if (isPast) ...[ const SizedBox(width: 6), const Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)) ],
                                  if (isLocked && !isPast) ...[ const SizedBox(width: 6), const Icon(Icons.lock, size: 13, color: Color(0xFFFF0000)) ],
                                  const Spacer(),
                                  if (!isCurrentWeek && !isNextWeek)
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 18, color: isDarkMode ? Colors.white38 : const Color(0xFFCCCCCC),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: _build14DayGrid((weekNum - 1) * 7 + 1, weekNum * 7, isDarkMode),
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 220),
                          ),
                          if (wi < weekCount - 1)
                            Divider(height: 1, thickness: 1, color: isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0), indent: 16, endIndent: 16),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
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

    // Auto-select first available meal tab when entering detail view
    if (_selectedMealTab == null && meals.isNotEmpty) {
      _selectedMealTab = meals.first.type;
    }

    // Calculate progress for this day locally
    final totalMeals = meals.length;
    final eatenMeals = meals.where((m) => m.eaten).length;
    final progressPercent = totalMeals == 0 ? 0 : ((eatenMeals / totalMeals) * 100).round();

    return Column(
      children: [
        // Back to Days Button — Clean Premium
        GestureDetector(
          onTap: () {
            setState(() {
              _showingDayGrid = true;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.white : Colors.black,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: const Color(0xFFCC0A16),
                ),
                const SizedBox(width: 4),
                Text(
                  'Back to Days',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Day Header Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white : Colors.black,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: const Color(0xFFCC0A16),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_getSelectedDayNumber()}',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -2,
                        color: isDarkMode ? Colors.white : const Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$progressPercent%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode ? Colors.white : const Color(0xFF111111),
                      ),
                    ),
                    Text(
                      'complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : const Color(0xFF999999),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Unified Nutrition + Progress + Tabs Card
        _buildStatsCard(totalMeals == 0 ? 0 : eatenMeals/totalMeals, isDarkMode, eatenMeals, totalMeals, meals),

        const SizedBox(height: 12),

        // Meal List — filtered to selected tab
        Builder(
          builder: (context) {
            final filtered = _selectedMealTab != null
                ? meals.where((m) => m.type == _selectedMealTab).toList()
                : meals;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return _buildMealCard(filtered[index], isDarkMode);
              },
            );
          },
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommendations and nutrition estimates may not always be accurate. Use your judgment and consult a professional when needed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Meal Type Tab Bar ────────────────────────────────────────────────────
  Widget _buildMealTabBar(List<Meal> meals, bool isDarkMode) {
    if (meals.isEmpty) return const SizedBox.shrink();

    // Ordered meal types present in today's meals
    const typeOrder = ['BREAKFAST', 'MORNING SNACK', 'LUNCH', 'SNACK', 'AFTERNOON SNACK', 'DINNER'];
    final presentTypes = typeOrder.where((t) => meals.any((m) => m.type == t)).toList();
    for (final m in meals) {
      if (!presentTypes.contains(m.type)) presentTypes.add(m.type);
    }

    // Returns just the tab row — no outer card (card is provided by _buildStatsCard)
    return Row(
      children: presentTypes.asMap().entries.map((entry) {
        final idx      = entry.key;
        final type     = entry.value;
        final isActive = _selectedMealTab == type;

        // Friendly short label
        String label = type[0] + type.substring(1).toLowerCase();
        if (type == 'MORNING SNACK')   label = 'A.M.';
        if (type == 'AFTERNOON SNACK') label = 'P.M.';

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: idx < presentTypes.length - 1 ? 6 : 0,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMealTab = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFF0000)
                      : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFFF0000)
                        : (isDarkMode ? Colors.white12 : Colors.black12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.black54),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }


  Widget _buildStatsCard(double progress, bool isDarkMode, int eaten, int total, List<Meal> meals) {

    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Calculate totals dynamically from the current day's meals
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
          width: 1,
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
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
          
          // Today's Progress
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
                '$eaten/$total meals',
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

          if (meals.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMealTabBar(meals, isDarkMode),
          ],
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


  String _getMealSvgIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('breakfast')) return 'assets/svg/mealsicons/breakfasticon.svg';
    if (t.contains('lunch')) return 'assets/svg/mealsicons/lunchicon.svg';
    if (t.contains('snack')) return 'assets/svg/mealsicons/snackicon.svg';
    if (t.contains('dinner')) return 'assets/svg/mealsicons/dinnericon.svg';
    return 'assets/svg/mealsicons/snackicon.svg';
  }

  // ── Swap Meal ─────────────────────────────────────────────────────────────
  // Shows a bottom sheet with alternative meals from meals_v2 for the same slot.
  // Tapping one replaces the current meal in the plan row.
  void _showSwapMealSheet(BuildContext context, Meal meal, bool isDarkMode) {
    final cardBg    = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final divColor  = isDarkMode ? Colors.white12 : Colors.black12;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: divColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: const Color(0xFFFF0000)),
                    const SizedBox(width: 10),
                    Text(
                      'Swap ${meal.type[0]}${meal.type.substring(1).toLowerCase()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: divColor, height: 1),
              // Alternatives list — loaded fresh from meals_v2
              Expanded(
                child: _SwapMealList(
                  currentMeal: meal,
                  isDarkMode: isDarkMode,
                  supabaseService: _supabaseService,
                  onSwap: (newMealData) async {
                    Navigator.of(context).pop();
                    await _applyMealSwap(meal, newMealData);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyMealSwap(Meal oldMeal, Map<String, dynamic> newMealData) async {
    if (oldMeal.planId == null) {
      print('WARNING: cannot swap — planId is null');
      return;
    }

    // Build a replacement Meal object from the new data
    final swapped = Meal.fromJson({
      ...newMealData,
      'plan_row_id': oldMeal.planId,
      'is_eaten':    false,
      'meal_type':   oldMeal.type.toLowerCase(),
    });

    // Optimistic UI
    final dateKey = _getDateKey(_selectedDay);
    setState(() {
      if (_mealsByDay.containsKey(dateKey)) {
        _mealsByDay[dateKey]![oldMeal.type] = swapped;
      }
    });

    // Persist to user_meal_plan_v2 (update meal_id + reset macros)
    try {
      final mealIdRaw = newMealData['id'];
      final mealIdInt = mealIdRaw is int
          ? mealIdRaw
          : int.tryParse(mealIdRaw.toString());

      if (mealIdInt != null) {
        await _supabaseService.client
            .from('user_meal_plan_v2')
            .update({
              'meal_id':        mealIdInt,
              'custom_calories': newMealData['base_calories'],
              'custom_protein':  newMealData['protein_g'],
              'custom_carbs':    newMealData['carbs_g'],
              'custom_fats':     newMealData['fat_g'],
              'is_custom':       true,
              'scaled_ingredients': newMealData['ingredients_json'],
            })
            .eq('id', oldMeal.planId!);

        print('DEBUG: Swap persisted — row=${oldMeal.planId} → meal=$mealIdInt');
      }
      _savePlanToCache(_buildCachePayload());
    } catch (e) {
      print('ERROR: Meal swap persist failed: $e');
    }
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
          width: 1,
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
          // Meal image with floating camera edit button
          if (isMobile) ...[
            MealImageWidget(
              mealId: meal.id,
              defaultImageUrl: meal.imageUrl,
              isDarkMode: isDarkMode,
              overlays: [
                // Eaten badge overlay
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
                        SvgPicture.asset(
                          _getMealSvgIcon(meal.type),
                          width: 24,
                          height: 24,
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
                  Text(
                    '${meal.calories} kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF0000),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showSwapMealSheet(context, meal, isDarkMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/swapmeal.png',
                          width: 16,
                          height: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Swap Meal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final builder = (BuildContext context) => EditMealModal(
                    meal: meal,
                    onSave: (updatedMeal) async {
                      final user = _supabaseService.client.auth.currentUser;
                      if (user == null) return;

                      final dateKey = _getDateKey(_selectedDay);
                      setState(() {
                        if (_mealsByDay.containsKey(dateKey)) {
                          _mealsByDay[dateKey]![updatedMeal.type] = updatedMeal;
                        }
                      });

                      final planRowId = updatedMeal.planId;
                      if (planRowId != null) {
                        try {
                          await _supabaseService.saveMealOverrides(planRowId, updatedMeal);
                          print('DEBUG: Meal overrides saved for plan row $planRowId');
                          _savePlanToCache(_buildCachePayload());
                          _loadMeals(clearData: false);
                        } catch (e) {
                          print('ERROR saving meal overrides: $e');
                        }
                      } else {
                        print('WARNING: planId is null for meal ${updatedMeal.id}, cannot save override.');
                      }
                    },
                  );

                  if (MediaQuery.of(context).size.width > 600) {
                    showDialog(context: context, builder: builder);
                  } else {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: builder,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: subTextColor,
                  ),
                ),
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
                      // Amount in blue
                      TextSpan(
                        text: ingredient.calories > 0
                            ? '${ingredient.amount} • '
                            : ingredient.amount,
                        style: const TextStyle(color: Colors.blue),
                      ),
                      // kcal in red — only shown when data is available
                      if (ingredient.calories > 0)
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

          // ── Instructions section ────────────────────────────────
          if (meal.instructions != null && meal.instructions!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.restaurant_menu_outlined,
                  size: 16,
                  color: Color(0xFFFF0000),
                ),
                const SizedBox(width: 6),
                const Text(
                  'How to prepare',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF0000),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              meal.instructions!.trim(),
              style: TextStyle(
                fontSize: 13.5,
                color: isDarkMode ? Colors.white70 : Colors.black87,
                height: 1.55,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Button - Eaten Toggle
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // ── 1. Optimistic UI toggle (instant) ──
                final newStatus = !meal.eaten;
                final newMeal = Meal(
                  id: meal.id,
                  type: meal.type,
                  icon: meal.icon,
                  name: meal.name,
                  imageUrl: meal.imageUrl,
                  instructions: meal.instructions, // preserve instructions
                  calories: meal.calories,
                  protein: meal.protein,
                  carbs: meal.carbs,
                  fats: meal.fats,
                  eaten: newStatus,
                  planId: meal.planId,
                  ingredients: meal.ingredients,
                );

                final dateKey = _getDateKey(_selectedDay);
                if (!_mealsByDay.containsKey(dateKey)) return;

                setState(() {
                  _mealsByDay[dateKey]![meal.type] = newMeal;
                });

                // ── Update local cache silently ──
                _savePlanToCache(_buildCachePayload());

                // ── 2. Persist to DB in background ──
                // Update is_eaten in user_meal_plan
                _saveMealStatus(dateKey, meal.type, newStatus);

                // Log immutable snapshot to meal_logs (only when marking eaten)
                if (newStatus && newMeal.id != null) {
                  final globalDay = _getSelectedDayNumber();
                  try {
                    await _supabaseService.logMealEaten(newMeal, globalDay);
                  } catch (e) {
                    print('WARNING: Could not save meal log: $e');
                    // UI already toggled — this is non-critical (meal_logs is for history)
                  }
                }
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
        childAspectRatio: 0.82,
        crossAxisSpacing: isSmallScreen ? 8 : 12,
        mainAxisSpacing: isSmallScreen ? 8 : 12,
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

    // Freemium: Day 1 is always free; remaining days require subscription
    final isPro = SubscriptionState().isPro;
    final isLocked = !isPro && dayNumber > 1;

    return GestureDetector(
      onTap: () async {
        if (isLocked) {
          // Apple Guideline 5.1.1(v): Show paywall directly — no auth gate before purchase.
          // RevenueCat supports anonymous purchases natively.
          AnalyticsService()
              .trackPaywallViewed(source: 'meal_locked_day_$dayNumber');
          await RevenueCatService().showPaywall();
          await SubscriptionState().refresh();
          return;
        }
        // Calculate Week and Day
        final globalDay = dayNumber;
        final week = ((globalDay - 1) ~/ 7) + 1;
        final day = ((globalDay - 1) % 7) + 1;
        
        print('Selected Day: $dayNumber -> Week $week, Day $day');
        
        setState(() {
          _selectedDay = dayDate;
          _showingDayGrid = false; // Switch to detail view
          _selectedMealTab = null; // Reset: auto-selects first meal of new day
        });
        
        // Only fetch from network if we don't already have this day's meals in memory.
        // _mealsByDay is keyed by date string and populated during initial load for all days.
        if (!_mealsByDay.containsKey(dateKey)) {
          _loadMeals(week: week, day: day, clearData: false);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main tile
          Container(
            decoration: BoxDecoration(
              color: isLocked
                  ? (isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0))
                  : isCompleted 
                      ? const Color(0xFF4CAF50) 
                      : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLocked
                    ? (isDarkMode ? Colors.white24 : Colors.black12)
                    : (isDarkMode ? Colors.white : Colors.black),
                width: 1.0,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double circleWidth = constraints.maxWidth;
                return Padding(
                  padding: EdgeInsets.all(circleWidth * 0.10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Day $dayNumber',
                          style: TextStyle(
                            fontSize: circleWidth * 0.35,
                            fontWeight: FontWeight.w900,
                            color: isLocked
                                ? (isDarkMode ? Colors.white30 : Colors.black26)
                                : isCompleted 
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
                        child: isLocked
                            ? Icon(
                                Icons.lock,
                                size: circleWidth * 0.28,
                                color: isDarkMode ? Colors.white30 : Colors.black26,
                              )
                            : Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  fontSize: circleWidth * 0.22,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted 
                                      ? Colors.white 
                                      : const Color(0xFF4CAF50), // Green for percentage
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  int _getSelectedDayNumber() {
    return PlanDurationService().getGlobalDayIndex(
      selectedDate: _selectedDay,
      planCreationDate: _planCreationDate,
    );
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

// ── _SwapMealList ─────────────────────────────────────────────────────────────
// Loads alternative meals from meals_v2 for the same slot type and shows them
// in a scrollable list. Tapping one triggers the swap callback.
class _SwapMealList extends StatefulWidget {
  final Meal currentMeal;
  final bool isDarkMode;
  final SupabaseService supabaseService;
  final void Function(Map<String, dynamic> newMealData) onSwap;

  const _SwapMealList({
    required this.currentMeal,
    required this.isDarkMode,
    required this.supabaseService,
    required this.onSwap,
  });

  @override
  State<_SwapMealList> createState() => _SwapMealListState();
}

class _SwapMealListState extends State<_SwapMealList> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _alternatives = [];

  @override
  void initState() {
    super.initState();
    _fetchAlternatives();
  }

  Future<void> _fetchAlternatives() async {
    try {
      final mealType = widget.currentMeal.type.toLowerCase();
      final currentId = int.tryParse(widget.currentMeal.id);
      final user = widget.supabaseService.client.auth.currentUser;

      String dietType = 'no_preference';
      List<String> excludedFoods = [];

      if (user != null) {
        final profile = await widget.supabaseService.client
            .from('user_quiz_profile')
            .select('diet_type, excluded_foods')
            .eq('user_id', user.id)
            .maybeSingle();
        if (profile != null) {
          dietType = (profile['diet_type'] as String? ?? 'no_preference').toLowerCase().trim();
          final rawExcluded = profile['excluded_foods'] as List<dynamic>?;
          if (rawExcluded != null) {
            excludedFoods = rawExcluded.map((e) => e.toString().toLowerCase().trim()).toList();
          }
        }
      }

      // Fetch a larger pool of candidates to filter and personalize client-side
      final results = await widget.supabaseService.client
          .from('meals_v2')
          .select(
            'id, meal_name, image_url, meal_type, base_calories, '
            'protein_g, carbs_g, fat_g, ingredients_json, instructions, '
            'diet_tags, allergens',
          )
          .eq('meal_type', mealType)
          .neq('id', currentId ?? -1)
          .order('id', ascending: false)
          .limit(100) as List<dynamic>;

      final rawList = results.cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> filtered = [];

      // Helper to parse tags
      List<String> _parseTags(dynamic raw) {
        if (raw == null) return [];
        if (raw is List) return raw.map((e) => e.toString().toLowerCase().trim()).toList();
        return [];
      }

      // ── Step 1: Apply Allergen Safety (hard exclude) + Diet Compatibility (soft) ──
      filtered = rawList.where((meal) {
        final mealAllergens = _parseTags(meal['allergens']);
        final hasAllergen = excludedFoods.any((ex) => mealAllergens.contains(ex));
        if (hasAllergen) return false; // hard exclude

        if (dietType != 'no_preference') {
          final mealDiets = _parseTags(meal['diet_tags']);
          // Check match for specific diet tags
          bool dietMatch = false;
          if (dietType == 'vegetarian' && mealDiets.contains('vegetarian')) dietMatch = true;
          else if (dietType == 'vegan' && mealDiets.contains('vegan')) dietMatch = true;
          else if (dietType == 'mediterranean' && mealDiets.contains('mediterranean')) dietMatch = true;
          else if (dietType == 'keto' && mealDiets.contains('keto')) dietMatch = true;
          else if (dietType == 'low_carb' && mealDiets.contains('low_carb')) dietMatch = true;
          else if (dietType == 'paleo' && mealDiets.contains('paleo')) dietMatch = true;
          else if (dietType == 'gluten_free' && mealDiets.contains('gluten_free')) dietMatch = true;
          return dietMatch;
        }
        return true;
      }).toList();

      // ── Step 2: Fallback if too restrictive (relax diet compatibility, keep allergen safety) ──
      if (filtered.isEmpty) {
        filtered = rawList.where((meal) {
          final mealAllergens = _parseTags(meal['allergens']);
          final hasAllergen = excludedFoods.any((ex) => mealAllergens.contains(ex));
          return !hasAllergen;
        }).toList();
      }

      // ── Step 3: Absolute fallback (return all raw results) ──
      if (filtered.isEmpty) {
        filtered = rawList;
      }

      // Keep top 30
      if (filtered.length > 30) {
        filtered = filtered.sublist(0, 30);
      }

      if (mounted) {
        setState(() {
          _alternatives = filtered;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = widget.isDarkMode;
    final textColor   = isDark ? Colors.white : Colors.black87;
    final subColor    = isDark ? Colors.white54 : Colors.black45;
    final tileBg      = isDark ? const Color(0xFF242424) : const Color(0xFFF8F8F8);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFFF0000)),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load alternatives.\n$_error',
            textAlign: TextAlign.center,
            style: TextStyle(color: subColor),
          ),
        ),
      );
    }

    if (_alternatives.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No alternatives found for this meal type.',
            style: TextStyle(color: subColor),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _alternatives.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final alt = _alternatives[i];
        final name = alt['meal_name'] as String? ?? 'Unknown';
        final cal  = alt['base_calories'] as int? ?? 0;
        final img  = alt['image_url'] as String?;

        return GestureDetector(
          onTap: () => widget.onSwap(alt),
          child: Container(
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: img != null && img.isNotEmpty
                      ? Image.network(
                          img,
                          width: 80,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 72,
                            color: isDark ? Colors.white10 : Colors.black12,
                            child: Icon(Icons.restaurant, color: subColor),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 72,
                          color: isDark ? Colors.white10 : Colors.black12,
                          child: Icon(Icons.restaurant, color: subColor),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cal kcal',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF0000),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.swap_horiz_rounded,
                  color: const Color(0xFFFF0000),
                  size: 22,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
