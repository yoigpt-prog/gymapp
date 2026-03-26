import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'pages/home_page.dart';
import 'pages/workout_page.dart';
import 'pages/meal_plan_page.dart';
import 'pages/progress_page.dart';
import 'package:gymguide_app/pages/more_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/legal/disclaimer_page.dart';
import 'pages/legal/subscription_terms_page.dart';
import 'pages/legal/data_export_page.dart';
import 'pages/legal/ai_transparency_page.dart';
import 'pages/legal/privacy_policy_page.dart';
import 'pages/legal/privacy_policy_page.dart';
import 'pages/legal/terms_of_service_page.dart';
import 'pages/legal/delete_account_page.dart';
import 'pages/legal/copyright_page.dart';
import 'pages/legal/age_requirement_page.dart';
import 'pages/legal/contact_support_page.dart';
import '../widgets/auth/auth_modal.dart';
import 'pages/auth_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/main_scaffold.dart';
import 'services/revenue_cat_service.dart';
import 'pages/calculators/bmi_calculator_page.dart';
import 'pages/calculators/calorie_calculator_page.dart';
import 'pages/calculators/macro_calculator_page.dart';
import 'pages/calculators/body_fat_calculator_page.dart';
import 'pages/calculators/one_rm_calculator_page.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wewztpamzhrzbbgyutyf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws',
  );

  // Initialize RevenueCat (no-op on Web)
  await RevenueCatService().initialize();

  runApp(const GymGuideApp());
}


class GymGuideApp extends StatefulWidget {
  const GymGuideApp({Key? key}) : super(key: key);

  @override
  State<GymGuideApp> createState() => _GymGuideAppState();
}

class _GymGuideAppState extends State<GymGuideApp> {
  ThemeMode _themeMode = ThemeMode.light; // Default to Light (White)

  @override
  void initState() {
    super.initState();
    // Check if the user needs to see the paywall on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RevenueCatService().presentPaywallIfNeeded();
    });
  }

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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        WidgetBuilder? builder;
        switch (settings.name) {
          case '/':
            builder = (context) => MainScaffold(initialIndex: 0, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/eula':
            builder = (context) => TermsOfServicePage(toggleTheme: _toggleTheme);
            break;
          case '/privacy':
            builder = (context) => PrivacyPolicyPage(toggleTheme: _toggleTheme);
            break;
          case '/terms':
            builder = (context) => TermsOfServicePage(toggleTheme: _toggleTheme);
            break;
          case '/disclaimer':
            builder = (context) => DisclaimerPage(toggleTheme: _toggleTheme);
            break;
          case '/subscription-terms':
            builder = (context) => SubscriptionTermsPage(toggleTheme: _toggleTheme);
            break;
          case '/data-export':
            builder = (context) => DataExportPage(toggleTheme: _toggleTheme);
            break;
          case '/ai-transparency':
            builder = (context) => AITransparencyPage(toggleTheme: _toggleTheme);
            break;
          case '/delete-account':
            builder = (context) => DeleteAccountPage(toggleTheme: _toggleTheme);
            break;
          case '/copyright':
            builder = (context) => CopyrightPage(toggleTheme: _toggleTheme);
            break;
          case '/age-requirement':
            builder = (context) => AgeRequirementPage(toggleTheme: _toggleTheme);
            break;
          case '/contact':
            builder = (context) => ContactSupportPage(toggleTheme: _toggleTheme);
            break;
          case '/calculators/bmi':
            builder = (context) => MainScaffold(initialIndex: 6, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/calculators/calorie':
            builder = (context) => MainScaffold(initialIndex: 7, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/calculators/macro':
            builder = (context) => MainScaffold(initialIndex: 8, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/calculators/body-fat':
            builder = (context) => MainScaffold(initialIndex: 9, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/calculators/one-rm':
            builder = (context) => MainScaffold(initialIndex: 10, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/profile':
            builder = (context) => MainScaffold(initialIndex: 4, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/settings':
            builder = (context) => MainScaffold(initialIndex: 5, toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark);
            break;
        }

        if (builder != null) {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) => builder!(context),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          );
        }
        return null;
      },
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
  bool _hasProfile = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen for auth state changes (will fire initially and on any login/logout)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _checkAuthState();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session == null || user == null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _hasProfile = false;
          _isLoading = false;
        });
      }
      return;
    }

    // User is authenticated, now check if they have a profile (user_preferences)
    try {
      final response = await Supabase.instance.client
          .from('user_preferences')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        if (response != null) {
          // Sync missing SharedPreferences for returning users on new devices
          // to prevent them from being forced into the onboarding quiz.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_workout_plan', true);
          await prefs.setBool('has_meal_plan', true);
        }

        setState(() {
          _isAuthenticated = true;
          _hasProfile = response != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Auth] Error checking profile: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _hasProfile = false;
          _isLoading = false;
        });
      }
    }
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

    if (!_hasProfile) {
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

