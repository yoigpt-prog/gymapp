import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import '../../config/env_config.dart';
import 'ai_transformation_page.dart';

// Web-only import
import 'ai_transformation_result_page_web.dart'
    if (dart.library.io) 'ai_transformation_result_page_stub.dart' as web_save;

class AITransformationResultPage extends StatefulWidget {
  final Uint8List originalImageBytes;
  final String resultImageUrl;
  final Uint8List? resultImageBytes;
  final String goal;
  final bool isDarkMode;
  final String requestId;
  final String shareToken;

  const AITransformationResultPage({
    Key? key,
    required this.originalImageBytes,
    required this.resultImageUrl,
    this.resultImageBytes,
    required this.goal,
    this.isDarkMode = false,
    this.requestId = '',
    this.shareToken = '',
  }) : super(key: key);

  @override
  State<AITransformationResultPage> createState() =>
      _AITransformationResultPageState();
}

class _AITransformationResultPageState
    extends State<AITransformationResultPage> with TickerProviderStateMixin {
  double _sliderPosition = 0.5;
  Uint8List? _resultImageBytes;
  bool _loadingResult = true;
  bool _isSaving = false;
  bool _isSharing = false;
  bool _isRegenerating = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color _red = Color(0xFFFF0000);

  late String _shareToken;

  // ── Share URL ─────────────────────────────────────────────────────────────
  Future<String?> _getOrGenerateShareUrl() async {
    if (_shareToken.isNotEmpty) {
      return 'https://www.gymguide.co/transformation/share/$_shareToken';
    }

    if (widget.requestId.isEmpty) return null;

    try {
      // 1. Fetch from DB
      final data = await Supabase.instance.client
          .from('transformation_requests')
          .select('share_token')
          .eq('id', widget.requestId)
          .maybeSingle();
          
      if (data != null && data['share_token'] != null && data['share_token'].toString().isNotEmpty) {
        _shareToken = data['share_token'].toString();
        return 'https://www.gymguide.co/transformation/share/$_shareToken';
      }

      // 2. Generate new if null
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final rnd = Random();
      final newToken = String.fromCharCodes(Iterable.generate(
          16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
          
      await Supabase.instance.client
          .from('transformation_requests')
          .update({'share_token': newToken})
          .eq('id', widget.requestId);
          
      setState(() {
        _shareToken = newToken;
      });
      
      // Update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_transform_share_token', newToken);

      return 'https://www.gymguide.co/transformation/share/$_shareToken';
    } catch (e) {
      if (EnvConfig.isStaging) debugPrint('[AI Share] Error generating token: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _shareToken = widget.shareToken;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _loadingResult = false;
        if (widget.resultImageBytes != null) {
          _resultImageBytes = widget.resultImageBytes;
        }
      });
      _fadeController.forward();
      if (_resultImageBytes == null) {
        _downloadBytesForSave();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Download bytes ────────────────────────────────────────────────────────
  Future<void> _downloadBytesForSave() async {
    try {
      final response = await http
          .get(Uri.parse(widget.resultImageUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;
        setState(() => _resultImageBytes = response.bodyBytes);
        if (EnvConfig.isStaging) {
          debugPrint('[AI Save] Bytes ready (${response.bodyBytes.length} bytes)');
        }
      }
    } catch (e) {
      if (EnvConfig.isStaging) debugPrint('[AI Save] Background download failed: $e');
    }
  }

  // ── Ensure bytes available ────────────────────────────────────────────────
  Future<bool> _ensureBytes() async {
    if (_resultImageBytes != null) return true;
    try {
      final response = await http
          .get(Uri.parse(widget.resultImageUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (mounted) setState(() => _resultImageBytes = response.bodyBytes);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Save Image ────────────────────────────────────────────────────────────
  Future<void> _saveImage() async {
    if (_isSaving) return;
    if (EnvConfig.isStaging) debugPrint('[AI Save] Save image start');

    setState(() => _isSaving = true);
    try {
      final hasBytes = await _ensureBytes();
      if (!hasBytes || _resultImageBytes == null) {
        _showError('Could not download image. Please try again.');
        if (EnvConfig.isStaging) debugPrint('[AI Save] Save failed — no bytes available');
        return;
      }

      if (kIsWeb) {
        _saveImageWeb(_resultImageBytes!);
        return;
      }

      // iOS / Android — save to gallery (strips EXIF via re-encode)
      try {
        await Gal.putImageBytes(_resultImageBytes!);
        if (EnvConfig.isStaging) debugPrint('[AI Save] Save success ✅');
        _showSuccess('Image saved successfully.');
      } catch (e) {
        if (EnvConfig.isStaging) debugPrint('[AI Save] Save failed — error=$e');
        _showError('Could not save image. Please try again.');
      }
    } catch (e) {
      if (EnvConfig.isStaging) debugPrint('[AI Save] Save error: $e');
      _showError('Could not save image: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _saveImageWeb(Uint8List bytes) {
    try {
      web_save.downloadImage(
        bytes,
        'gymguide_transformation_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      _showSuccess('Image saved successfully.');
      if (EnvConfig.isStaging) debugPrint('[AI Save] Web download triggered ✅');
    } catch (e) {
      if (EnvConfig.isStaging) debugPrint('[AI Save] Web download failed: $e');
      _showError('Could not download image.');
    }
  }

  // ── Regenerate ────────────────────────────────────────────────────────────
  void _regenerate() {
    if (_isRegenerating) return; // prevent double-tap
    if (EnvConfig.isStaging) debugPrint('[AI Regenerate] Going back to upload page');
    setState(() => _isRegenerating = true);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => AITransformationPage(
          isDarkMode: widget.isDarkMode,
          forceNew: true,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Share ─────────────────────────────────────────────────────────────────
  Future<void> _shareImage({String? platform}) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    final shareUrl = await _getOrGenerateShareUrl();
    
    if (shareUrl == null) {
      if (mounted) {
        setState(() => _isSharing = false);
        _showError('Share link not ready. Please try again.');
      }
      return;
    }

    if (EnvConfig.isStaging) {
      debugPrint('[AI Share] share_token=$_shareToken');
      debugPrint('[AI Share] shareUrl=$shareUrl');
    }

    // Copy Link
    if (platform == 'Copy Link') {
      try {
        await Clipboard.setData(ClipboardData(text: shareUrl));
        _showSuccess('Link copied to clipboard!');
      } finally {
        if (mounted) setState(() => _isSharing = false);
      }
      return;
    }

    // WhatsApp — direct URL share
    if (platform == 'WhatsApp') {
      try {
        final text = 'Check out my AI transformation with GymGuide.\n\n$shareUrl';
        final waUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl);
        } else {
          await Share.share(text, subject: 'My GymGuide AI Transformation');
        }
      } finally {
        if (mounted) setState(() => _isSharing = false);
      }
      return;
    }

    // X (Twitter)
    if (platform == 'X (Twitter)') {
      try {
        final text = 'Check out my AI transformation with GymGuide.\n\n$shareUrl';
        final xUrl = Uri.parse('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}');
        if (await canLaunchUrl(xUrl)) {
          await launchUrl(xUrl);
        } else {
          await Share.share(text, subject: 'My GymGuide AI Transformation');
        }
      } finally {
        if (mounted) setState(() => _isSharing = false);
      }
      return;
    }

    // Facebook
    if (platform == 'Facebook') {
      try {
        final fbUrl = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(shareUrl)}');
        if (await canLaunchUrl(fbUrl)) {
          await launchUrl(fbUrl);
        } else {
          await Share.share(shareUrl, subject: 'My GymGuide AI Transformation');
        }
      } finally {
        if (mounted) setState(() => _isSharing = false);
      }
      return;
    }

    // General Share (bottom button or fallback)
    if (platform == null || platform == 'Share Transformation' || platform == 'More') {
      try {
        final text = 'Check out my AI transformation with GymGuide.\n\n$shareUrl';
        
        final hasBytes = await _ensureBytes();
        if (hasBytes && _resultImageBytes != null) {
             final xfile = XFile.fromData(
                _resultImageBytes!,
                mimeType: 'image/jpeg',
                name: 'gymguide_transformation.jpg',
             );
             await Share.shareXFiles([xfile], text: text, subject: 'My GymGuide AI Transformation');
        } else {
            await Share.share(text, subject: 'My GymGuide AI Transformation');
        }

        if (EnvConfig.isStaging) debugPrint('[AI Share] System share triggered');
      } catch (e) {
        if (EnvConfig.isStaging) debugPrint('[AI Share] Share error: $e');
      } finally {
        if (mounted) setState(() => _isSharing = false);
      }
      return;
    }
  }

  // (Removed _showPlatformInstruction since it's no longer needed)

  // ── Snackbars ─────────────────────────────────────────────────────────────
  void _showSuccess(String message) {
    if (!mounted) return;
    debugPrint('[AI SUCCESS] $message');
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text(message),
    //   backgroundColor: Colors.green.shade600,
    //   behavior: SnackBarBehavior.floating,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // ));
  }

  void _showError(String message) {
    if (!mounted) return;
    debugPrint('[AI ERROR] $message');
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text(message),
    //   backgroundColor: Colors.red.shade700,
    //   behavior: SnackBarBehavior.floating,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
          'Your Transformation',
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
      body: _loadingResult
          ? _buildLoadingState(isDark)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResultHeader(isDark),
                  const SizedBox(height: 20),
                  _buildBeforeAfterSlider(isDark),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Slide to compare',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildGoalBadge(isDark),
                  const SizedBox(height: 28),
                  _buildActionButtons(isDark),
                  const SizedBox(height: 20),
                  _buildShareSection(isDark),
                  const SizedBox(height: 20),
                  _buildDisclaimer(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _red, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            'Loading your result...',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade500, size: 14),
              const SizedBox(width: 6),
              Text(
                'TRANSFORMATION READY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your AI\nTransformation',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drag the slider to see your before & after',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildBeforeAfterSlider(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width - 40;
    final imageHeight = screenWidth * 1.3;

    return Container(
      width: screenWidth,
      height: imageHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _sliderPosition =
                (_sliderPosition + details.delta.dx / screenWidth)
                    .clamp(0.0, 1.0);
          });
        },
        child: Stack(
          children: [
            // AFTER image (full width, behind)
            Positioned.fill(
              child: _resultImageBytes != null
                  ? Image.memory(_resultImageBytes!, fit: BoxFit.cover)
                  : Image.network(
                      widget.resultImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFFF0000), strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                        child: const Center(
                          child: Text('Result unavailable',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ),
            ),

            // BEFORE image (clipped from left)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _sliderPosition,
                  child: SizedBox(
                    width: screenWidth,
                    height: imageHeight,
                    child: Image.memory(widget.originalImageBytes,
                        fit: BoxFit.cover),
                  ),
                ),
              ),
            ),

            // Divider line
            Positioned(
              left: screenWidth * _sliderPosition - 1.5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 8),
                        ],
                      ),
                      child: const Icon(Icons.compare_arrows,
                          color: Colors.black87, size: 20),
                    ),
                  ],
                ),
              ),
            ),

            // Labels
            Positioned(top: 12, left: 12, child: _label('BEFORE')),
            Positioned(top: 12, right: 12, child: _label('AFTER')),

            // Branding
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Generated with GymGuide AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGoalBadge(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_outlined, color: _red, size: 15),
              const SizedBox(width: 6),
              Text(
                widget.goal,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.download_outlined,
            label: _isSaving ? 'Saving...' : 'Save Image',
            onTap: _isSaving ? null : _saveImage,
            isDark: isDark,
            filled: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            icon: Icons.refresh_rounded,
            label: _isRegenerating ? 'Loading...' : 'Regenerate',
            onTap: _isRegenerating ? null : _regenerate,
            isDark: isDark,
            filled: false,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? _red : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onTap == null
                ? Colors.grey.shade400
                : filled
                    ? _red
                    : (isDark ? Colors.white24 : Colors.black),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: onTap == null
                    ? Colors.grey
                    : filled
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: onTap == null
                    ? Colors.grey
                    : filled
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareSection(bool isDark) {
    final platforms = [
      const _PlatformShare('Copy Link', Colors.blue, icon: Icons.link),
      const _PlatformShare('WhatsApp', Color(0xFF25D366), assetPath: 'assets/whatsappicon.png'),
      const _PlatformShare('X (Twitter)', Colors.black, assetPath: 'assets/xicon.png'),
      const _PlatformShare('Facebook', Color(0xFF1877F2), assetPath: 'assets/fbicon.png'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHARE YOUR RESULT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: platforms.map((p) {
              return GestureDetector(
                onTap: () => _shareImage(platform: p.name),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: p.assetPath != null
                          ? null
                          : BoxDecoration(
                              color: p.color.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: p.color.withOpacity(0.3)),
                            ),
                      child: p.assetPath != null
                          ? ClipOval(
                              child: Image.asset(
                                p.assetPath!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(p.icon, color: p.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _isSharing ? null : () => _shareImage(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: _red.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSharing ? Icons.hourglass_empty : Icons.share_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSharing ? 'Sharing...' : 'Share Transformation',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
}

class _PlatformShare {
  final String name;
  final IconData? icon;
  final Color color;
  final String? assetPath;

  const _PlatformShare(this.name, this.color, {this.icon, this.assetPath});
}
