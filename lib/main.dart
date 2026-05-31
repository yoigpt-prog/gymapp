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
import 'config/env_config.dart';
import 'widgets/staging_banner.dart';
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
import 'pages/legal/about_app_page.dart';
import 'pages/legal/about_us_web_page.dart';
import 'pages/legal/faq_page.dart';
import 'pages/legal/sitemap_page.dart';
import 'pages/blog_page.dart';
import 'pages/blog_detail_page.dart';
import 'data/blog_content.dart';
import 'data/blog_articles.dart';
import 'pages/exercise_page.dart';
import 'pages/download_page.dart';
import '../widgets/auth/auth_modal.dart';
import 'pages/auth_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/main_scaffold.dart';
import 'pages/ai/ai_transformation_share_page.dart';
import 'pages/ai/ai_transformation_page.dart';
import 'pages/ai/physique_scan_page.dart';
import 'pages/welcome_screen.dart';
import 'services/revenue_cat_service.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/notification_sync_service.dart';
import 'pages/calculators/bmi_calculator_page.dart';
import 'package:seo/seo.dart';
import 'pages/calculators/calorie_calculator_page.dart';
import 'pages/calculators/macro_calculator_page.dart';
import 'pages/calculators/body_fat_calculator_page.dart';
import 'pages/calculators/one_rm_calculator_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'widgets/auth/auth_modal.dart' show googleSignInInitialized;

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('[ENV] Running in ${EnvConfig.displayName} mode');
  debugPrint('[AI Start Log] Current URL: ${Uri.base}');
  debugPrint('[AI Start Log] Path: ${Uri.base.path}');
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  NotificationSyncService.initializeAuthListener();

  // Initialize RevenueCat (no-op on Web)
  await RevenueCatService().initialize();

  // Initialize PostHog analytics SDK only — no identity or event tracking here.
  // Supabase session is NOT guaranteed to be restored by this point on real devices.
  // All identity (identifyUser) and tracking (trackAppOpen) happen inside
  // MainScaffold._initAuthLogic() via the Supabase auth state stream.
  await AnalyticsService().initialize();

  // Pre-initialize Google Sign-In so it's warm before the user taps the button.
  // Only on mobile — web uses Supabase OAuth redirect instead.
  if (!kIsWeb) {
    unawaited(GoogleSignIn.instance.initialize(
      serverClientId:
          '632794058416-9jq69n9p2jncp386teqi5g9obgrdvtik.apps.googleusercontent.com',
    ).then((_) {
      googleSignInInitialized = true;
      debugPrint('[GOOGLE] Pre-initialized ✅');
    }).catchError((e) {
      debugPrint('[GOOGLE] Pre-init failed (will retry on tap): $e');
    }));
  }

  runApp(const GymGuideApp());
}


class GymGuideApp extends StatefulWidget {
  const GymGuideApp({Key? key}) : super(key: key);

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<GymGuideApp> createState() => _GymGuideAppState();
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Builds a [PageRouteBuilder] that fades in the new page.
PageRouteBuilder<T> _fadeRoute<T>({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, _) => builder(context),
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _GymGuideAppState extends State<GymGuideApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isDark = false;
  bool _overlayActive = false;
  Color _fadeColor = const Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _isDark = _themeMode == ThemeMode.dark;
    
    // Initialize Push Notifications
    PushNotificationService().initialize(GymGuideApp.navigatorKey);
  }

