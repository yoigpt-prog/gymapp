import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'home_page.dart';
import '../services/video_cache_service.dart';
import '../services/set_progress_service.dart';
import '../config/env_config.dart';
import '../widgets/ai_coach_button.dart';

class ExerciseDetailPage extends StatefulWidget {
  final ExerciseDetail exercise;
  final bool isDarkMode;

  /// Context needed to persist set progress.
  /// [planId]     — ai_plans.id. Pass user.id as fallback when no plan exists.
  /// [weekNumber] — 1-based week number inside the plan.
  /// [dayNumber]  — 1-based global day number (across all weeks).
  final String planId;
  final int weekNumber;
  final int dayNumber;
  final List<SetProgress>? initialProgress; // Pre-fetched set progress

  const ExerciseDetailPage({
    Key? key,
    required this.exercise,
    required this.isDarkMode,
    this.planId = 'free',
    this.weekNumber = 1,
    this.dayNumber = 1,
    this.initialProgress,
  }) : super(key: key);

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late List<bool> _completedSets;
  late List<int> _repsPerSet;
  bool _isLoading = true;
  bool _hasSaveError = false;

  final SetProgressService _svc = SetProgressService();

  // Stable exercise key: always prefer exercise_id; fall back to a positional key.
  String get _exerciseId {
    final id = widget.exercise.id.trim();
    return id.isNotEmpty ? id : 'w${widget.weekNumber}_d${widget.dayNumber}_${widget.exercise.name}';
  }

  @override
  void initState() {
    super.initState();
    final totalSets = widget.exercise.sets ?? 3;
    final baseReps = widget.exercise.reps ?? 12;

    if (widget.initialProgress != null && widget.initialProgress!.isNotEmpty) {
      final count = widget.initialProgress!.length;
      final sortedProgress = List<SetProgress>.from(widget.initialProgress!)
        ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
      
      _completedSets = List.generate(count, (i) => sortedProgress[i].isCompleted);
      _repsPerSet = List.generate(count, (i) => sortedProgress[i].reps);
      _isLoading = false;
      _loadProgressSilent();
    } else {
      // Start with defaults — will be overwritten by DB data in _loadProgress.
      _completedSets = List.generate(totalSets, (_) => false);
      _repsPerSet = List.generate(totalSets, (_) => baseReps);
      _loadProgress();
    }
  }

  Future<void> _loadProgressSilent() async {
    final saved = await _svc.loadSetProgress(
      planId: widget.planId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
      exerciseId: _exerciseId,
    );

    if (!mounted) return;

    if (saved.isNotEmpty) {
      final totalSets = widget.exercise.sets ?? 3;
      final baseReps = widget.exercise.reps ?? 12;

      final maxIndex = saved.keys.fold<int>(-1, (prev, k) => k > prev ? k : prev);
      final savedCount = maxIndex + 1;
      final count = savedCount > 0 ? savedCount : totalSets;

      final List<bool> completed = List.generate(count, (i) => saved[i]?.isCompleted ?? false);
      final List<int> reps = List.generate(count, (i) => saved[i]?.reps ?? baseReps);

      setState(() {
        _completedSets = completed;
        _repsPerSet = reps;
      });
    }
  }

