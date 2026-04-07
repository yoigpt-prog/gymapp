import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/supabase_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/analytics_service.dart';
import 'exercise_detail_page.dart';
import 'dart:async'; // Required for StreamSubscription
import 'dart:convert';
import 'dart:math';
import 'workout_plan_modal.dart';
import 'home_page.dart'; // Import ExerciseDetail model
import 'custom_plan_quiz.dart';
import 'main_scaffold.dart';
import '../widgets/red_header.dart';
import '../widgets/polygon_border.dart';

class WorkoutPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const WorkoutPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<WorkoutPage> createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage> {
  bool _isDarkMode = false;
  Map<String, dynamic>? _generatedPlan;
  bool _isLoadingPlan = true;
  bool _isRestDay = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  // Scroll controller for hiding header
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  double _lastScrollOffset = 0;

  // Week navigation
  int _weekOffset = 0; // 0 = current week, -1 = previous week, +1 = next week
  DateTime _selectedDay = DateTime.now(); // Track which day is selected
  bool _showingDayGrid =
      true; // Toggle between grid view and detail view (mobile only)

  // Generate 3 days centered around current day, adjusted by week offset
  List<Map<String, dynamic>> _generateDays() {
    final now = DateTime.now();
    final startDay = now.add(Duration(
        days: (_weekOffset * 7) - 2)); // Start 2 days before current to center

    return List.generate(5, (index) {
      final day = startDay.add(Duration(days: index));
      final isToday =
          day.day == now.day && day.month == now.month && day.year == now.year;
      final progress = _getWorkoutProgressForDay(day);

      return {
        'label':
            '${_getDayName(day.weekday)}|${day.day.toString().padLeft(2, '0')}',
        'isToday': isToday,
        'isCompleted': progress >= 1.0,
        'date': day,
        'progress': progress,
      };
    });
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Subscribe to Auth State Changes to handle race conditions on reload
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('[WorkoutPage] Auth Event $event → triggering refresh');
        _refresh();
      }
    });

    // Start refresh — completed exercises are loaded inside refresh after plan loads
    _refresh();

    // Check subscription access after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSubscriptionAccess();
    });
  }

  // ── Subscription Guard ───────────────────────────────────────────────────
  /// Called on every page visit. Shows the paywall if the user has completed
  /// the quiz but does NOT have an active "premium" subscription.
  /// On dismiss/cancel → hard redirect to Home via [MainScaffoldState].
  Future<void> _checkSubscriptionAccess() async {
    if (kIsWeb || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedQuiz = prefs.getBool('hasCompletedQuiz') ?? false;
      if (!hasCompletedQuiz) return; // First-time user — let quiz handle it.

      final isPro = await RevenueCatService().isProUser();
      if (isPro || !mounted) return; // Subscribed — all good.

      debugPrint('[WorkoutPage] Not subscribed — showing paywall gate.');
      AnalyticsService().trackPaywallViewed(source: 'workout_page');

      final result = await RevenueCatService().showPaywall();

      final isProAfter = await RevenueCatService().isProUser();
      if (isProAfter) {
          final customerInfo = await RevenueCatService().getCustomerInfo();
          String planId = 'unknown';
          if (customerInfo != null && customerInfo.entitlements.active.containsKey('premium')) {
             planId = customerInfo.entitlements.active['premium']!.productIdentifier;
          }
          AnalyticsService().trackPurchaseSuccess(plan: planId);
      }

      final didSubscribe =
          result == PaywallResult.purchased || result == PaywallResult.restored || isProAfter;

      if (!didSubscribe && mounted) {
        // Hard gate: redirect to Home.
        debugPrint('[WorkoutPage] Paywall dismissed — redirecting to Home.');
        final scaffold = context.findAncestorStateOfType<MainScaffoldState>();
        scaffold?.changeTab(0);
      }
    } catch (e) {
      debugPrint('[WorkoutPage] _checkSubscriptionAccess error: $e');
    }
  }
  // ────────────────────────────────────────────────────────────────

  Future<void> _loadCompletedExercises() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final allCompleted = await SupabaseService().getAllCompletedExercises();
      if (mounted) {
        setState(() {
          _completedExercisesByDay.clear();
          allCompleted.forEach((key, list) {
            _completedExercisesByDay[key] = list.toSet();
          });
          
          final dateKey = _getDateKey(_selectedDay);
          if (_completedExercisesByDay.containsKey(dateKey)) {
            _completedExercises.clear();
            _completedExercises.addAll(_completedExercisesByDay[dateKey]!);
          }
        });
      }
    }
  }

  // Direct injection of plan (No DB fetch needed)
  void setPlan(Map<String, dynamic> plan) {
    if (!mounted) return;
    print('----------------------------------------------------------------');
    print('DIRECT PLAN INJECTION -> Skipping DB Fetch');
    print('INJECTED PLAN ID: ${plan['id']}');

    setState(() {
      _generatedPlan = plan;
      _isLoadingPlan = false;
      _exercises = [];
      _isRestDay = false;
      _selectedDay = DateTime.now(); // Reset to today
    });

    // Strict update with retry
    _updateDailyWorkouts(enableRetry: true);
  }

  // Public refresh method
  Future<void> refresh({bool force = false}) => _refresh();

  // Robust refresh: Fetch plan -> Then fetch workouts
  Future<void> _refresh() async {
    // 1. CLEAR CACHE & RESET STATE
    if (mounted) {
      setState(() {
        _generatedPlan = null;
        _exercises = [];
        _isRestDay = false;
        _isLoadingPlan = true;
        _selectedDay = DateTime.now(); // Reset selection to Today
      });
    }

    print('----------------------------------------------------------------');
    print('PLAN CACHE CLEARED -> FETCHING LATEST PLAN...');

    // 2. FORCE FETCH plan
    await _loadGeneratedPlan();

    // 3. FETCH progress from cloud (must come after plan so _exercises is populated)
    await _loadCompletedExercises();

    // 4. UPDATE VIEW
    if (mounted) {
      await _updateDailyWorkouts(enableRetry: false);
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentScrollOffset = _scrollController.offset;

    if (currentScrollOffset > _lastScrollOffset && currentScrollOffset > 50) {
      // Scrolling down
      if (_showHeader) {
        setState(() {
          _showHeader = false;
        });
      }
    } else if (currentScrollOffset < _lastScrollOffset) {
      // Scrolling up
      if (!_showHeader) {
        setState(() {
          _showHeader = true;
        });
      }
    }

    _lastScrollOffset = currentScrollOffset;
  }

  // Helper to normalize IDs (Strict 6 digits)
  String _normalizeId(dynamic id) {
    if (id == null) return '';
    return id.toString().trim().padLeft(6, '0');
  }

  // Restore: Load plan from DB
  Future<void> _loadGeneratedPlan() async {
    setState(() {
      _isLoadingPlan = true;
      _generatedPlan = null; // FORCE CLEAR stale data
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      Map<String, dynamic>? planRow;

      if (user != null) {
        try {
          print('DEBUG: Fetching latest plan for User: ${user.id}...');
          // Select only columns required by user
          final response = await Supabase.instance.client
              .from('ai_plans')
              .select('id, schedule_json, created_at') // Match reqs
              .eq('user_id', user.id)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (response != null) {
            planRow = response;
            // calculate total weeks strictly from DB data
            int d = 28;
            if (planRow['schedule_json'] != null &&
                planRow['schedule_json']['plan_duration_days'] != null) {
              d = planRow['schedule_json']['plan_duration_days'];
            }
            int w = (d / 7).ceil();
            print(
                'DEBUG: FETCHED PLAN -> plan_id=${planRow['id']} -> totalWeeks=$w');
          }
        } catch (e) {
          print('ERROR loading plan from DB: $e');
        }

        // ── Fallback: auto-generate if plan is missing or has empty weeks ──
        final sched = planRow?['schedule_json'];
        final weeks = sched?['weeks'];
        final weeksEmpty = weeks == null || (weeks is Map && weeks.isEmpty);

        if (planRow == null || weeksEmpty) {
          print(
              'DEBUG: Plan missing or weeks empty — calling generate_user_workout_plan RPC...');
          try {
            final rpcResponse = await Supabase.instance.client.rpc(
              'generate_user_workout_plan',
              params: {'p_user_id': user.id},
            );
            print('DEBUG: RPC response: $rpcResponse');
            print('DEBUG: RPC succeeded — re-fetching plan...');
            final refreshed = await Supabase.instance.client
                .from('ai_plans')
                .select('id, schedule_json, created_at')
                .eq('user_id', user.id)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (refreshed != null) planRow = refreshed;
          } catch (e) {
            print('WARNING: auto-generate workout plan failed: $e');
          }
        }
      }

      if (planRow != null && mounted) {
        setState(() {
          _generatedPlan = planRow;
          _hasPlan = true;
          _isLoadingPlan = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _generatedPlan = null;
            _isLoadingPlan = false;
          });
        }
        print('DEBUG: No plan found.');
      }
    } catch (e) {
      print('Error _loadGeneratedPlan: $e');
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  bool _hasPlan = false;
  bool _isLoading = true;
  List<ExerciseDetail> _exercises = [];
  List<ExerciseDetail> _allExercisesCache = []; // Master cache
  final Set<String> _completedExercises = {}; // Track completed exercise names

  // Track completed exercises per day
  final Map<String, Set<String>> _completedExercisesByDay = {};

  // Helper to get date key
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // STRICT Helper: Get Day Data by Index (Index 1..TotalDays)
  Map<String, dynamic>? _getDayData(int globalDayIndex) {
    if (_generatedPlan == null) return null;

    final schedule = _generatedPlan!['schedule_json'];
    if (schedule == null) return null;

    final weeks = schedule['weeks'];
    if (weeks == null) return null;

    // Math:
    // globalDayIndex 1 (Day 1) -> Week 1, Day 1
    // globalDayIndex 8 (Day 8) -> Week 2, Day 1
    int weekIndex = ((globalDayIndex - 1) ~/ 7) + 1;
    int dayInWeek = ((globalDayIndex - 1) % 7) + 1;

    final weekKey = weekIndex.toString();
    final weekData = weeks[weekKey];

    // Logs for strict validation
    if (weekData == null) {
      // This fails if requested day exceeds plan duration
      return null;
    }

    final days = weekData['days'];
    if (days == null) return null;

    return days[dayInWeek.toString()];
  }

  // Get GLOBAL Day Index from _selectedDay (1-based)
  int _getCurrentGlobalDayIndex() {
    // We rely on "created_at" to find start date
    if (_generatedPlan == null) return 1;

    final createdAtStr = _generatedPlan!['created_at'];
    if (createdAtStr == null) return 1;

    final createdAt = DateTime.parse(createdAtStr);
    final start =
        DateTime(createdAt.year, createdAt.month, createdAt.day); // midnight
    final current =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

    int diffDays = current.difference(start).inDays;
    // diffDays 0 = Day 1
    // STRICT: clamp min to 1
    if (diffDays < 0) return 1;

    // Do we clamp max?
    // Probably not here, but consumers should handle.
    return diffDays + 1;
  }

  // Helper method to get workout progress for any day
  double _getWorkoutProgressForDay(DateTime date) {
    // We need to calculate global index for THIS 'date', distinct from _selectedDay
    if (_generatedPlan == null) return 0.0;

    final createdAtStr = _generatedPlan!['created_at'];
    if (createdAtStr == null) return 0.0;

    final createdAt = DateTime.parse(createdAtStr);
    final start =
        DateTime(createdAt.year, createdAt.month, createdAt.day); // midnight
    final current = DateTime(date.year, date.month, date.day);

    int diffDays = current.difference(start).inDays;
    if (diffDays < 0) return 0.0;

    int globalIndex = diffDays + 1;
    final dayData = _getDayData(globalIndex);

    if (dayData == null || dayData['type'] == 'rest') return 0.0;

    final rawIds = dayData['exercises'] as List? ?? [];
    final totalExercises = rawIds.length;
    if (totalExercises == 0) return 0.0;

    final dateKey = _getDateKey(date);
    final dayCompleted = _completedExercisesByDay[dateKey];

    final completedCount = dayCompleted?.length ?? 0;

    return (completedCount / totalExercises).clamp(0.0, 1.0);
  }

  Future<void> _checkPlanStatus() async {
    // CLOUD CHECK: use Supabase — local SharedPreferences is unreliable on new devices.
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('ai_plans')
          .select('id')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();
      if (mounted) setState(() => _hasPlan = row != null);
      debugPrint('[WorkoutPage] _checkPlanStatus: hasPlan=${row != null}');
    } catch (e) {
      debugPrint('[WorkoutPage] _checkPlanStatus error: $e');
    }
  }

  // Fetch all exercises once and cache them
  Future<void> _initializeExercises() async {
    try {
      final stats = await SupabaseService().getProfileStats();
      final String gender = (stats?['gender']?.toString() ?? 'male').toLowerCase();

      var query = Supabase.instance.client.from('exercises').select(
          'is_male, is_female, group_path, exercise_name, target_muscle, synergist, difficulty_level, instruction_1, instruction_2, instruction_3, instruction_4, urls, exercise_type, equipment');

      if (gender == 'male') {
        query = query.eq('is_male', true);
      } else if (gender == 'female') {
        query = query.eq('is_female', true);
      }

      final response = await query;

      _allExercisesCache = (response as List)
          .map((json) => ExerciseDetail.fromJson(json))
          .toList();

      _updateDailyWorkouts();
    } catch (e) {
      print('Error fetching exercises: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _normalizeExerciseId(dynamic v) {
    final s = v.toString().trim();
    if (RegExp(r'^\d{6}$').hasMatch(s)) return s;
    if (RegExp(r'^\d+$').hasMatch(s)) return s.padLeft(6, '0');
    return s;
  }

  // Filter exercises strictly from the generated plan for the selected day
  Future<void> _updateDailyWorkouts({bool enableRetry = false}) async {
    setState(() {
      _isRestDay = false;
    });

    if (_generatedPlan == null) {
      if (mounted)
        setState(() {
          _exercises = [];
          _isLoading = false;
        });
      return;
    }

    setState(() => _isLoading = true);

    // Sync local completion state from the map
    final dateKey = _getDateKey(_selectedDay);
    final completedForDay = _completedExercisesByDay[dateKey] ?? {};
    _completedExercises.clear();
    _completedExercises.addAll(completedForDay);

    // MANDATORY: STRICT INDEX CALCULATION
    int globalDayIndex = _getCurrentGlobalDayIndex();
    final schedule = _generatedPlan!['schedule_json'];

    // Debug Logs as Requested
    int weeksCount = 4; // Default
    if (schedule != null && schedule['weeks_count'] != null) {
      weeksCount = schedule['weeks_count'];
    } else if (schedule != null && schedule['plan_duration_days'] != null) {
      weeksCount = (schedule['plan_duration_days'] / 7).ceil();
    }
    int totalDays = weeksCount * 7;

    int weekIndex = ((globalDayIndex - 1) ~/ 7) + 1;
    int dayInWeek = ((globalDayIndex - 1) % 7) + 1;

    print('===========================================');
    print('STRICT TEMPLATE DEBUG');
    print('Global Day Index: $globalDayIndex');
    print('Week Index: $weekIndex');
    print('Day of Week: $dayInWeek (formula: (($globalDayIndex - 1) % 7) + 1)');
    print('Total Plan Duration: $weeksCount weeks ($totalDays days)');

    // Use strict helper to get day data
    final dayData = _getDayData(globalDayIndex);

    if (dayData == null) {
      print('DEBUG: Day data not found for globalDayIndex=$globalDayIndex');
      print('===========================================');
      setState(() {
        _exercises = [];
        _isLoading = false;
      });
      return;
    }

    final dayType = dayData['type'];

    // 2. STRENGTHENED CHECK: Case-insensitive 'rest'
    if (dayType != null && dayType.toString().toLowerCase() == 'rest') {
      // Show REST DAY view
      // STRICT: NEVER show "No exercises found" for Rest.
      print('Action: Showing REST UI');
      setState(() {
        _exercises = [];
        _isLoading = false;
        _isRestDay = true;
      });
      return;
    }

    // Get exercise count (0 for rest days)
    final rawExercises = dayData['exercises'] as List? ?? [];
    final List<String> idsForDay =
        rawExercises.map((e) => _normalizeExerciseId(e)).toList();

    // 2. Workout day - fetch exercises
    print(
        "Fetching exercises for IDs: ${idsForDay.take(3).toList()}${idsForDay.length > 3 ? '...' : ''}");

    if (idsForDay.isEmpty) {
      // If workout day truly has no exercises, we show empty list (UI shows "No exercises found")
      setState(() {
        _exercises = [];
        _isLoading = false;
      });
      return;
    }

    try {
      List<dynamic> rows = [];
      int attempt = 0;
      int maxAttempts = enableRetry ? 5 : 1;

      while (attempt < maxAttempts) {
        attempt++;
        if (attempt > 1) {
          print('DEBUG: Retry Attempt $attempt for exercises...');
          await Future.delayed(Duration(milliseconds: 250 * attempt));
        }

        final response = await Supabase.instance.client
            .from('exercises')
            .select(
                'id, exercise_name, urls, synergist, is_male, is_female, target_muscle, difficulty_level, instruction_1, instruction_2, instruction_3, instruction_4, exercise_type, equipment')
            .inFilter('id', idsForDay);

        rows = response as List<dynamic>;

        if (rows.isNotEmpty) break;
      }

      print('Fetched ${rows.length} exercises from Supabase');

      // Build a map for O(1) lookup
      final Map<String, dynamic> byId = {
        for (var r in rows) _normalizeExerciseId(r['id']): r
      };

      // Reorder: Use ONLY ordered list from template. NO fallback.
      final List<ExerciseDetail> orderedExercises = [];

      for (var id in idsForDay) {
        final r = byId[id];
        if (r != null) {
          orderedExercises.add(ExerciseDetail.fromJson(r));
        } else {
          print('DEBUG: Missing ID $id in exercises table');
        }
      }

      print('Final Ordered Exercise Count: ${orderedExercises.length}');

      if (mounted) {
        setState(() {
          _exercises = orderedExercises;
          _isLoading = false;
        });
      }
      
      // Now that _exercises is fully populated, evaluate and persist completion state
      final isCompletedDay = completedForDay.length >= orderedExercises.length && orderedExercises.isNotEmpty;
      SupabaseService().updateCompletedExercises(dateKey, completedForDay.toList(), isCompletedDay);
      
    } catch (e) {
      print('ERROR fetching exercises: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markExerciseComplete(String exerciseName) async {
    // Capture dateKey BEFORE setState so it is accessible in the async block below.
    final dateKey = _getDateKey(_selectedDay);

    setState(() {
      _completedExercises.add(exerciseName);
      _completedExercisesByDay.putIfAbsent(dateKey, () => {});
      _completedExercisesByDay[dateKey]!.add(exerciseName);
    });

    // Save to Supabase Cloud
    final isCompletedDay = (_completedExercisesByDay[dateKey]?.length ?? 0) >= _exercises.length
        && _exercises.isNotEmpty;
    final listToSave = _completedExercisesByDay[dateKey]!.toList();

    await SupabaseService().updateCompletedExercises(
      dateKey,
      listToSave,
      isCompletedDay,
    );
  }

  int get _completedCount => _completedExercises.length;
  int get _totalCount => _exercises.length;

  Future<void> _createPlan() async {
    // CLOUD CHECK: Only push to quiz if user has NO profile in Supabase.
    // Never rely on local SharedPreferences for this gate.
    final user = Supabase.instance.client.auth.currentUser;
    bool hasProfile = false;
    
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('user_preferences')
            .select('user_id')
            .eq('user_id', user.id)
            .maybeSingle();
        hasProfile = response != null;
        debugPrint('[WorkoutPage] _createPlan: user=${user.id}, hasProfile=$hasProfile');
      } catch (e) {
        debugPrint('[WorkoutPage] Error checking profile: $e');
      }
    }

    if (!hasProfile && mounted) {
      // No profile → send to onboarding quiz
      final completed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CustomPlanQuizPage(quizType: 'workout'),
        ),
      );

      if (completed is Map && completed['completed'] == true) {
        setState(() => _hasPlan = true);
        debugPrint('[WorkoutPage] Quiz completed → triggering plan refresh');
        await _refresh();
      } else if (completed is Map && completed.containsKey('navIndex')) {
        final mainState = context.findAncestorStateOfType<MainScaffoldState>();
        mainState?.changeTab(completed['navIndex']);
      }
    } else {
      // Profile exists → go straight to plan generation
      setState(() => _hasPlan = true);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Check BOTH flags
    if (_isLoading || _isLoadingPlan) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: const Color(0xFFFF0000))),
      );
    }

    if (!_hasPlan) {
      return _buildSetupView(isDarkMode);
    }

    // Use desktop layout for screens wider than 800px
    if (screenWidth > 800 && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android) {
      return _buildDesktopLayout(isDarkMode);
    }

    return _buildPlannerView(isDarkMode);
  }

  // Initial setup screen for first-time users
  Widget _buildSetupView(bool isDarkMode) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '💪',
                      style: TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Start Your Fitness Journey',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '30-Day Workout Challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Transform your body with our expertly designed\nworkout program!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Features
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildFeatureRow('🎯', 'Structured 30-day plan'),
                          const SizedBox(height: 16),
                          _buildFeatureRow('📊', 'Track daily progress'),
                          const SizedBox(height: 16),
                          _buildFeatureRow('💯', 'Detailed instructions'),
                          const SizedBox(height: 16),
                          _buildFeatureRow('🔥', 'Build strength & endurance'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Start button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _createPlan,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF0000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Start Your Workout Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Main planner view
  Widget _buildPlannerView(bool isDarkMode) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header with Today's Workout
              if (kIsWeb)
                AnimatedContainer(
                  duration: Duration.zero,
                  height: _showHeader ? null : 0,
                  child: AnimatedOpacity(
                    duration: Duration.zero,
                    opacity: _showHeader ? 1.0 : 0.0,
                    child: RedHeader(
                      title:
                          '${_getDayName(_selectedDay.weekday)} : Day ${_getSelectedDayNumber()}',
                      subtitle: 'Your Workout Plan',
                      onToggleTheme: widget.toggleTheme,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: const Color(0xFFFF0000),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: _showingDayGrid
                        ? _buildGridView(isDarkMode)
                        : _buildDetailView(isDarkMode),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Grid view: Dynamic duration
  Widget _buildGridView(bool isDarkMode) {
    // 1) Read duration_days from plan
    int duration = 28; // Default 4 weeks
    if (_generatedPlan != null && _generatedPlan!['schedule_json'] != null) {
      final s = _generatedPlan!['schedule_json'];
      if (s['plan_duration_days'] != null) {
        duration = s['plan_duration_days'];
      }
    }

    // 2) Compute totalWeeks
    int totalWeeks = (duration / 7).ceil();
    if (totalWeeks < 1) totalWeeks = 1;

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      children: [
        // 3) Dynamic Workout Plan Grid
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
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Title
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${(duration / 7).ceil()}-Week Workout Plan',
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
                'Select a day to view your workouts',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
                ),
              ),

              SizedBox(height: isSmallScreen ? 16 : 30),

              // 4) Loop to render each Week
              for (int w = 0; w < totalWeeks; w++) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week ${w + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF0000),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Grid for this week. Days are 1-based.
                    // Week 1: 1..7
                    // Week 2: 8..14
                    // etc.
                    _build14DayGrid((w * 7) + 1, (w * 7) + 7, isDarkMode),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 30),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Detail view: Selected day's workouts
  Widget _buildDetailView(bool isDarkMode) {
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
                const Icon(Icons.arrow_back, size: 20),
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
                '${(_getWorkoutProgressForDay(_selectedDay) * 100).round()}% Complete',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Today's Progress Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.white : Colors.black,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    '$_completedCount/$_totalCount exercises',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDarkMode ? Colors.white54 : const Color(0xFF999999),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _totalCount > 0 ? _completedCount / _totalCount : 0.0,
                  backgroundColor: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF0F0F0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Exercise List
        _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: const Color(0xFFFF0000)),
              )
            : _isRestDay
                ? _buildRestDayCard(isDarkMode)
                : _exercises.isEmpty
                    ? Center(
                        child: Text(
                          'No exercises found',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _exercises[index];
                          return _buildExerciseTile(
                            exercise.name,
                            '3 sets × 12 reps',
                            isDarkMode,
                            isMobile: true,
                          );
                        },
                      ),
      ],
    );
  }

  // Desktop layout with 40% banner
  Widget _buildDesktopLayout(bool isDarkMode) {
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            // Header
            RedHeader(
              title:
                  '${_getDayName(_selectedDay.weekday)} : Day ${_getSelectedDayNumber()}',
              subtitle: 'Your Workout Plan',
              onToggleTheme: widget.toggleTheme,
              isDarkMode: widget.isDarkMode,
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate 40% of available width for banner
                  final bannerWidth = constraints.maxWidth * 0.4;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main content area (60%)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  // Weekly Calendar
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? const Color(0xFF1A1A1A)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white10
                                            : Colors.black12,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Your Plan',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  builder: (context) =>
                                                      const WorkoutPlanModal(),
                                                );
                                              },
                                              child: const Text(
                                                'View All',
                                                style: TextStyle(
                                                  color: Color(0xFFFF0000),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildDesktopDayCard(
                                                'Wed', true, false, isDarkMode),
                                            _buildDesktopDayCard(
                                                'Thu', true, false, isDarkMode),
                                            _buildDesktopDayCard(
                                                'Fri', false, true, isDarkMode),
                                            _buildDesktopDayCard('Sat', false,
                                                false, isDarkMode),
                                            _buildDesktopDayCard('Sun', false,
                                                false, isDarkMode),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Today's Progress Section
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? const Color(0xFF1A1A1A)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white10
                                            : Colors.black12,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Today\'s Progress',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            Text(
                                              '$_completedCount/$_totalCount exercises',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode
                                                    ? Colors.white54
                                                    : const Color(0xFF999999),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: _totalCount > 0
                                                ? _completedCount / _totalCount
                                                : 0.0,
                                            backgroundColor: isDarkMode
                                                ? const Color(0xFF2C2C2C)
                                                : const Color(0xFFF0F0F0),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(Color(0xFFFF0000)),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Exercise List
                                  _isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                              color: const Color(0xFFFF0000)),
                                        )
                                      : _exercises.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No exercises found',
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                              itemCount: _exercises.length,
                                              itemBuilder: (context, index) {
                                                final exercise =
                                                    _exercises[index];
                                                return _buildExerciseTile(
                                                  exercise.name,
                                                  '3 sets × 12 reps',
                                                  isDarkMode,
                                                  isMobile: false,
                                                );
                                              },
                                            ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Banner Panel (40%)
                      Container(
                        width: bannerWidth,
                        padding: const EdgeInsets.only(
                            top: 24, right: 24, bottom: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                          ),
                          child: Center(
                            child: Text(
                              'Banner Area\n40% Width',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black54,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDayCard(String dayData, bool completed, bool isToday,
      bool isDarkMode, double screenWidth,
      {double progressPercent = 0.0,
      int mealsEaten = 0,
      int totalMeals = 5,
      bool isSelected = false}) {
    // dayData format: "DayName|DayNum", e.g., "Sun|04"
    final parts = dayData.split('|');
    final dayName = parts[0];
    final dayNum = parts.length > 1 ? parts[1] : '';

    final percentage = (progressPercent * 100).round();
    final isCompleted = completed || progressPercent >= 1.0;

    return Transform.scale(
      scale: isSelected && !isToday ? 1.10 : 1.0,
      child: AspectRatio(
        aspectRatio: 1.1, // More square-like, less cramped
        child: Container(
          padding: const EdgeInsets.all(8), // Better spacing
          decoration: BoxDecoration(
            color: isToday
                ? const Color(0xFFFF0000)
                : (isDarkMode ? const Color(0xFF2D2D2D) : Colors.white),
            border: Border.all(
              color: isDarkMode ? Colors.white54 : Colors.black,
              width: 1, // Cleaner, thinner border
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Day and Date - Larger and centered
              Text(
                '$dayName $dayNum',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isToday
                      ? Colors.white
                      : (isDarkMode ? Colors.white : Colors.black),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Progress Percentage or Checkmark
              if (isCompleted)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 32,
                )
              else
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? Colors.white
                        : (isDarkMode ? Colors.white : const Color(0xFF2196F3)),
                  ),
                ),

              const SizedBox(height: 8),

              // Progress Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalMeals, (index) {
                  final isFilled = index < mealsEaten;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isFilled
                          ? (isToday ? Colors.white : const Color(0xFF4CAF50))
                          : (isToday
                              ? Colors.white.withOpacity(0.3)
                              : (isDarkMode ? Colors.white24 : Colors.black26)),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDayCard(
      String day, bool completed, bool isToday, bool isDarkMode) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFFFF0000)
            : (isDarkMode ? const Color(0xFF2D2D2D) : Colors.white),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 12, // Reduced for small screens
              fontWeight: FontWeight.bold,
              color: isToday
                  ? Colors.white
                  : (isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          if (isToday)
            const Text(
              'Today',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white,
              ),
            )
          else if (completed)
            const Icon(
              Icons.check,
              color: Color(0xFF4CAF50),
              size: 18,
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseTile(String title, String subtitle, bool isDarkMode,
      {bool isMobile = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border.all(
          color: isMobile
              ? (isDarkMode ? Colors.white : Colors.black)
              : Colors.black, // Mobile dark mode white, others black
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          )
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _completedExercises.contains(title)
            ? Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 24,
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                  size: 20,
                ),
              ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDarkMode ? Colors.white54 : Colors.black38,
          size: 18,
        ),
        onTap: () async {
          final completed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseDetailPage(
                exercise:
                    _exercises[_exercises.indexWhere((e) => e.name == title)],
                isDarkMode: isDarkMode,
              ),
            ),
          );

          // Mark exercise as complete if user marked all sets complete
          if (completed == true) {
            _markExerciseComplete(title);
          }
        },
      ),
    );
  }

  Widget _buildGeneratedPlanView() {
    final plan = _generatedPlan!['workout_plan'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Personalized Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: plan.length,
          itemBuilder: (context, index) {
            final day = plan[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isDarkMode ? Colors.white24 : Colors.black12,
                  width: 0.5,
                ),
              ),
              child: ExpansionTile(
                title: Text(
                  day['day'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  day['focus'],
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                children: [
                  if (day['exercises'] != null)
                    ...(day['exercises'] as List).map<Widget>((ex) {
                      return ListTile(
                        title: Text(
                          ex['name'],
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '${ex['sets']} sets x ${ex['reps']}',
                          style: TextStyle(
                            color:
                                _isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // New Rest Day Card
  Widget _buildRestDayCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.white24 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: Color(0xFF4CAF50),
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Rest & Recover',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your muscles need time to repair and grow. Take it easy today!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // New methods for 14-day grid layout
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
    DateTime planStartDate;
    if (_generatedPlan != null && _generatedPlan!['created_at'] != null) {
      final createdAt = DateTime.parse(_generatedPlan!['created_at']);
      // Normalize to midnight
      planStartDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
    } else {
      final now = DateTime.now();
      planStartDate = now.subtract(Duration(days: now.weekday - 1));
      planStartDate =
          DateTime(planStartDate.year, planStartDate.month, planStartDate.day);
    }

    final dayDate = planStartDate.add(Duration(days: dayNumber - 1));
    final isSelected = dayDate.day == _selectedDay.day &&
        dayDate.month == _selectedDay.month &&
        dayDate.year == _selectedDay.year;

    // Get progress and data
    final dateKey = _getDateKey(dayDate);
    final dayCompleted = _completedExercisesByDay[dateKey];

    final dayData = _getDayData(dayNumber);
    final rawIds = dayData != null ? (dayData['exercises'] as List? ?? []) : [];
    final totalExercises = rawIds.length;
    final dayType = dayData != null
        ? dayData['type']
        : 'workout'; // Default to workout if unknown

    final completedCount = dayCompleted?.length ?? 0;
    final progressPercent = totalExercises == 0
        ? 0
        : ((completedCount / totalExercises) * 100).round();
    final isRest = dayType == 'rest';
    final isCompleted = !isRest && progressPercent == 100;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = dayDate;
          _showingDayGrid = false;
        });
        _updateDailyWorkouts();
      },
      child: Container(
        decoration: ShapeDecoration(
          color: isCompleted
              ? const Color(0xFF4CAF50) // Solid green when completed
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double circleWidth = constraints.maxWidth;
            return Padding(
              padding: EdgeInsets.all(circleWidth * 0.15),
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
                        color: isCompleted 
                            ? Colors.white 
                            : (isDarkMode ? Colors.white : Colors.black),
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: circleWidth * 0.05),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isRest ? 'Rest' : (isCompleted ? '100%' : '$progressPercent%'),
                      style: TextStyle(
                        fontSize: circleWidth * 0.22,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? Colors.white // White text on green background
                            : (isRest
                                ? const Color(0xFFFF0000)
                                : const Color(0xFF4CAF50)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method to get the selected day number (Global Index 1..N)
  int _getSelectedDayNumber() {
    return _getCurrentGlobalDayIndex();
  }

  Widget _buildStatsSummary(bool isDarkMode) {
    final stats = _calculateOverallStats();

    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color:
                isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
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
            '${stats['exercisesLogged']}',
            'Exercises Logged',
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
    int exercisesLogged = 0;
    int totalExercises = 0;

    final now = DateTime.now();
    final planStartDate = now.subtract(Duration(days: now.weekday - 1));

    for (int day = 1; day <= 14; day++) {
      // Calculate global index relative to "now"'s week window?
      // Wait, this method iterates 1..14 (2 weeks)
      // "planStartDate" is the current week's Monday.
      // We need to find the GLOBAL index for these 14 days.

      final dayDate = planStartDate.add(Duration(days: day - 1));

      // Calculate Global Index for this date
      final createdAtStr =
          _generatedPlan != null ? _generatedPlan!['created_at'] : null;
      int globalIndex = 0;

      if (createdAtStr != null) {
        final createdAt = DateTime.parse(createdAtStr);
        final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final current = DateTime(dayDate.year, dayDate.month, dayDate.day);
        int diff = current.difference(start).inDays;
        if (diff >= 0) globalIndex = diff + 1;
      }

      final dateKey = _getDateKey(dayDate);
      final dayCompleted = _completedExercisesByDay[dateKey];

      Map<String, dynamic>? dayData;
      if (globalIndex > 0) {
        dayData = _getDayData(globalIndex);
      }

      final rawIds =
          dayData != null ? (dayData['exercises'] as List? ?? []) : [];
      final dayTotalExercises = rawIds.length;

      final dayCompletedCount = dayCompleted?.length ?? 0;

      totalExercises += dayTotalExercises;
      exercisesLogged += dayCompletedCount;

      if (dayCompletedCount == dayTotalExercises && dayCompletedCount > 0) {
        daysComplete++;
      }
    }

    final overallPercent = totalExercises == 0
        ? 0
        : ((exercisesLogged / totalExercises) * 100).round();

    return {
      'daysComplete': daysComplete,
      'exercisesLogged': exercisesLogged,
      'overall': overallPercent,
    };
  }
}
