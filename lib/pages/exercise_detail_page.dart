import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'home_page.dart'; // Import for ExerciseDetail model
import '../services/video_cache_service.dart';

class ExerciseDetailPage extends StatefulWidget {
  final ExerciseDetail exercise;
  final bool isDarkMode;

  const ExerciseDetailPage({
    Key? key,
    required this.exercise,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  final List<bool> _completedSets = [false, false, false]; // Track 3 sets

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF0000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exercise.name,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video/Image demonstration
            LayoutBuilder(
              builder: (context, constraints) {
                final videoHeight = (constraints.maxWidth * 9 / 16).clamp(220.0, 420.0);
                return Container(
                  width: double.infinity,
                  height: videoHeight,
                  color: widget.isDarkMode ? Colors.black26 : Colors.grey.shade300,
                  child: widget.exercise.imagePath.isNotEmpty
                      ? _buildMediaPreview(widget.exercise.imagePath, videoHeight)
                      : Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF0000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                );
              },
            ),

            // Track Your Sets (between video and instructions)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track Your Sets',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Set checkboxes
                  _buildSetCheckbox(0, 'Set 1', '12 reps'),
                  _buildSetCheckbox(1, 'Set 2', '12 reps'),
                  _buildSetCheckbox(2, 'Set 3', '12 reps'),

                  const SizedBox(height: 24),

                  // Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _allSetsCompleted
                          ? () => Navigator.pop(context, true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Mark Complete & Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Skip Exercise',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Instructions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.exercise.steps.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final step = entry.value;
                    return _buildInstructionStep(index, step);
                  }).toList(),

                  const SizedBox(height: 24),

                  // Body Part and Difficulty
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        const TextSpan(
                          text: 'Body Part: ',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: widget.exercise.target,
                          style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        const TextSpan(
                          text: 'Synergist: ',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: widget.exercise.synergist,
                          style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        const TextSpan(
                          text: 'Difficulty: ',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: widget.exercise.difficulty,
                          style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

          ],
        ),
      ),
    ),
  );
}

  Widget _buildMediaPreview(String url, [double? height]) {
    final cleanUrl = url.trim();
    final isVideo = cleanUrl.toLowerCase().endsWith('.mp4') ||
        cleanUrl.toLowerCase().endsWith('.mov') ||
        cleanUrl.toLowerCase().endsWith('.webm');

    if (isVideo) {
      return VideoPlayerWidget(videoUrl: cleanUrl, height: height);
    } else {
      return Image.network(
        cleanUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.grey.shade400,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: const Color(0xFFFF0000),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetCheckbox(int index, String label, String reps) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        // Scale values responsively
        final hPadding = (screenWidth * 0.045).clamp(14.0, 28.0);
        final vPadding = (screenWidth * 0.035).clamp(12.0, 20.0);
        final fontSize = (screenWidth * 0.042).clamp(14.0, 18.0);
        final repsFontSize = (screenWidth * 0.036).clamp(12.0, 16.0);
        final checkboxSize = (screenWidth * 0.065).clamp(22.0, 32.0);
        final borderRadius = (screenWidth * 0.035).clamp(10.0, 16.0);
        final borderWidth = (screenWidth * 0.004).clamp(1.5, 2.5);
        final isCompleted = _completedSets[index];

        // Clear, visually distinct border colors
        final borderColor = isCompleted
            ? Colors.green
            : widget.isDarkMode
                ? const Color(0xFF555555)
                : const Color(0xFFBBBBBB);

        final bgColor = isCompleted
            ? (widget.isDarkMode
                ? const Color(0xFF0D2E0D)
                : const Color(0xFFEAF7EA))
            : (widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: EdgeInsets.only(bottom: screenWidth * 0.03),
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? Colors.green.withOpacity(0.12)
                    : (widget.isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.06)),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _completedSets[index] = !_completedSets[index];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: checkboxSize,
                  height: checkboxSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.grey.shade400,
                      width: borderWidth,
                    ),
                    color: isCompleted ? Colors.green : Colors.transparent,
                  ),
                  child: isCompleted
                      ? Icon(Icons.check,
                          size: checkboxSize * 0.6, color: Colors.white)
                      : null,
                ),
              ),
              SizedBox(width: hPadding * 0.7),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                reps,
                style: TextStyle(
                  fontSize: repsFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _allSetsCompleted => _completedSets.every((completed) => completed);
}

/// Cached video player — delegates controller lifecycle to [VideoCacheService].
///
/// Key behaviours
/// • First open  : fetches from R2, caches controller in memory.
/// • Rebuild     : controller is reused from cache — zero extra GET requests.
/// • Second open : controller already ready → plays instantly, no spinner.
/// • Dispose     : does NOT dispose the controller (cache keeps it alive).
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double? height;

  const VideoPlayerWidget({Key? key, required this.videoUrl, this.height})
      : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  /// Ask the cache for a ready controller.
  /// If it already exists the future completes synchronously-ish (next microtask).
  Future<void> _loadFromCache() async {
    // Fast path: already initialised — skip setState overhead.
    if (VideoCacheService.instance.isReady(widget.videoUrl)) {
      final cached =
          await VideoCacheService.instance.getController(widget.videoUrl);
      if (mounted && cached != null) {
        setState(() {
          _controller = cached;
          _isInitialized = true;
        });
      }
      return;
    }

    // Slow path: fetch & initialise (only happens once per URL per session).
    final controller =
        await VideoCacheService.instance.getController(widget.videoUrl);
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _isInitialized = controller != null;
      _hasError = controller == null;
    });
  }

  @override
  void dispose() {
    // ⚠️  Do NOT dispose — VideoCacheService owns the controller lifetime.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 250;

    if (_hasError) {
      return SizedBox(
        height: h,
        child: Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400),
        ),
      );
    }

    if (_isInitialized && _controller != null) {
      return SizedBox(
        width: double.infinity,
        height: h,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }

    return SizedBox(
      height: h,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