  // ── Load saved progress ──────────────────────────────────────────────────────

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);

    final saved = await _svc.loadSetProgress(
      planId: widget.planId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
      exerciseId: _exerciseId,
    );

    if (!mounted) return;

    if (saved.isNotEmpty) {
      final totalSets = widget.exercise.sets ?? 3;
      final baseReps = widget.exercise.reps ?? 12;

      // Determine final count: use saved count if it matches, else keep widget's.
      final maxIndex = saved.keys.fold<int>(-1, (prev, k) => k > prev ? k : prev);
      final savedCount = maxIndex + 1;
      final count = savedCount > 0 ? savedCount : totalSets;

      final List<bool> completed = List.generate(count, (i) => saved[i]?.isCompleted ?? false);
      final List<int> reps = List.generate(count, (i) => saved[i]?.reps ?? baseReps);

      setState(() {
        _completedSets = completed;
        _repsPerSet = reps;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // ── Persist helpers ──────────────────────────────────────────────────────────

  Future<void> _persistSet(int index) async {
    final ok = await _svc.saveSet(
      planId: widget.planId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
      exerciseId: _exerciseId,
      setIndex: index,
      reps: _repsPerSet[index],
      isCompleted: _completedSets[index],
    );
    if (mounted) setState(() => _hasSaveError = !ok);
    if (!ok) {
      // Brief auto-retry after 1.5 s
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      await _svc.saveSet(
        planId: widget.planId,
        weekNumber: widget.weekNumber,
        dayNumber: widget.dayNumber,
        exerciseId: _exerciseId,
        setIndex: index,
        reps: _repsPerSet[index],
        isCompleted: _completedSets[index],
      );
      if (mounted) setState(() => _hasSaveError = false);
    }
  }

  Future<void> _persistReps(int index) async {
    await _svc.saveReps(
      planId: widget.planId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
      exerciseId: _exerciseId,
      setIndex: index,
      reps: _repsPerSet[index],
      isCompleted: _completedSets[index],
    );
  }

  // ── Set actions ──────────────────────────────────────────────────────────────

  void _toggleSet(int index) {
    // 1. Optimistic UI update immediately
    setState(() => _completedSets[index] = !_completedSets[index]);
    // 2. Persist in background
    _persistSet(index);
  }

  void _changeReps(int index, int delta) {
    final newReps = (_repsPerSet[index] + delta).clamp(1, 99);
    setState(() => _repsPerSet[index] = newReps);
    _persistReps(index);
  }

  void _addSet() {
    setState(() {
      _completedSets.add(false);
      _repsPerSet.add(_repsPerSet.isNotEmpty ? _repsPerSet.last : (widget.exercise.reps ?? 12));
    });
    // Persist the new set slot
    _persistSet(_completedSets.length - 1);
  }

  void _removeSet() {
    if (_completedSets.length <= 1) return;
    final indexToDelete = _completedSets.length - 1;
    setState(() {
      _completedSets.removeLast();
      _repsPerSet.removeLast();
    });
    // Explicitly delete from DB so it doesn't linger
    _svc.deleteSet(
      planId: widget.planId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
      exerciseId: _exerciseId,
      setIndex: indexToDelete,
    );
  }

  // ── Mark complete ────────────────────────────────────────────────────────────

  Future<void> _markCompleteAndContinue() async {
    // Mark all sets complete optimistically
    setState(() {
      for (int i = 0; i < _completedSets.length; i++) {
        _completedSets[i] = true;
      }
    });

    // Bulk-save all sets as completed
    await _svc.saveAllSets(
      planId: widget.planId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
      exerciseId: _exerciseId,
      completedSets: _completedSets,
      repsPerSet: _repsPerSet,
    );

    if (mounted) Navigator.pop(context, {
      'completed': true,
      'sets': _completedSets.length,
      'reps': _repsPerSet,
    });
  }

  bool get _allSetsCompleted => _completedSets.every((c) => c);

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Media ───────────────────────────────────────────────────
                Builder(builder: (context) {
                  final cleanUrl = widget.exercise.imagePath.trim();
                  final isVideo = cleanUrl.toLowerCase().endsWith('.mp4') ||
                      cleanUrl.toLowerCase().endsWith('.mov') ||
                      cleanUrl.toLowerCase().endsWith('.webm');

                  if (isVideo) {
                    return Container(
                      width: double.infinity,
                      color: isDark ? Colors.black26 : Colors.grey.shade300,
                      child: VideoPlayerWidget(videoUrl: cleanUrl),
                    );
                  }

                  return LayoutBuilder(builder: (context, constraints) {
                    final h = (constraints.maxWidth * 9 / 16).clamp(220.0, 420.0);
                    return Container(
                      width: double.infinity,
                      height: h,
                      color: isDark ? Colors.black26 : Colors.grey.shade300,
                      child: cleanUrl.isNotEmpty
                          ? _buildMediaPreview(cleanUrl, h)
                          : const Center(child: Icon(Icons.fitness_center, size: 64, color: Colors.grey)),
                    );
                  });
                }),

                // ── Save error banner ────────────────────────────────────────
                if (_hasSaveError)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.orange.shade700,
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Could not save progress — retrying…',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Track Your Sets ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with set stepper
                      Row(
                        children: [
                          Text(
                            'Track Your Sets',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const Spacer(),
                          _stepperButton(
                            icon: Icons.remove,
                            enabled: !_isLoading && _completedSets.length > 1,
                            onTap: _removeSet,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${_completedSets.length} sets',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                          ),
                          _stepperButton(
                            icon: Icons.add,
                            enabled: !_isLoading && _completedSets.length < 10,
                            onTap: _addSet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap circle to complete · Use − + to adjust reps',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                      ),
                      const SizedBox(height: 16),

                      // Set rows — show spinner while loading saved progress
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(color: Color(0xFFFF0000)),
                          ),
                        )
                      else
                        for (int i = 0; i < _completedSets.length; i++)
                          _buildSetRow(i, isDark, cardBg, textPrimary),

                      const SizedBox(height: 24),

                      // Mark Complete button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_allSetsCompleted && !_isLoading)
                              ? _markCompleteAndContinue
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            disabledBackgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 24),
                              SizedBox(width: 8),
                              Text('Mark Complete & Continue',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Skip Exercise',
                            style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Instructions ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Instructions',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 24),
                      ...widget.exercise.steps.asMap().entries.map(
                            (e) => _buildStep(e.key + 1, e.value, isDark),
                          ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                        child: Column(children: [
                          _buildTableRow('Body Part', widget.exercise.target, isDark, isFirst: true),
                          _buildTableRow('Synergist', widget.exercise.synergist, isDark),
                          _buildTableRow('Difficulty', widget.exercise.difficulty, isDark, isLast: true),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // AI Coach button (staging only)
          if (EnvConfig.isStaging)
            Positioned.fill(
              child: AiCoachButton(
                key: const ValueKey('ai_coach_exercise_detail'),
                initialBottom: 16.0,
                minBottom: 16.0,
              ),
            ),
        ],
      ),
    );
  }

  // ── Shared stepper button ────────────────────────────────────────────────────
  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    double size = 32,
  }) {
    return Material(
      color: enabled ? const Color(0xFFFF0000) : Colors.grey.shade300,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.55, color: enabled ? Colors.white : Colors.grey.shade500),
        ),
      ),
    );
  }

  // ── Set row ──────────────────────────────────────────────────────────────────
  Widget _buildSetRow(int index, bool isDark, Color cardBg, Color textPrimary) {
    final isCompleted = _completedSets[index];
    final reps = _repsPerSet[index];
    final borderColor = isCompleted ? Colors.green : (isDark ? const Color(0xFF555555) : const Color(0xFFBBBBBB));
    final bg = isCompleted ? (isDark ? const Color(0xFF0D2E0D) : const Color(0xFFEAF7EA)) : cardBg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: isCompleted ? Colors.green.withOpacity(0.12) : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Complete circle — tap toggles completion immediately & persists
          GestureDetector(
            onTap: () => _toggleSet(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? Colors.green : Colors.grey.shade400, width: 2),
                color: isCompleted ? Colors.green : Colors.transparent,
              ),
              child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Set ${index + 1}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const Spacer(),
          // Inline reps stepper — persists on change
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepperButton(
                icon: Icons.remove,
                enabled: reps > 1,
                onTap: () => _changeReps(index, -1),
                size: 26,
              ),
              SizedBox(
                width: 68,
                child: Text(
                  '$reps reps',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.green : const Color(0xFFFF0000),
                  ),
                ),
              ),
              _stepperButton(
                icon: Icons.add,
                enabled: reps < 99,
                onTap: () => _changeReps(index, 1),
                size: 26,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Media ────────────────────────────────────────────────────────────────────
  Widget _buildMediaPreview(String url, [double? height]) {
    final cleanUrl = url.trim();
    final isVideo = cleanUrl.toLowerCase().endsWith('.mp4') ||
        cleanUrl.toLowerCase().endsWith('.mov') ||
        cleanUrl.toLowerCase().endsWith('.webm');
    if (isVideo) return VideoPlayerWidget(videoUrl: cleanUrl, height: height);
    return Image.network(
      cleanUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400)),
      loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
    );
  }

  // ── Instruction step ─────────────────────────────────────────────────────────
  Widget _buildStep(int number, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: Color(0xFFFF0000), shape: BoxShape.circle),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text,
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87, height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info table row ────────────────────────────────────────────────────────────
  Widget _buildTableRow(String label, String value, bool isDark,
      {bool isFirst = false, bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ── Video Player ─────────────────────────────────────────────────────────────────
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double? height;

  const VideoPlayerWidget({Key? key, required this.videoUrl, this.height}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    if (!mounted) return;

    final controller = await VideoCacheService.instance.getController(widget.videoUrl);
    if (!mounted) {
      if (controller != null) {
        VideoCacheService.instance.release(widget.videoUrl);
      }
      return;
    }

    if (controller != null) {
      // Ensure looping, muted, and playing — the service sets these but guard
      // in case the controller was retrieved from cache in a paused state.
      controller.setLooping(true);
      controller.setVolume(0.0);
      if (!controller.value.isPlaying) controller.play();

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _hasError = false;
      });
    } else {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint('[VideoPlayerWidget] Retry $_retryCount/$_maxRetries for: ${widget.videoUrl}');
        await Future.delayed(Duration(seconds: 1 + 2 * _retryCount));
        _loadFromCache();
      } else {
        if (mounted) setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    // ⚠️  Do NOT dispose — VideoCacheService owns the controller lifetime.
    if (_controller != null) {
      _controller!.pause();
      VideoCacheService.instance.release(widget.videoUrl);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
        ),
      );
    }

    if (_isInitialized && _controller != null) {
      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      );
    }

    // Small red spinner while initialising / retrying.
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: Color(0xFFFF0000),
          ),
        ),
      ),
    );
  }
}
