import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/env_config.dart';

class AITransformationSharePage extends StatefulWidget {
  final String shareToken;

  const AITransformationSharePage({Key? key, required this.shareToken})
      : super(key: key);

  @override
  State<AITransformationSharePage> createState() =>
      _AITransformationSharePageState();
}

class _AITransformationSharePageState extends State<AITransformationSharePage> {
  bool _isLoading = true;
  String? _originalImageUrl;
  String? _resultImageUrl;
  String? _goal;
  bool _notFound = false;
  double _sliderPosition = 0.5;

  static const Color _red = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _fetchTransformation();
  }

  Future<void> _fetchTransformation() async {
    try {
      if (EnvConfig.isStaging) {
        debugPrint('[AI Share Page] Fetching token: ${widget.shareToken}');
      }
      // Public query without auth, relies on RLS policy
      final response = await Supabase.instance.client
          .from('transformation_requests')
          .select('original_image_url, result_image_url, goal')
          .eq('share_token', widget.shareToken)
          .eq('status', 'completed')
          .maybeSingle();

      if (response == null) {
        if (mounted) setState(() => _notFound = true);
      } else {
        if (mounted) {
          setState(() {
            _originalImageUrl = response['original_image_url'];
            _resultImageUrl = response['result_image_url'];
            _goal = response['goal'] ?? 'Fitness';
          });
        }
      }
    } catch (e) {
      if (EnvConfig.isStaging) debugPrint('[AI Share Page] Fetch error: $e');
      if (mounted) setState(() => _notFound = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _launchAppStore() async {
    final url = Uri.parse('https://www.gymguide.co/download');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    const isDark = true; // Always force dark mode for this page for consistency
    const bg = Color(0xFF0F0F0F);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _red, strokeWidth: 2))
            : _notFound
                ? _buildNotFound()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'GymGuide',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildResultCard(),
                            const SizedBox(height: 32),
                            _buildCTA(),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Slider (Before/After)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: _resultImageUrl != null && _originalImageUrl != null
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      return GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _sliderPosition = (_sliderPosition + details.delta.dx / width).clamp(0.0, 1.0);
                          });
                        },
                        child: Stack(
                          children: [
                            // AFTER image (full width, behind)
                            Positioned.fill(
                              child: Image.network(
                                _resultImageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(color: _red, strokeWidth: 2),
                                  );
                                },
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
                                    width: width,
                                    height: height,
                                    child: Image.network(
                                      _originalImageUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(color: _red, strokeWidth: 2),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Thin divider white line
                            Positioned(
                              left: width * _sliderPosition - 1,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: Colors.white,
                              ),
                            ),
                            // Floating drag handle button
                            Positioned(
                              left: width * _sliderPosition - 18,
                              top: height / 2 - 18,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.unfold_more_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: CircularProgressIndicator(color: _red, strokeWidth: 2),
                  ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: _red, size: 14),
                      const SizedBox(width: 6),
                      const Text(
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
                const SizedBox(height: 16),
                const Text(
                  'AI Body Transformation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Goal: $_goal',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTA() {
    return Column(
      children: [
        GestureDetector(
          onTap: _launchAppStore,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _red.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Try GymGuide AI Free',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'AI previews are estimates only. Results vary depending on training, nutrition, genetics, and consistency.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white38,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 40, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          const Text(
            'Transformation Not Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'This transformation link is invalid or has been removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white54,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Go to GymGuide',
                style: TextStyle(color: _red, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
