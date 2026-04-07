import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' show pi, cos, sin;
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
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/revenue_cat_service.dart';
import '../services/analytics_service.dart';

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
  String activityLevel = '';
  String mainGoal = '';
  String targetWeight = '';
  String targetWeightUnit = 'kg';
  String planDuration = '';
  String experience = '';
  String workoutLocation = '';
  List<String> equipment = ['All'];
  String trainingDays = '';
  String sessionDuration = '';
  String workoutTime = '';
  List<String> injuries = ['None'];

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
  // Trial toggle removed

  // Intro progress animation state
  bool _isIntroProgress = false;
  bool _introComplete = false;
  Timer? _introTimer;
  bool _isGenerating = false;

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
    _introTimer?.cancel();
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

  /// Presents the RevenueCat paywall on iOS/Android.
  /// Returns [true] ONLY when the user successfully purchases or restores.
  /// Returns [false] on cancel, dismiss, error, or unavailable store.
  /// On Web, always returns [true] so development flow continues.
  Future<bool> _presentRevenueCatPaywall() async {
    if (kIsWeb) return true;

    // First check if user is already subscribed — skip paywall if so.
    final alreadyPro = await RevenueCatService().isProUser();
    if (alreadyPro) {
      debugPrint('[RevenueCat] User already has premium — skipping paywall.');
      return true;
    }

    try {
      AnalyticsService().trackPaywallViewed(source: 'quiz_completion');
      
      final result = await RevenueCatService().showPaywall();
      debugPrint('[RevenueCat] Paywall result: $result');

      if (result == null) {
        // Store unavailable (emulator / billing not configured).
        // Do NOT bypass — treat as cancelled so the user cannot access plans.
        debugPrint('[RevenueCat] Store unavailable — denying access.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription required. Please try again later.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // Track successful purchase
      if (result == PaywallResult.purchased) {
          final customerInfo = await RevenueCatService().getCustomerInfo();
          String planId = 'unknown';
          if (customerInfo != null && customerInfo.entitlements.active.containsKey('premium')) {
             planId = customerInfo.entitlements.active['premium']!.productIdentifier;
          }
          AnalyticsService().trackPurchaseSuccess(plan: planId);
      }

      // Only grant access on explicit purchase or restore.
      return result == PaywallResult.purchased || result == PaywallResult.restored;
    } catch (e) {
      debugPrint('[RevenueCat] presentPaywall error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _startRealGenerationFlow() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _isIntroProgress = true;
      _introComplete = false;
    });

    final supabaseService = SupabaseService();
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

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
        'meals_per_day': 4,
        'diet_type': dietType,
        'allergies': allergies,
      };
      final normalized = quizService.normalizeQuizAnswers(answersJson: answersJson);

      if (!mounted) return;
      setState(() {
        progressStatus = 'Preparing your preferences...';
        progressPercent = 15;
        currentStep = 1;
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
      double? hNum;
      if (heightUnit == 'ft') {
        final ftMatch = RegExp(r'(\d+)ft').firstMatch(height);
        final inMatch = RegExp(r'(\d+)in').firstMatch(height);
        if (ftMatch != null && inMatch != null) {
          final feet = int.parse(ftMatch.group(1)!);
          final inches = int.parse(inMatch.group(1)!);
          final totalInches = (feet * 12) + inches;
          hNum = totalInches * 2.54;
        }
      } else {
        hNum = double.tryParse(height.replaceAll(RegExp(r'[^\d.]'), ''));
      }
      double? wNum = double.tryParse(weight.replaceAll(RegExp(r'[^\d.]'), ''));
      if (wNum != null && weightUnit == 'lbs') {
        wNum = wNum * 0.453592;
      }

      final int? aNum = int.tryParse(age.replaceAll(RegExp(r'[^\d.]'), ''));
      
      double? tWNum = double.tryParse(targetWeight.replaceAll(RegExp(r'[^\d.]'), ''));
      if (tWNum != null && targetWeightUnit == 'lbs') {
        tWNum = tWNum * 0.453592;
      }

      await supabaseService.saveUserPreferences(
        mainGoal: mainGoal,
        dietType: dietType,
        allergies: allergies,
        durationWeeks: durationWeeks,
        trainingLocation: normalized['training_location'],
        gender: normalized['gender'],
        trainingDays: normalized['training_days'],
        height: hNum,
        weight: wNum,
        age: aNum,
        targetWeight: tWNum,
      );

      if (!mounted) return;
      setState(() {
        progressStatus = 'Organizing workouts...';
        progressPercent = 45;
        currentStep = 2;
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
        progressStatus = 'Creating your schedule...';
        progressPercent = 80;
        currentStep = 3;
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
      // Mark quiz as completed so subscription guards activate on later visits.
      await prefs.setBool('hasCompletedQuiz', true);

      final userId = supabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        await prefs.remove('meal_plan_cache_$userId');
      }

      if (mounted) {
        AnalyticsService().trackQuizCompleted();
        setState(() {
          progressPercent = 100;
          progressStatus = 'Setup complete!';
          _introComplete = true; // Important: Make the button appear
          _isGenerating = false;
        });
      }
    } catch (e) {
      print('ERROR in plan generation: $e');
      debugPrint('[QUIZ ERROR] Plan generation failed: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _introComplete = true; // Let them hit the button anyway
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Block back navigation on intro progress screen (27) and paywall (28)
    final bool isLocked = (currentScreen == 25 && _isIntroProgress);

    return PopScope(
      canPop: !isLocked,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
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
                      color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
                      padding: const EdgeInsets.all(20),
                      child: _buildCurrentScreen(isDarkMode),
                    ),
                  ),
                ),
              ),

            ],
          ),
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
      ),
    );
  }



  Widget _buildCurrentScreen(bool isDarkMode) {
    switch (currentScreen) {
      case 0: return _buildWelcomeScreen();
      case 1: return _buildGenderScreen(isDarkMode);
      case 2: return _buildAgeScreen(isDarkMode);
      case 3: return _buildHeightScreen(isDarkMode);
      case 4: return _buildWeightScreen(isDarkMode);
      case 5: return _buildActivityLevelScreen(isDarkMode);
      case 6: return _buildGoalScreen(isDarkMode);
      case 7: return _buildTargetWeightScreen(isDarkMode);
      case 8: return _buildPlanDurationScreen(isDarkMode);
      case 9: return _buildExperienceScreen(isDarkMode);
      case 10: return _buildWorkoutLocationScreen(isDarkMode);
      case 11: return _buildEquipmentScreen(isDarkMode);
      case 12: return _buildTrainingDaysScreen(isDarkMode);
      case 13: return _buildSessionDurationScreen(isDarkMode);
      case 14: return _buildWorkoutTimeScreen(isDarkMode);
      case 15: return _buildInjuriesScreen(isDarkMode);
      case 16: return _buildDietTypeScreen(isDarkMode);
      case 17: return _buildAllergiesScreen(isDarkMode);
      case 18: return _buildMacroBalanceScreen(isDarkMode);
      case 19: return _buildSleepHoursScreen(isDarkMode);
      case 20: return _buildSleepQualityScreen(isDarkMode);
      case 21: return _buildStressLevelScreen(isDarkMode);
      case 22: return _buildWaterIntakeScreen(isDarkMode);
      case 23: return _buildMedicalDisclaimerScreen(isDarkMode);
      case 24: return _buildSummaryScreen(isDarkMode);
      case 25: return _buildProgressScreen(isDarkMode);
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
                          'Start Your Program Now.',
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
                          'A simple, flexible plan to help you move better, eat smarter, and stay consistent.',
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
                            horizontal: 24,
                            vertical: isVerySmallScreen ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/svg/mealsicons/iconfire.png', width: badgeSize + 6, height: badgeSize + 6),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Effective workouts',
                                    style: TextStyle(
                                      fontSize: badgeSize,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/svg/mealsicons/iconmeal.png', width: badgeSize + 6, height: badgeSize + 6),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Flexible meal ideas',
                                    style: TextStyle(
                                      fontSize: badgeSize,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/svg/mealsicons/iconprogress.png', width: badgeSize + 6, height: badgeSize + 6),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Easy progress tracking',
                                    style: TextStyle(
                                      fontSize: badgeSize,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final supabaseService = SupabaseService();
                              var user = supabaseService.client.auth.currentUser;
                              bool justSignedIn = false;
                              if (user == null) {
                                await AuthModal.show(context);
                                user = supabaseService.client.auth.currentUser;
                                if (user == null) return; // still not signed in
                                justSignedIn = true;
                              }
                              
                              if (justSignedIn) {
                                // Double check if this existing user already has a profile!
                                try {
                                  final response = await supabaseService.client
                                      .from('user_preferences')
                                      .select('user_id')
                                      .eq('user_id', user.id)
                                      .maybeSingle();
                                      
                                  if (response != null && mounted) {
                                    // They ALREADY have a profile/plan. Close the quiz and load it!
                                    // the MainScaffold auth listener will handle refreshing the UI.
                                    Navigator.pop(context, {'completed': true, 'navIndex': widget.quizType == 'workout' ? 1 : 2});
                                    return;
                                  }
                                } catch (_) {}
                              }
                              
                              AnalyticsService().trackQuizStarted();
                              nextScreen(1);
                            },
                            style: ElevatedButton.styleFrom(
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
                              "GET STARTED",
                              style: TextStyle(
                                fontSize: buttonSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: spacing),
                        Text(
                          'No strict rules. No pressure.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: Colors.white.withOpacity(0.8),
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
    double progress = (questionNumber / 23).clamp(0.0, 1.0);
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
    String? subtitle,
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
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  _buildAnimatedWidget(
                    delay: 150,
                    slideUp: false,
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
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

  Widget _buildContinueButton(VoidCallback onPressed, {bool enabled = true, String text = 'CONTINUE'}) {
    return _buildAnimatedWidget(
      delay: 600,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 15),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? const Color(0xFFFF0000) : Colors.grey.shade400,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            disabledForegroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: enabled ? 4 : 0,
            shadowColor: const Color(0xFFFF0000).withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_arrow, size: 16),
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
    String? subtitle,
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
      subtitle: subtitle,
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
    String? subtitle,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelect,
    required bool isDarkMode,
  }) {
    final bool hasSelection = selectedValue.isNotEmpty;
    return _buildQuestionScreen(
      questionNumber: questionNumber,
      title: title,
      subtitle: subtitle,
      onContinue: hasSelection ? () => nextScreen(questionNumber + 1) : () {},
      isDarkMode: isDarkMode,
      content: ListView.builder(
        itemCount: options.length + 1, // +1 for continue button
        itemBuilder: (context, index) {
          if (index == options.length) {
            return _buildContinueButton(
              () => nextScreen(questionNumber + 1),
              enabled: hasSelection,
            );
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
    String? subtitle,
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
      subtitle: subtitle,
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
    String? subtitle,
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
      subtitle: subtitle,
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
    String? subtitle,
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
      subtitle: subtitle,
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
      subtitle: "Used to estimate general recommendations.",
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
      subtitle: "Used for general calculations.",
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
      subtitle: "This helps us estimate general daily needs.",
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

  Widget _buildActivityLevelScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 5,
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
      questionNumber: 6,
      title: "What's your main fitness goal?",
      options: ['Lose Fat & Stay Lean', 'Build Muscle & Gain Strength'],
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
      questionNumber: 7,
      title: "Do you have a goal in mind? (optional)",
      subtitle: "This is only used to track your progress.",
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
      questionNumber: 8,
      title: "How long do you want this first plan to last?",
      options: ['2 Weeks (14 Days)', '3 Weeks (21 Days)', '4 Weeks (28 Days)', '12 Weeks (90 Days)'],
      selectedValue: planDuration,
      onSelect: (val) => setState(() => planDuration = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildExperienceScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 9,
      title: "What is your fitness experience?",
      options: ['Beginner', 'Intermediate', 'Advanced'],
      selectedValue: experience,
      onSelect: (val) => setState(() => experience = val),
      isDarkMode: isDarkMode,
    );
  }


  Widget _buildWorkoutLocationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 10,
      title: "Where will you work out most often?",
      options: ['Home', 'Gym'],
      selectedValue: workoutLocation,
      onSelect: (val) => setState(() => workoutLocation = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildEquipmentScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 11,
      title: "Which equipment do you have access to?",
      options: ['Bodyweight', 'Dumbbells', 'Resistance Bands', 'Barbell', 'Kettlebells', 'Machines', 'All'],
      selectedValues: equipment,
      onToggle: (val) => toggleOption(equipment, val),
      isDarkMode: isDarkMode,
      columns: 2,
    );
  }

  Widget _buildTrainingDaysScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 12,
      title: "How many days per week can you train?",
      options: ['3 days', '4 days', '5 days', '6 days', '7 days'],
      selectedValue: trainingDays,
      onSelect: (val) => setState(() => trainingDays = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSessionDurationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 13,
      title: "How much time do you have per session?",
      options: ['20 min', '30 min', '45 min', '60 min', '90 min'],
      selectedValue: sessionDuration,
      onSelect: (val) => setState(() => sessionDuration = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildWorkoutTimeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 14,
      title: "What time of day do you usually work out?",
      options: ['Morning', 'Afternoon', 'Evening', 'Flexible'],
      selectedValue: workoutTime,
      onSelect: (val) => setState(() => workoutTime = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildInjuriesScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 15,
      title: "Do you have any areas that feel uncomfortable during exercise?",
      subtitle: "We'll keep your plan flexible and easy to adjust.",
      options: ['None', 'Back', 'Knees', 'Shoulders', 'Hips', 'Neck', 'Elbows', 'Wrists', 'Ankles'],
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

  Widget _buildDietTypeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 16,
      title: "What best describes your diet type?",
      subtitle: "This helps us suggest meals you may enjoy.",
      options: ['No Preference', 'Vegetarian', 'Vegan', 'Pescatarian', 'Mediterranean', 'Keto', 'Low-Carb', 'Gluten-Free'],
      selectedValue: dietType,
      onSelect: (val) => setState(() => dietType = val),
      isDarkMode: isDarkMode,
    );
  }


  Widget _buildAllergiesScreen(bool isDarkMode) {
    return _buildMultiSelectionScreen(
      questionNumber: 17,
      title: "Any ingredients we should exclude?",
      subtitle: "This helps filter recipe suggestions.",
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
      questionNumber: 18,
      title: "What macro balance fits you best?",
      options: ['Balanced', 'Higher Protein', 'Lower Carb', 'Higher Carb'],
      selectedValue: macroBalance,
      onSelect: (val) => setState(() => macroBalance = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSleepHoursScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 19,
      title: "How many hours do you sleep?",
      subtitle: "Sleep plays a big role in fitness recovery.",
      options: ['Less than 5', '5-6 hours', '7-8 hours', 'More than 8'],
      selectedValue: sleepHours,
      onSelect: (val) => setState(() => sleepHours = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSleepQualityScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 20,
      title: "How would you rate your sleep quality?",
      options: ['Poor', 'Fair', 'Good', 'Excellent'],
      selectedValue: sleepQuality,
      onSelect: (val) => setState(() => sleepQuality = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildStressLevelScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 21,
      title: "What's your current lifestyle stress level?",
      subtitle: "Used to suggest appropriate recovery times.",
      options: ['Low', 'Moderate', 'High'],
      selectedValue: stressLevel,
      onSelect: (val) => setState(() => stressLevel = val),
      isDarkMode: isDarkMode,
    );
  }


  Widget _buildWaterIntakeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 22,
      title: "How much water do you usually drink per day?",
      subtitle: "We'll suggest a general daily hydration goal.",
      options: ['Less than 1 liter (about 4 cups)', '1–2 liters (4–8 cups)', '2–3 liters (8–12 cups)', 'More than 3 liters (12+ cups)'],
      selectedValue: waterIntake,
      onSelect: (val) => setState(() => waterIntake = val),
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildMedicalDisclaimerScreen(bool isDarkMode) {
    return Column(
      children: [
        _buildProgressBar(23),
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
                    "Before we continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildAnimatedWidget(
                  delay: 150,
                  slideUp: false,
                  child: Text(
                    "This app provides general fitness and nutrition guidance. It is not medical advice.\n\nAlways consult a qualified professional before making major changes to your diet or exercise routine.",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                _buildContinueButton(() => nextScreen(24), text: 'I UNDERSTAND'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Completion Screens ---

  // ── BMI helpers ──────────────────────────────────────────────────────────

  /// Parse weight/height from quiz state variables and compute BMI.
  double? _computeBmi() {
    try {
      // ── Parse weight in kg (read unit from the string itself) ──
      double? kg;
      final wMatch = RegExp(r'([\d.]+)').firstMatch(weight);
      if (wMatch == null) return null;
      final wVal = double.parse(wMatch.group(1)!);
      // Determine unit from the embedded string, fall back to state var
      final isLbs = weight.toLowerCase().contains('lb');
      kg = isLbs ? wVal * 0.453592 : wVal;

      // ── Parse height in metres (read unit from the string itself) ──
      double? m;
      // Try ft/in format first (e.g. "5ft 10in")
      final ftMatch = RegExp(r'(\d+)ft\s*(\d+)in').firstMatch(height);
      if (ftMatch != null) {
        final totalIn = int.parse(ftMatch.group(1)!) * 12 + int.parse(ftMatch.group(2)!);
        m = totalIn * 0.0254;
      } else {
        // Assume cm (e.g. "175 cm")
        final hMatch = RegExp(r'([\d.]+)').firstMatch(height);
        if (hMatch == null) return null;
        m = double.parse(hMatch.group(1)!) / 100;
      }
      if (m == null || m <= 0) return null;
      return kg / (m * m);
    } catch (_) {
      return null;
    }
  }

  Widget _buildBmiWidget(bool isDarkMode, {bool compact = false, bool veryCompact = false}) {
    final bmi = _computeBmi();
    if (bmi == null) return const SizedBox.shrink();

    // BMI range: 15 → 40 display
    const double minBmi = 15, maxBmi = 40;
    final double clampedBmi = bmi.clamp(minBmi, maxBmi);
    final double fraction = (clampedBmi - minBmi) / (maxBmi - minBmi);

    // Responsive sizes
    final double gaugeHeight = veryCompact ? 120 : (compact ? 145 : 190);
    final double containerPadding = veryCompact ? 12 : (compact ? 16 : 20);
    final double descFontSize = veryCompact ? 12 : 13;
    final double afterGaugeSpacing = veryCompact ? 6 : (compact ? 10 : 16);
    final double descVertPadding = veryCompact ? 10 : 14;

    // Category
    Color catColor;
    if (bmi < 18.5) {
      catColor = const Color(0xFF5BC8F5);
    } else if (bmi < 25) {
      catColor = const Color(0xFF27AE60);
    } else if (bmi < 30) {
      catColor = const Color(0xFFE67E22);
    } else {
      catColor = const Color(0xFFE74C3C);
    }

    return _buildAnimatedWidget(
      delay: 500,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: veryCompact ? 6 : 10),
        padding: EdgeInsets.all(containerPadding),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? Colors.white12 : const Color(0xFFE8E8E8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Body-Mass-Index (BMI)',
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: veryCompact ? 4 : 8),
            // ── Semicircle gauge ──────────────────────────────────────
            AspectRatio(
              aspectRatio: 2.0,
              child: CustomPaint(
                painter: BmiGaugePainter(
                  fraction: fraction,
                  bmi: bmi,
                  catColor: catColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ),
            SizedBox(height: afterGaugeSpacing),
            // ── Compliance text ─────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDarkMode ? Colors.white24 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Your BMI estimate: ${bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This is a general reference and not a medical assessment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: descFontSize,
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
    );
  }

  Widget _buildSummaryScreen(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final isVerySmallScreen = constraints.maxHeight < 600;
        final double iconSize = isVerySmallScreen ? 32 : (isSmallScreen ? 44 : 60);
        final double iconPadding = isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20);
        final double titleSize = isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24);
        final double subtitleSize = isVerySmallScreen ? 13 : (isSmallScreen ? 14 : 16);
        final double topSpacing = isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 32);
        final double afterIconSpacing = isVerySmallScreen ? 10 : (isSmallScreen ? 16 : 24);
        final double smallSpacing = isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12);
        final double afterSubtitleSpacing = isVerySmallScreen ? 10 : (isSmallScreen ? 14 : 20);

        return Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: isVerySmallScreen ? 8 : 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: topSpacing),
                    _buildAnimatedWidget(
                      delay: 0,
                      child: Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle, color: const Color(0xFFFF0000), size: iconSize),
                      ),
                    ),
                    SizedBox(height: afterIconSpacing),
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
                          fontSize: subtitleSize,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: afterSubtitleSpacing),
                    // ── BMI Widget ────────────────────────────────────────
                    _buildBmiWidget(isDarkMode, compact: isSmallScreen, veryCompact: isVerySmallScreen),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
              child: _buildContinueButton(() async {
                // 1. Auth check before we start loading UI
                final supabaseService = SupabaseService();
                var user = supabaseService.client.auth.currentUser;
                if (user == null) {
                  await AuthModal.show(context);
                  user = supabaseService.client.auth.currentUser;
                  if (user == null) return; // aborted login
                }

                if (!mounted) return;
                setState(() {
                  _isIntroProgress = true;
                  _introComplete = false;
                  progressPercent = 0;
                });
                nextScreen(25);
                
                // Real layout executes plan concurrently with the UI steps!
                await _startRealGenerationFlow();
              }),
            ),
          ],
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
    // ── INTRO mode (fake 7-second animation before paywall) ──────────────────
    if (_isIntroProgress) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxHeight < 700;
          final double progressSize = isSmallScreen ? 100 : 150;
          final double percentageSize = isSmallScreen ? 24 : 32;
          final double spacing = isSmallScreen ? 20 : 40;
          final double smallSpacing = isSmallScreen ? 15 : 30;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                              child: Text(
                                '${progressPercent.toInt()}%',
                                style: TextStyle(
                                  fontSize: percentageSize,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                ),
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
                      _buildProgressStep('Preparing your preferences', currentStep >= 1, isDarkMode),
                      _buildProgressStep('Organizing workouts', currentStep >= 2, isDarkMode),
                      _buildProgressStep('Creating your schedule', currentStep >= 3, isDarkMode),
                      const SizedBox(height: 32),
                      // Button appears only when animation completes
                      AnimatedOpacity(
                        opacity: _introComplete ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: _introComplete
                            ? SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isGenerating ? null : () async {
                                    final purchased = await _presentRevenueCatPaywall();
                                    if (!mounted) return;
                                    if (purchased) {
                                      // Subscription confirmed — persist flag and go to plans.
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('hasCompletedQuiz', true);
                                      if (!mounted) return;
                                      Navigator.pop(context, {
                                        'completed': true,
                                        'navIndex': 1, // Workout tab
                                      });
                                    } else {
                                      // User dismissed paywall — hard gate: send to Home.
                                      if (!mounted) return;
                                      Navigator.pop(context, {
                                        'completed': false,
                                        'navIndex': 0, // Home tab
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF0000),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 5,
                                    shadowColor: const Color(0xFFFF0000).withOpacity(0.4),
                                  ),
                                  child: _isGenerating
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Start My Program',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              )
                            : const SizedBox(height: 56),
                      ),
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

    // ── REAL generation mode ─────────────────────────────────────────────────
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
                    Icon(
                      Icons.cloud_sync_outlined,
                      size: isSmallScreen ? 80 : 100,
                      color: const Color(0xFFFF0000),
                    ),
                    SizedBox(height: smallSpacing + 10),
                    Text(
                      progressStatus,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Removed duplicate progress steps from REAL loading mode to avoid confusing users
                    const SizedBox(height: 10),
                    const CircularProgressIndicator(
                       color: Color(0xFFFF0000),
                    ),
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
}

// ── BMI Gauge Painter ─────────────────────────────────────────────────────────
/// Draws a semicircle BMI gauge with coloured arc segments and a needle pointer.
class BmiGaugePainter extends CustomPainter {
  final double fraction;   // 0..1 position on the gauge
  final double bmi;        // raw BMI value for the centre label
  final Color catColor;    // colour of the active category
  final bool isDarkMode;

  BmiGaugePainter({
    required this.fraction,
    required this.bmi,
    required this.catColor,
    required this.isDarkMode,
  });

  // BMI zone colours (left → right on arc)
  static const List<Color> _zoneColors = [
    Color(0xFF4FC3F7), // Underweight  (15–18.5)
    Color(0xFF29B6F6), // Underweight  (transition)
    Color(0xFF66BB6A), // Normal       (18.5–25)
    Color(0xFF43A047), // Normal
    Color(0xFFFFCA28), // Overweight   (25–30)
    Color(0xFFFFA726), // Overweight
    Color(0xFFEF5350), // Obese        (30–40)
    Color(0xFFE53935), // Obese
  ];

  // Proportional stops on the 180° arc for each zone boundary
  // 18.5 → (18.5-15)/25 = 14%,  25 → 40%,  30 → 60%
  static const List<double> _stops = [
    0.00, 0.14, // underweight
    0.14, 0.40, // normal
    0.40, 0.60, // overweight
    0.60, 1.00, // obese
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 10; // bottom baseline with small padding
    final radius = (size.width * 0.42).clamp(60.0, 160.0);
    const strokeW = 22.0;
    const gapBetweenSegments = 0.025; // radians gap between arc segments

    // The semicircle spans from π (left) to 0 (right) in standard math coords,
    // but drawArc uses clockwise angles starting from the 3-o'clock position.
    // We paint from 180° (left) sweeping 180° → ends at 0° (right).
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    // Draw background track
    arcPaint.color = (isDarkMode ? Colors.white : Colors.black).withOpacity(0.08);
    canvas.drawArc(rect, pi, pi, false, arcPaint);

    // Reset color to fully opaque so the segment gradients don't inherit 8% opacity
    arcPaint.color = Colors.white;

    // Draw coloured zone segments (4 zones, each with two stop entries)
    final zoneData = [
      (_stops[0], _stops[1], _zoneColors[0], _zoneColors[1]), // underweight
      (_stops[2], _stops[3], _zoneColors[2], _zoneColors[3]), // normal
      (_stops[4], _stops[5], _zoneColors[4], _zoneColors[5]), // overweight
      (_stops[6], _stops[7], _zoneColors[6], _zoneColors[7]), // obese
    ];

    for (final zone in zoneData) {
      final startAngle = pi + zone.$1 * pi + gapBetweenSegments / 2;
      final sweepAngle = (zone.$2 - zone.$1) * pi - gapBetweenSegments;
      // Use a simple gradient approximation via shader
      final startPt = Offset(
        cx + radius * cos(startAngle),
        cy + radius * sin(startAngle),
      );
      final endPt = Offset(
        cx + radius * cos(startAngle + sweepAngle),
        cy + radius * sin(startAngle + sweepAngle),
      );
      arcPaint.shader = LinearGradient(
        colors: [zone.$3, zone.$4],
      ).createShader(Rect.fromPoints(startPt, endPt));
      canvas.drawArc(
        rect.inflate(0),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
    arcPaint.shader = null;

    // ── Needle ──────────────────────────────────────────────────────────────
    // angle: π = left end (BMI 15), 2π = right end (BMI 40)
    final needleAngle = pi + fraction * pi;
    final needleLen = radius - strokeW / 2 + 2;
    final needleInnerRadius = radius * 0.45; // Leave center empty for the BMI text
    
    final needleStartX = cx + needleInnerRadius * cos(needleAngle);
    final needleStartY = cy + needleInnerRadius * sin(needleAngle);
    
    final needleX = cx + needleLen * cos(needleAngle);
    final needleY = cy + needleLen * sin(needleAngle);

    final needlePaint = Paint()
      ..color = isDarkMode ? Colors.white : Colors.black87
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(needleStartX, needleStartY), Offset(needleX, needleY), needlePaint);

    // Pointer base circle at the inner start
    canvas.drawCircle(
      Offset(needleStartX, needleStartY),
      5,
      Paint()..color = isDarkMode ? Colors.white : Colors.black87,
    );
    canvas.drawCircle(
      Offset(needleStartX, needleStartY),
      3,
      Paint()..color = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
    );

    // ── Centre text: BMI value ───────────────────────────────────────────────
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    _drawText(
      canvas,
      bmi.toStringAsFixed(1),
      Offset(cx, cy - radius * 0.32),
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: catColor,
    );
    _drawText(
      canvas,
      'BMI',
      Offset(cx, cy - radius * 0.12),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.5),
    );

    // ── Scale labels at arc ends ─────────────────────────────────────────────
    // "15" at left, "40" at right
    final labelStyle = TextStyle(
      fontSize: 11,
      color: textColor.withOpacity(0.5),
      fontWeight: FontWeight.w500,
    );
    _drawTextStyle(
        canvas, '15', Offset(cx - radius - strokeW * 0.6, cy + 14), labelStyle);
    _drawTextStyle(
        canvas, '40', Offset(cx + radius + strokeW * 0.3, cy + 14), labelStyle);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawTextStyle(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(BmiGaugePainter old) =>
      old.fraction != fraction || old.bmi != bmi;
}
