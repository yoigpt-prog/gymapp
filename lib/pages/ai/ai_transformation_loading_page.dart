import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../config/env_config.dart';
import '../../services/ai_image_composer_service.dart';
import 'ai_transformation_result_page.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../services/revenue_cat_service.dart';

class AITransformationLoadingPage extends StatefulWidget {
  final Uint8List imageBytes;
  final String goal;
  final bool isDarkMode;
  final bool freeUserPreview;

  const AITransformationLoadingPage({
    Key? key,
    required this.imageBytes,
    required this.goal,
    this.isDarkMode = false,
    this.freeUserPreview = false,
  }) : super(key: key);

  @override
  State<AITransformationLoadingPage> createState() =>
      _AITransformationLoadingPageState();
}

class _AITransformationLoadingPageState
    extends State<AITransformationLoadingPage> with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  double _progress = 0.0;
  int _messageIndex = 0;
  Timer? _progressTimer;
  bool _done = false;
  bool _isFreePreviewActive = false;

  static const Color _red = Color(0xFFFF0000);

  final List<String> _messages = [
    'Analyzing physique...',
    'Detecting body proportions...',
    'Building your future body...',
    'Enhancing realism...',
    'Generating transformation...',
    'Finalizing results...',
  ];

  @override
  void initState() {
    super.initState();
    _isFreePreviewActive = widget.freeUserPreview;

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(_rotateController);

    _startProgress();
    if (!_isFreePreviewActive) {
      _generateTransformation();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgress() {
    _progressTimer?.cancel();
    int tick = (_progress * 55).round();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      tick++;
      setState(() {
        if (_isFreePreviewActive) {
          _progress = (tick / 55).clamp(0.0, 0.30);
        } else {
          _progress = (tick / 55).clamp(0.0, 0.95);
        }
        _messageIndex =
            ((_progress * (_messages.length - 1)).floor()).clamp(0, _messages.length - 1);
      });
      if (_isFreePreviewActive && _progress >= 0.30) {
        timer.cancel();
        _showPremiumModal();
      } else if (_done || tick >= 55) {
        timer.cancel();
      }
    });
  }

  Future<void> _generateTransformation() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _onError('Authentication required');
        return;
      }

      // 1. Upload original image to Supabase storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalPath = '${user.id}/$timestamp.jpg';

      await Supabase.instance.client.storage
          .from('transformation-originals')
          .uploadBinary(originalPath, widget.imageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));

      final originalUrl = Supabase.instance.client.storage
          .from('transformation-originals')
          .getPublicUrl(originalPath);

      // 2. Log request to transformation_requests table
      final requestRow = await Supabase.instance.client
          .from('transformation_requests')
          .insert({
            'user_id': user.id,
            'original_image_url': originalUrl,
            'goal': widget.goal,
            'status': 'processing',
          })
          .select('id, share_token')
          .single();

      final requestId = requestRow['id'].toString();
      final shareToken = requestRow['share_token']?.toString() ?? '';

      if (EnvConfig.isStaging) {
        debugPrint('[AI Regenerate] New request created — requestId=$requestId shareToken=$shareToken');
      }

      // 3. Call Supabase Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'generate-transformation',
        body: {
          'requestId': requestId,
          'originalImageUrl': originalUrl,
          'goal': widget.goal,
        },
      );

      if (response.status != 200) {
        throw Exception('Edge function error: ${response.data}');
      }

      final resultUrl = response.data['resultUrl'] as String?;
      if (resultUrl == null || resultUrl.isEmpty) {
        throw Exception('No result URL returned');
      }

      if (EnvConfig.isStaging) {
        debugPrint('[AI Regenerate] Result URL received: $resultUrl');
      }

      // --- NEW THUMBNAIL LOGIC ---
      String? thumbnailUrl;
      Uint8List? resultImageBytes;
      try {
        if (EnvConfig.isStaging) debugPrint('[AI Thumbnail] Downloading result image to generate thumbnail');
        final httpResp = await http.get(Uri.parse(resultUrl)).timeout(const Duration(seconds: 15));
        
        if (httpResp.statusCode == 200 && httpResp.bodyBytes.isNotEmpty) {
          resultImageBytes = httpResp.bodyBytes;
          
          if (EnvConfig.isStaging) debugPrint('[AI Thumbnail] Generating OG thumbnail');
          final thumbBytes = await AiImageComposerService.createOgThumbnail(
            widget.imageBytes, resultImageBytes, widget.goal
          );
          
          final thumbPath = '${user.id}/${requestId}_thumb.png';
          await Supabase.instance.client.storage
              .from('transformation-originals')
              .uploadBinary(thumbPath, thumbBytes,
                  fileOptions: const FileOptions(contentType: 'image/png'));
                  
          thumbnailUrl = Supabase.instance.client.storage
              .from('transformation-originals')
              .getPublicUrl(thumbPath);
              
          if (EnvConfig.isStaging) debugPrint('[AI Thumbnail] Thumbnail uploaded: $thumbnailUrl');
        }
      } catch (e) {
        if (EnvConfig.isStaging) debugPrint('[AI Thumbnail] Failed to generate/upload thumbnail: $e');
        // Do not block the flow!
      }

      // Update request row with result
      await Supabase.instance.client
          .from('transformation_requests')
          .update({
            'result_image_url': resultUrl,
            if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
            'status': 'completed'
          })
          .eq('id', requestId);

      // Persist to SharedPreferences for instant restore on next open
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ai_transform_request_id', requestId);
        await prefs.setString('ai_transform_share_token', shareToken);
        await prefs.setString('ai_transform_result_url', resultUrl);
        await prefs.setString('ai_transform_original_url', originalUrl);
        await prefs.setString('ai_transform_goal', widget.goal);
        await prefs.setString('ai_transform_created_at', DateTime.now().toIso8601String());
        if (EnvConfig.isStaging) debugPrint('[AI Persist] Saved to SharedPreferences ✅');
      } catch (e) {
        if (EnvConfig.isStaging) debugPrint('[AI Persist] Failed to save to SharedPreferences: $e');
      }

      if (!mounted) return;

      setState(() {
        _done = true;
        _progress = 1.0;
        _messageIndex = _messages.length - 1;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Navigate directly to result page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => AITransformationResultPage(
              originalImageBytes: widget.imageBytes,
              resultImageUrl: resultUrl,
              resultImageBytes: resultImageBytes,
              goal: widget.goal,
              isDarkMode: widget.isDarkMode,
              requestId: requestId,
              shareToken: shareToken,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 700),
          ),
        );
      });
    } catch (e) {
      debugPrint('[AI Transformation] Error: $e');
      if (mounted) _onError(e.toString());
    }
  }

  void _onError(String message) {
    setState(() {
      _done = true;
      _progress = 0;
    });
    if (!mounted) return;

    final lowercaseMsg = message.toLowerCase();
    final isSensitiveOrFailed = lowercaseMsg.contains('flagged as sensitive') ||
        lowercaseMsg.contains('prediction failed') ||
        lowercaseMsg.contains('sensitive') ||
        lowercaseMsg.contains('e005') ||
        lowercaseMsg.contains('moderated');

    final title = isSensitiveOrFailed
        ? "We couldn’t create your transformation"
        : 'Generation Failed';
    final body = isSensitiveOrFailed
        ? "Please try another photo. For best results, upload a clear full-body image with good lighting and simple clothing."
        : 'Something went wrong. Please try again.\n\n$message';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF141414) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: widget.isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _red.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: _red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    nav.pop(); // close dialog
                    nav.pop(); // go back to upload page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFF0F0F0F);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // ── Animated Scan Effect ──────────────────────────────
              _buildScanEffect(),

              const SizedBox(height: 48),

              // ── Status Message ────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _messages[_messageIndex],
                  key: ValueKey(_messageIndex),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Please keep the app open',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 40),

              // ── Progress Bar ──────────────────────────────────────
              _buildProgressBar(),

              const SizedBox(height: 12),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const Spacer(),

              // ── Branding ──────────────────────────────────────────
              Text(
                'Powered by GymGuide AI',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanEffect() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, child) => Transform.scale(
        scale: _pulseAnimation.value,
        child: child,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (_, child) => Transform.rotate(
              angle: _rotateAnimation.value * 6.28,
              child: child,
            ),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _red.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
            ),
          ),
          // Inner circle with image
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: _red, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _red.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
          ),
          // Scan line
          ClipOval(
            child: SizedBox(
              width: 160,
              height: 160,
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (_, __) => Align(
                  alignment: Alignment(_scanAnimation.value, _scanAnimation.value),
                  child: Container(
                    height: 2,
                    width: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _red.withOpacity(0),
                          _red.withOpacity(0.8),
                          _red.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // AI Icon overlay
          Positioned(
            bottom: 15,
            right: 15,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _red.withOpacity(0.5), blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumModal() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: _red.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: _red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Unlock AI Transformation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your transformation preview is ready to generate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _red.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI body transformation is a Premium feature. Subscribe to continue and generate your personalized result.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        try {
                          final result = await RevenueCatService().showPaywall();
                          final isPro = await RevenueCatService().isProUser();
                          if (isPro || result == PaywallResult.purchased || result == PaywallResult.restored) {
                            if (mounted) {
                              setState(() {
                                _isFreePreviewActive = false;
                              });
                              _startProgress();
                              _generateTransformation();
                            }
                          } else {
                            if (mounted) {
                              _showPremiumModal();
                            }
                          }
                        } catch (e) {
                          debugPrint('[AI Paywall] Error: $e');
                          if (mounted) {
                            _showPremiumModal();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        'Continue to Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Not Now',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

  Widget _buildProgressBar() {
    return Stack(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 8,
          width: (MediaQuery.of(context).size.width * _progress - 64).clamp(0.0, double.infinity),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_red, _red.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                  color: _red.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
        ),
      ],
    );
  }
}
