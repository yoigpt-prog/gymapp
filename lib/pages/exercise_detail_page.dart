import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'home_page.dart'; // Import for ExerciseDetail model

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white : Colors.black,
          width: 0.3,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _completedSets[index] = !_completedSets[index];
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _completedSets[index] ? Colors.green : Colors.grey.shade400,
                  width: 2,
                ),
                color: _completedSets[index] ? Colors.green : Colors.transparent,
              ),
              child: _completedSets[index]
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            reps,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  bool get _allSetsCompleted => _completedSets.every((completed) => completed);
}

// VideoPlayerWidget from home_page.dart
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double? height;

  const VideoPlayerWidget({Key? key, required this.videoUrl, this.height}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.setLooping(true);
          _controller.setVolume(0.0); // Mute for autoplay
          _controller.play();
        }
      }).catchError((error) {
        debugPrint('Video initialization failed: $error');
        if (mounted) {
          setState(() {
            _isInitialized = false;
            // You could add an error state variable here if you want to show an error icon
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 250;
    if (_isInitialized) {
      return SizedBox(
        width: double.infinity,
        height: h,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: h,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
  }
}
