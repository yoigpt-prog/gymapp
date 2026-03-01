import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_page.dart';
import 'meal_plan_page.dart';
import '../widgets/gym_bottom_nav_bar.dart';
import '../services/quiz_service.dart';
import '../services/plan_service.dart';
import '../services/supabase_service.dart';
import '../widgets/auth/auth_modal.dart';

class CustomPlanQuizPage extends StatefulWidget {
  final String quizType; // 'workout' or 'meal'

  const CustomPlanQuizPage({Key? key, required this.quizType}) : super(key: key);

  @override
  State<CustomPlanQuizPage> createState() => _CustomPlanQuizPageState();
}

class _CustomPlanQuizPageState extends State<CustomPlanQuizPage> with TickerProviderStateMixin {
  int currentScreen = 0;
  
  // Form Data
  String name = '';
  String gender = '';
  String age = '';
  String height = '';
  String heightUnit = 'cm';
  String weight = '';
  String weightUnit = 'kg';
  String bodyType = '';
  String activityLevel = '';
  String mainGoal = '';
  String targetWeight = '';
  String targetWeightUnit = 'kg';
  String planDuration = '';
  String experience = '';
  List<String> bodyAreas = ['Full Body'];
  String workoutLocation = '';
  List<String> equipment = ['All'];
  String trainingDays = '';
  String sessionDuration = '';
  String workoutTime = '';
  List<String> injuries = ['None'];
  List<String> healthConditions = ['None'];
  String dietType = 'No Preference';
  String excludeFoods = '';
  List<String> allergies = ['None'];
  String macroBalance = '';
  String sleepHours = '';
  String sleepQuality = '';
  String stressLevel = '';
  String workType = '';
  String avoidMovements = '';
  String waterIntake = '';

  // Progress & State
  double progressPercent = 0;
  String progressStatus = 'Initializing...';
  int currentStep = 1;
  String selectedPlan = 'weekly';
  bool isTrialEnabled = true;

  // Animations
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Picker controllers — keyed by 'questionNumber_unit' so they survive setState
  final Map<String, FixedExtentScrollController> _pickerControllers = {};

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Set default units based on locale
    try {
      if (!kIsWeb) {
        final String locale = Platform.localeName;
        if (locale.toUpperCase().contains('US')) {
          heightUnit = 'ft';
          weightUnit = 'lbs';
          targetWeightUnit = 'lbs';
        } else {
          heightUnit = 'cm';
          weightUnit = 'kg';
          targetWeightUnit = 'kg';
        }
      } else {
         // Web default (Metric)
         heightUnit = 'cm';
         weightUnit = 'kg';
         targetWeightUnit = 'kg';
      }
    } catch (e) {
      // Fallback to Metric if locale check fails
      heightUnit = 'cm';
      weightUnit = 'kg';
      targetWeightUnit = 'kg';
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    for (final c in _pickerControllers.values) c.dispose();
    _pickerControllers.clear();
    super.dispose();
  }

  void nextScreen(int screen) {
    setState(() {
      currentScreen = screen;
    });
  }

