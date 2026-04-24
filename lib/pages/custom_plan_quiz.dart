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
  bool _isLoadingOfferings = true;
  bool _hasOfferings = false;
  int currentStep = 1;
  String selectedPlan = 'weekly';
  double _targetWeightDragAccum = 0; // persistent drag state for ruler
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

    AnalyticsService().trackPaywallViewed(source: 'quiz_completion');

    try {
      // Go straight to RevenueCatUI — it handles store errors natively.
      // We deliberately DO NOT pre-check offerings here; the old pre-check
      // caused "Store Unavailable" dialogs in Apple's sandbox during review.
      final result = await RevenueCatService().showPaywall();
      debugPrint('[RevenueCat] Paywall result: $result');

      if (result == null || result == PaywallResult.cancelled) {
        // User dismissed or store failed silently — stay on free tier.
        debugPrint('[RevenueCat] Paywall dismissed or unavailable — freemium access only.');
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

    final stopwatch = Stopwatch()..start();

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
        progressStatus = 'Analyzing your body & goals...';
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
      // Save integer immediately — WorkoutPage/_MealPlanPage read this on refresh.
      // This is the FASTEST and most reliable path; no regex, no Supabase round-trip.
      await prefs.setInt('duration_weeks_int', durationWeeks);
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
        progressStatus = 'Designing your workout plan...';
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
        progressStatus = 'Generating your meal plan...';
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
      // Redundant safety write — ensures the integer is always present
      // even if the earlier write was skipped due to an early error.
      await prefs.setInt('duration_weeks_int', durationWeeks);
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
        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed < 7000) {
          setState(() {
            progressStatus = 'Optimizing for fastest results...';
            progressPercent = 95;
            currentStep = 4;
          });
          await Future.delayed(Duration(milliseconds: 7000 - elapsed));
        }
        if (mounted) {
          setState(() {
            progressPercent = 100;
            progressStatus = 'Building Your Personalized Plan...';
            _introComplete = true; // Important: Make the button appear
            _isGenerating = false;
            currentStep = 5;
          });
        }
      }
    } catch (e) {
      print('ERROR in plan generation: $e');
      debugPrint('[QUIZ ERROR] Plan generation failed: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _introComplete = true; // Let them hit the button anyway
          currentStep = 5; // force completion to let UI unlock visually
          progressPercent = 100;
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
        final screenWidth  = constraints.maxWidth;
        final isVerySmall  = screenHeight < 550;
        final isTablet     = screenWidth  > 600;
        final hPad         = isTablet ? 28.0 : 20.0;
        final contentW     = isTablet ? 420.0 : screenWidth;
        final heroH        = (screenHeight * 0.40).clamp(160.0, 280.0);

        return Stack(
          children: [
            // ── Dark background ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFF0D0608),
            ),
            // ── Red radial glow — top right ──────────────────────────────────
            Positioned(
              top: -screenHeight * 0.12,
              right: isTablet ? (screenWidth - contentW) / 2 - contentW * 0.25 : -screenWidth * 0.28,
              child: IgnorePointer(
                child: Container(
                  width: contentW * 1.15,
                  height: screenHeight * 0.62,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xA8B5061C),
                        Color(0x45B5061C),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.42, 1.0],
                      radius: 0.55,
                    ),
                  ),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: contentW,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: isVerySmall ? 0 : 8),

                        // Top badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.38),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withOpacity(0.18)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Text('🏆', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 5),
                                Text('Built for Real Results',
                                  style: TextStyle(
                                    fontSize: isTablet ? 11 : 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  )),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.38),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withOpacity(0.18)),
                              ),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Image.asset('assets/rating4.9.png',
                                  height: isTablet ? 18 : 15, fit: BoxFit.contain),
                                const SizedBox(height: 2),
                                Text('4.9 Rating',
                                  style: TextStyle(
                                    fontSize: isTablet ? 10 : 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  )),
                              ]),
                            ),
                          ],
                        ),

                        // Hero image
                        Expanded(
                          child: Image.asset(
                            'assets/quizimg.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Headline
                        Text(
                          'Build Your Dream Body',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 32 : (isVerySmall ? 22 : 26),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: isVerySmall ? 4 : 6),
                        Text(
                          'A personalized plan built just for\nyour body & goals',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12.5,
                            color: Colors.white.withOpacity(0.58),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Features row (3 columns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _quizFeatureColumnDark('🔥', 'Personalized Workouts', isLast: false)),
                            const SizedBox(width: 8),
                            Expanded(child: _quizFeatureColumnDark('🥗', 'Smart Meal Plans', isLast: false)),
                            const SizedBox(width: 8),
                            Expanded(child: _quizFeatureColumnDark('📊', 'Track Your Progress', isLast: true)),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // CTA + footer
                        SizedBox(
                          width: double.infinity,
                          height: isVerySmall ? 52 : 58,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF1E40), Color(0xFFC8061B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF1E40).withOpacity(0.45),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                final supabaseService = SupabaseService();
                                var user = supabaseService.client.auth.currentUser;
                                bool justSignedIn = false;
                                if (user == null) {
                                  await AuthModal.show(context);
                                  user = supabaseService.client.auth.currentUser;
                                  if (user == null) return;
                                  justSignedIn = true;
                                }
                                if (justSignedIn) {
                                  try {
                                    final response = await supabaseService.client
                                        .from('user_preferences')
                                        .select('user_id')
                                        .eq('user_id', user.id)
                                        .maybeSingle();
                                    if (response != null && mounted) {
                                      Navigator.pop(context, {
                                        'completed': true,
                                        'navIndex': widget.quizType == 'workout' ? 1 : 2,
                                      });
                                      return;
                                    }
                                  } catch (_) {}
                                }
                                AnalyticsService().trackQuizStarted();
                                nextScreen(1);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 0,
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Text(
                                  'GET MY PLAN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 16),
                                ),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 34,
                              child: Stack(
                                children: [
                                  Positioned(left: 0, child: _quizAvatar('assets/avatar1.png', 34)),
                                  Positioned(left: 20, child: _quizAvatar('assets/avatar2.png', 34)),
                                  Positioned(left: 40, child: _quizAvatar('assets/avatar3.png', 34)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Join 12,000+ users',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'already transforming their bodies',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: isVerySmall ? 8 : 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _quizFeatureColumnDark(String emoji, String title, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title.replaceFirst(' ', '\n'), // Max 2 lines
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quizFeatureRow(String emoji, String title, String sub, bool compact, bool isTablet) {
    return Row(children: [
      Container(
        width: compact ? 34 : 40, height: compact ? 34 : 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(emoji, style: TextStyle(fontSize: compact ? 16 : 18))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: isTablet ? 14 : 12.5,
          fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 1),
        Text(sub, style: TextStyle(fontSize: isTablet ? 11.5 : 10.5,
          color: Colors.white.withOpacity(0.65))),
      ])),
      Container(
        width: 20, height: 20,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
      ),
    ]);
  }

  Widget _quizAvatar(String asset, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFCC0A16), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
      ),
      child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final isVerySmall = h < 500;
        final isSmall = h < 650;
        final double titleFontSize = isVerySmall ? 13 : (isSmall ? 14.5 : 16);
        final double subtitleFontSize = isVerySmall ? 11.5 : (isSmall ? 12.5 : 14);
        final double innerPad = isVerySmall ? 12 : (isSmall ? 14 : 20);
        final double titleSubGap = isVerySmall ? 4 : 8;
        final double contentGap = isVerySmall ? 6 : 12;

        return Column(
          children: [
            _buildProgressBar(questionNumber),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(innerPad),
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
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: titleSubGap),
                      _buildAnimatedWidget(
                        delay: 150,
                        slideUp: false,
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: contentGap),
                    Expanded(
                      child: content,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContinueButton(VoidCallback onPressed, {bool enabled = true, String text = 'CONTINUE', double topMargin = 15, double verticalPad = 14}) {
    return _buildAnimatedWidget(
      delay: 600,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: topMargin),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? const Color(0xFFFF0000) : Colors.grey.shade400,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            disabledForegroundColor: Colors.white70,
            padding: EdgeInsets.symmetric(vertical: verticalPad),
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
    String? iconPath,
    String? trailingText,
    double fontSize = 14,
    double verticalPadding = 12,
    double bottomMargin = 8,
    bool isGrid = false,
  }) {
    final double hPad = isGrid ? 8 : 14;
    final double gap1 = isGrid ? 6 : 10;
    final double gap2 = isGrid ? 4 : 8;
    // Icon size is proportional to the option height (verticalPadding * 2 + fontSize) so it never overflows
    final double iconSize = isGrid
        ? (fontSize + 8).clamp(20.0, 32.0)
        : (verticalPadding * 1.6 + fontSize * 0.5).clamp(20.0, 34.0);

    return _buildAnimatedWidget(
      delay: 100 + (index * 50),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: bottomMargin),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: verticalPadding),
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
              SizedBox(
                width: 20,
                height: 20,
                child: Container(
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
              ),
              SizedBox(width: gap1),
              Expanded(
                child: isGrid 
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                      )
                    : Text(
                        text,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
              ),
              if (trailingText != null) ...[
                SizedBox(width: gap1),
                Text(
                  trailingText,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white70 : const Color(0xFF444444),
                  ),
                ),
              ],
              if (iconPath != null) ...[
                SizedBox(width: gap2),
                Image.asset(iconPath, width: iconSize, height: iconSize),
              ],
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
    Map<String, String> optionIcons = const {},
    Map<String, String> optionSubtitles = const {},
  }) {
    final bool hasSelection = selectedValue.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final isVerySmall = h < 500;
        final isSmall = h < 650;
        final int count = options.length;
        // Extra tightening for 7+ options to prevent overflow
        final double tightFactor = count >= 7 ? 3.4 : (count >= 5 ? 3.0 : 2.8);
        final double marginFactor = count >= 7 ? 8.0 : (count >= 5 ? 7.0 : 6.0);
        // Compute available space for options: subtract progress bar (~31px) + title block (~60px) + button (~60px) + gaps
        final headerEst = isVerySmall ? 110.0 : (isSmall ? 130.0 : 155.0);
        final btnEst = isVerySmall ? 50.0 : 60.0;
        final availableForOptions = h - headerEst - btnEst;
        final double optionVPad = (availableForOptions / count / tightFactor).clamp(4.0, 12.0);
        final double optionMargin = (availableForOptions / count / marginFactor).clamp(2.0, 8.0);
        final double optionFont = isVerySmall ? 12.0 : (isSmall ? 13.0 : 14.0);
        final double btnTopMargin = isVerySmall ? 6.0 : (isSmall ? 10.0 : 15.0);
        final double btnVPad = isVerySmall ? 10.0 : (isSmall ? 12.0 : 14.0);

        return _buildQuestionScreen(
          questionNumber: questionNumber,
          title: title,
          subtitle: subtitle,
          onContinue: hasSelection ? () => nextScreen(questionNumber + 1) : () {},
          isDarkMode: isDarkMode,
          content: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, innerConstraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: innerConstraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: options.asMap().entries.map((entry) {
                            final option = entry.value;
                            return _buildOption(
                              text: option,
                              isSelected: selectedValue == option,
                              onTap: () => onSelect(option),
                              index: entry.key,
                              isDarkMode: isDarkMode,
                              iconPath: optionIcons[option],
                              trailingText: optionSubtitles[option],
                              fontSize: optionFont,
                              verticalPadding: optionVPad,
                              bottomMargin: optionMargin,
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildContinueButton(
                () => nextScreen(questionNumber + 1),
                enabled: hasSelection,
                topMargin: btnTopMargin,
                verticalPad: btnVPad,
              ),
            ],
          ),
        );
      },
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
    Map<String, String> optionIcons = const {},
    bool fullWidthFirst = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final isVerySmall = h < 500;
        final isSmall = h < 650;
        final int effectiveCols = columns;
        final headerEst = isVerySmall ? 110.0 : (isSmall ? 130.0 : 155.0);
        final btnEst = isVerySmall ? 50.0 : 60.0;
        final availableForOptions = h - headerEst - btnEst;
        // When fullWidthFirst, the first item is 1 row, rest fill the grid
        final int gridItemCount = fullWidthFirst ? options.length - 1 : options.length;
        final int rowCount = (gridItemCount / effectiveCols).ceil() + (fullWidthFirst ? 1 : 0);
        final double optionVPad = (availableForOptions / rowCount / 2.8).clamp(4.0, 12.0);
        final double optionMargin = (availableForOptions / rowCount / 6).clamp(2.0, 8.0);
        final double optionFont = isVerySmall ? 11.5 : (isSmall ? 12.5 : 14.0);
        final double btnTopMargin = isVerySmall ? 4.0 : (isSmall ? 8.0 : 15.0);
        final double btnVPad = isVerySmall ? 10.0 : (isSmall ? 12.0 : 14.0);

        Widget buildOptionItem(int index, {bool forceFullWidth = false}) {
          final option = options[index];
          return _buildOption(
            text: option,
            isSelected: selectedValues.contains(option),
            onTap: () => onToggle(option),
            index: index,
            isRadio: false,
            isDarkMode: isDarkMode,
            iconPath: optionIcons[option],
            fontSize: optionFont,
            verticalPadding: optionVPad,
            bottomMargin: optionMargin,
            isGrid: effectiveCols > 1 && !forceFullWidth,
          );
        }

        Widget optionsWidget;
        if (fullWidthFirst && effectiveCols > 1) {
          // First item spans full width, rest in 2-column grid
          final rows = <Widget>[];
          // Full-width first row
          rows.add(buildOptionItem(0, forceFullWidth: true));
          // Remaining items in grid
          final rest = options.sublist(1);
          final int restRows = (rest.length / effectiveCols).ceil();
          for (int r = 0; r < restRows; r++) {
            final rowChildren = <Widget>[];
            for (int c = 0; c < effectiveCols; c++) {
              final idx = r * effectiveCols + c;
              if (idx < rest.length) {
                final globalIdx = idx + 1;
                rowChildren.add(Expanded(child: buildOptionItem(globalIdx)));
                if (c < effectiveCols - 1) rowChildren.add(const SizedBox(width: 8));
              } else {
                rowChildren.add(const Expanded(child: SizedBox()));
              }
            }
            rows.add(Row(children: rowChildren));
          }
          optionsWidget = Column(children: rows);
        } else if (effectiveCols > 1) {
          final int rowCount2 = (options.length / effectiveCols).ceil();
          final rows = <Widget>[];
          for (int r = 0; r < rowCount2; r++) {
            final rowChildren = <Widget>[];
            for (int c = 0; c < effectiveCols; c++) {
              final idx = r * effectiveCols + c;
              if (idx < options.length) {
                rowChildren.add(Expanded(child: buildOptionItem(idx)));
                if (c < effectiveCols - 1) rowChildren.add(const SizedBox(width: 8));
              } else {
                rowChildren.add(const Expanded(child: SizedBox()));
              }
            }
            rows.add(Row(children: rowChildren));
          }
          optionsWidget = Column(children: rows);
        } else {
          optionsWidget = Column(
            children: List.generate(options.length, (i) => buildOptionItem(i)),
          );
        }

        return _buildQuestionScreen(
          questionNumber: questionNumber,
          title: title,
          subtitle: subtitle,
          onContinue: () => nextScreen(questionNumber + 1),
          isDarkMode: isDarkMode,
          content: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, innerConstraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: innerConstraints.maxHeight,
                        ),
                        child: optionsWidget,
                      ),
                    );
                  },
                ),
              ),
              _buildContinueButton(
                () => nextScreen(questionNumber + 1),
                topMargin: btnTopMargin,
                verticalPad: btnVPad,
              ),
            ],
          ),
        );
      },
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
    Widget? extraContent,
  }) {
    return LayoutBuilder(
      builder: (context, pickerConstraints) {
    final int curIndex = values.indexOf(selectedValue).clamp(0, values.length - 1);
    final double itemH = pickerConstraints.maxHeight < 500 ? 38.0 : (pickerConstraints.maxHeight < 650 ? 44.0 : 52.0);

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

    final bool isVerySmallPicker = pickerConstraints.maxHeight < 500;
    final bool isSmallPicker = pickerConstraints.maxHeight < 650;
    final double unitToggleHPad = isVerySmallPicker ? 16 : (isSmallPicker ? 20 : 28);
    final double unitToggleVPad = isVerySmallPicker ? 6 : (isSmallPicker ? 8 : 10);
    final double unitToggleMargin = isVerySmallPicker ? 8 : (isSmallPicker ? 12 : 16);
    final double btnVPad = isVerySmallPicker ? 10.0 : (isSmallPicker ? 12.0 : 14.0);
    final double btnTopMargin = isVerySmallPicker ? 6.0 : (isSmallPicker ? 10.0 : 20.0);

    return _buildQuestionScreen(
      questionNumber: questionNumber,
      title: title,
      subtitle: subtitle,
      onContinue: () => nextScreen(questionNumber + 1),
      isDarkMode: isDarkMode,
      content: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(height: isVerySmallPicker ? 4 : 8),
          // Unit toggle (optional)
          if (units.isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: unitToggleMargin),
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
                      padding: EdgeInsets.symmetric(horizontal: unitToggleHPad, vertical: unitToggleVPad),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFFF0000) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        u,
                        style: TextStyle(
                          color: isSel ? Colors.white : (isDarkMode ? Colors.white60 : Colors.grey),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: isVerySmallPicker ? 13 : 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Picker area — uses flex only when no extraContent, otherwise fixed height
          if (extraContent == null)
            Expanded(
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    step(event.scrollDelta.dy > 0 ? 1 : -1);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) {
                    dragAccum += d.delta.dy;
                    while (dragAccum <= -itemH) { dragAccum += itemH; step(1); }
                    while (dragAccum >= itemH)  { dragAccum -= itemH; step(-1); }
                  },
                  onVerticalDragEnd: (_) { dragAccum = 0; },
                  child: LayoutBuilder(
                    builder: (ctx, bc) {
                      final pickerHeight = itemH * 5;
                      return Center(
                        child: SizedBox(
                          height: pickerHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: itemH,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              Column(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => step(-1),
                                      behavior: HitTestBehavior.opaque,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  SizedBox(height: itemH),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => step(1),
                                      behavior: HitTestBehavior.opaque,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                              buildPickerItems(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
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
                          while (dragAccum <= -itemH) { dragAccum += itemH; step(1); }
                          while (dragAccum >= itemH)  { dragAccum -= itemH; step(-1); }
                        },
                        onVerticalDragEnd: (_) { dragAccum = 0; },
                        child: SizedBox(
                          height: itemH * 5,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: itemH,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              Column(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => step(-1),
                                      behavior: HitTestBehavior.opaque,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  SizedBox(height: itemH),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => step(1),
                                      behavior: HitTestBehavior.opaque,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                              buildPickerItems(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    extraContent,
                  ],
                ),
              ),
            ),
          _buildContinueButton(
            () => nextScreen(questionNumber + 1),
            topMargin: btnTopMargin,
            verticalPad: btnVPad,
          ),
        ],
      ),
    );
  }
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
      optionIcons: {
        'Male': 'assets/quizemojis/male.png',
        'Female': 'assets/quizemojis/female.png',
      },
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
      optionIcons: {
        'Sedentary (mostly sitting, office work)': 'assets/quizemojis/Sedentary.png',
        'Light (some walking or light movement)': 'assets/quizemojis/Light.png',
        'Moderate (active job or frequent movement)': 'assets/quizemojis/Moderate.png',
        'Very Active (physical labor or athlete)': 'assets/quizemojis/Very Active.png',
      },
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
      optionIcons: {
        'Lose Fat & Stay Lean': 'assets/quizemojis/Lose Fat & Stay Lean.png',
        'Build Muscle & Gain Strength': 'assets/quizemojis/Build Muscle.png',
      },
    );
  }

  Widget _buildTargetWeightScreen(bool isDarkMode) {
    if (targetWeight.isEmpty) {
      targetWeight = targetWeightUnit == 'kg' ? '65 kg' : '145 lbs';
    }

    double currentW = double.tryParse(weight.replaceAll(RegExp(r'[^\d.]'), '')) ??
        (weightUnit == 'kg' ? 70.0 : 155.0);
    if (weightUnit != targetWeightUnit) {
      currentW = targetWeightUnit == 'kg'
          ? currentW * 0.453592
          : currentW * 2.20462;
    }
    final double minW = targetWeightUnit == 'kg' ? 30.0 : 66.0;
    final double maxW = targetWeightUnit == 'kg' ? 200.0 : 396.0;
    double targetW =
        (double.tryParse(targetWeight.replaceAll(RegExp(r'[^\d.]'), '')) ?? currentW)
            .clamp(minW, maxW);
    final bool isLoss =
        targetW < currentW || (targetW == currentW && mainGoal.contains('Lose'));
    final double diff = (targetW - currentW).abs();
    final double weeklyRate = isLoss
        ? (targetWeightUnit == 'kg' ? 0.5 : 1.1)
        : (targetWeightUnit == 'kg' ? 0.25 : 0.55);
    final int weeks =
        diff > 0 ? (diff / weeklyRate).ceil().clamp(1, 104) : 1;
    final double percent = currentW > 0 ? (diff / currentW * 100) : 0;
    final DateTime td = DateTime.now().add(Duration(days: weeks * 7));
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
    final String formattedDate = "${mo[td.month - 1]} ${td.day}, ${td.year}";
    final String emojiAsset = isLoss
        ? 'assets/svg/mealsicons/iconfire.png'
        : 'assets/quizemojis/Build Muscle.png';
    final String messageText =
        isLoss ? "drop body weight by " : "increase muscle mass by ";
    final String messageSub = isLoss
        ? "As your body fat decreases, you will look leaner and more defined."
        : "As your muscle mass increases, you will gain a stronger physique.";

    return _buildQuestionScreen(
      questionNumber: 7,
      title: "Do you have a goal in mind? (optional)",
      subtitle: "This is only used to track your progress.",
      onContinue: () => nextScreen(8),
      isDarkMode: isDarkMode,
      content: LayoutBuilder(
        builder: (ctx, bc) {
          final bool isSmall = bc.maxHeight < 520;
          // Drum-roll picker height: same proportion as other quiz screens
          final double pickerH =
              (bc.maxHeight * (isSmall ? 0.42 : 0.46)).clamp(160.0, 280.0);

          // Drum-roll constants
          const int halfRange = 2;      // show -2..+2 => 5 rows
          const int totalRows = halfRange * 2 + 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // Unit toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDarkMode
                          ? Colors.white12
                          : const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['kg', 'lbs'].map((u) {
                    final isSel = targetWeightUnit == u;
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (targetWeightUnit != u) {
                          targetWeightUnit = u;
                          targetWeight = u == 'kg' ? '65 kg' : '145 lbs';
                          _targetWeightDragAccum = 0;
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 22 : 28,
                            vertical: isSmall ? 8 : 10),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFFF0000)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(u,
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : (isDarkMode
                                      ? Colors.white60
                                      : Colors.grey),
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 15,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ),

              SizedBox(height: isSmall ? 10 : 16),

              // Row: drum-roll picker (left) + big number (right)
              SizedBox(
                height: pickerH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Drum-roll picker
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (d) {
                          _targetWeightDragAccum += d.delta.dy;
                          const double pxPerStep = 10.0;
                          while (_targetWeightDragAccum <= -pxPerStep) {
                            _targetWeightDragAccum += pxPerStep;
                            final next = (targetW + 1).clamp(minW, maxW);
                            setState(() => targetWeight =
                                "${next.round()} $targetWeightUnit");
                          }
                          while (_targetWeightDragAccum >= pxPerStep) {
                            _targetWeightDragAccum -= pxPerStep;
                            final next = (targetW - 1).clamp(minW, maxW);
                            setState(() => targetWeight =
                                "${next.round()} $targetWeightUnit");
                          }
                        },
                        onVerticalDragEnd: (_) =>
                            _targetWeightDragAccum = 0,
                        child: LayoutBuilder(
                          builder: (rctx, rbc) {
                            final double itemH =
                                rbc.maxHeight / totalRows;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Centre highlight box
                                Container(
                                  height: itemH,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.white
                                            .withOpacity(0.08)
                                        : Colors.black
                                            .withOpacity(0.06),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                // Number rows
                                Column(
                                  children: List.generate(totalRows,
                                      (i) {
                                    final int offset = i - halfRange;
                                    final int val =
                                        targetW.round() + offset;
                                    final bool isCenter =
                                        offset == 0;
                                    final int absOff = offset.abs();
                                    return GestureDetector(
                                      onTap: () => setState(() =>
                                          targetWeight =
                                              "$val $targetWeightUnit"),
                                      child: SizedBox(
                                        height: itemH,
                                        child: Center(
                                          child:
                                              AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                                milliseconds: 150),
                                            style: TextStyle(
                                              fontSize: isCenter
                                                  ? 28
                                                  : (absOff == 1
                                                      ? 19
                                                      : 14),
                                              fontWeight: isCenter
                                                  ? FontWeight.bold
                                                  : FontWeight.w400,
                                              color: isCenter
                                                  ? (isDarkMode
                                                      ? Colors.white
                                                      : Colors.black)
                                                  : (isDarkMode
                                                      ? Colors.white
                                                          .withOpacity(
                                                              absOff ==
                                                                      1
                                                                  ? 0.45
                                                                  : 0.20)
                                                      : Colors.black
                                                          .withOpacity(
                                                              absOff ==
                                                                      1
                                                                  ? 0.35
                                                                  : 0.15)),
                                            ),
                                            child: Text(
                                                "$val $targetWeightUnit"),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),


                  ],
                ),
              ),

              const Spacer(),

              // Est. target date (above message card)
              Row(
                children: [
                  Image.asset(
                    'assets/svg/mealsicons/iconprogress.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: isDarkMode
                          ? Colors.white54
                          : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Est. target: $formattedDate",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.white54
                          : Colors.black54,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isSmall ? 8 : 10),

              // Message card
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isSmall ? 10 : 14),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFFFF8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white12
                        : const Color(0xFFFFE0E0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          emojiAsset,
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text:
                                    "Challenge target, you'll $messageText",
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              TextSpan(
                                text:
                                    "${percent.toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  color: Color(0xFFFF0000),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      messageSub,
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white60
                            : Colors.black54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              _buildContinueButton(() => nextScreen(8)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlanDurationScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 8,
      title: "How long do you want this first plan to last?",
      options: ['2 Weeks', '3 Weeks', '4 Weeks', '12 Weeks'],
      selectedValue: planDuration,
      onSelect: (val) => setState(() => planDuration = val),
      isDarkMode: isDarkMode,
      optionIcons: {
        '2 Weeks': 'assets/quizemojis/2 weeks.png',
        '3 Weeks': 'assets/quizemojis/3 weeks.png',
        '4 Weeks': 'assets/quizemojis/4 weeks.png',
        '12 Weeks': 'assets/quizemojis/12 weeks.png',
      },
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
      optionIcons: {
        'Beginner': 'assets/quizemojis/beginner.png',
        'Intermediate': 'assets/quizemojis/Intermediate.png',
        'Advanced': 'assets/quizemojis/Advanced.png',
      },
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
      optionIcons: {
        'Home': 'assets/quizemojis/home-.png',
        'Gym': 'assets/quizemojis/gym.png',
      },
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
      columns: 1,
      optionIcons: {
        'Bodyweight': 'assets/quizemojis/Bodyweight.png',
        'Dumbbells': 'assets/quizemojis/dumbbell.png',
        'Resistance Bands': 'assets/quizemojis/resistance-band.png',
        'Barbell': 'assets/quizemojis/barbell.png',
        'Kettlebells': 'assets/quizemojis/Kettlebells.png',
        'Machines': 'assets/quizemojis/Machines.png',
        'All': 'assets/quizemojis/All.png',
      },
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
      optionIcons: {
        '3 days': 'assets/quizemojis/3 days.png',
        '4 days': 'assets/quizemojis/4 days.png',
        '5 days': 'assets/quizemojis/5 days.png',
        '6 days': 'assets/quizemojis/6 days.png',
        '7 days': 'assets/quizemojis/7 days.png',
      },
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
      optionIcons: {
        '20 min': 'assets/quizemojis/20 min.png',
        '30 min': 'assets/quizemojis/30 min.png',
        '45 min': 'assets/quizemojis/45 min.png',
        '60 min': 'assets/quizemojis/60 min.png',
        '90 min': 'assets/quizemojis/90 min.png',
      },
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
      optionIcons: {
        'Morning': 'assets/quizemojis/Morning.png',
        'Afternoon': 'assets/quizemojis/Afternoon.png',
        'Evening': 'assets/quizemojis/Evening.png',
        'Flexible': 'assets/quizemojis/flexible.png',
      },
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
      columns: 2,
      fullWidthFirst: true, // 'None' spans full width; remaining 8 fill 2-column grid
      optionIcons: {
        'Back': 'assets/quizemojis/Back.png',
        'Knees': 'assets/quizemojis/Knees.png',
        'Shoulders': 'assets/quizemojis/Shoulders.png',
        'Hips': 'assets/quizemojis/Hips.png',
        'Neck': 'assets/quizemojis/Neck.png',
        'Elbows': 'assets/quizemojis/Elbows.png',
        'Wrists': 'assets/quizemojis/Wrists.png',
        'Ankles': 'assets/quizemojis/Ankles.png',
      },
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
      optionIcons: {
        'No Preference': 'assets/quizemojis/No Preference.png',
        'Vegetarian': 'assets/quizemojis/Vegetarian.png',
        'Vegan': 'assets/quizemojis/vegan.png',
        'Pescatarian': 'assets/quizemojis/Pescatarian.png',
        'Mediterranean': 'assets/quizemojis/Mediterranean.png',
        'Keto': 'assets/quizemojis/keto.png',
        'Low-Carb': 'assets/quizemojis/Low-Carb.png',
        'Gluten-Free': 'assets/quizemojis/gluten-free.png',
      },
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
      columns: 1,
      optionIcons: {
        'Nuts': 'assets/quizemojis/nuts.png',
        'Dairy': 'assets/quizemojis/dairy.png',
        'Gluten': 'assets/quizemojis/Gluten.png',
        'Eggs': 'assets/quizemojis/egg.png',
        'Soy': 'assets/quizemojis/Soy.png',
        'Shellfish': 'assets/quizemojis/Shellfish.png',
      },
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
      optionIcons: {
        'Balanced': 'assets/quizemojis/Balanced.png',
        'Higher Protein': 'assets/quizemojis/Higher Protein.png',
        'Lower Carb': 'assets/quizemojis/Lower Carb.png',
        'Higher Carb': 'assets/quizemojis/Higher Carb.png',
      },
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
      optionIcons: {
        'Less than 5': 'assets/quizemojis/Poor.png',
        '5-6 hours': 'assets/quizemojis/Fair.png',
        '7-8 hours': 'assets/quizemojis/Good.png',
        'More than 8': 'assets/quizemojis/Excellent.png',
      },
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
      optionIcons: {
        'Poor': 'assets/quizemojis/Poor.png',
        'Fair': 'assets/quizemojis/Fair.png',
        'Good': 'assets/quizemojis/Good.png',
        'Excellent': 'assets/quizemojis/Excellent.png',
      },
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
      optionIcons: {
        'Low': 'assets/quizemojis/Good.png',
        'Moderate': 'assets/quizemojis/Fair.png',
        'High': 'assets/quizemojis/Poor.png',
      },
    );
  }


  Widget _buildWaterIntakeScreen(bool isDarkMode) {
    return _buildSelectionScreen(
      questionNumber: 22,
      title: "How much water do you usually drink per day?",
      subtitle: "We'll suggest a general daily hydration goal.",
      options: [
        'Less than 1 Liter',
        '1–2 Liters',
        '2–3 Liters',
        'More than 3 Liters'
      ],
      selectedValue: waterIntake,
      onSelect: (val) => setState(() => waterIntake = val),
      isDarkMode: isDarkMode,
      optionIcons: {
        'Less than 1 Liter': 'assets/quizemojis/glass-of-water.png',
        '1–2 Liters': 'assets/quizemojis/glass-of-water.png',
        '2–3 Liters': 'assets/quizemojis/glass-of-water.png',
        'More than 3 Liters': 'assets/quizemojis/glass-of-water.png',
      },
      optionSubtitles: {
        'Less than 1 Liter': '4×',
        '1–2 Liters': '6×',
        '2–3 Liters': '10×',
        'More than 3 Liters': '12×',
      },
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
                const Spacer(flex: 1),
                _buildContinueButton(() => nextScreen(24), text: 'I UNDERSTAND', verticalPad: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSummaryScreen(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenH = constraints.maxHeight;
        final isSmall = screenH < 600;
        final isMedium = screenH < 750;

        final double hPad    = isSmall ? 16 : 24;
        final double vPad    = isSmall ? 16 : (isMedium ? 24 : 32);
        final double iconSz  = isSmall ? 36 : 48;
        final double titleSz = isSmall ? 22 : (isMedium ? 25 : 28);
        final double subSz   = isSmall ? 13 : 15;
        final double rowVPad = isSmall ? 11 : (isMedium ? 13 : 16);
        final double gap     = isSmall ? 20 : (isMedium ? 28 : 36);
        final double btnH    = isSmall ? 52 : 60;
        final double btnSz   = isSmall ? 15 : 17;

        final dividerColor = isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFEEEEEE);
        final cardColor    = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
        final cardBorder   = isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04);

        final allRows = <(String, String, String)>[
          // Workout
          ('Goal',          mainGoal.isEmpty        ? 'Weight Loss'    : mainGoal,        'assets/emojis/target.png'),
          ('Duration',      planDuration.isEmpty    ? '4 Weeks'        : planDuration,    'assets/emojis/hourglass.png'),
          ('Training Days', trainingDays.isEmpty    ? '3-4 Days'       : trainingDays,    'assets/emojis/calendar.png'),
          ('Location',      workoutLocation.isEmpty ? 'Gym'            : workoutLocation, 'assets/emojis/pin.png'),
          // Meal
          ('Diet Type',     dietType.isEmpty        ? 'No Preference'  : dietType,        'assets/emojis/salad.png'),
          ('Macro Focus',   macroBalance.isEmpty    ? 'Balanced'       : macroBalance,    'assets/emojis/scale.png'),
          ('Allergies',     (allergies.isEmpty || allergies.first == 'None') ? 'None' : allergies.join(', '), 'assets/emojis/peanuts.png'),
          ('Meals / Day',   '4 Meals', 'assets/emojis/plate.png'),
        ];

        return Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth - (hPad * 2), // Constrain to available width so text wraps properly
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Icon ──
                          _buildAnimatedWidget(
                            delay: 0,
                            child: Container(
                              padding: EdgeInsets.all(isSmall ? 14 : 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0000).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset('assets/sparkles.png', width: iconSz, height: iconSz),
                            ),
                          ),
                    SizedBox(height: isSmall ? 14 : 20),

                    // ── Title ──
                    _buildAnimatedWidget(
                      delay: 100,
                      child: Text(
                        'Plan Review',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSz,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDarkMode ? Colors.white : const Color(0xFF111111),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 6 : 10),

                    // ── Subtitle ──
                    _buildAnimatedWidget(
                      delay: 200,
                      child: Text(
                        "Here's a quick overview of your personalized plan before we build it.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: subSz,
                          height: 1.5,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                        ),
                      ),
                    ),
                    SizedBox(height: gap),

                    // ── Single combined Plan Summary card ──
                    _buildAnimatedWidget(
                      delay: 300,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                          border: Border.all(color: cardBorder, width: 1),
                        ),
                        child: Column(
                          children: [
                            // Card header
                            Container(
                              padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16, horizontal: 20),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.white.withOpacity(0.03) : const Color(0xFFF9F9F9),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Image.asset('assets/sparkles.png', width: 18, height: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PLAN SUMMARY',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: isDarkMode ? Colors.white70 : const Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: dividerColor),

                            // All rows combined
                            ...allRows.asMap().entries.map((entry) {
                              final isLast = entry.key == allRows.length - 1;
                              return Column(
                                children: [
                                  _buildSleekRow(entry.value.$1, entry.value.$2, entry.value.$3, isDarkMode, rowVPad),
                                  if (!isLast) Divider(height: 1, color: dividerColor),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                          SizedBox(height: isSmall ? 12 : 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── CTA ──
            _buildAnimatedWidget(
              delay: 500,
              slideUp: true,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(left: hPad, right: hPad, bottom: isSmall ? 12 : 20, top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: btnH,
                        child: ElevatedButton(
                          onPressed: () async {
                            final supabaseService = SupabaseService();
                            var user = supabaseService.client.auth.currentUser;
                            if (user == null) {
                              await AuthModal.show(context);
                              user = supabaseService.client.auth.currentUser;
                              if (user == null) return;
                            }
                            if (!mounted) return;
                            setState(() {
                              _isIntroProgress = true;
                              _introComplete = false;
                              progressPercent = 0;
                            });
                            nextScreen(25);
                            await _startRealGenerationFlow();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0000),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Build My Full Plan',
                            style: TextStyle(
                              fontSize: btnSz,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 13, color: isDarkMode ? Colors.white60 : const Color(0xFF777777)),
                            const SizedBox(width: 5),
                            Text(
                              'No commitment • Takes less than 10 seconds',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white60 : const Color(0xFF777777),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSleekRow(String label, String value, String iconPath, bool isDarkMode, [double vPad = 16]) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: vPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white60 : const Color(0xFF777777),
                ),
              ),
              const SizedBox(width: 10),
              Image.asset(iconPath, width: 20, height: 20),
            ],
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF111111),
              ),
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
          final h = constraints.maxHeight;
          final isVerySmall = h < 500;
          final isSmall = h < 700;
          final double progressSize = isVerySmall ? 80 : (isSmall ? 100 : 150);
          final double percentageSize = isVerySmall ? 20 : (isSmall ? 24 : 32);
          final double spacing = isVerySmall ? 12 : (isSmall ? 20 : 40);
          final double smallSpacing = isVerySmall ? 10 : (isSmall ? 15 : 30);
          final double stepFont = isVerySmall ? 13 : (isSmall ? 14 : 15);
          final double stepVPad = isVerySmall ? 4 : (isSmall ? 6 : 8);
          final double btnVPad = isVerySmall ? 12 : (isSmall ? 14 : 18);
          final double bottomGap = isVerySmall ? 8 : (isSmall ? 12 : 20);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: spacing),
                SizedBox(
                  height: progressSize,
                  width: progressSize,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progressPercent / 100.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Stack(
                        children: [
                          Center(
                            child: SizedBox(
                              width: progressSize,
                              height: progressSize,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: isSmall ? 8 : 12,
                                backgroundColor: const Color(0xFFE0E0E0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              '${(value * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: percentageSize,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: smallSpacing),
                Text(
                  progressStatus,
                  style: TextStyle(
                    fontSize: isVerySmall ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: spacing),
                _buildProgressStepCompact('Analyzing your body & goals', 'assets/emojis/fire.png', currentStep >= 2, isDarkMode, stepFont, stepVPad),
                _buildProgressStepCompact('Designing your workout plan', 'assets/emojis/flex.png', currentStep >= 3, isDarkMode, stepFont, stepVPad),
                _buildProgressStepCompact('Generating your meal plan', 'assets/emojis/salad2.png', currentStep >= 4, isDarkMode, stepFont, stepVPad),
                _buildProgressStepCompact('Optimizing for fastest results', 'assets/emojis/chart.png', currentStep >= 5, isDarkMode, stepFont, stepVPad),
                const Spacer(),
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
                              Navigator.pop(context, {
                                'completed': true,
                                'navIndex': widget.quizType == 'workout' ? 1 : 2,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF0000),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: btnVPad),
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
                SizedBox(height: bottomGap),
              ],
            ),
          );
        },
      );
    }

    // ── REAL generation mode ─────────────────────────────────────────────────
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final double iconSize = isSmallScreen ? 80 : 100;
        final double spacing = isSmallScreen ? 20 : 40;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  size: iconSize,
                  color: const Color(0xFFFF0000),
                ),
                SizedBox(height: spacing * 0.75),
                Text(
                  progressStatus,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                   color: Color(0xFFFF0000),
                ),
              ],
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

  Widget _buildProgressStep(String label, String iconPath, bool isCompleted, bool isDarkMode) {
    return _buildProgressStepCompact(label, iconPath, isCompleted, isDarkMode, 15, 8);
  }

  Widget _buildProgressStepCompact(String label, String iconPath, bool isCompleted, bool isDarkMode, double fontSize, double vPad) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? const Color(0xFFFF0000) : (isDarkMode ? Colors.grey : const Color(0xFFCCCCCC)),
            size: fontSize + 5,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: isCompleted 
                    ? (isDarkMode ? Colors.white : const Color(0xFF1A1A1A)) 
                    : (isDarkMode ? Colors.white54 : const Color(0xFF999999)),
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(iconPath, width: fontSize + 5, height: fontSize + 5),
        ],
      ),
    );
  }
}

/// Small left-pointing triangle used as the vertical ruler centre indicator.
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}


