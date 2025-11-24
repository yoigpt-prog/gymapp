import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/workout_page.dart';
import 'pages/meal_plan_page.dart';
import 'pages/progress_page.dart';
import 'package:gymguide_app/pages/more_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wewztpamzhrzbbgyutyf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws',
  );

  runApp(const GymGuideApp());
}

class GymGuideApp extends StatefulWidget {
  const GymGuideApp({Key? key}) : super(key: key);

  @override
  State<GymGuideApp> createState() => _GymGuideAppState();
}

class _GymGuideAppState extends State<GymGuideApp> {
  ThemeMode _themeMode = ThemeMode.light; // Default to Light (White)

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymGuide',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        primarySwatch: Colors.red,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primarySwatch: Colors.red,
      ),
      home: MainScaffold(
        toggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MainScaffold({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      const WorkoutPage(),
      const MealPlanPage(),
      const ProgressPage(),
      MorePage(
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
      _pages[4] = MorePage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red, // Active item color
        unselectedItemColor: widget.isDarkMode ? Colors.white70 : Colors.grey,
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workout'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Meal Plan'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
