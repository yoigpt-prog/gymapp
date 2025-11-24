import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class HomePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const HomePage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _gender = 'male'; // 'male' or 'female'
  String _side = 'front';  // 'front' or 'back'
  String? _highlightedMuscle; // e.g. 'abs'
  String? _selectedMuscle; // For detail view

  final List<ExerciseDetail> _exercises = []; // Removed mock data

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200;

    return SafeArea(
      child: Container(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
        child: Column(
          children: [
            // Top red header
            Container(
              height: 80,
              color: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'USER Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blueAccent,
                        child: ClipOval(
                          child: Container(color: Colors.white), // placeholder avatar
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search, color: subTextColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search workouts, muscle...',
                        style: TextStyle(color: subTextColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Gender + front / back + filter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _buildToggleChip(
                    label: 'Male',
                    isSelected: _gender == 'male',
                    onTap: () => setState(() => _gender = 'male'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildToggleChip(
                    label: 'Female',
                    isSelected: _gender == 'female',
                    onTap: () => setState(() => _gender = 'female'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 16),
                  _buildToggleChip(
                    label: 'Front',
                    isSelected: _side == 'front',
                    onTap: () => setState(() => _side = 'front'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildToggleChip(
                    label: 'Back',
                    isSelected: _side == 'back',
                    onTap: () => setState(() => _side = 'back'),
                    isDark: isDark,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showFilterModal(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.tune, size: 22, color: textColor),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Muscle map
            // Muscle map or Exercise List
            Expanded(
              child: _selectedMuscle != null
                  ? _buildExerciseList(isDark, textColor, cardColor)
                  : Center(
                      child: MuscleMap(
                        gender: _gender,
                        side: _side,
                        highlightedMuscle: _highlightedMuscle,
                        isDarkMode: isDark,
                        onTapMuscle: (m) {
                          setState(() {
                            if (_highlightedMuscle == m) {
                              // If already highlighted, select it and show details
                              _selectedMuscle = m;
                            } else {
                              // First tap highlights
                              _highlightedMuscle = m;
                            }
                          });
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildFilterSection('DIFFICULTY', [
                          'Beginner',
                          'Intermediate',
                          'Advanced'
                        ]),
                        const SizedBox(height: 24),
                        _buildFilterSection('WORKOUT TYPE', [
                          'Strength',
                          'Stretching',
                          'Cardio'
                        ]),
                        const SizedBox(height: 24),
                        _buildFilterSection('EQUIPMENT', [
                          'Assisted',
                          'Band',
                          'Barbell',
                          'Battling Rope',
                          'Body weight',
                          'Bosu ball',
                          'Cable',
                          'Dumbbell',
                          'EZ Barbell',
                          'Kettlebell',
                          'Leverage machine',
                          'Medicine Ball',
                          'Olympic barbell',
                          'Pilates Machine',
                          'Power Sled',
                          'Resistance Band',
                          'Roll',
                          'Rollball',
                          'Rope',
                          'Sled machine',
                          'Smith machine',
                          'Stability ball',
                          'Stick',
                          'Suspension',
                          'Trap bar',
                          'Vibrate Plate',
                          'Weighted',
                          'Wheel roller',
                        ]),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white70 : const Color(0xFF4A5568),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExerciseList(bool isDark, Color textColor, Color cardColor) {
    final future = Supabase.instance.client
        .from('exercises')
        .select()
        .eq('group_path', _selectedMuscle!)
        .order('exercise_name', ascending: true);

    return Column(
      children: [
        // Back button header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textColor),
                onPressed: () => setState(() => _selectedMuscle = null),
              ),
              Expanded(
                child: Text(
                  '${_selectedMuscle![0].toUpperCase()}${_selectedMuscle!.substring(1)} Exercises',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading exercises: ${snapshot.error}',
                    style: TextStyle(color: textColor),
                  ),
                );
              }
              final data = snapshot.data;
              if (data == null || data.isEmpty) {
                return Center(
                  child: Text(
                    'No exercises found for this muscle.',
                    style: TextStyle(color: textColor),
                  ),
                );
              }

              final exercises = data.map((json) => ExerciseDetail.fromJson(json)).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  return ExerciseDetailCard(
                    exercise: exercises[index],
                    isDarkMode: isDark,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ExerciseDetail {
  final String name;
  final String muscleId;
  final String imagePath;
  final String target;
  final String synergists;
  final String difficulty;
  final List<String> steps;

  ExerciseDetail({
    required this.name,
    required this.muscleId,
    required this.imagePath,
    required this.target,
    required this.synergists,
    required this.difficulty,
    required this.steps,
  });

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    // Helper to get non-null string
    String getString(String key, {String defaultVal = ''}) {
      return json[key]?.toString() ?? defaultVal;
    }

    // Collect instructions
    List<String> instructions = [];
    for (int i = 1; i <= 4; i++) {
      final step = json['instruction_$i']?.toString();
      if (step != null && step.isNotEmpty) {
        instructions.add(step);
      }
    }
    // Fallback if no instructions found
    if (instructions.isEmpty) {
      instructions = ['Follow the video demonstration.'];
    }

    return ExerciseDetail(
      name: getString('exercise_name', defaultVal: 'Unknown Exercise'),
      muscleId: getString('group_path'),
      imagePath: getString('urls'),
      target: getString('target_muscle', defaultVal: getString('target', defaultVal: (json['group_path'] as String? ?? 'General').toUpperCase())),
      synergists: getString('synergist', defaultVal: getString('synergists', defaultVal: getString('syntects', defaultVal: 'Various'))),
      difficulty: getString('difficulty_level', defaultVal: getString('difficulty', defaultVal: 'Intermediate')),
      steps: instructions,
    );
  }
}

class ExerciseDetailCard extends StatelessWidget {
  final ExerciseDetail exercise;
  final bool isDarkMode;

  const ExerciseDetailCard({
    Key? key,
    required this.exercise,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: Colors.red,
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 26), // Balance the back icon
              ],
            ),
          ),

          // Video/Image Preview
          Container(
            width: double.infinity,
            color: isDarkMode ? Colors.black26 : Colors.grey.shade100,
            child: exercise.imagePath.isNotEmpty
                ? _buildMediaPreview(exercise.imagePath, isDarkMode)
                : SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ),
          ),

          // Instructions
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: exercise.steps.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Metadata
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildMetaRow('Target', exercise.target, textColor),
                const SizedBox(height: 8),
                _buildMetaRow('Synergist', exercise.synergists, textColor),
                const SizedBox(height: 8),
                _buildMetaRow('Difficulty', exercise.difficulty, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, Color textColor) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red, // Changed to red
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPreview(String url, bool isDarkMode) {
    // Simple check for video extensions
    final cleanUrl = url.trim();
    final isVideo = cleanUrl.toLowerCase().endsWith('.mp4') ||
        cleanUrl.toLowerCase().endsWith('.mov') ||
        cleanUrl.toLowerCase().endsWith('.webm');

    if (isVideo) {
      return VideoPlayerWidget(videoUrl: cleanUrl);
    } else {
      return Image.network(
        cleanUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

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
        setState(() {
          _isInitialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0); // Mute for autoplay
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      return AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}

/// Muscle map widget handling multiple muscles
class MuscleMap extends StatelessWidget {
  final String gender; // 'male' or 'female'
  final String side;   // 'front' or 'back'
  final String? highlightedMuscle;
  final ValueChanged<String> onTapMuscle;
  final bool isDarkMode;

  const MuscleMap({
    Key? key,
    required this.gender,
    required this.side,
    required this.highlightedMuscle,
    required this.onTapMuscle,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // folders like: assets/svg/male/front/base_day.svg, abs.svg, chest.svg, etc.
    final basePath = 'assets/svg/$gender/$side';

    // Define available muscles based on side
    final List<String> muscles = side == 'front'
        ? [
            'abs',
            'chest',
            'biceps',
            'shoulders',
            'thighs',
            'obliques',
            'traps',
            'forarms',
            'neck'
          ]
        : [
            'lats',
            'lowerback',
            'traps',
            'shoulders',
            'triceps',
            'forarms',
            'hips&glutes',
            'hamstrings',
            'calves'
          ];

    // Debug flag to show hit boxes
    const bool showDebugBoxes = false;

    // Define regions based on SVG analysis (approximate relative coordinates)
    final List<MuscleRegion> regions = side == 'front'
        ? [
            MuscleRegion(id: 'neck', left: 0.42, top: 0.09, width: 0.16, height: 0.07, label: 'Neck'),
            MuscleRegion(id: 'traps', left: 0.32, top: 0.11, width: 0.36, height: 0.06, label: 'Traps'),
            MuscleRegion(id: 'shoulders', left: 0.18, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'), // Left
            MuscleRegion(id: 'shoulders', left: 0.64, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'), // Right
            MuscleRegion(id: 'chest', left: 0.30, top: 0.18, width: 0.40, height: 0.11, label: 'Chest'),
            MuscleRegion(id: 'biceps', left: 0.12, top: 0.28, width: 0.16, height: 0.12, label: 'Bic'), // Left
            MuscleRegion(id: 'biceps', left: 0.72, top: 0.28, width: 0.16, height: 0.12, label: 'Bic'), // Right
            MuscleRegion(id: 'forarms', left: 0.06, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'), // Left
            MuscleRegion(id: 'forarms', left: 0.76, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'), // Right
            MuscleRegion(id: 'abs', left: 0.38, top: 0.29, width: 0.24, height: 0.16, label: 'Abs'),
            MuscleRegion(id: 'obliques', left: 0.30, top: 0.32, width: 0.08, height: 0.12, label: 'Obl'), // Left
            MuscleRegion(id: 'obliques', left: 0.62, top: 0.32, width: 0.08, height: 0.12, label: 'Obl'), // Right
            MuscleRegion(id: 'thighs', left: 0.28, top: 0.50, width: 0.44, height: 0.25, label: 'Thighs'),
          ]
        : [
            MuscleRegion(id: 'traps', left: 0.35, top: 0.10, width: 0.30, height: 0.06, label: 'Traps'),
            MuscleRegion(id: 'shoulders', left: 0.18, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'),
            MuscleRegion(id: 'shoulders', left: 0.64, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'),
            MuscleRegion(id: 'lats', left: 0.30, top: 0.22, width: 0.40, height: 0.18, label: 'Lats'),
            MuscleRegion(id: 'lowerback', left: 0.38, top: 0.40, width: 0.24, height: 0.08, label: 'LowBk'),
            MuscleRegion(id: 'triceps', left: 0.15, top: 0.26, width: 0.14, height: 0.12, label: 'Tri'),
            MuscleRegion(id: 'triceps', left: 0.71, top: 0.26, width: 0.14, height: 0.12, label: 'Tri'),
            MuscleRegion(id: 'forarms', left: 0.06, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'),
            MuscleRegion(id: 'forarms', left: 0.76, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'),
            MuscleRegion(id: 'hips&glutes', left: 0.30, top: 0.48, width: 0.40, height: 0.14, label: 'Glutes'),
            MuscleRegion(id: 'hamstrings', left: 0.30, top: 0.62, width: 0.40, height: 0.16, label: 'Hams'),
            MuscleRegion(id: 'calves', left: 0.30, top: 0.78, width: 0.40, height: 0.14, label: 'Calves'),
          ];

    return AspectRatio(
      aspectRatio: 1080 / 1920, // Match SVG aspect ratio
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset localPosition = details.localPosition;
              final Size size = box.size;
              
              // Normalize coordinates (0.0 to 1.0)
              final double dx = localPosition.dx / size.width;
              final double dy = localPosition.dy / size.height;

              print('Tap at: $dx, $dy (Size: $size)');

              for (final region in regions) {
                if (dx >= region.left && dx <= region.left + region.width &&
                    dy >= region.top && dy <= region.top + region.height) {
                  print('Hit region: ${region.id}');
                  onTapMuscle(region.id);
                  break;
                }
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base outline
                SvgPicture.asset(
                  '$basePath/base_day.svg',
                  fit: BoxFit.contain,
                  colorFilter: isDarkMode
                      ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                      : null,
                ),

                // Muscle layers (Visual only, no interaction)
                ...muscles.map((muscle) => IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: highlightedMuscle == muscle ? 1.0 : 0.0,
                        child: SvgPicture.asset(
                          '$basePath/$muscle.svg',
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            Colors.redAccent.withOpacity(0.85),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    )),
                
                // Debug overlay
                if (showDebugBoxes)
                  CustomPaint(
                    size: Size.infinite,
                    painter: HitBoxPainter(regions: regions),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MuscleRegion {
  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
  final String label;

  MuscleRegion({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.label,
  });
}

class HitBoxPainter extends CustomPainter {
  final List<MuscleRegion> regions;
  HitBoxPainter({required this.regions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final border = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final region in regions) {
      final rect = Rect.fromLTWH(
        region.left * size.width,
        region.top * size.height,
        region.width * size.width,
        region.height * size.height,
      );
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, border);
      
      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: region.label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, rect.center - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

