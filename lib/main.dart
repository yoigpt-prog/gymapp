import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/workout_page.dart';
import 'pages/meal_plan_page.dart';
import 'pages/progress_page.dart';
import 'package:gymguide_app/pages/more_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/auth_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/main_scaffold.dart'; // New import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://your-project-url.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_KEY_HERE',
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
      // home: const AuthWrapper(), // Disabled for now
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _hasName = false;

  @override
  void initState() {
    super.initState();

    _checkAuthState();
    
    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {

      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {

    // FOR DEBUGGING: Force Onboarding state
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _isAuthenticated = true;
        _hasName = false;
        _isLoading = false;
      });

      return;
    }

    /* 
    // Original logic
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null) {
      // Check if user has a name in metadata
      final user = Supabase.instance.client.auth.currentUser;
      final name = user?.userMetadata?['full_name'];
      
      setState(() {
        _isAuthenticated = true;
        _hasName = name != null && name.toString().isNotEmpty;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAuthenticated = false;
        _hasName = false;
        _isLoading = false;
      });
    }
    */
  }

  @override
  Widget build(BuildContext context) {

    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    if (!_isAuthenticated) {
      return const AuthPage();
    }

    if (!_hasName) {
      return const OnboardingPage();
    }

    // Pass theme callback down the tree - finding the ancestor state
    final appState = context.findAncestorStateOfType<_GymGuideAppState>();
    return MainScaffold(
      toggleTheme: appState?._toggleTheme ?? () {},
      isDarkMode: appState?._themeMode == ThemeMode.dark,
    );
  }
}

