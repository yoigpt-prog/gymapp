import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/env_config.dart';
import 'ai_transformation_loading_page.dart';
import 'ai_transformation_result_page.dart';
import '../../services/revenue_cat_service.dart';
import '../../services/analytics_service.dart';

class AITransformationPage extends StatefulWidget {
  final bool isDarkMode;
  final bool forceNew;

  const AITransformationPage({
    Key? key,
    this.isDarkMode = false,
    this.forceNew = false,
  }) : super(key: key);

  @override
  State<AITransformationPage> createState() => _AITransformationPageState();
}

class _AITransformationPageState extends State<AITransformationPage>
    with TickerProviderStateMixin {
  Uint8List? _selectedImageBytes;
  bool _isValidating = false;
  bool _isImageValid = false;
  String _validationError = '';
  String _selectedGoal = 'Build Muscle';
  bool _isRestoring = true;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final ImagePicker _picker = ImagePicker();

  static const Color _red = Color(0xFFFF0000);

  static const List<Map<String, dynamic>> _goals = [
    {'label': 'Build Muscle', 'icon': Icons.fitness_center_rounded},
    {'label': 'Lose Weight', 'icon': Icons.local_fire_department_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initialRestore();
  }

  Future<int> _getYearlyUsage(String feature, int year) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 0;
      final response = await Supabase.instance.client
          .from('ai_feature_usage')
          .select('usage_count')
          .eq('user_id', user.id)
          .eq('feature', feature)
          .eq('year', year)
          .maybeSingle();
      if (response == null || response['usage_count'] == null) return 0;
      return response['usage_count'] as int;
    } catch (e) {
      debugPrint('[AITransformation] _getYearlyUsage error: $e');
      return 0;
    }
  }

  Future<void> _initialRestore() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isRestoring = false);
        return;
      }

      // Check yearly limit to display error immediately if reached
      final year = DateTime.now().year;
      final usage = await _getYearlyUsage('ai_transformation', year);
      if (usage >= 3 && mounted) {
        setState(() {
          _errorMessage = 'You’ve reached your  limit for AI Transformation Simulator. Please try again .';
        });
      }

      if (widget.forceNew) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('ai_transform_request_id');
        await prefs.remove('ai_transform_share_token');
        await prefs.remove('ai_transform_result_url');
        await prefs.remove('ai_transform_original_url');
        await prefs.remove('ai_transform_goal');
        await prefs.remove('ai_transform_created_at');
        if (mounted) setState(() => _isRestoring = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final reqId = prefs.getString('ai_transform_request_id');
      if (reqId == null) {
        // Fallback: check Supabase directly
        final resp = await Supabase.instance.client
            .from('transformation_requests')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (resp == null) {
          if (mounted) setState(() => _isRestoring = false);
          return;
        }

        final status = resp['status'];
        if (status == 'processing') {
          // Download original image bytes to pass to loading page
          final origUrl = resp['original_image_url'] as String;
          final bytesResp = await http.get(Uri.parse(origUrl));
          if (bytesResp.statusCode == 200 && mounted) {
            if (EnvConfig.isStaging) debugPrint('[AI Persist] Restoring processing state from DB');
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => AITransformationLoadingPage(
                  imageBytes: bytesResp.bodyBytes,
                  goal: resp['goal'] as String,
                  isDarkMode: widget.isDarkMode,
                ),
                transitionDuration: Duration.zero,
              ),
            );
          } else {
            if (mounted) setState(() => _isRestoring = false);
          }
        } else if (status == 'completed') {
          final origUrl = resp['original_image_url'] as String;
          final bytesResp = await http.get(Uri.parse(origUrl));
          if (bytesResp.statusCode == 200 && mounted) {
            if (EnvConfig.isStaging) debugPrint('[AI Persist] Restoring completed state from DB');
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => AITransformationResultPage(
                  originalImageBytes: bytesResp.bodyBytes,
                  resultImageUrl: resp['result_image_url'] as String,
                  goal: resp['goal'] as String,
                  isDarkMode: widget.isDarkMode,
                  requestId: resp['id'].toString(),
                  shareToken: resp['share_token']?.toString() ?? '',
                ),
                transitionDuration: Duration.zero,
              ),
            );
          } else {
            if (mounted) setState(() => _isRestoring = false);
          }
        } else {
          if (mounted) setState(() => _isRestoring = false);
        }
        return;
      }

      // We have cache
      final statusResp = await Supabase.instance.client
          .from('transformation_requests')
          .select('status, result_image_url, share_token')
          .eq('id', reqId)
          .maybeSingle();

      if (statusResp == null) {
        if (mounted) setState(() => _isRestoring = false);
        return;
      }

      final status = statusResp['status'];
      final shareToken = statusResp['share_token']?.toString() ?? '';
      
      final origUrl = prefs.getString('ai_transform_original_url');
      final goal = prefs.getString('ai_transform_goal') ?? 'Build Muscle';

      if (origUrl == null) {
        if (mounted) setState(() => _isRestoring = false);
        return;
      }

      final bytesResp = await http.get(Uri.parse(origUrl));
      if (bytesResp.statusCode != 200) {
        if (mounted) setState(() => _isRestoring = false);
        return;
      }

      if (!mounted) return;

      if (status == 'completed') {
        final resultUrl = statusResp['result_image_url'] ?? prefs.getString('ai_transform_result_url');
        if (EnvConfig.isStaging) debugPrint('[AI Persist] Restoring completed state from cache');
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AITransformationResultPage(
              originalImageBytes: bytesResp.bodyBytes,
              resultImageUrl: resultUrl,
              goal: goal,
              isDarkMode: widget.isDarkMode,
              requestId: reqId,
              shareToken: shareToken,
            ),
            transitionDuration: Duration.zero,
          ),
        );
      } else if (status == 'processing') {
        if (EnvConfig.isStaging) debugPrint('[AI Persist] Restoring processing state from cache');
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AITransformationLoadingPage(
              imageBytes: bytesResp.bodyBytes,
              goal: goal,
              isDarkMode: widget.isDarkMode,
            ),
            transitionDuration: Duration.zero,
          ),
        );
      } else {
        if (mounted) setState(() => _isRestoring = false);
      }
    } catch (e) {
      if (EnvConfig.isStaging) debugPrint('[AI Persist] Error restoring: $e');
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _isImageValid = false;
          _validationError = '';
        });
        await _validateImage(bytes);
      }
    } catch (e) {
      debugPrint('[AI] Gallery pick error: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _isImageValid = false;
          _validationError = '';
        });
        await _validateImage(bytes);
      }
    } catch (e) {
      debugPrint('[AI] Camera pick error: $e');
    }
  }

  Future<void> _validateImage(Uint8List bytes) async {
    setState(() {
      _isValidating = true;
      _validationError = '';
    });

    bool localQualityValid = bytes.length >= 5000;
    debugPrint('[AI] localQualityValid: $localQualityValid');

    if (!localQualityValid) {
      setState(() {
        _isValidating = false;
        _isImageValid = false;
        _validationError = 'Image quality too low.';
      });
      return;
    }

    try {
      final base64Image = base64Encode(bytes);
      final response = await Supabase.instance.client.functions.invoke(
        'validate-transformation-image',
        body: {'imageBase64': base64Image},
      );

      final data = response.data;
      final isValid = data['valid'] == true;
      final reason = data['reason'] ?? 'unknown';

      debugPrint('[AI] backendBodyValid: $isValid');
      debugPrint('[AI] rejectionReason: $reason');

      setState(() {
        _isValidating = false;
        _isImageValid = isValid;
        _validationError = reason;
      });
    } catch (e) {
      debugPrint('[AI] Validation error: $e');
      setState(() {
        _isValidating = false;
        _isImageValid = false;
        _validationError = 'Connection error during validation.';
      });
    }
  }

  Future<void> _checkUsageAndShowImageSourceModal() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final year = DateTime.now().year;
      final usage = await _getYearlyUsage('ai_transformation', year);
      if (usage >= 3) {
        if (mounted) {
          setState(() {
            _errorMessage = 'You’ve reached your  limit for AI Transformation Simulator. Please try again .';
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[AITransformation] _getYearlyUsage error: $e');
    }

    if (!mounted) return;
    _showImageSourceModal();
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildImageSourceSheet(),
    );
  }

  Widget _buildImageSourceSheet() {
    final isDark = widget.isDarkMode;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Choose Photo Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sourceOption(
            icon: Icons.camera_alt_outlined,
            label: 'Take Photo',
            subtitle: 'Use your camera',
            onTap: () {
              Navigator.pop(context);
              _pickFromCamera();
            },
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          _sourceOption(
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
            subtitle: 'Select existing photo',
            onTap: () {
              Navigator.pop(context);
              _pickFromGallery();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sourceOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDarkMode;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _red, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInstallAppPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          backgroundColor: Colors.white,
          elevation: 24,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Install the App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI body transformation is available in the GymGuide mobile app. Install the app to generate your personalized transformation preview.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black.withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await AnalyticsService().trackDownloadLinkClicked(store: 'app_store');
                          final url = Uri.parse(AnalyticsService().appendVisitorId('https://apps.apple.com/us/app/gym-guide-app/id6760553535'));
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        child: Container(
                          width: 160,
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.apple, color: Colors.white, size: 28),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Download on the', style: TextStyle(fontSize: 10, color: Colors.white, height: 1)),
                                  Text('App Store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await AnalyticsService().trackDownloadLinkClicked(store: 'google_play');
                          final url = Uri.parse(AnalyticsService().appendVisitorId('https://play.google.com/store/apps/details?id=com.gymguide.app'));
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        child: Container(
                          width: 160,
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/svg/logo/playminiicon.png', width: 26, height: 26),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('GET IT ON', style: TextStyle(fontSize: 10, color: Colors.white, height: 1)),
                                  Text('Google Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black45,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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

  Future<void> _startGeneration() async {
    if (_selectedImageBytes == null || !_isImageValid) return;

    if (kIsWeb) {
      _showInstallAppPopup(context);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to use AI Transformation'),
          backgroundColor: _red,
        ),
      );
      return;
    }

    try {
      final year = DateTime.now().year;
      final usage = await _getYearlyUsage('ai_transformation', year);
      if (usage >= 3) {
        if (mounted) {
          setState(() {
            _errorMessage = "You've reached your limit for AI Transformation Simulator. Please try again .";
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[AITransformation] error checking usage before start: $e');
    }

    // Check premium status — free users get fake preview; premium gets real generation
    bool isPremium = false;
    try {
      isPremium = await RevenueCatService().isProUser();
    } catch (e) {
      debugPrint('[AITransformation] isProUser check error: $e');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => AITransformationLoadingPage(
          imageBytes: _selectedImageBytes!,
          goal: _selectedGoal,
          isDarkMode: widget.isDarkMode,
          freeUserPreview: !isPremium,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFAFAFA);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
          ),
        ),
        title: Text(
          'AI Transformation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      body: _isRestoring
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _red, strokeWidth: 2.5),
                  const SizedBox(height: 16),
                  Text(
                    'Restoring your last transformation...',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 28),
                  _buildUploadSection(isDark),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    _buildErrorCard(isDark),
                  ],
                  const SizedBox(height: 24),
                  _buildGoalSelector(isDark),
                  const SizedBox(height: 24),
                  _buildPhotoRequirements(isDark),
                  const SizedBox(height: 28),
                  _buildCTAButton(),
                  const SizedBox(height: 16),
                  _buildDisclaimer(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: _red, size: 14),
              const SizedBox(width: 6),
              Text(
                'AI POWERED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _red,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'See Your\nFuture Body',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Preview a realistic AI-powered body transformation based on your physique and goals.',
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white60 : Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection(bool isDark) {
    return GestureDetector(
      onTap: _checkUsageAndShowImageSourceModal,
      child: AnimatedBuilder(
        animation: _selectedImageBytes == null
            ? _pulseAnimation
            : const AlwaysStoppedAnimation(1.0),
        builder: (_, child) => Transform.scale(
          scale: _selectedImageBytes == null ? _pulseAnimation.value : 1.0,
          child: child,
        ),
        child: Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedImageBytes != null
                  ? (_isImageValid ? Colors.green : _red)
                  : (isDark ? Colors.white24 : Colors.black),
              width: _selectedImageBytes != null ? 2 : 1,
            ),
          ),
          child: _selectedImageBytes != null
              ? _buildSelectedImage(isDark)
              : _buildEmptyUpload(isDark),
        ),
      ),
    );
  }

  Widget _buildEmptyUpload(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _red.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add_photo_alternate_outlined, color: _red, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Upload Your Photo',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Camera or Gallery',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImage(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Container(color: Colors.black.withOpacity(0.35)),
        ),
        if (_isValidating)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                SizedBox(height: 12),
                Text(
                  'Analyzing with AI...',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else if (_isImageValid && _validationError == 'valid_with_warning')
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.orangeAccent, size: 44),
                SizedBox(height: 8),
                Text(
                  'Photo accepted',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'For best results, use fitted clothing and good lighting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (_isImageValid)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 52),
                SizedBox(height: 8),
                Text(
                  'Photo validated ✓',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ],
            ),
          )
        else if (!_isImageValid && _validationError.isNotEmpty)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 44),
                SizedBox(height: 8),
                Text(
                  'Full-body photo required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Upload a clear standing photo facing the camera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _checkUsageAndShowImageSourceModal,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Change',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoRequirements(bool isDark) {
    final reqs = [
      'Front-facing body photo',
      'Good lighting, no harsh shadows',
      'Full body preferred',
      'Minimal background clutter',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, size: 18, color: _red),
              const SizedBox(width: 8),
              Text(
                'Photo Requirements',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...reqs.map(
            (req) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 15, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    req,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildGoalSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transformation Goal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: _goals.map((g) {
            final selected = _selectedGoal == g['label'];
            final isLast = _goals.last == g;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 10),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedGoal = g['label'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFF0000)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFF0000)
                            : Colors.black,
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF0000).withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          g['icon'] as IconData,
                          size: 22,
                          color: selected ? Colors.white : Colors.black,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          g['label'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCTAButton() {
    final canProceed =
        _selectedImageBytes != null && _isImageValid && !_isValidating && _errorMessage == null;

    return GestureDetector(
      onTap: canProceed ? _startGeneration : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: canProceed ? _red : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(16),
          boxShadow: canProceed
              ? [
                  BoxShadow(
                      color: _red.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              canProceed
                  ? 'Generate My Transformation'
                  : 'Upload a Valid Photo First',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI previews are estimates only. Results vary depending on training, nutrition, genetics, and consistency.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black45,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
