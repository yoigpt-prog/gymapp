import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Auth Timer State
  Timer? _authTimer;
  bool _isAuthModalOpen = false;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isEmailVerified = true; 
  bool _isLoadingAuth = true;
  bool _hasInteracted = false; // New Interaction Flag

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializePages();
    _initAuthLogic();
  }

  void _initializePages() {
     _pages = [
      HomePage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      WorkoutPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      MealPlanPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      ProgressPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      ProfilePage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      SettingsPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      BmiCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      CalorieCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      MacroCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      BodyFatCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      OneRmCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
    ];
  }

  // --- AUTH LOGIC START ---

  void _initAuthLogic() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      
      if (mounted) {
        _checkAuthStatus();
        
        if (session != null) {
          _cancelAuthTimer();
          if (_isAuthModalOpen) {
            Navigator.of(context, rootNavigator: true).pop(); 
          }
        } else {
          // If logged out, wait for interaction again? Or restart immediately if already interacted?
          // User request implies "first enter count after first user click".
          // If they were logged in and then logged out, they are "active", so maybe start timer?
          // Let's stick to strict "if _hasInteracted" trigger.
          if (_hasInteracted) {
             _startAuthTimer();
          }
        }
      }
    });

    _checkAuthStatus();
    // Do NOT start timer here automatically. Wait for interaction.
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
    
    if (mounted) {
      setState(() {
        if (session != null && user != null) {
           _isEmailVerified = user.emailConfirmedAt != null || (user.appMetadata['provider'] != 'email');
        } else {
           _isEmailVerified = true;
        }
        _isLoadingAuth = false;
      });
    }
  }

  void _startAuthTimer() {
    _cancelAuthTimer(); 
    _scheduleNextAuthPrompt();
  }

  Future<void> _scheduleNextAuthPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDismissedStr = prefs.getString('authPromptDismissedAt');
    
    int delaySeconds = 20; // Updated to 20s
    
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
      if (mounted && Supabase.instance.client.auth.currentSession == null) {
        _showAuthModal();
      }
    });
  }

  void _cancelAuthTimer() {
    _authTimer?.cancel();
    _authTimer = null;
  }

  Future<void> _showAuthModal() async {
    if (_isAuthModalOpen) return;
    if (!mounted) return;

    _isAuthModalOpen = true;
    
    await showDialog(
      context: context,
      barrierDismissible: true, 
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: AuthModal(),
      ),
    ).then((_) async {
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

  void changeTab(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _handleTabChange(int index) async {
    if (index == 1 || index == 2) {
      final prefs = await SharedPreferences.getInstance();
      final hasWorkoutPlan = prefs.getBool('has_workout_plan') ?? false;
      final hasMealPlan = prefs.getBool('has_meal_plan') ?? false;
      
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
          
          if (result is Map && result.containsKey('navIndex')) {
            _handleTabChange(result['navIndex']);
            return;
          }
          
          if (result is! Map || result['completed'] != true) {
            return;
          }
        }
      }
    }
    
    changeTab(index);
  }

  @override
  Widget build(BuildContext context) {
    // BLOCKING OTP UI
    if (!_isLoadingAuth && Supabase.instance.client.auth.currentSession != null && !_isEmailVerified) {
       // ... (OTP UI Code remains same) ...
       return Scaffold(
         body: Center(
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
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Still unverified. Please check your email.')));
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
            final isDesktop = constraints.maxWidth > 800;
        
              if (isDesktop) {
                return Scaffold(
                  body: Row(
                    children: [
                      SidebarDrawer(
                        currentIndex: _currentIndex,
                        onItemSelected: (index) {
                          if (index >= 0) {
                            _handleTabChange(index);
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
                );
              }
              
              return Scaffold(
                body: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
                bottomNavigationBar: GymBottomNavBar(
                  currentIndex: _currentIndex,
                  onTap: _handleTabChange,
                  isDarkMode: widget.isDarkMode,
                ),
              );
          },
        ),
      ),
    );
  }
}
