import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_page.dart';
import 'meal_plan_page.dart';
import '../widgets/gym_bottom_nav_bar.dart';

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
  String mealsPerDay = '';
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

  void startPlanGeneration() {
    nextScreen(32); // Progress Screen
    // Simulate progress
    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        progressPercent += 1;
        if (progressPercent < 25) {
          progressStatus = 'Analyzing your profile...';
          currentStep = 1;
        } else if (progressPercent < 50) {
          progressStatus = 'Generating workout plan...';
          currentStep = 2;
        } else if (progressPercent < 75) {
          progressStatus = 'Creating meal recommendations...';
          currentStep = 3;
        } else {
          progressStatus = 'Finalizing your program...';
          currentStep = 4;
        }

        if (progressPercent >= 100) {
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) nextScreen(33); // Upgrade Screen
          });
        }
      });
    });
  }

  Future<void> _onStartFreeTrial() async {
    final prefs = await SharedPreferences.getInstance();
    // Save both flags so user doesn't need to take quiz twice
    await prefs.setBool('has_workout_plan', true);
    await prefs.setBool('has_meal_plan', true);
    // Save plan duration for progress tracking
    await prefs.setString('plan_duration', planDuration);
    
    // Save unit preferences
    await prefs.setString('weight_unit', weightUnit); // 'kg' or 'lbs'
    await prefs.setString('height_unit', heightUnit); // 'cm' or 'ft'
    
    if (mounted) {
      // Pop with success result so MainScaffold knows quiz was completed
      Navigator.pop(context, {'completed': true});
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
      case 1: return _buildNameScreen(isDarkMode);
      case 2: return _buildGenderScreen(isDarkMode);
      case 3: return _buildAgeScreen(isDarkMode);
      case 4: return _buildHeightScreen(isDarkMode);
      case 5: return _buildWeightScreen(isDarkMode);
      case 6: return _buildBodyTypeScreen(isDarkMode);
      case 7: return _buildActivityLevelScreen(isDarkMode);
      case 8: return _buildGoalScreen(isDarkMode);
      case 9: return _buildTargetWeightScreen(isDarkMode);
      case 10: return _buildPlanDurationScreen(isDarkMode);
      case 11: return _buildExperienceScreen(isDarkMode);
      case 12: return _buildBodyAreasScreen(isDarkMode);
      case 13: return _buildWorkoutLocationScreen(isDarkMode);
      case 14: return _buildEquipmentScreen(isDarkMode);
      case 15: return _buildTrainingDaysScreen(isDarkMode);
      case 16: return _buildSessionDurationScreen(isDarkMode);
      case 17: return _buildWorkoutTimeScreen(isDarkMode);
      case 18: return _buildInjuriesScreen(isDarkMode);
      case 19: return _buildHealthConditionsScreen(isDarkMode);
      case 20: return _buildDietTypeScreen(isDarkMode);
      case 21: return _buildExcludeFoodsScreen(isDarkMode);
      case 22: return _buildAllergiesScreen(isDarkMode);
      case 23: return _buildMealsPerDayScreen(isDarkMode);
      case 24: return _buildMacroBalanceScreen(isDarkMode);
      case 25: return _buildSleepHoursScreen(isDarkMode);
      case 26: return _buildSleepQualityScreen(isDarkMode);
      case 27: return _buildStressLevelScreen(isDarkMode);
      case 28: return _buildWorkTypeScreen(isDarkMode);
      case 29: return _buildAvoidMovementsScreen(isDarkMode);
      case 30: return _buildWaterIntakeScreen(isDarkMode);
      case 31: return _buildSummaryScreen(isDarkMode);
      case 32: return _buildProgressScreen(isDarkMode);
      case 33: return _buildUpgradeScreen(isDarkMode);
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
                            onPressed: () => nextScreen(1),
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
    double progress = (questionNumber / 30).clamp(0.0, 1.0);
    return Column(
      children: [
        _buildAnimatedWidget(
          delay: 0,
          slideUp: false,
          child: Text(
            'Question $questionNumber of 30',
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
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

  // --- Question Implementations ---

  Widget _buildNameScreen(bool isDarkMode) {
    return _buildInputScreen(
      questionNumber: 1,
      title: "What's your name?",
      placeholder: "Enter your name",
      value: name,
      onChanged: (val) => setState(() => name = val),
      onContinue: () => nextScreen(2),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildGenderScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 2,
      title: "What's your gender?",
      options: ['Male', 'Female'],
      selectedValue: gender,
      onSelect: (val) => setState(() => gender = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildAgeScreen(bool isDarkMode) {
    return _buildInputScreen(
      questionNumber: 3,
      title: "How old are you?",
      placeholder: "Age",
      value: age,
      onChanged: (val) => setState(() => age = val),
      onContinue: () => nextScreen(4),
      keyboardType: TextInputType.number,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildHeightScreen(bool isDarkMode) {
    return _buildUnitInputScreen(
      questionNumber: 4,
      title: "What's your height?",
      placeholder: "Height",
      value: height,
      unit: heightUnit,
      units: ['cm', 'ft'],
      onChanged: (val) => setState(() => height = val),
      onUnitChanged: (val) => setState(() => heightUnit = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWeightScreen(bool isDarkMode) {
    return _buildUnitInputScreen(
      questionNumber: 5,
      title: "What's your current weight?",
      placeholder: "Weight",
      value: weight,
      unit: weightUnit,
      units: ['kg', 'lbs'],
      onChanged: (val) => setState(() => weight = val),
      onUnitChanged: (val) => setState(() => weightUnit = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildBodyTypeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 6,
      title: "What is your body type?",
      options: ['Ectomorph', 'Mesomorph', 'Endomorph'],
      selectedValue: bodyType,
      onSelect: (val) => setState(() => bodyType = val),
      isDarkMode: isDarkMode,
    );
  }



  Widget _buildActivityLevelScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 7,
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
      questionNumber: 8,
      title: "What's your main fitness goal?",
      options: ['Lose Weight / Fat Loss', 'Build Muscle', 'Get Stronger', 'Improve Fitness (Cardio)', 'Improve Flexibility & Mobility', 'Maintain Weight'],
      selectedValue: mainGoal,
      onSelect: (val) => setState(() => mainGoal = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildTargetWeightScreen(bool isDarkMode) {
    return _buildUnitInputScreen(
      questionNumber: 9,
      title: "What is your target weight?",
      placeholder: "Target Weight",
      value: targetWeight,
      unit: targetWeightUnit,
      units: ['kg', 'lbs'],
      onChanged: (val) => setState(() => targetWeight = val),
      onUnitChanged: (val) => setState(() => targetWeightUnit = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildPlanDurationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 10,
      title: "How long do you want this first plan to last?",
      options: ['2 Weeks (14 Days)', '3 Weeks (21 Days)', '4 Weeks (28 Days)', '12 Weeks (90 Days)'],
      selectedValue: planDuration,
      onSelect: (val) => setState(() => planDuration = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildExperienceScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 11,
      title: "What is your fitness experience?",
      options: ['Beginner', 'Intermediate', 'Advanced'],
      selectedValue: experience,
      onSelect: (val) => setState(() => experience = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildBodyAreasScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 12,
      title: "Which areas do you most want to improve?",
      options: ['Chest', 'Arms', 'Abs', 'Butt', 'Back', 'Legs', 'Shoulders', 'Full Body'],
      selectedValues: bodyAreas,
      onToggle: (val) => toggleOption(bodyAreas, val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWorkoutLocationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 13,
      title: "Where will you work out most often?",
      options: ['Home', 'Gym', 'Outdoors', 'Mixed'],
      selectedValue: workoutLocation,
      onSelect: (val) => setState(() => workoutLocation = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildEquipmentScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 14,
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
      questionNumber: 15,
      title: "How many days per week can you train?",
      options: ['1 day', '2 days', '3 days', '4 days', '5 days', '6 days', '7 days'],
      selectedValue: trainingDays,
      onSelect: (val) => setState(() => trainingDays = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSessionDurationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 16,
      title: "How much time do you have per session?",
      options: ['15 min', '20 min', '30 min', '45 min', '60 min', '90 min'],
      selectedValue: sessionDuration,
      onSelect: (val) => setState(() => sessionDuration = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWorkoutTimeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 17,
      title: "What time of day do you usually work out?",
      options: ['Morning', 'Afternoon', 'Evening', 'Flexible'],
      selectedValue: workoutTime,
      onSelect: (val) => setState(() => workoutTime = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildInjuriesScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 18,
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
      questionNumber: 19,
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
      questionNumber: 20,
      title: "What best describes your diet type?",
      options: ['No Preference', 'Vegetarian', 'Vegan', 'Pescatarian', 'Mediterranean', 'Keto', 'Low-Carb', 'Gluten-Free'],
      selectedValue: dietType,
      onSelect: (val) => setState(() => dietType = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildExcludeFoodsScreen(bool isDarkMode) {
    return _buildInputScreen(
      questionNumber: 21,
      title: "Any foods you want to exclude?",
      placeholder: "E.g. Mushrooms, Olives",
      value: excludeFoods,
      onChanged: (val) => setState(() => excludeFoods = val),
      onContinue: () => nextScreen(22),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildAllergiesScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 22,
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

  Widget _buildMealsPerDayScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 23,
      title: "How many meals do you prefer per day?",
      options: ['2 meals', '3 meals', '4 meals', '5 meals'],
      selectedValue: mealsPerDay,
      onSelect: (val) => setState(() => mealsPerDay = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildMacroBalanceScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 24,
      title: "What macro balance fits you best?",
      options: ['Balanced', 'Higher Protein', 'Lower Carb', 'Higher Carb'],
      selectedValue: macroBalance,
      onSelect: (val) => setState(() => macroBalance = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSleepHoursScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 25,
      title: "How many hours do you sleep?",
      options: ['Less than 5', '5-6 hours', '7-8 hours', 'More than 8'],
      selectedValue: sleepHours,
      onSelect: (val) => setState(() => sleepHours = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSleepQualityScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 26,
      title: "How would you rate your sleep quality?",
      options: ['Poor', 'Fair', 'Good', 'Excellent'],
      selectedValue: sleepQuality,
      onSelect: (val) => setState(() => sleepQuality = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildStressLevelScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 27,
      title: "What's your current stress level?",
      options: ['Low', 'Moderate', 'High'],
      selectedValue: stressLevel,
      onSelect: (val) => setState(() => stressLevel = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWorkTypeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 28,
      title: "What's your work type?",
      options: ['Desk Job', 'Active Job', 'Mixed'],
      selectedValue: workType,
      onSelect: (val) => setState(() => workType = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildAvoidMovementsScreen(bool isDarkMode) {
    return _buildInputScreen(
      questionNumber: 29,
      title: "Any movements to avoid?",
      placeholder: "E.g. Squats, Jumping",
      value: avoidMovements,
      onChanged: (val) => setState(() => avoidMovements = val),
      onContinue: () => nextScreen(30),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWaterIntakeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 30,
      title: "How much water do you usually drink per day?",
      options: ['Less than 1 liter (about 4 cups)', '1–2 liters (4–8 cups)', '2–3 liters (8–12 cups)', 'More than 3 liters (12+ cups)'],
      selectedValue: waterIntake,
      onSelect: (val) => setState(() => waterIntake = val),
      isDarkMode: isDarkMode,
    );
  }

  // --- Completion Screens ---

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
                    SizedBox(height: spacing),
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
                onPressed: _onStartFreeTrial,
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