  void _toggleTheme() async {
    if (_overlayActive) return; // Prevent double-taps

    // 1. Fade to the target theme's background color
    setState(() {
      _fadeColor = _isDark ? Colors.white : const Color(0xFF121212);
      _overlayActive = true;
    });

    // 2. Wait for the overlay to become fully opaque
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    // 3. Flip the actual theme while the screen is hidden
    setState(() {
      _isDark = !_isDark;
      _themeMode = _isDark ? ThemeMode.dark : ThemeMode.light;
    });

    // 4. Give the UI a tiny moment to build the new colors
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    // 5. Fade the overlay back out to reveal the new theme smoothly
    setState(() {
      _overlayActive = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    const pageTransitionsTheme = PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: NoTransitionsBuilder(),
        TargetPlatform.iOS: NoTransitionsBuilder(),
        TargetPlatform.macOS: NoTransitionsBuilder(),
      },
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          StagingBanner(
            child: SeoController(
            enabled: true,
            tree: WidgetTree(context: context),
            child: MaterialApp(
        navigatorKey: GymGuideApp.navigatorKey,
        title: 'GymGuide',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFFFFFF),
          primarySwatch: Colors.red,
          pageTransitionsTheme: pageTransitionsTheme,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          primarySwatch: Colors.red,
          pageTransitionsTheme: pageTransitionsTheme,
        ),
        initialRoute: kIsWeb ? Uri.base.path : '/',
        onGenerateInitialRoutes: (initialRoute) {
          debugPrint('[Router] onGenerateInitialRoutes: initialRoute=$initialRoute');
          
          if (!kIsWeb) {
            try {
              // Add a fake host to parse query parameters even for simple paths like /?visitor_id=XYZ
              final uri = Uri.tryParse('http://localhost$initialRoute');
              if (uri != null && uri.queryParameters.containsKey('visitor_id')) {
                AnalyticsService().setSourceVisitorId(uri.queryParameters['visitor_id']!);
              }
            } catch (e) {
              debugPrint('[Router] initialRoute parse error: $e');
            }
          }

          if (initialRoute.startsWith('/transformation/share/')) {
            var token = initialRoute.substring('/transformation/share/'.length);
            if (token.contains('?')) {
              token = token.split('?').first;
            }
            if (token.contains('#')) {
              token = token.split('#').first;
            }
            token = token.replaceAll('/', '');
            debugPrint('[Router] Initial route is share page. token=$token');
            return [
              MaterialPageRoute(
                builder: (context) => AITransformationSharePage(shareToken: token),
                settings: RouteSettings(name: initialRoute),
              ),
            ];
          }
          if (initialRoute.startsWith('/exercise/')) {
            var slug = initialRoute.substring('/exercise/'.length);
            if (slug.contains('?')) {
              slug = slug.split('?').first;
            }
            if (slug.contains('#')) {
              slug = slug.split('#').first;
            }
            slug = slug.replaceAll('/', '');
            debugPrint('[Router] Initial route is exercise page. slug=$slug');
            return [
              MaterialPageRoute(
                builder: (context) => ExercisePage(slug: slug, toggleTheme: _toggleTheme),
                settings: RouteSettings(name: initialRoute),
              ),
            ];
          }
          return [
            MaterialPageRoute(
              builder: (context) => MainScaffold(
                key: MainScaffold.globalKey,
                initialIndex: 0,
                toggleTheme: _toggleTheme,
                isDarkMode: _themeMode == ThemeMode.dark,
              ),
              settings: RouteSettings(name: '/'),
            ),
          ];
        },
        onGenerateRoute: (settings) {
        if (EnvConfig.isStaging) {
          debugPrint('[Router] onGenerateRoute: name=${settings.name} arguments=${settings.arguments}');
        }
        WidgetBuilder? builder;
        
        // Handle deep links for exercises
        if (settings.name != null && settings.name!.startsWith('/transformation/share/')) {
          final token = settings.name!.substring('/transformation/share/'.length);
          builder = (context) => AITransformationSharePage(shareToken: token);
        } else if (settings.name != null && settings.name!.startsWith('/exercise/')) {
          final slug = settings.name!.substring('/exercise/'.length);
          builder = (context) => ExercisePage(slug: slug, toggleTheme: _toggleTheme);
        } else if (settings.name != null && settings.name!.startsWith('/blog/')) {
          final slug = settings.name!.substring('/blog/'.length);
          // Find article by slug, or default to first if not found to avoid crash
          final article = blogArticles.firstWhere(
            (a) => a['slug'] == slug, 
            orElse: () => blogArticles.first,
          );
          builder = (context) => BlogDetailPage(
                title: article['title']!,
                description: article['desc']!,
                imagePath: article['image']!,
                filePath: article['file']!,
                category: article['category'] ?? 'EDITORIAL',
                toggleTheme: _toggleTheme,
              );
        } else {
          switch (settings.name) {
            case '/':
            builder = (context) => MainScaffold(
                    key: MainScaffold.globalKey,
                    initialIndex: 0,
                    toggleTheme: _toggleTheme,
                    isDarkMode: _themeMode == ThemeMode.dark,
                  );
            break;
          case '/home':
            builder = (context) => MainScaffold(
                    initialIndex: 0,
                    toggleTheme: _toggleTheme,
                    isDarkMode: _themeMode == ThemeMode.dark,
                  );
            break;
          case '/workout':
            builder = (context) => MainScaffold(
                    initialIndex: 1,
                    toggleTheme: _toggleTheme,
                    isDarkMode: _themeMode == ThemeMode.dark,
                  );
            break;
          case '/meal-plan':
            builder = (context) => MainScaffold(
                    initialIndex: 2,
                    toggleTheme: _toggleTheme,
                    isDarkMode: _themeMode == ThemeMode.dark,
                  );
            break;
          case '/progress':
            builder = (context) => MainScaffold(
                    initialIndex: 3,
                    toggleTheme: _toggleTheme,
                    isDarkMode: _themeMode == ThemeMode.dark,
                  );
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
          case '/about':
            builder = (context) => kIsWeb
                ? AboutUsWebPage(toggleTheme: _toggleTheme)
                : AboutAppPage(toggleTheme: _toggleTheme);
            break;
          case '/faq':
            builder = (context) => FaqPage(toggleTheme: _toggleTheme);
            break;
          case '/sitemap':
            builder = (context) => SitemapPage(toggleTheme: _toggleTheme);
            break;
          case '/Blog':
            builder = (context) => BlogPage(toggleTheme: _toggleTheme);
            break;
          case '/download':
            builder = (context) => DownloadPage(toggleTheme: _toggleTheme);
            break;
          case '/ai-transformation-simulator':
            builder = (context) => AITransformationPage(isDarkMode: _themeMode == ThemeMode.dark);
            break;
          case '/rate-your-body':
            builder = (context) => PhysiqueScanPage(isDarkMode: _themeMode == ThemeMode.dark);
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
        }

        // Main scaffold routes — instant (tab switching handled internally)
        if (builder != null && [
          '/', '/home', '/workout', '/meal-plan', '/progress', '/profile', '/settings',
          '/calculators/bmi', '/calculators/calorie',
          '/calculators/macro', '/calculators/body-fat', '/calculators/one-rm',
        ].contains(settings.name)) {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) => builder!(context),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          );
        }

        // Footer / legal pages — smooth fade in
        if (builder != null) {
          return _fadeRoute(settings: settings, builder: builder!);
        }
        return null;
      },
      // home: const AuthWrapper(), // Disabled for now
      ), // MaterialApp
      ), // SeoController
      ), // StagingBanner
      
      // The smooth fade overlay (sits on top of everything)
      IgnorePointer(
        child: AnimatedOpacity(
          opacity: _overlayActive ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Container(color: _fadeColor),
        ),
      ),
      ], // Stack children
      ), // Stack
    ); // Directionality
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

    // Listen for auth state changes.
    // On Flutter Web the initial session is restored asynchronously —
    // this stream fires once with AuthChangeEvent.initialSession when ready.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('[AuthWrapper] Event: ${data.event}  user=${data.session?.user.id}');
      // Skip events that don't affect the user session state
      if (data.event == AuthChangeEvent.passwordRecovery) return;
      _checkAuthState(event: data.event);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState({AuthChangeEvent? event}) async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session == null || user == null) {
      debugPrint('[AuthWrapper] No session — showing AuthPage.');
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _hasProfile = false;
          _isLoading = false;
        });
      }
      return;
    }

    debugPrint('[AuthWrapper] Session confirmed for user: ${user.id}');

    // Always query Supabase to determine profile state. Never skip.
    try {
      final response = await Supabase.instance.client
          .from('user_preferences')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final hasProfile = response != null;
      debugPrint('[AuthWrapper] has_profile=$hasProfile for user=${user.id}');

      if (mounted) {
        if (event == AuthChangeEvent.signedOut) {
          AnalyticsService().reset();
        }

        if (hasProfile) {
          // Sync convenience flags for use by local code paths.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_workout_plan', true);
          await prefs.setBool('has_meal_plan', true);
        }

        setState(() {
          _isAuthenticated = true;
          _hasProfile = hasProfile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AuthWrapper] Error checking profile: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _hasProfile = false; // Default to safe: show onboarding check
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
      key: MainScaffold.globalKey,
      toggleTheme: appState?._toggleTheme ?? () {},
      isDarkMode: appState?._themeMode == ThemeMode.dark,
    );
  }
}