  void toggleOption(List<String> list, String value, {int? maxSelections}) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        if (maxSelections != null && list.length >= maxSelections) return;
        list.add(value);
      }
    });
  }

  Future<void> startPlanGeneration() async {
    // 0. Auth check
    final supabaseService = SupabaseService();
    var user = supabaseService.client.auth.currentUser;
    if (user == null) {
      await AuthModal.show(context);
      user = supabaseService.client.auth.currentUser;
      if (user == null) return;
    }

    nextScreen(28); // Progress Screen

    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      progressStatus = 'Analyzing your profile...';
      progressPercent = 20;
    });

    try {
      final quizService = QuizService();
      final Map<String, dynamic> answersJson = {
        'gender': gender,
        'age': age,
        'height': height,
        'weight': weight,
        'main_goal': mainGoal,
        'experience': experience,
        'training_days': trainingDays,
        'workout_location': workoutLocation,
        'plan_duration': planDuration,
        'meals_per_day': 4, // Fixed: Always 4 meals
        'diet_type': dietType,
        'allergies': allergies,
      };
      final normalized = quizService.normalizeQuizAnswers(answersJson: answersJson);

      if (!mounted) return;
      setState(() {
        progressStatus = 'Saving your preferences...';
        progressPercent = 40;
      });

      int durationWeeks = 4;
      final weekMatch = RegExp(r'(\d+)\s*[Ww]eeks?').firstMatch(planDuration);
      if (weekMatch != null) {
        durationWeeks = int.parse(weekMatch.group(1)!);
      } else {
        final digitMatch = RegExp(r'(\d+)').firstMatch(planDuration);
        if (digitMatch != null) {
          final val = int.parse(digitMatch.group(1)!);
          durationWeeks = val <= 52 ? val : (val / 7).round();
        }
      }

      await supabaseService.saveUserPreferences(
        mainGoal: mainGoal,
        dietType: dietType,
        allergies: allergies,
        durationWeeks: durationWeeks,
        trainingLocation: normalized['training_location'],
        gender: normalized['gender'],
        trainingDays: normalized['training_days'],
      );

      if (!mounted) return;
      setState(() {
        progressStatus = 'Generating workout plan...';
        progressPercent = 60;
      });

      final planService = PlanService();
      try {
        await planService.generateWorkoutPlan();
        print('DEBUG: Workout plan generated successfully.');
      } catch (e) {
        print('WARNING: Workout plan generation failed: $e');
      }

      if (!mounted) return;
      setState(() {
        progressStatus = 'Generating meal plan...';
        progressPercent = 80;
      });

      try {
        await planService.generateMealPlan(forceRegenerate: true);
        print('DEBUG: Meal plan generated successfully.');
      } catch (e) {
        print('WARNING: Meal plan generation failed: $e');
      }

      await prefs.setBool('has_workout_plan', true);
      await prefs.setBool('has_meal_plan', true);
      await prefs.setString('plan_duration', planDuration);
      await prefs.setString('weight_unit', weightUnit);
      await prefs.setString('height_unit', heightUnit);

      final userId = supabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        await prefs.remove('meal_plan_cache_$userId');
      }

      if (mounted) {
        setState(() {
          progressPercent = 100;
          progressStatus = 'Ready!';
        });
        await Future.delayed(const Duration(milliseconds: 600));
        Navigator.pop(context, {
          'completed': true,
          'navIndex': 1, // Workout tab
        });
      }
    } catch (e) {
      print('ERROR in plan generation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Content Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(currentScreen),
                  child: Container(
                    color: isDarkMode ? const Color(0xFF121212) : Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: _buildCurrentScreen(isDarkMode),
                  ),
                ),
              ),
            ),
            
          ],
        ),
      ),
      bottomNavigationBar: currentScreen == 0
          ? GymBottomNavBar(
              currentIndex: widget.quizType == 'workout' ? 1 : (widget.quizType == 'meal' ? 2 : 0),
              onTap: (index) {
                Navigator.pop(context, {'navIndex': index});
              },
              isDarkMode: isDarkMode,
            )
          : null,
    );
  }



  Widget _buildCurrentScreen(bool isDarkMode) {
    switch (currentScreen) {
      case 0: return _buildWelcomeScreen();
      case 1: return _buildGenderScreen(isDarkMode);
      case 2: return _buildAgeScreen(isDarkMode);
      case 3: return _buildHeightScreen(isDarkMode);
      case 4: return _buildWeightScreen(isDarkMode);
      case 5: return _buildBodyTypeScreen(isDarkMode);
      case 6: return _buildActivityLevelScreen(isDarkMode);
      case 7: return _buildGoalScreen(isDarkMode);
      case 8: return _buildTargetWeightScreen(isDarkMode);
      case 9: return _buildPlanDurationScreen(isDarkMode);
      case 10: return _buildExperienceScreen(isDarkMode);
      case 11: return _buildBodyAreasScreen(isDarkMode);
      case 12: return _buildWorkoutLocationScreen(isDarkMode);
      case 13: return _buildEquipmentScreen(isDarkMode);
      case 14: return _buildTrainingDaysScreen(isDarkMode);
      case 15: return _buildSessionDurationScreen(isDarkMode);
      case 16: return _buildWorkoutTimeScreen(isDarkMode);
      case 17: return _buildInjuriesScreen(isDarkMode);
      case 18: return _buildHealthConditionsScreen(isDarkMode);
      case 19: return _buildDietTypeScreen(isDarkMode);
      case 20: return _buildAllergiesScreen(isDarkMode);
      case 21: return _buildMacroBalanceScreen(isDarkMode);
      case 22: return _buildSleepHoursScreen(isDarkMode);
      case 23: return _buildSleepQualityScreen(isDarkMode);
      case 24: return _buildStressLevelScreen(isDarkMode);
      case 25: return _buildWaterIntakeScreen(isDarkMode);
      case 26: return _buildSummaryScreen(isDarkMode);
      case 27: return _buildProgressScreen(isDarkMode);
      case 28: return _buildUpgradeScreen(isDarkMode);
      default: return _buildWelcomeScreen();
    }
  }

  Widget _buildWelcomeScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final isVerySmallScreen = screenHeight < 550;
        final isSmallScreen = screenHeight < 700;
        
        // Responsive sizing based on screen height
        final double imageHeight = isVerySmallScreen 
            ? screenHeight * 0.45 
            : (isSmallScreen ? screenHeight * 0.50 : screenHeight * 0.55);
        final double titleSize = isVerySmallScreen ? 18 : (isSmallScreen ? 22 : 26);
        final double subtitleSize = isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 14);
        final double badgeSize = isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16);
        final double buttonSize = isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16);
        final double verticalPadding = isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 10);
        final double spacing = isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12);
        final double smallSpacing = isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 6);
        
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Decorative circles
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/quizimg.png',
                            height: imageHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: smallSpacing),
                        Text(
                          'Transform Your Body',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 10,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: smallSpacing),
                        Text(
                          'Get a science-backed fitness plan designed just for you',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: spacing),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isVerySmallScreen ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '✨ Create Your Custom Plan in 2 Minutes ✨',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: badgeSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: spacing),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final supabaseService = SupabaseService();
                              var user = supabaseService.client.auth.currentUser;
                              if (user == null) {
                                await AuthModal.show(context);
                                user = supabaseService.client.auth.currentUser;
                                if (user == null) return; // still not signed in
                              }
                              nextScreen(1);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFFF0000),
                              padding: EdgeInsets.symmetric(
                                vertical: isVerySmallScreen ? 14 : 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              elevation: 10,
                            ),
                            child: Text(
                              "LET'S GET STARTED",
                              style: TextStyle(
                                fontSize: buttonSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets & Animations ---

  Widget _buildAnimatedWidget({
    required Widget child,
    required int delay, // milliseconds
    bool slideUp = true,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, slideUp ? (20 * (1 - value)) : (-15 * (1 - value))),
            child: child,
          ),
        );
      },
      onEnd: () {},
      child: child,
    );
  }

  Widget _buildProgressBar(int questionNumber) {
    double progress = (questionNumber / 26).clamp(0.0, 1.0);
    return Column(
      children: [

        const SizedBox(height: 12),
        _buildAnimatedWidget(
          delay: 100,
          slideUp: false,
          child: Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0000), Color(0xFFFF3333)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withOpacity(0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildQuestionScreen({
    required int questionNumber,
    required String title,
    required Widget content,
    required VoidCallback onContinue,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        _buildProgressBar(questionNumber),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedWidget(
                  delay: 100,
                  slideUp: false,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: content,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(VoidCallback onPressed) {
    return _buildAnimatedWidget(
      delay: 600,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 15),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF0000),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 4,
            shadowColor: const Color(0xFFFF0000).withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.play_arrow, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    required int index,
    required bool isDarkMode,
    bool isRadio = true,
  }) {
    return _buildAnimatedWidget(
      delay: 100 + (index * 50),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDarkMode ? const Color(0xFF8B0000) : const Color(0xFFFFE5E5))
                : (isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF8F8F8)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF0000) : (isDarkMode ? Colors.grey : const Color(0xFFCCCCCC)),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Specific Question Type Builders ---

  Widget _buildInputScreen({
    required int questionNumber,
    required String title,
    required String placeholder,
    required String value,
    required ValueChanged<String> onChanged,
    required VoidCallback onContinue,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return _buildQuestionScreen(
      questionNumber: questionNumber,
      title: title,
      onContinue: onContinue,
      isDarkMode: isDarkMode,
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildAnimatedWidget(
              delay: 100,
              child: TextField(
                controller: TextEditingController(text: value)
                  ..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
                onChanged: onChanged,
                keyboardType: keyboardType,
                style: TextStyle(fontSize: 15, color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                  filled: false,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF0000), width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildContinueButton(onContinue),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionScreen({
    required int questionNumber,
    required String title,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelect,
    required bool isDarkMode,
  }) {
    return _buildQuestionScreen(
      questionNumber: questionNumber,
      title: title,
      onContinue: () => nextScreen(questionNumber + 1),
      isDarkMode: isDarkMode,
      content: ListView.builder(
        itemCount: options.length + 1, // +1 for continue button
        itemBuilder: (context, index) {
          if (index == options.length) {
            return _buildContinueButton(() => nextScreen(questionNumber + 1));
          }
          final option = options[index];
          return _buildOption(
            text: option,
            isSelected: selectedValue == option,
            onTap: () => onSelect(option),
            index: index,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildMultiSelectionScreen({
    required int questionNumber,
    required String title,
    required List<String> options,
    required List<String> selectedValues,
    required ValueChanged<String> onToggle,
    required bool isDarkMode,
    int columns = 1,
  }) {
    // Force single column on small screens to prevent overflow
    if (MediaQuery.of(context).size.width < 600) {
      columns = 1;
    }
    return _buildQuestionScreen(
      questionNumber: questionNumber,
      title: title,
      onContinue: () => nextScreen(questionNumber + 1),
      isDarkMode: isDarkMode,
      content: CustomScrollView(
        slivers: [
          if (columns > 1)
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: 3.5, // Adjusted for better fit
                crossAxisSpacing: 10,
                mainAxisSpacing: 0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final option = options[index];
                  return _buildOption(
                    text: option,
                    isSelected: selectedValues.contains(option),
                    onTap: () => onToggle(option),
                    index: index,
                    isRadio: false,
                    isDarkMode: isDarkMode,
                  );
                },
                childCount: options.length,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final option = options[index];
                  return _buildOption(
                    text: option,
                    isSelected: selectedValues.contains(option),
                    onTap: () => onToggle(option),
                    index: index,
                    isRadio: false,
                    isDarkMode: isDarkMode,
                  );
                },
                childCount: options.length,
              ),
            ),
            
          SliverToBoxAdapter(
            child: _buildContinueButton(() => nextScreen(questionNumber + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitInputScreen({
    required int questionNumber,
    required String title,
    required String placeholder,
    required String value,
    required String unit,
    required List<String> units,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onUnitChanged,
    required bool isDarkMode,
  }) {
    return _buildQuestionScreen(
      questionNumber: questionNumber,
      title: title,
      onContinue: () => nextScreen(questionNumber + 1),
      isDarkMode: isDarkMode,
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildAnimatedWidget(
              delay: 100,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: value)
                        ..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
                      onChanged: onChanged,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 15, color: isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                        filled: false,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF0000), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0), width: 2),
                    ),
                    child: Row(
                      children: units.map((u) {
                        final isSelected = unit == u;
                        return GestureDetector(
                          onTap: () => onUnitChanged(u),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              u,
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : const Color(0xFF666666)),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildContinueButton(() => nextScreen(questionNumber + 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPickerScreen({
    required int questionNumber,
    required String title,
    required List<String> values,
    required String selectedValue,
    required ValueChanged<String> onChanged,
    required bool isDarkMode,
    List<String> units = const [],
    String unit = '',
    ValueChanged<String>? onUnitChanged,
  }) {
    final int curIndex = values.indexOf(selectedValue).clamp(0, values.length - 1);
    const double itemH = 52.0;

    void step(int delta) {
      final newIndex = (curIndex + delta).clamp(0, values.length - 1);
      if (newIndex != curIndex) onChanged(values[newIndex]);
    }

    // Build the 5-item static display (-2, -1, 0, +1, +2 around selected)
    Widget buildPickerItems() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final offset = i - 2; // -2 to +2
          final idx = curIndex + offset;
          final isCenter = offset == 0;
          if (idx < 0 || idx >= values.length) {
            return SizedBox(height: itemH);
          }
          return SizedBox(
            height: itemH,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: isCenter ? 30 : (offset.abs() == 1 ? 20 : 15),
                  fontWeight: isCenter ? FontWeight.bold : FontWeight.w400,
                  color: isCenter
                      ? (isDarkMode ? Colors.white : Colors.black)
                      : (isDarkMode
                          ? Colors.white.withOpacity(offset.abs() == 1 ? 0.45 : 0.2)
                          : Colors.black.withOpacity(offset.abs() == 1 ? 0.35 : 0.15)),
                ),
                child: Text(values[idx]),
              ),
            ),
          );
        }),
      );
    }

    // Track drag accumulator as a state in the parent (hack: use local var inside gesture)
    double dragAccum = 0;

    return _buildQuestionScreen(
      questionNumber: questionNumber,
      title: title,
      onContinue: () => nextScreen(questionNumber + 1),
      isDarkMode: isDarkMode,
      content: Column(
        children: [
          const SizedBox(height: 8),
          // Unit toggle (optional)
          if (units.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDarkMode ? Colors.white12 : const Color(0xFFE0E0E0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: units.map((u) {
                  final isSel = unit == u;
                  return GestureDetector(
                    onTap: () => onUnitChanged?.call(u),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFFF0000) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        u,
                        style: TextStyle(
                          color: isSel ? Colors.white : (isDarkMode ? Colors.white60 : Colors.grey),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Picker area
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                step(event.scrollDelta.dy > 0 ? 1 : -1);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) {
                dragAccum += d.delta.dy;
                // Snap every 52px of drag
                while (dragAccum <= -itemH) { dragAccum += itemH; step(1); }
                while (dragAccum >= itemH)  { dragAccum -= itemH; step(-1); }
              },
              onVerticalDragEnd: (_) { dragAccum = 0; },
              child: SizedBox(
                height: itemH * 5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Highlight band for center item
                    Container(
                      height: itemH,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Tap zones: top half = step(-1), bottom half = step(+1)
                    Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => step(-1),
                            behavior: HitTestBehavior.opaque,
                            child: const SizedBox.expand(),
                          ),
                        ),
                        SizedBox(height: itemH), // center item — no tap override
                        Expanded(
                          child: GestureDetector(
                            onTap: () => step(1),
                            behavior: HitTestBehavior.opaque,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                    // Items display
                    buildPickerItems(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildContinueButton(() => nextScreen(questionNumber + 1)),
        ],
      ),
    );
  }


  // --- Question Implementations ---


  Widget _buildGenderScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 1,
      title: "What's your gender?",
      options: ['Male', 'Female'],
      selectedValue: gender,
      onSelect: (val) => setState(() => gender = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildAgeScreen(bool isDarkMode) {
    final ages = List.generate(83, (i) => '${i + 13}'); // 13–95
    if (age.isEmpty) age = '25';
    return _buildNumberPickerScreen(
      questionNumber: 2,
      title: "How old are you?",
      values: ages,
      selectedValue: age,
      onChanged: (val) => setState(() => age = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildHeightScreen(bool isDarkMode) {
    final List<String> vals = heightUnit == 'cm'
        ? List.generate(121, (i) => '${i + 130} cm')
        : List.generate(36, (i) {
            final totalInches = i + 48;
            return "${totalInches ~/ 12}ft ${totalInches % 12}in";
          });
    if (height.isEmpty) height = heightUnit == 'cm' ? '175 cm' : '5ft 10in';
    return _buildNumberPickerScreen(
      questionNumber: 3,
      title: "What's your height?",
      values: vals,
      selectedValue: height,
      onChanged: (val) => setState(() => height = val),
      isDarkMode: isDarkMode,
      units: ['cm', 'ft'],
      unit: heightUnit,
      onUnitChanged: (u) => setState(() {
        // Remove old controller so a fresh one is created at the new default
        _pickerControllers.remove('3_$heightUnit')?.dispose();
        _pickerControllers.remove('3_$u')?.dispose();
        heightUnit = u;
        height = u == 'cm' ? '175 cm' : '5ft 10in';
      }),
    );
  }

  Widget _buildWeightScreen(bool isDarkMode) {
    final List<String> vals = weightUnit == 'kg'
        ? List.generate(171, (i) => '${i + 30} kg')
        : List.generate(331, (i) => '${i + 66} lbs');
    if (weight.isEmpty) weight = weightUnit == 'kg' ? '70 kg' : '155 lbs';
    return _buildNumberPickerScreen(
      questionNumber: 4,
      title: "What's your current weight?",
      values: vals,
      selectedValue: weight,
      onChanged: (val) => setState(() => weight = val),
      isDarkMode: isDarkMode,
      units: ['kg', 'lbs'],
      unit: weightUnit,
      onUnitChanged: (u) => setState(() {
        _pickerControllers.remove('4_$weightUnit')?.dispose();
        _pickerControllers.remove('4_$u')?.dispose();
        weightUnit = u;
        weight = u == 'kg' ? '70 kg' : '155 lbs';
      }),
    );
  }

  Widget _buildBodyTypeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 5,
      title: "What is your body type?",
      options: ['Ectomorph', 'Mesomorph', 'Endomorph'],
      selectedValue: bodyType,
      onSelect: (val) => setState(() => bodyType = val),
      isDarkMode: isDarkMode,
    );
  }



  Widget _buildActivityLevelScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 6,
      title: "What best describes your daily activity level (outside of workouts)?",
      options: [
        'Sedentary (mostly sitting, office work)',
        'Light (some walking or light movement)',
        'Moderate (active job or frequent movement)',
        'Very Active (physical labor or athlete)'
      ],
      selectedValue: activityLevel,
      onSelect: (val) => setState(() => activityLevel = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildGoalScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 7,
      title: "What's your main fitness goal?",
      options: ['Lose Fat', 'Build Muscle'],
      selectedValue: mainGoal,
      onSelect: (val) => setState(() => mainGoal = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildTargetWeightScreen(bool isDarkMode) {
    final List<String> vals = targetWeightUnit == 'kg'
        ? List.generate(171, (i) => '${i + 30} kg')
        : List.generate(331, (i) => '${i + 66} lbs');
    if (targetWeight.isEmpty) targetWeight = targetWeightUnit == 'kg' ? '65 kg' : '145 lbs';
    return _buildNumberPickerScreen(
      questionNumber: 8,
      title: "What is your target weight?",
      values: vals,
      selectedValue: targetWeight,
      onChanged: (val) => setState(() => targetWeight = val),
      isDarkMode: isDarkMode,
      units: ['kg', 'lbs'],
      unit: targetWeightUnit,
      onUnitChanged: (u) => setState(() {
        _pickerControllers.remove('8_$targetWeightUnit')?.dispose();
        _pickerControllers.remove('8_$u')?.dispose();
        targetWeightUnit = u;
        targetWeight = u == 'kg' ? '65 kg' : '145 lbs';
      }),
    );
  }

  Widget _buildPlanDurationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 9,
      title: "How long do you want this first plan to last?",
      options: ['2 Weeks (14 Days)', '3 Weeks (21 Days)', '4 Weeks (28 Days)', '12 Weeks (90 Days)'],
      selectedValue: planDuration,
      onSelect: (val) => setState(() => planDuration = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildExperienceScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 10,
      title: "What is your fitness experience?",
      options: ['Beginner', 'Intermediate', 'Advanced'],
      selectedValue: experience,
      onSelect: (val) => setState(() => experience = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildBodyAreasScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 11,
      title: "Which areas do you most want to improve?",
      options: ['Chest', 'Arms', 'Abs', 'Butt', 'Back', 'Legs', 'Shoulders', 'Full Body'],
      selectedValues: bodyAreas,
      onToggle: (val) => toggleOption(bodyAreas, val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWorkoutLocationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 12,
      title: "Where will you work out most often?",
      options: ['Home', 'Gym'],
      selectedValue: workoutLocation,
      onSelect: (val) => setState(() => workoutLocation = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildEquipmentScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 13,
      title: "Which equipment do you have access to?",
      options: ['Bodyweight', 'Dumbbells', 'Resistance Bands', 'Barbell', 'Kettlebells', 'Machines', 'Bench', 'Cable', 'Pull-Up Bar', 'Medicine Ball', 'All'],
      selectedValues: equipment,
      onToggle: (val) => toggleOption(equipment, val),
      isDarkMode: isDarkMode,
      columns: 2,
    );
  }

  Widget _buildTrainingDaysScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 14,
      title: "How many days per week can you train?",
      options: ['3 days', '4 days', '5 days', '6 days', '7 days'],
      selectedValue: trainingDays,
      onSelect: (val) => setState(() => trainingDays = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSessionDurationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 15,
      title: "How much time do you have per session?",
      options: ['20 min', '30 min', '45 min', '60 min', '90 min'],
      selectedValue: sessionDuration,
      onSelect: (val) => setState(() => sessionDuration = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWorkoutTimeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 16,
      title: "What time of day do you usually work out?",
      options: ['Morning', 'Afternoon', 'Evening', 'Flexible'],
      selectedValue: workoutTime,
      onSelect: (val) => setState(() => workoutTime = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildInjuriesScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 17,
      title: "Do you have any current injuries or pain?",
      options: ['Back', 'Knees', 'Shoulders', 'Hips', 'Neck', 'Elbows', 'Wrists', 'Ankles', 'None'],
      selectedValues: injuries,
      onToggle: (val) {
        if (val == 'None') {
          setState(() => injuries = ['None']);
        } else {
          if (injuries.contains('None')) injuries.remove('None');
          toggleOption(injuries, val);
        }
      },
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildHealthConditionsScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 18,
      title: "Do you have any health conditions we should consider?",
      options: ['Hypertension', 'Diabetes', 'Heart Condition', 'Joint Issues', 'None'],
      selectedValues: healthConditions,
      onToggle: (val) {
        if (val == 'None') {
          setState(() => healthConditions = ['None']);
        } else {
          if (healthConditions.contains('None')) healthConditions.remove('None');
          toggleOption(healthConditions, val);
        }
      },
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildDietTypeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 19,
      title: "What best describes your diet type?",
      options: ['No Preference', 'Vegetarian', 'Vegan', 'Pescatarian', 'Mediterranean', 'Keto', 'Low-Carb', 'Gluten-Free'],
      selectedValue: dietType,
      onSelect: (val) => setState(() => dietType = val),
      isDarkMode: isDarkMode,
    );
  }


  Widget _buildAllergiesScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 20,
      title: "Do you have any allergies?",
      options: ['None', 'Nuts', 'Dairy', 'Gluten', 'Eggs', 'Soy', 'Shellfish'],
      selectedValues: allergies,
      onToggle: (val) {
        if (val == 'None') {
          setState(() => allergies = ['None']);
        } else {
          if (allergies.contains('None')) allergies.remove('None');
          toggleOption(allergies, val);
        }
      },
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildMacroBalanceScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 21,
      title: "What macro balance fits you best?",
      options: ['Balanced', 'Higher Protein', 'Lower Carb', 'Higher Carb'],
      selectedValue: macroBalance,
      onSelect: (val) => setState(() => macroBalance = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSleepHoursScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 22,
      title: "How many hours do you sleep?",
      options: ['Less than 5', '5-6 hours', '7-8 hours', 'More than 8'],
      selectedValue: sleepHours,
      onSelect: (val) => setState(() => sleepHours = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSleepQualityScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 23,
      title: "How would you rate your sleep quality?",
      options: ['Poor', 'Fair', 'Good', 'Excellent'],
      selectedValue: sleepQuality,
      onSelect: (val) => setState(() => sleepQuality = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildStressLevelScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 24,
      title: "What's your current stress level?",
      options: ['Low', 'Moderate', 'High'],
      selectedValue: stressLevel,
      onSelect: (val) => setState(() => stressLevel = val),
      isDarkMode: isDarkMode,
    );
  }


  Widget _buildWaterIntakeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 25,
      title: "How much water do you usually drink per day?",
      options: ['Less than 1 liter (about 4 cups)', '1–2 liters (4–8 cups)', '2–3 liters (8–12 cups)', 'More than 3 liters (12+ cups)'],
      selectedValue: waterIntake,
      onSelect: (val) => setState(() => waterIntake = val),
      isDarkMode: isDarkMode,
    );
  }

  // --- Completion Screens ---

  // ── BMI helpers ──────────────────────────────────────────────────────────

  /// Parse weight/height from quiz state variables and compute BMI.
  double? _computeBmi() {
    try {
      // Parse weight in kg
      double? kg;
      final wMatch = RegExp(r'([\d.]+)').firstMatch(weight);
      if (wMatch == null) return null;
      final wVal = double.parse(wMatch.group(1)!);
      kg = weightUnit == 'lbs' ? wVal * 0.453592 : wVal;

      // Parse height in metres
      double? m;
      if (heightUnit == 'cm') {
        final hMatch = RegExp(r'([\d.]+)').firstMatch(height);
        if (hMatch == null) return null;
        m = double.parse(hMatch.group(1)!) / 100;
      } else {
        // e.g. "5ft 10in"
        final ftMatch = RegExp(r'(\d+)ft\s*(\d+)in').firstMatch(height);
        if (ftMatch == null) return null;
        final totalIn = int.parse(ftMatch.group(1)!) * 12 + int.parse(ftMatch.group(2)!);
        m = totalIn * 0.0254;
      }
      if (m == null || m <= 0) return null;
      return kg / (m * m);
    } catch (_) {
      return null;
    }
  }

  Widget _buildBmiWidget(bool isDarkMode) {
    final bmi = _computeBmi();
    if (bmi == null) return const SizedBox.shrink();

    // BMI range: 15 → 40 display
    const double minBmi = 15, maxBmi = 40;
    final double clampedBmi = bmi.clamp(minBmi, maxBmi);
    final double fraction = (clampedBmi - minBmi) / (maxBmi - minBmi);

    // Category
    String category;
    String description;
    Color catColor;
    String catIcon;
    if (bmi < 18.5) {
      category = 'Underweight';
      description = 'Focus on building lean muscle mass and increasing caloric intake.';
      catColor = const Color(0xFF5BC8F5);
      catIcon = '⚡';
    } else if (bmi < 25) {
      category = 'Healthy BMI';
      description = 'Good starting BMI to build muscle, lose fat and get your dream body.';
      catColor = const Color(0xFF27AE60);
      catIcon = '👌';
    } else if (bmi < 30) {
      category = 'Overweight';
      description = 'A fat-loss focused program will help you reach a healthier weight.';
      catColor = const Color(0xFFE67E22);
      catIcon = '🔥';
    } else {
      category = 'Obese';
      description = 'Starting with low-intensity cardio and diet changes will make a big difference.';
      catColor = const Color(0xFFE74C3C);
      catIcon = '💪';
    }

    return _buildAnimatedWidget(
      delay: 500,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? Colors.white12 : const Color(0xFFE8E8E8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Body-Mass-Index (BMI)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            // Gradient bar + pointer
            LayoutBuilder(
              builder: (ctx, bc) {
                final barWidth = bc.maxWidth;
                final pointerX = fraction * barWidth;
                return Column(
                  children: [
                    // Pointer label
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: (pointerX - 50).clamp(0, barWidth - 100),
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'You - ${bmi.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Gradient bar with pointer dot
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF5BC8F5), // underweight blue
                                Color(0xFF27AE60), // normal green
                                Color(0xFFF1C40F), // overweight yellow
                                Color(0xFFE74C3C), // obese red
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: (pointerX - 10).clamp(0, barWidth - 20),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Scale labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('15', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('18.5', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('25', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('30', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('40', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Underweight', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('Normal', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('Overweight', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('Obese', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // Category card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: catColor.withOpacity(isDarkMode ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: catColor.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(catIcon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF555555),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryScreen(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final double iconSize = isSmallScreen ? 40 : 60;
        final double titleSize = isSmallScreen ? 20 : 24;
        final double spacing = isSmallScreen ? 20 : 40;
        final double smallSpacing = isSmallScreen ? 10 : 15;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: spacing),
                    _buildAnimatedWidget(
                      delay: 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle, color: const Color(0xFFFF0000), size: iconSize),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildAnimatedWidget(
                      delay: 200,
                      child: Text(
                        'Profile Completed!',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    SizedBox(height: smallSpacing),
                    _buildAnimatedWidget(
                      delay: 400,
                      child: Text(
                        'We have gathered all the information needed to create your personalized plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── BMI Widget ────────────────────────────────────────
                    _buildBmiWidget(isDarkMode),
                    const SizedBox(height: 8),
                    _buildContinueButton(startPlanGeneration),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressScreen(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final double progressSize = isSmallScreen ? 100 : 150;
        final double percentageSize = isSmallScreen ? 24 : 32;
        final double spacing = isSmallScreen ? 20 : 40;
        final double smallSpacing = isSmallScreen ? 15 : 30;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: spacing),
                    SizedBox(
                      height: progressSize,
                      width: progressSize,
                      child: Stack(
                        children: [
                          Center(
                            child: SizedBox(
                              width: progressSize,
                              height: progressSize,
                              child: CircularProgressIndicator(
                                value: progressPercent / 100,
                                strokeWidth: isSmallScreen ? 8 : 12,
                                backgroundColor: const Color(0xFFE0E0E0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${progressPercent.toInt()}%',
                                  style: TextStyle(
                                    fontSize: percentageSize,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: smallSpacing),
                    Text(
                      progressStatus,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: spacing),
                    // Steps
                    _buildProgressStep('Analyzing Profile', currentStep >= 1, isDarkMode),
                    _buildProgressStep('Generating Workouts', currentStep >= 2, isDarkMode),
                    _buildProgressStep('Creating Meal Plan', currentStep >= 3, isDarkMode),
                    _buildProgressStep('Finalizing Program', currentStep >= 4, isDarkMode),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepItem(String text, int step) {
    bool isActive = currentStep == step;
    bool isComplete = currentStep > step;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFFFFE5E5) : (isActive ? const Color(0xFFFFF0F0) : const Color(0xFFF8F8F8)),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isComplete ? const Color(0xFFFF0000) : (isActive ? const Color(0xFFFF0000) : Colors.transparent),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            isComplete ? '✅' : '⏳',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 15),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String label, bool isCompleted, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? const Color(0xFFFF0000) : (isDarkMode ? Colors.grey : const Color(0xFFCCCCCC)),
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isCompleted 
                  ? (isDarkMode ? Colors.white : const Color(0xFF1A1A1A)) 
                  : (isDarkMode ? Colors.white54 : const Color(0xFF999999)),
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeScreen(bool isDarkMode) {
    // Calculate weekly price based on trial toggle
    String weeklyPrice = isTrialEnabled ? '\$2.99' : '\$1.99';
    String weeklyDescription = isTrialEnabled ? '/ week - 3-Day Free Trial Included' : '/ week';
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final isSmallScreen = screenHeight < 700;
        final isVerySmallScreen = screenHeight < 600;

        // Dynamic sizing
        final double iconSize = isVerySmallScreen ? 40 : (isSmallScreen ? 50 : 60);
        final double iconPadding = isVerySmallScreen ? 10 : (isSmallScreen ? 15 : 20);
        final double titleSize = isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24);
        final double featureSpacing = isVerySmallScreen ? 8 : 12;
        final double sectionSpacing = isVerySmallScreen ? 15 : (isSmallScreen ? 20 : 30);
        final double planSpacing = isVerySmallScreen ? 10 : 15;
        final double buttonVerticalPadding = isVerySmallScreen ? 14 : 18;

        return Column(
          children: [
            SizedBox(height: isVerySmallScreen ? 10 : 20),
            // Image/Icon
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '🏋️',
                style: TextStyle(fontSize: iconSize),
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 10 : 20),
            Text(
              'Unlock Premium Access',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 10 : 20),
            
            // Features
            _buildFeatureItem('📋 Personalized Workout Plans', fontSize: isVerySmallScreen ? 13 : 15, padding: featureSpacing),
            _buildFeatureItem('🍽️ Custom Meal Plans', fontSize: isVerySmallScreen ? 13 : 15, padding: featureSpacing),
            _buildFeatureItem('🔄 Unlimited Access to All Features', fontSize: isVerySmallScreen ? 13 : 15, padding: featureSpacing),
            
            SizedBox(height: sectionSpacing),
            
            // Plan Options - Scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Yearly Plan
                    _buildPlanOptionNew(
                      title: 'Yearly Plan',
                      price: '\$29.00',
                      period: '/ year',
                      badge: 'SAVE 85%',
                      isSelected: selectedPlan == 'yearly',
                      onTap: () => setState(() => selectedPlan = 'yearly'),
                      isDarkMode: isDarkMode,
                      padding: isVerySmallScreen ? 15 : 20,
                      compact: isVerySmallScreen,
                    ),
                    SizedBox(height: planSpacing),
                    
                    // Weekly Plan
                    _buildPlanOptionNew(
                      title: 'Weekly Plan',
                      price: weeklyPrice,
                      period: weeklyDescription,
                      badge: null,
                      isSelected: selectedPlan == 'weekly',
                      onTap: () => setState(() => selectedPlan = 'weekly'),
                      isDarkMode: isDarkMode,
                      padding: isVerySmallScreen ? 15 : 20,
                      compact: isVerySmallScreen,
                    ),
                    SizedBox(height: isVerySmallScreen ? 15 : 20),
                    
                    // Free Trial Toggle
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isVerySmallScreen ? 10 : 15),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Free Trial Enabled',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          Switch(
                            value: isTrialEnabled,
                            onChanged: (value) {
                              setState(() {
                                isTrialEnabled = value;
                              });
                            },
                            activeColor: const Color(0xFFFF0000),
                            activeTrackColor: const Color(0xFFFF9999),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: isVerySmallScreen ? 10 : 20),
            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: startPlanGeneration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: buttonVerticalPadding),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFFFF0000).withOpacity(0.4),
                ),
                child: Text(
                  isTrialEnabled ? 'Start Free Trial >' : 'Subscribe Now >',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureItem(String text, {double fontSize = 15, double padding = 12}) {
    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOptionNew({
    required String title,
    required String price,
    required String period,
    required String? badge,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
    double padding = 20,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF0000) : (isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0)),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFFF0000).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: compact ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: compact ? 12 : 13,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF0000) : (isDarkMode ? Colors.grey : const Color(0xFFCCCCCC)),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOption({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isPopular,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDarkMode ? const Color(0xFF2C2C2C) : Colors.white)
              : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFFFF0000).withOpacity(0.1) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            if (isPopular)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          period,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white54 : const Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFF0000) : (isDarkMode ? Colors.grey : const Color(0xFFCCCCCC)),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16, color: Color(0xFFFF0000)),
                  const SizedBox(width: 8),
                  Text(
                    feature,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}
