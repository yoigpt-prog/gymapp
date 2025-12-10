import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'workout_page.dart';
import 'meal_plan_page.dart';
import 'progress_page.dart';
import 'progress_page.dart';
import 'profile_page.dart';
import 'more_page.dart'; // Keeping for now if referenced elsewhere, but MainScaffold uses SettingsPage class which is in more_page.dart file currently? No, I renamed the class in more_page.dart.
// Wait, I renamed the class in more_page.dart to SettingsPage, but the file is still more_page.dart.
// I should probably rename the file too, but for now I'll just import it.
// Actually, I should check if I renamed the file. I didn't.
// So 'more_page.dart' now contains 'SettingsPage'.
// And I created 'profile_page.dart'.
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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize pages if theme props change (simple way to propagate)
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _pages[0] = HomePage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[1] = WorkoutPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[2] = MealPlanPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[3] = ProgressPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[4] = ProfilePage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[5] = SettingsPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[6] = BmiCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[7] = CalorieCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[8] = MacroCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[9] = BodyFatCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
      _pages[10] = OneRmCalculatorPage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
    }
  }

  void changeTab(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _handleTabChange(int index) async {
    // Check if user is trying to access Workout or Meal Plan tabs
    if (index == 1 || index == 2) {
      final prefs = await SharedPreferences.getInstance();
      final hasWorkoutPlan = prefs.getBool('has_workout_plan') ?? false;
      final hasMealPlan = prefs.getBool('has_meal_plan') ?? false;
      
      // If user hasn't completed quiz, show it
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
          
          // Handle navigation from quiz
          if (result is Map && result.containsKey('navIndex')) {
            _handleTabChange(result['navIndex']);
            return;
          }
          
          // Don't change tab if quiz wasn't completed
          if (result is! Map || result['completed'] != true) {
            return;
          }
        }
      }
    }
    
    // Change to the selected tab
    changeTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        
        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                // Permanent Sidebar for Desktop
                SidebarDrawer(
                  currentIndex: _currentIndex,
                  onItemSelected: (index) {
                    if (index >= 0) {
                      _handleTabChange(index);
                    }
                  },
                  isDarkMode: widget.isDarkMode,
                ),
                // Main Content with Footer
                Expanded(
                  child: Column(
                    children: [
                      // Main Content Area
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            // Footer scroll logic disabled
                            // _footerKey.currentState?.onScroll(notification);
                            return false;
                          },
                          child: IndexedStack(
                            index: _currentIndex,
                            children: _pages,
                          ),
                        ),
                      ),
                      
                      // Footer (Fixed at bottom)
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
    );
  }
}
