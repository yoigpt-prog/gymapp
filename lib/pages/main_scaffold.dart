import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'dart:async';
import 'home_page.dart';
import 'workout_page.dart';
import 'meal_plan_page.dart';
import 'progress_page.dart';
import 'profile_page.dart';
import 'more_page.dart'; // This file now contains SettingsPage class
import 'custom_plan_quiz.dart';
import '../widgets/gym_bottom_nav_bar.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/web_footer.dart';
import 'calculators/bmi_calculator_page.dart';
import 'calculators/calorie_calculator_page.dart';
import 'calculators/macro_calculator_page.dart';
import 'calculators/body_fat_calculator_page.dart';
import 'calculators/one_rm_calculator_page.dart';
import '../widgets/auth/auth_modal.dart'; // Import AuthModal
import '../services/revenue_cat_service.dart';
import '../services/analytics_service.dart';
import '../services/subscription_state.dart';

class MainScaffold extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  final int initialIndex;

  const MainScaffold({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;
  final GlobalKey<WebFooterState> _footerKey = GlobalKey<WebFooterState>();
  late List<Widget> _pages; // Re-added missing declaration
  final GlobalKey<WorkoutPageState> _workoutKey = GlobalKey<WorkoutPageState>();
  final GlobalKey<MealPlanPageState> _mealPlanKey = GlobalKey<MealPlanPageState>();
  final GlobalKey<ProgressPageState> _progressKey = GlobalKey<ProgressPageState>();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();

  // Keys to prevent unnecessary state destruction on theme toggle
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _bmiKey = GlobalKey();
  final GlobalKey _calorieKey = GlobalKey();
  final GlobalKey _macroKey = GlobalKey();
  final GlobalKey _bodyFatKey = GlobalKey();
  final GlobalKey _oneRmKey = GlobalKey();

  // Auth Timer State
  Timer? _authTimer;
  bool _isAuthModalOpen = false;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isEmailVerified = true; 
  bool _isLoadingAuth = true;
  bool _hasInteracted = false; // New Interaction Flag
  int _schedulingId = 0; // incremented on every cancel to invalidate stale async prompts

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializePages();
    _initAuthLogic();
    
    // Track initial screen
    _trackCurrentScreen();
  }

  void _trackCurrentScreen() {
    // Screen tracking removed per minimal analytics strategy
  }

  void _initializePages() {
     _pages = [
      HomePage(
        key: _homeKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      WorkoutPage(
        key: _workoutKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      MealPlanPage(
        key: _mealPlanKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      ProgressPage(
        key: _progressKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      ProfilePage(
        key: _profileKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      SettingsPage(
        key: _settingsKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      BmiCalculatorPage(
        key: _bmiKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      CalorieCalculatorPage(
        key: _calorieKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      MacroCalculatorPage(
        key: _macroKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      BodyFatCalculatorPage(
        key: _bodyFatKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      OneRmCalculatorPage(
        key: _oneRmKey,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
    ];
  }

  // --- AUTH LOGIC START ---

  void _initAuthLogic() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;

      if (mounted) {
        _checkAuthStatus();

        if (event == AuthChangeEvent.signedOut) {
          // LOGOUT: clear all identity and flags
          AnalyticsService().reset();
          SubscriptionState().reset();
          SharedPreferences.getInstance().then((prefs) {
            prefs.remove('has_workout_plan');
            prefs.remove('has_meal_plan');
            prefs.remove('plan_duration');
            prefs.remove('duration_weeks_int');
          });
          setState(() => _currentIndex = 0);
          _workoutKey.currentState?.refresh(force: true);
          _mealPlanKey.currentState?.refresh();
          _progressKey.currentState?.refresh(force: true);
          _profileKey.currentState?.refresh();

        } else if (session != null) {
          // AUTHENTICATED: login / token restore / token refresh
          // Step 1: identify with real UUID (no-op if same user already identified)
          AnalyticsService().identifyUser(session.user.id);
          // Step 2: App Open - fires once per cold start, deduplicated by flag
          AnalyticsService().trackAppOpen();
          // Step 3: Refresh subscription status cache
          SubscriptionState().refresh();

          _cancelAuthTimer();
          _workoutKey.currentState?.refresh(force: true);
          _mealPlanKey.currentState?.refresh();
          _progressKey.currentState?.refresh(force: true);
          _profileKey.currentState?.refresh();

          if (AuthModal.isVisible && !AuthModal.isInMultiStep) {
            AuthModal.isVisible = false;
            Navigator.of(context, rootNavigator: true).pop();
            _isAuthModalOpen = false;
          }

        } else if (event == AuthChangeEvent.initialSession) {
          // GUEST: initialSession fired with session==null means user is not logged in.
          // This is the correct deterministic place to fire App Open for guests.
          // The 500ms fallback timer has been removed - it caused duplicate fires
          // on real devices when the auth stream arrived after the timer.
          AnalyticsService().trackAppOpen();

        } else {
          // OTHER NULL-SESSION EVENTS: tokenRefreshed, userUpdated, etc.
          final liveSession = Supabase.instance.client.auth.currentSession;
          if (liveSession == null && _hasInteracted) {
            _startAuthTimer();
          } else if (liveSession != null) {
            _cancelAuthTimer();
          }
        }
      }
    });

    _checkAuthStatus();

    // Safety fallback for guest App Open on real Android devices.
    // The AuthChangeEvent.initialSession may not fire on all Android versions.
    // This fires after 2s ONLY if App Open was not already tracked by the stream.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        AnalyticsService().trackAppOpen(); // no-op if already tracked (deduped by flag)
      }
    });

    // Do NOT start auth prompt timer here - wait for first user interaction.
  }

  void _onUserInteraction() {
    if (!_hasInteracted) {
      _hasInteracted = true;
      if (Supabase.instance.client.auth.currentSession == null) {
        print('First interaction detected. Starting Auth Timer...');
        _startAuthTimer();
      }
    }
  }

  Future<void> _checkAuthStatus() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session != null && user != null) {
      debugPrint('[MainScaffold] Auth check: user=${user.id}');

      // Safety net: identify the user here in case the auth stream event
      // was missed on real Android devices. identifyUser() is idempotent —
      // it skips if the same userId is already identified.
      AnalyticsService().identifyUser(user.id);

      try {
        // ALWAYS check Supabase — never skip based on local flags.
        // This is the only reliable gate for cross-device sessions.
        final response = await Supabase.instance.client
            .from('user_preferences')
            .select('user_id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null) {
          // User has a profile — keep local flags in sync as a convenience.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_workout_plan', true);
          await prefs.setBool('has_meal_plan', true);
          debugPrint('[MainScaffold] Returning user confirmed. Flags synced.');
        } else {
          debugPrint('[MainScaffold] No user_preferences row found for user.');
        }
      } catch (e) {
        debugPrint('[MainScaffold] Error in _checkAuthStatus: $e');
      }
    } else {
      debugPrint('[MainScaffold] No active session.');
    }

    if (mounted) {
      setState(() {
        if (session != null && user != null) {
          _isEmailVerified = user.emailConfirmedAt != null ||
              (user.appMetadata['provider'] != 'email');
        } else {
          _isEmailVerified = true;
        }
        _isLoadingAuth = false;
      });
    }
  }

  void _startAuthTimer() {
    // Don't schedule if user is already authenticated
    if (Supabase.instance.client.auth.currentSession != null) return;
    _cancelAuthTimer();
    _scheduleNextAuthPrompt();
  }

  Future<void> _scheduleNextAuthPrompt() async {
    // Capture the current scheduling generation so stale async calls become no-ops
    final myId = _schedulingId;

    final prefs = await SharedPreferences.getInstance();

    // If _cancelAuthTimer was called while we were awaiting, bail out
    if (!mounted || _schedulingId != myId) return;
    // If user signed in while we were awaiting SharedPreferences, bail out
    if (Supabase.instance.client.auth.currentSession != null) return;

    final lastDismissedStr = prefs.getString('authPromptDismissedAt');
    
    int delaySeconds = 20;
    
    if (lastDismissedStr != null) {
      final lastDismissed = DateTime.parse(lastDismissedStr);
      final now = DateTime.now();
      final difference = now.difference(lastDismissed).inSeconds;
      
      if (difference < 20 && difference >= 0) {
        delaySeconds = 20 - difference;
      }
    }
    
    print('Scheduling Auth Prompt in $delaySeconds seconds (Last dismissed: $lastDismissedStr)');

    _authTimer = Timer(Duration(seconds: delaySeconds), () {
      // Don't stack a second modal if the quiz (or any other code) already has one open
      if (AuthModal.isVisible) return;
      if (mounted && Supabase.instance.client.auth.currentSession == null) {
        _showAuthModal();
      }
    });
  }

  void _cancelAuthTimer() {
    _schedulingId++; // invalidates any in-flight _scheduleNextAuthPrompt calls
    _authTimer?.cancel();
    _authTimer = null;
  }

  Future<void> _showAuthModal() async {
    if (_isAuthModalOpen) return;
    if (AuthModal.isVisible) return; // Already open from quiz or elsewhere
    if (!mounted) return;

    _isAuthModalOpen = true;
    
    await AuthModal.show(context).then((_) async {
       if (mounted) {
         _isAuthModalOpen = false;
         
         if (Supabase.instance.client.auth.currentSession == null) {
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('authPromptDismissedAt', DateTime.now().toIso8601String());
           _startAuthTimer(); 
         }
       }
    });
  }
  
  // --- AUTH LOGIC END ---

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cancelAuthTimer();
    super.dispose();
  }

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _initializePages(); 
    }
  }

  Future<void> changeTab(int index) async {
    if (index == 1 || index == 2) {
      final prefs = await SharedPreferences.getInstance();

      // ── Apple-compliant: NO hard subscription gate here ───────────────────
      // Users can always enter Workout and Meal tabs.
      // Subscription promotion is handled by in-page banners and soft locks.
      // ─────────────────────────────────────────────────────────────────────

      bool hasWorkoutPlan = prefs.getBool('has_workout_plan') ?? false;
      bool hasMealPlan = prefs.getBool('has_meal_plan') ?? false;

      if (!hasWorkoutPlan && !hasMealPlan) {
        if (mounted) {
          final result = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, anim1, anim2) => CustomPlanQuizPage(
                quizType: index == 1 ? 'workout' : 'meal',
              ),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
          
          // Helper to inject plan
          void injectPlanIfPresent(dynamic res) {
             if (res is Map && res.containsKey('plan')) {
                print('DEBUG: MainScaffold received new plan -> Injecting into WorkoutPage');
                _workoutKey.currentState?.setPlan(res['plan']);
                _mealPlanKey.currentState?.refresh(); // Refresh meals too
                _profileKey.currentState?.refresh();  // Refresh profile stats
             } else if (res is Map && res['completed'] == true) {
                // Determine if we need to force reload if plan object missing but completed
               _workoutKey.currentState?.refresh(force: true);
               _mealPlanKey.currentState?.refresh(); // Refresh meals too
               _profileKey.currentState?.refresh();  // Refresh profile stats
             }
          }

          injectPlanIfPresent(result);
          
          if (result is Map && result.containsKey('navIndex')) {
            changeTab(result['navIndex']);
            return;
          }
          
          if (result is! Map || result['completed'] != true) {
             return;
          }
        }
      }
    }
    
    // Refresh Logic when tapping specifically on Tabs
    if (index == 1 && _currentIndex == 1) {
       // Only refresh if tapping the tab while already on it
       _workoutKey.currentState?.refresh(force: true);
    }
    
    if (index == 3) {
      _progressKey.currentState?.refresh(force: true);
    }
    
    if (mounted) {
      setState(() => _currentIndex = index);
      _trackCurrentScreen();
    }
  }

  /// Refreshes all content pages (called after quiz completion or login).
  void refreshAllPages() {
    _workoutKey.currentState?.refresh(force: true);
    _mealPlanKey.currentState?.refresh();
    _progressKey.currentState?.refresh(force: true);
    _profileKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    // PREVENT RENDER UNTIL SYNC COMPLETES
    if (_isLoadingAuth) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    // BLOCKING OTP UI
    if (Supabase.instance.client.auth.currentSession != null && !_isEmailVerified) {
       // ... (OTP UI Code remains same) ...
       return Scaffold(
         body: Container(
           width: double.infinity,
           height: double.infinity,
           child: Center(
             child: Padding(
               padding: const EdgeInsets.all(32.0),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.mark_email_unread_outlined, size: 64, color: Colors.red),
                   const SizedBox(height: 24),
                   const Text('Verify your email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   const Text(
                     'We sent a verification link/code to your email address. Please verify your account to continue.',
                     textAlign: TextAlign.center,
                     style: TextStyle(fontSize: 16, color: Colors.grey),
                   ),
                   const SizedBox(height: 32),
                   ElevatedButton(
                     onPressed: () async {
                        try {
                          final response = await Supabase.instance.client.auth.refreshSession();
                          if (response.user != null) {
                             await _checkAuthStatus(); // Update UI
                          }
                        } catch (e) {
                          try {
                             await Supabase.instance.client.auth.getUser(); 
                             await _checkAuthStatus();
                          } catch (e2) {}
                        }
                        
                        if (mounted && !_isEmailVerified) {
                           debugPrint('[AUTH] Still unverified. Please check email.');
                        }
                     },
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                     child: const Text('I have verified my email'),
                   ),
                   TextButton(
                     onPressed: () async {
                       await Supabase.instance.client.auth.signOut();
                     }, 
                     child: const Text('Sign Out', style: TextStyle(color: Colors.grey))
                   )
                 ],
               ),
             ),
           ),
         ),
       );
    }
  
    return Listener(
      onPointerDown: (_) => _onUserInteraction(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onUserInteraction();
          return false;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ... (Rest of build methods) ...
            final isDesktop = constraints.maxWidth > 800 && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android;
        
              if (isDesktop) {
                return Scaffold(
                  body: Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: Row(
                      children: [
                      SidebarDrawer(
                        currentIndex: _currentIndex,
                        onItemSelected: (index) {
                          if (index >= 0) {
                            changeTab(index);
                          }
                        },
                        isDarkMode: widget.isDarkMode,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) => false, // Handled by parent
                                child: IndexedStack(
                                  index: _currentIndex,
                                  children: _pages,
                                ),
                              ),
                            ),
                            WebFooter(
                              key: _footerKey,
                              isDarkMode: widget.isDarkMode,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
              
              return Scaffold(
                body: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
                bottomNavigationBar: GymBottomNavBar(
                  currentIndex: _currentIndex,
                  onTap: changeTab,
                  isDarkMode: widget.isDarkMode,
                ),
              );
          },
        ),
      ),
    );
  }
}
