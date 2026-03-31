import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io';
import 'package:flutter/foundation.dart'; // Removed for web compatibility
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../widgets/red_header.dart';
import 'legal/privacy_policy_page.dart';
import 'legal/terms_of_service_page.dart';
import 'legal/disclaimer_page.dart';
import 'legal/subscription_terms_page.dart';
import 'legal/data_export_page.dart';
import 'legal/delete_account_page.dart';
import 'legal/copyright_page.dart';
import 'legal/age_requirement_page.dart';
import 'legal/ai_transparency_page.dart';
import 'legal/contact_support_page.dart';
import 'legal/about_app_page.dart';
import '../widgets/desktop_right_panel.dart';
import 'calculators/bmi_calculator_page.dart';
import 'calculators/calorie_calculator_page.dart';
import 'calculators/macro_calculator_page.dart';
import 'calculators/body_fat_calculator_page.dart';
import 'calculators/one_rm_calculator_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const ProfilePage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  // Profile image state
  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();
  // Persisted image key in SharedPreferences
  static const String _kProfileImageKey = 'profile_image_bytes_b64';

  // User profile data
  String _userName = 'Guest User';
  String _userEmail = 'guest@gymguide.co';
  String _memberSince = '';

  // Physical stats
  Map<String, dynamic> _userStats = {
    'height': '',
    'weight': '',
    'age': '',
    'gender': '',
    'goal': '',
    'target_weight': '',
    'activity_level': '',
    'diet': '',
  };

  final ScrollController _scrollController = ScrollController();

  /// Called by MainScaffold after the quiz completes so the profile
  /// refreshes without navigating away and back.
  void refresh() => _loadUserData();

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadUserData();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString(_kProfileImageKey);
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        if (mounted) {
          setState(() {
            _profileImageBytes = bytes;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;

    setState(() {
      _userName = user?.userMetadata?['full_name'] ?? 'Guest User';
      _userEmail = user?.email ?? 'guest@gymguide.co';

      // Member Since: derive from user creation date
      if (user?.createdAt != null) {
        try {
          final dt = DateTime.parse(user!.createdAt);
          const months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ];
          _memberSince = '${months[dt.month - 1]} ${dt.year}';
        } catch (_) {}
      }
    });

    if (user != null) {
      try {
        final profileStats = await SupabaseService().getProfileStats();
        if (profileStats != null) {
          String goalDisplay(String? g) {
            switch (g) {
              case 'fat_loss': return 'Lose Weight';
              case 'muscle_gain': return 'Build Muscle';
              default: return g ?? '';
            }
          }

          String cap(String? s) => (s != null && s.isNotEmpty)
              ? s[0].toUpperCase() + s.substring(1)
              : '';

          if (mounted) {
            final prefs = await SharedPreferences.getInstance();
            final unit = prefs.getString('weight_unit') ?? 'kg';
            final multiplier = unit == 'lbs' ? 2.20462 : 1.0;

            setState(() {
              if (profileStats['height_cm'] != null) {
                _userStats['height'] = profileStats['height_cm'].toString();
              }
              if (profileStats['weight_kg'] != null) {
                final w = (profileStats['weight_kg'] as num).toDouble() * multiplier;
                _userStats['weight'] = '${w.toStringAsFixed(1)} $unit';
              }
              if (profileStats['target_weight_kg'] != null) {
                final tw = (profileStats['target_weight_kg'] as num).toDouble() * multiplier;
                _userStats['target_weight'] = '${tw.toStringAsFixed(1)} $unit';
              }
              if (profileStats['age'] != null) {
                _userStats['age'] = profileStats['age'].toString();
              }
              if (profileStats['goal'] != null) {
                _userStats['goal'] = goalDisplay(profileStats['goal'] as String?);
              }
              if (profileStats['gender'] != null) {
                _userStats['gender'] = cap(profileStats['gender'] as String?);
              }
            });
          }
        }
      } catch (e) {
        debugPrint('[PROFILE] Could not fetch user_preferences: $e');
      }
    }

    // 3. Apply defaults for anything still empty
    if (mounted) {
      setState(() {
        if (_userStats['height']!.isEmpty) _userStats['height'] = '— cm';
        if (_userStats['weight']!.isEmpty) _userStats['weight'] = '— kg';
        if (_userStats['target_weight']!.isEmpty) _userStats['target_weight'] = '— kg';
        if (_userStats['age']!.isEmpty) _userStats['age'] = '—';
        if (_userStats['gender']!.isEmpty) _userStats['gender'] = '—';
        if (_userStats['goal']!.isEmpty) _userStats['goal'] = '—';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        // Persist image locally as base64
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kProfileImageKey, base64Encode(bytes));
        if (mounted) {
          setState(() {
            _profileImageBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint('[PROFILE ERROR] Picking image: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        debugPrint('[PROFILE] Logged out successfully');
        _loadUserData(); // Update UI to show Guest
      }
    } catch (e) {
      debugPrint('[PROFILE ERROR] Signing out: $e');
    }
  }

  void _shareApp() {
    const appUrl = 'https://gymguide.co';
    const shareText =
        '💪 Join me on GymGuide – your personal AI fitness coach! '
        'Get custom workout & meal plans in 2 minutes. $appUrl';

    // Bottom sheet with share options
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final isDark = widget.isDarkMode;
        final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final txt = isDark ? Colors.white : Colors.black87;
        final sub = isDark ? Colors.white70 : Colors.black54;
        return Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Share GymGuide',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: txt)),
              const SizedBox(height: 8),
              Text(
                  'Invite your friends & family to start their fitness journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: sub)),
              const SizedBox(height: 24),
              // Share buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    icon: Icons.link,
                    label: 'Copy Link',
                    color: const Color(0xFF607D8B),
                    onTap: () {
                      Navigator.pop(context);
                      // Copy to clipboard
                      _copyToClipboard(appUrl);
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.message_outlined,
                    label: 'Message',
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.pop(context);
                      _openShareUrl(
                          'sms:?body=${Uri.encodeComponent(shareText)}');
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    color: const Color(0xFFFF5722),
                    onTap: () {
                      Navigator.pop(context);
                      _openShareUrl(
                        'mailto:?subject=${Uri.encodeComponent("GymGuide – AI Fitness Coach")}'
                        '&body=${Uri.encodeComponent(shareText)}',
                      );
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.facebook,
                    label: 'Facebook',
                    color: const Color(0xFF1877F2),
                    onTap: () {
                      Navigator.pop(context);
                      _openShareUrl(
                        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(appUrl)}',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              )),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    // Show a lightweight confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openShareUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this option on your device.')),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final heightController = TextEditingController(text: _userStats['height']?.replaceAll(' cm', ''));
    final weightController = TextEditingController(text: _userStats['weight']?.replaceAll(RegExp(r' (kg|lbs)'), ''));
    final targetWeightController = TextEditingController(text: _userStats['target_weight']?.replaceAll(RegExp(r' (kg|lbs)'), ''));
    final ageController = TextEditingController(text: _userStats['age']);
    const genderOptions = ['Male', 'Female', 'Other'];
    const goalOptions = [
      'Build Muscle',
      'Lose Weight',
      'Improve Fitness',
      'Maintain Weight',
      'Gain Strength'
    ];

    String selectedGender = genderOptions.contains(_userStats['gender'])
        ? _userStats['gender']
        : genderOptions.first;
    String selectedGoal = goalOptions.contains(_userStats['goal'])
        ? _userStats['goal']
        : goalOptions.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height (e.g., 180 cm)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (e.g., 75)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: targetWeightController,
                  decoration: const InputDecoration(
                    labelText: 'Target Weight (e.g., 70)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGender = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGoal,
                  decoration: const InputDecoration(
                    labelText: 'Fitness Goal',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Build Muscle',
                    'Lose Weight',
                    'Improve Fitness',
                    'Maintain Weight',
                    'Gain Strength',
                  ]
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGoal = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final unit = prefs.getString('weight_unit') ?? 'kg';
                final saveMultiplier = unit == 'lbs' ? 0.453592 : 1.0;

                // Save to Supabase
                final hNum = double.tryParse(heightController.text.replaceAll(RegExp(r'[^\d.]'), ''));
                final wNumRaw = double.tryParse(weightController.text.replaceAll(RegExp(r'[^\d.]'), ''));
                final wNum = wNumRaw != null ? wNumRaw * saveMultiplier : null;
                
                final aNum = int.tryParse(ageController.text.replaceAll(RegExp(r'[^\d.]'), ''));
                
                final twNumRaw = double.tryParse(targetWeightController.text.replaceAll(RegExp(r'[^\d.]'), ''));
                final twNum = twNumRaw != null ? twNumRaw * saveMultiplier : null;

                String dbGoal = selectedGoal;
                if (selectedGoal == 'Lose Weight') dbGoal = 'fat_loss';
                if (selectedGoal == 'Build Muscle') dbGoal = 'muscle_gain';

                await SupabaseService().updateProfileStats(
                  name: nameController.text,
                  height: hNum,
                  weight: wNum,
                  targetWeight: twNum,
                  age: aNum,
                  gender: selectedGender.toLowerCase(), // Store lowercase standard
                  goal: dbGoal,
                );

                setState(() {
                  _userName = nameController.text;
                  _userStats['height'] = '${hNum ?? '—'} cm';
                  _userStats['weight'] = '${wNum ?? '—'} kg';
                  _userStats['target_weight'] = '${twNum ?? '—'} kg';
                  _userStats['age'] = '${aNum ?? '—'}';
                  _userStats['gender'] = selectedGender;
                  _userStats['goal'] = selectedGoal;
                });

                Navigator.pop(context);
                debugPrint('[PROFILE] Profile updated successfully');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800 && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android;

        if (isDesktop) {
          return _buildDesktopLayout();
        }

        return _buildMobileLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            RedHeader(
              title: 'Profile',
              subtitle: 'Your Fitness Journey',
              onToggleTheme: widget.toggleTheme,
              isDarkMode: widget.isDarkMode,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive ad panel: 22% of screen width, clamped to [200, 320]
                  final adPanelWidth = (constraints.maxWidth * 0.22).clamp(200.0, 320.0);

                  const double spacing = 16.0;

                  return Stack(
                    children: [
                      // Layer 1: Scrollable Content with Scrollbar on far right
                      Positioned.fill(
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(spacing),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 1200),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left Column: User Profile Card
                                          SizedBox(
                                            width: 350,
                                            child: _buildUserProfileCard(),
                                          ),
                                          const SizedBox(width: 24),

                                          // Right Column: Stats & Goals Grid
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildSectionTitle('Physical Stats'),
                                                const SizedBox(height: 16),
                                                _buildStatsGrid(),
                                                const SizedBox(height: 32),
                                                _buildSectionTitle('Goals & Preferences'),
                                                const SizedBox(height: 16),
                                                _buildGoalsGrid(),
                                                const SizedBox(height: 24),
                                                _buildResetPlanCard(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: spacing),
                                SizedBox(width: adPanelWidth), // Spacer for Ad
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Layer 2: Fixed Ad Panel
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(spacing),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(child: SizedBox()), // Allows clicks to pass through
                              const SizedBox(width: spacing),
                              SizedBox(
                                width: adPanelWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                    border: Border.all(
                                      color: widget.isDarkMode ? Colors.white : Colors.black,
                                      width: 1.0,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: DesktopRightPanel(isDarkMode: widget.isDarkMode),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // State for notifications toggle on mobile
  bool _notificationsEnabled = true;

  Widget _buildMobileLayout() {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (kIsWeb)
                RedHeader(
                  title: 'Profile',
                  subtitle: 'Your Fitness Journey',
                  onToggleTheme: widget.toggleTheme,
                  isDarkMode: widget.isDarkMode,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserProfileCard(isMobile: true),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Physical Stats'),
                      const SizedBox(height: 16),
                      _buildStatsGrid(isMobile: true),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Goals & Preferences'),
                      const SizedBox(height: 16),
                      _buildMobileGoalsGrid(),
                      const SizedBox(height: 24),
                      // Share App Card
                      _buildMobileSettingsCard(
                        icon: Icons.share_outlined,
                        title: 'Share GymGuide',
                        subtitle: 'Invite friends & family',
                        trailing: GestureDetector(
                          onTap: _shareApp,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Share',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Notifications Toggle

                      _buildMobileSettingsCard(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Manage notification preferences',
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                          },
                          activeColor: const Color(0xFFFF0000),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dark Mode Toggle
                      _buildMobileSettingsCard(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark Mode',
                        subtitle: widget.isDarkMode
                            ? 'Dark mode is on'
                            : 'Light mode is on',
                        trailing: Switch(
                          value: widget.isDarkMode,
                          onChanged: (_) => widget.toggleTheme(),
                          activeColor: const Color(0xFFFF0000),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // ── FITNESS CALCULATORS ───────────────────────
                      _buildMobileSectionHeader('Fitness Calculators'),
                      const SizedBox(height: 12),
                      _buildMobileLegalItem(
                        icon: Icons.monitor_weight_outlined,
                        title: 'BMI Calculator',
                        subtitle: 'Body mass index',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => BmiCalculatorPage(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode))),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.local_fire_department_outlined,
                        title: 'Calorie Calculator',
                        subtitle: 'Daily calorie needs',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => CalorieCalculatorPage(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode))),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.pie_chart_outline,
                        title: 'Macro Calculator',
                        subtitle: 'Protein, carbs & fats',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => MacroCalculatorPage(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode))),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.accessibility_new_outlined,
                        title: 'Body Fat Calculator',
                        subtitle: 'Estimate body fat %',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => BodyFatCalculatorPage(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode))),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.fitness_center_outlined,
                        title: '1RM Calculator',
                        subtitle: 'One rep max estimator',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => OneRmCalculatorPage(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode))),
                      ),
                      const SizedBox(height: 24),

                      // ── LEGAL & PRIVACY ──────────────────────────
                      _buildMobileSectionHeader('Legal & Privacy'),
                      const SizedBox(height: 12),
                      _buildMobileLegalItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'Your data & privacy',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.article_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Terms & conditions',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const TermsOfServicePage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.description_outlined,
                        title: 'EULA',
                        subtitle: 'End User License Agreement',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SubscriptionTermsPage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.info_outline,
                        title: 'Disclaimer',
                        subtitle: 'Health & safety info',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const DisclaimerPage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.copyright_outlined,
                        title: 'Copyright',
                        subtitle: 'Intellectual property rights',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const CopyrightPage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.verified_user_outlined,
                        title: 'Age Requirement',
                        subtitle: 'Eligibility requirements',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AgeRequirementPage())),
                      ),
                      const SizedBox(height: 24),

                      // ── DATA & TRANSPARENCY ───────────────────────
                      _buildMobileSectionHeader('Data & Transparency'),
                      const SizedBox(height: 12),
                      _buildResetPlanCard(),
                      const SizedBox(height: 12),
                      _buildMobileLegalItem(
                        icon: Icons.download_outlined,
                        title: 'Download My Data',
                        subtitle: 'Export your personal data',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const DataExportPage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.delete_forever_outlined,
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account',
                        isDestructive: true,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const DeleteAccountPage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.psychology_outlined,
                        title: 'AI Transparency',
                        subtitle: 'How AI is used in this app',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AITransparencyPage())),
                      ),
                      const SizedBox(height: 24),

                      // ── SUPPORT ───────────────────────────────────
                      _buildMobileSectionHeader('Support'),
                      const SizedBox(height: 12),
                      _buildMobileLegalItem(
                        icon: Icons.headset_mic_outlined,
                        title: 'Contact Support',
                        subtitle: 'support@gymguide.co',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ContactSupportPage())),
                      ),
                      const SizedBox(height: 8),
                      _buildMobileLegalItem(
                        icon: Icons.info_outline_rounded,
                        title: 'About App',
                        subtitle: 'Version & company info',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AboutAppPage())),
                      ),
                      const SizedBox(height: 24),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF0000),
                            side: const BorderSide(color: Color(0xFFFF0000)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileGoalsGrid() {
    // Only show Goal card on mobile (excluding Target Weight, Activity, Diet Type)
    // Full width for single Goal card
    return _buildStatCard('Goal', _userStats['goal'], Icons.flag_outlined, true);
  }

  Widget _buildMobileSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: widget.isDarkMode ? Colors.white54 : Colors.black54,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMobileSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white : Colors.black,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF0000),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildMobileLegalItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDestructive
        ? const Color(0xFFFF0000)
        : (widget.isDarkMode ? Colors.white : Colors.black87);
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    final iconBg = isDestructive
        ? const Color(0xFFFF0000).withOpacity(0.12)
        : const Color(0xFFFF0000).withOpacity(0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFF0000).withOpacity(0.4)
                : (widget.isDarkMode ? Colors.white : Colors.black),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF0000),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive ? const Color(0xFFFF0000) : subTextColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the correct default avatar SVG based on the user's gender.
  /// Male is the default. Switches to femaleprofile.svg when gender is 'Female'.
  Widget _buildDefaultAvatar() {
    final gender = (_userStats['gender'] ?? '').toString().toLowerCase();
    final svgAsset = (gender == 'female')
        ? 'assets/svg/logo/femaleprofile.svg'
        : 'assets/svg/logo/maleprofile.svg';
    return SvgPicture.asset(
      svgAsset,
      fit: BoxFit.cover,
      width: 120,
      height: 120,
    );
  }

  Widget _buildUserProfileCard({bool isMobile = false}) {
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    // Determine border color: black for mobile, subtle for desktop
    final borderColor = isMobile
        ? Colors.black
        : (widget.isDarkMode ? Colors.white12 : Colors.black12);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(
          color: isMobile
              ? (widget.isDarkMode ? Colors.white : Colors.black)
              : borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Profile Image: user-uploaded > SVG default based on gender
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF0000).withOpacity(0.1),
                    border:
                        Border.all(color: const Color(0xFFFF0000), width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _profileImageBytes != null
                      // User has set a custom photo
                      ? Image.memory(
                          _profileImageBytes!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        )
                      // Show gender-appropriate SVG default
                      : _buildDefaultAvatar(),
                ),
              ),
              // Camera button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Text(
            _userEmail,
            style: TextStyle(
              fontSize: 16,
              color: subTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildProfileStatRow(
            'Member Since',
            _memberSince.isEmpty ? '—' : _memberSince,
            textColor,
          ),
          const SizedBox(height: 16),
          _buildProfileStatRow(
              'Plan Status', 'Free Trial', const Color(0xFFFF0000)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProfileStatRow(String label, String value, Color valueColor) {
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: subTextColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: widget.isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildStatsGrid({bool isMobile = false}) {
    return Column(
      children: [
        _buildStatCard('Height', _userStats['height'], Icons.height, isMobile),
        const SizedBox(height: 12),
        _buildStatCard('Weight', _userStats['weight'],
            Icons.monitor_weight_outlined, isMobile),
        const SizedBox(height: 12),
        _buildStatCard('Age', _userStats['age'], Icons.cake_outlined, isMobile),
        const SizedBox(height: 12),
        _buildStatCard(
            'Gender', _userStats['gender'], Icons.person_outline, isMobile),
      ],
    );
  }

  Widget _buildGoalsGrid({bool isMobile = false}) {
    return Column(
      children: [
        _buildStatCard(
            'Goal', _userStats['goal'], Icons.flag_outlined, isMobile),
        const SizedBox(height: 12),
        _buildStatCard('Target Weight', _userStats['target_weight'],
            Icons.track_changes, isMobile),
        const SizedBox(height: 12),
        _buildStatCard('Activity', _userStats['activity_level'],
            Icons.directions_run, isMobile),
        const SizedBox(height: 12),
        _buildStatCard(
            'Diet Type', _userStats['diet'], Icons.restaurant_menu, isMobile),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, bool isMobile,
      {double? width}) {
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20, vertical: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(
          color: isMobile
              ? (widget.isDarkMode ? Colors.white : Colors.black)
              : (widget.isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF0000),
              size: isMobile ? 20 : 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: subTextColor,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPlanCard() {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white : Colors.black,
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // If the available width is small, we wrap the button to the next line
          final isNarrow = constraints.maxWidth < 340;

          final iconWidget = Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFFF0000),
              size: 24,
            ),
          );

          final textSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset Your Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                'Start fresh and generate a new plan',
                style: TextStyle(
                  fontSize: 13,
                  color: subTextColor,
                ),
              ),
            ],
          );

          final buttonWidget = ElevatedButton(
            onPressed: _showResetConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Create New Plan', style: TextStyle(fontWeight: FontWeight.bold)),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 16),
                  Expanded(child: textSection),
                  if (!isNarrow) ...[
                    const SizedBox(width: 12),
                    buttonWidget,
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: buttonWidget,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final controller = TextEditingController();
        bool canConfirm = false;
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            return AlertDialog(
              title: const Text('⚠️ Reset Your Plan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete your current workout plan, meal plan, and progress. This cannot be undone.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Type RESET to confirm:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    onChanged: (val) {
                      setStateSB(() {
                        canConfirm = val.trim() == 'RESET';
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'RESET',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    autocorrect: false,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canConfirm
                      ? () {
                          Navigator.pop(dialogContext);
                          _resetUserPlan();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Create New Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _resetUserPlan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Delete user plan data from Supabase in the correct cascade order
      // Fetch the user's plan IDs first, then delete pivot rows
      final planRows = await Supabase.instance.client
          .from('user_meal_plans')
          .select('id')
          .eq('user_id', user.id);
      final planIds = (planRows as List).map<String>((r) => r['id'].toString()).toList();
      if (planIds.isNotEmpty) {
        await Supabase.instance.client
            .from('user_meal_plan_meals')
            .delete()
            .inFilter('plan_id', planIds);
      }

      await Supabase.instance.client.from('user_meal_plans').delete().eq('user_id', user.id);
      await Supabase.instance.client.from('user_workout_progress').delete().eq('user_id', user.id);
      await Supabase.instance.client.from('user_weekly_weights').delete().eq('user_id', user.id);
      // Also clear the user_preferences row so the app treats them as a new user
      await Supabase.instance.client.from('user_preferences').delete().eq('user_id', user.id);

      // 2. Clear local auth flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_workout_plan');
      await prefs.remove('has_meal_plan');
      await prefs.remove('meal_plan_cache_${user.id}');
      await prefs.remove('plan_duration');
      await prefs.remove('weight_unit');

      if (mounted) {
        // 3. Navigate back to root (GymGuideApp will restart the full auth/onboarding flow)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const GymGuideApp()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[PROFILE] Error resetting plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset plan: $e')),
        );
      }
    }
  }
}
