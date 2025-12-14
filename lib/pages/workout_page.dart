import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'exercise_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'workout_plan_modal.dart';
import 'home_page.dart'; // Import ExerciseDetail model
import 'custom_plan_quiz.dart';
import 'main_scaffold.dart';
import '../widgets/red_header.dart';

class WorkoutPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const WorkoutPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  bool _isDarkMode = false;
  Map<String, dynamic>? _generatedPlan;
  bool _isLoadingPlan = true;

  // Scroll controller for hiding header
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  double _lastScrollOffset = 0;

  // Week navigation
  int _weekOffset = 0; // 0 = current week, -1 = previous week, +1 = next week
  DateTime _selectedDay = DateTime.now(); // Track which day is selected
  bool _showingDayGrid = true; // Toggle between grid view and detail view (mobile only)

  // Generate 3 days centered around current day, adjusted by week offset
  List<Map<String, dynamic>> _generateDays() {
    final now = DateTime.now();
    final startDay = now.add(Duration(days: (_weekOffset * 7) - 2)); // Start 2 days before current to center
    
    return List.generate(5, (index) {
      final day = startDay.add(Duration(days: index));
      final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
      final progress = _getWorkoutProgressForDay(day);
      
      return {
        'label': '${_getDayName(day.weekday)}|${day.day.toString().padLeft(2, '0')}',
        'isToday': isToday,
        'isCompleted': progress >= 1.0,
        'date': day,
        'progress': progress,
      };
    });
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadGeneratedPlan();
    _checkPlanStatus();
    _initializeExercises();
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

  Future<void> _loadGeneratedPlan() async {
    // AI PLAN LOADING DISABLED
    setState(() {
      _generatedPlan = null;
      _isLoadingPlan = false;
    });
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
  
  // Helper method to get workout progress for any day
  double _getWorkoutProgressForDay(DateTime date) {
    final dateKey = _getDateKey(date);
    final dayCompleted = _completedExercisesByDay[dateKey];
    if (dayCompleted == null || dayCompleted.isEmpty) return 0.0;
    
    // Assuming 5 exercises per day (adjust based on actual workout structure)
    final totalExercises = 5;
    final completedCount = dayCompleted.length;
    
    return totalExercises == 0 ? 0.0 : (completedCount / totalExercises).clamp(0.0, 1.0);
  }

  Future<void> _checkPlanStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasPlan = prefs.getBool('has_workout_plan') ?? false;
    });
  }

  // Fetch all exercises once and cache them
  Future<void> _initializeExercises() async {
    try {
      // Get user gender from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final String gender = prefs.getString('profile_gender') ?? 'Male';
      
      var query = Supabase.instance.client
          .from('exercises')
          .select('is_male, is_female, group_path, exercise_name, target_muscle, synergists, difficulty_level, instruction_1, instruction_2, instruction_3, instruction_4, urls, exercise_type, equipment');
          
      // Apply gender filter
      if (gender == 'Male') {
        query = query.eq('is_male', true);
      } else if (gender == 'Female') {
        query = query.eq('is_female', true);
      }
      
      final response = await query;
      
      _allExercisesCache = (response as List)
          .map((json) => ExerciseDetail.fromJson(json))
          .toList();

      _updateDailyWorkouts(); // Initial load for current day
      
    } catch (e) {
      print('Error fetching exercises: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Locally filter exercises for the selected day - Instant!
  void _updateDailyWorkouts() {
     if (_allExercisesCache.isEmpty) {
       setState(() => _isLoading = false);
       return;
     }

      // Filter to random 5-10 exercises for the day
      // Use the selected day as a seed for consistent results
      final seed = _selectedDay.year * 10000 + _selectedDay.month * 100 + _selectedDay.day;
      final random = Random(seed);
      
      // Determine count (between 5 and 10)
      final count = 5 + random.nextInt(6); // 5 + (0 to 5) = 5 to 10
      
      // Shuffle a copy of the cache to avoid modifying original order permanently
      final shuffled = List<ExerciseDetail>.from(_allExercisesCache)..shuffle(random);
      
      setState(() {
        _exercises = shuffled.take(count).toList();
        _isLoading = false;
      });
      
      print('DEBUG: Updated daily workouts for $_selectedDay (Seed: $seed)');
  }

  void _markExerciseComplete(String exerciseName) {
    setState(() {
      _completedExercises.add(exerciseName);
      
      // Also track per-day completion
      final dateKey = _getDateKey(_selectedDay);
      _completedExercisesByDay.putIfAbsent(dateKey, () => {});
      _completedExercisesByDay[dateKey]!.add(exerciseName);
    });
  }

  int get _completedCount => _completedExercises.length;
  int get _totalCount => _exercises.length;

  Future<void> _createPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final quizCompleted = prefs.getBool('quiz_completed') ?? false;
    
    // Check if quiz is completed
    if (!quizCompleted && mounted) {
      // Navigate to quiz
      final completed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CustomPlanQuizPage(quizType: 'workout'),
        ),
      );
      
      // If quiz was completed, create the plan
      if (completed is Map && completed['completed'] == true) {
        await prefs.setBool('has_workout_plan', true);
        setState(() {
          _hasPlan = true;
        });
      } else if (completed is Map && completed.containsKey('navIndex')) {
        // Handle navigation
        final mainState = context.findAncestorStateOfType<MainScaffoldState>();
        mainState?.changeTab(completed['navIndex']);
      }
    } else {
      // Quiz already completed, create plan directly
      await prefs.setBool('has_workout_plan', true);
      setState(() {
        _hasPlan = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: const Color(0xFFFF0000))),
      );
    }

    // Use desktop layout for screens wider than 800px
    if (screenWidth > 800) {
      return _buildDesktopLayout(isDarkMode);
    }

    return _buildPlannerView(isDarkMode);
  }

  // Initial setup screen for first-time users
  Widget _buildSetupView(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey.shade50,
      body: SafeArea(
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
                        backgroundColor: Colors.white,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header with Today's Workout
          AnimatedContainer(
            duration: Duration.zero,
            height: _showHeader ? null : 0,
            child: AnimatedOpacity(
              duration: Duration.zero,
              opacity: _showHeader ? 1.0 : 0.0,
              child: RedHeader(
                title: 'Fri : Day 26',
                subtitle: 'Your Workout Plan',
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
      ),
    );
  }

  // Grid view: 14-day selection
  Widget _buildGridView(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Column(
      children: [
        // 14-Day Workout Plan Grid
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
                '14-Day Workout Plan',
                style: TextStyle(
                  fontSize: isSmallScreen ? 22 : 28,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF333333),
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
                color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
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
                      color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    '$_completedCount/$_totalCount exercises',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : const Color(0xFF999999),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _totalCount > 0 ? _completedCount / _totalCount : 0.0,
                  backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
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
                child: CircularProgressIndicator(color: const Color(0xFFFF0000)),
              )
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
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header
          RedHeader(
            title: 'Fri : Day 26',
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
                            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                // Weekly Calendar
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDarkMode ? Colors.white10 : Colors.black12,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Your Plan',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                builder: (context) => const WorkoutPlanModal(),
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildDesktopDayCard('Wed', true, false, isDarkMode),
                                          _buildDesktopDayCard('Thu', true, false, isDarkMode),
                                          _buildDesktopDayCard('Fri', false, true, isDarkMode),
                                          _buildDesktopDayCard('Sat', false, false, isDarkMode),
                                          _buildDesktopDayCard('Sun', false, false, isDarkMode),
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
                                    color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDarkMode ? Colors.white10 : Colors.black12,
                                      width: 1,
                                    ),
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
                                              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          Text(
                                            '$_completedCount/$_totalCount exercises',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode ? Colors.white54 : const Color(0xFF999999),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: _totalCount > 0 ? _completedCount / _totalCount : 0.0,
                                          backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
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
                                        child: CircularProgressIndicator(color: const Color(0xFFFF0000)),
                                      )
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
                      padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            'Banner Area\n40% Width',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.black54,
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
    );
  }

  Widget _buildMobileDayCard(
    String dayData, 
    bool completed, 
    bool isToday, 
    bool isDarkMode, 
    double screenWidth,
    {double progressPercent = 0.0, int mealsEaten = 0, int totalMeals = 5, bool isSelected = false}) {
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
              : (isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5)), 
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

  Widget _buildDesktopDayCard(String day, bool completed, bool isToday, bool isDarkMode) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: isToday 
            ? const Color(0xFFFF0000) 
            : (isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5)),
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

  Widget _buildExerciseTile(String title, String subtitle, bool isDarkMode, {bool isMobile = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border.all(
        color: isMobile ? (isDarkMode ? Colors.white : Colors.black) : Colors.black, // Mobile dark mode white, others black
        width: 1,
      ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                exercise: _exercises[_exercises.indexWhere((e) => e.name == title)],
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
                            color: _isDarkMode ? Colors.white70 : Colors.grey[600],
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
    final now = DateTime.now();
    final planStartDate = now.subtract(Duration(days: now.weekday - 1));
    final dayDate = planStartDate.add(Duration(days: dayNumber - 1));
    final isSelected = dayDate.day == _selectedDay.day && 
                      dayDate.month == _selectedDay.month && 
                      dayDate.year == _selectedDay.year;
    
    // Get progress for this day
    final dateKey = _getDateKey(dayDate);
    final dayCompleted = _completedExercisesByDay[dateKey];
    final totalExercises = 5; // Assuming 5 exercises per day
    final completedCount = dayCompleted?.length ?? 0;
    final progressPercent = totalExercises == 0 ? 0 : ((completedCount / totalExercises) * 100).round();
    final isCompleted = progressPercent == 100;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = dayDate;
          _showingDayGrid = false; // Switch to detail view
        });
        _updateDailyWorkouts();
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
    // Normalize to midnight to avoid time drift issues causing off-by-one errors
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final planStartDate = DateTime(currentMonday.year, currentMonday.month, currentMonday.day);
    
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    
    final difference = selectedDate.difference(planStartDate).inDays;
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
      final dayDate = planStartDate.add(Duration(days: day - 1));
      final dateKey = _getDateKey(dayDate);
      final dayCompleted = _completedExercisesByDay[dateKey];
      
      final dayTotalExercises = 5; // Assuming 5 exercises per day
      final dayCompletedCount = dayCompleted?.length ?? 0;
      
      totalExercises += dayTotalExercises;
      exercisesLogged += dayCompletedCount;
      
      if (dayCompletedCount == dayTotalExercises && dayCompletedCount > 0) {
        daysComplete++;
      }
    }
    
    final overallPercent = totalExercises == 0 ? 0 : ((exercisesLogged / totalExercises) * 100).round();
    
    return {
      'daysComplete': daysComplete,
      'exercisesLogged': exercisesLogged,
      'overall': overallPercent,
    };
  }
}
