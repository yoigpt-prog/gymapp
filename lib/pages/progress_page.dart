import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/red_header.dart';

// ---------------------------------------------------------------------------
// Shared data model loaded once by ProgressPage
// ---------------------------------------------------------------------------
class _ProgressData {
  final int durationWeeks;
  final int trainingDaysPerWeek;
  final int currentWeek;
  final String goalLabel; // e.g. "Lose Weight"
  final String planName; // e.g. "Lose belly fat"

  // Meal eaten stats
  final Set<int> eatenDays; // global day numbers with ≥1 eaten meal
  final int totalMealDays;
  final int elapsedDays;
  final int streakDays;
  final List<String> completedWorkoutDays;
  // Per weekday (Mon=1..Sun=7) eaten count for current week
  final Map<int, int> currentWeekEaten; // weekday -> count of eaten slots

  // Body metrics
  final double? startWeightKg;
  final double? currentWeightKg;
  final double? heightCm;

  // Weekly weights map
  final Map<int, double> weekWeights;

  const _ProgressData({
    required this.durationWeeks,
    required this.trainingDaysPerWeek,
    required this.currentWeek,
    required this.goalLabel,
    required this.planName,
    required this.eatenDays,
    required this.totalMealDays,
    required this.elapsedDays,
    required this.streakDays,
    required this.completedWorkoutDays,
    required this.currentWeekEaten,
    required this.startWeightKg,
    required this.currentWeightKg,
    required this.heightCm,
    required this.weekWeights,
  });
}

// ---------------------------------------------------------------------------
// ProgressPage – StatefulWidget that loads all shared data once
// ---------------------------------------------------------------------------
class ProgressPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const ProgressPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<ProgressPage> createState() => ProgressPageState();
}

class ProgressPageState extends State<ProgressPage> {
  _ProgressData? _data;
  bool _loading = true;
  bool _signedIn = false;

  final _supabase = Supabase.instance.client;

  // Scroll controller for hiding header
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _supabase.auth.onAuthStateChange.listen((event) {
      if (mounted) _loadAll();
    });
    _loadAll();
  }

  Future<void> refresh({bool force = false}) async {
    if (force && mounted) {
      setState(() => _loading = true);
    }
    await _loadAll();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentScrollOffset = _scrollController.offset;
    if (currentScrollOffset > _lastScrollOffset && currentScrollOffset > 50) {
      if (_showHeader) {
        setState(() => _showHeader = false);
      }
    } else if (currentScrollOffset < _lastScrollOffset) {
      if (!_showHeader) {
        setState(() => _showHeader = true);
      }
    }
    _lastScrollOffset = currentScrollOffset;
  }

  String _goalLabel(String? raw) {
    switch (raw) {
      case 'fat_loss':
        return 'Lose Weight';
      case 'muscle_gain':
        return 'Build Muscle';
      default:
        return raw ?? 'Fitness';
    }
  }

  Future<void> _loadAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted)
        setState(() {
          _loading = false;
          _signedIn = false;
          _data = null;
        });
      return;
    }
    if (mounted)
      setState(() {
        _loading = true;
        _signedIn = true;
      });

    // ── 1. User preferences ─────────────────────────────────────────────────
    int durationWeeksFromPrefs = 4;
    String goalLabel = 'Custom Plan';
    DateTime? planStartFromPrefs;

    int trainingDaysPerWeek = 4;

    try {
      final pref = await _supabase
          .from('user_preferences')
          .select('duration_weeks, training_days, goal, created_at')
          .eq('user_id', user.id)
          .maybeSingle();
      durationWeeksFromPrefs = (pref?['duration_weeks'] as int?) ?? 4;
      trainingDaysPerWeek = (pref?['training_days'] as int?) ?? 4;
      goalLabel = _goalLabel(pref?['goal'] as String?);
      if (pref?['created_at'] != null) {
        planStartFromPrefs = DateTime.tryParse(pref!['created_at'].toString());
      }
    } catch (_) {}

    // ── 2. Meal eaten data + derive actual plan duration ─────────────────────
    final Set<int> eatenDays = {};
    final Set<int> allDays = {};
    DateTime? planStartFromPlan;

    try {
      // Try with is_eaten first — also fetch created_at to get the actual plan start
      final mealRows = await _supabase
          .from('user_meal_plan')
          .select('day, is_eaten, created_at')
          .eq('user_id', user.id)
          .order('day', ascending: true);

      DateTime? firstCreatedAt;
      for (final r in (mealRows as List)) {
        final int day = (r['day'] as int?) ?? 0;
        if (day <= 0) continue;
        allDays.add(day);
        if (r['is_eaten'] == true) eatenDays.add(day);
        // Capture the earliest created_at
        if (r['created_at'] != null && firstCreatedAt == null) {
          final parsed = DateTime.tryParse(r['created_at'].toString());
          if (parsed != null) firstCreatedAt = parsed;
        }
      }
      if (firstCreatedAt != null) {
        // Normalise to midnight
        planStartFromPlan = DateTime(
            firstCreatedAt.year, firstCreatedAt.month, firstCreatedAt.day);
      }
    } catch (_) {
      // is_eaten column may not exist yet — fallback to just day
      try {
        final mealRows = await _supabase
            .from('user_meal_plan')
            .select('day')
            .eq('user_id', user.id);
        for (final r in (mealRows as List)) {
          final int day = (r['day'] as int?) ?? 0;
          if (day > 0) allDays.add(day);
        }
      } catch (_) {}
    }

    // Derive actual duration from the actual max day in the plan (same logic as MealPlanPage)
    final int maxDay =
        allDays.isEmpty ? 0 : allDays.reduce((a, b) => a > b ? a : b);
    final int durationWeeksFromPlan = maxDay > 0 ? (maxDay / 7).ceil() : 0;
    // Use the higher of the two: DB actual plan OR user preference
    final int durationWeeks = (durationWeeksFromPlan > durationWeeksFromPrefs)
        ? durationWeeksFromPlan
        : durationWeeksFromPrefs;

    // Prefer plan start date from actual plan rows (more accurate) over created_at from prefs
    final DateTime? planStart = planStartFromPlan ?? planStartFromPrefs;

    final now = DateTime.now();
    final int elapsedDays = planStart != null
        ? (now.difference(planStart).inDays + 1).clamp(0, durationWeeks * 7)
        : 0;
    final int currentWeek = planStart != null
        ? ((elapsedDays - 1) ~/ 7 + 1).clamp(1, durationWeeks)
        : 1;
    final int weekStart = (currentWeek - 1) * 7 + 1;
    final int weekEnd = weekStart + 6;

    // ── 3. Build weekly eaten map ─────────────────────────────────────────────
    final Map<int, int> weekEaten = {};
    for (final day in eatenDays) {
      if (day >= weekStart && day <= weekEnd) {
        final wd = day - weekStart + 1;
        weekEaten[wd] = (weekEaten[wd] ?? 0) + 1;
      }
    }

    // ── 4. Streak ────────────────────────────────────────────────────────────
    int streakDays = 0;
    if (planStart != null) {
      for (int i = elapsedDays; i >= 1; i--) {
        if (eatenDays.contains(i)) {
          streakDays++;
        } else {
          break;
        }
      }
    }

    // ── 5. Weekly weights ────────────────────────────────────────────────────
    final Map<int, double> weekWeights = {};
    try {
      final wwRows = await _supabase
          .from('user_weekly_weights')
          .select('week_number, weight_kg')
          .eq('user_id', user.id)
          .order('week_number');
      for (final r in (wwRows as List)) {
        weekWeights[r['week_number'] as int] =
            (r['weight_kg'] as num).toDouble();
      }
    } catch (_) {} // table may not exist yet — silently skip

    // ── 6. Body metrics + Workout completion (SharedPreferences) ─────────────
    double? startW, curW, heightCm;
    List<String> completedWorkoutDays = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      completedWorkoutDays =
          prefs.getStringList('completed_workout_days_${user.id}') ?? [];
      final wStr = prefs.getString('profile_weight') ?? '';
      final wNum = double.tryParse(wStr.replaceAll(RegExp(r'[^\d.]'), ''));
      if (wNum != null && wNum > 0) {
        startW = wNum;
        curW = wNum;
      }

      if (weekWeights.isNotEmpty) {
        final sorted = weekWeights.keys.toList()..sort();
        if (startW == null) startW = weekWeights[sorted.first];
        curW = weekWeights[sorted.last];
      }
      final hStr = prefs.getString('profile_height') ?? '';
      final hNum = double.tryParse(hStr.replaceAll(RegExp(r'[^\d.]'), ''));
      if (hNum != null && hNum > 0) heightCm = hNum;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _data = _ProgressData(
          durationWeeks: durationWeeks,
          trainingDaysPerWeek: trainingDaysPerWeek,
          currentWeek: currentWeek,
          goalLabel: goalLabel,
          planName: goalLabel,
          eatenDays: eatenDays,
          // Total days = actual plan extent (durationWeeks * 7)
          totalMealDays: durationWeeks * 7,
          elapsedDays: elapsedDays,
          streakDays: streakDays,
          completedWorkoutDays: completedWorkoutDays,
          currentWeekEaten: weekEaten,
          startWeightKg: startW,
          currentWeightKg: curW,
          heightCm: heightCm,
          weekWeights: weekWeights,
        );
        _loading = false;
      });
    }
  }

  String get _headerSubtitle {
    if (!_signedIn) return 'Sign in to view your progress';
    if (_loading || _data == null) return 'Loading…';
    return 'Week ${_data!.currentWeek} of ${_data!.durationWeeks} • ${_data!.planName}';
  }

  List<Widget> _buildCards() {
    final d = widget.isDarkMode;
    if (!_signedIn) {
      return [
        _NotSignedInBanner(isDarkMode: d),
      ];
    }
    return [
      _ProgramCompletionCard(isDarkMode: d, data: _data, loading: _loading),
      const SizedBox(height: 16),
      _StreakCard(isDarkMode: d, data: _data),
      const SizedBox(height: 16),
      _WeeklyMetricsEntryCard(isDarkMode: d),
      const SizedBox(height: 16),
      _BodyMetricsCard(isDarkMode: d, data: _data),
      const SizedBox(height: 20),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 800) {
      return _buildDesktopLayout(context, bgColor);
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (kIsWeb)
                AnimatedContainer(
                  duration: Duration.zero,
                  height: _showHeader ? null : 0,
                  child: AnimatedOpacity(
                    duration: Duration.zero,
                    opacity: _showHeader ? 1.0 : 0.0,
                    child: RedHeader(
                      title: 'Progress',
                      subtitle: _headerSubtitle,
                      onToggleTheme: widget.toggleTheme,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(children: _buildCards()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Color bgColor) {
    final d = widget.isDarkMode;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            RedHeader(
              title: 'Progress',
              subtitle: _headerSubtitle,
              onToggleTheme: widget.toggleTheme,
              isDarkMode: d,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bannerWidth = constraints.maxWidth * 0.4;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            color: d ? const Color(0xFF1E1E1E) : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  _ProgramCompletionCard(
                                      isDarkMode: d,
                                      data: _data,
                                      loading: _loading),
                                  const SizedBox(height: 16),
                                  _WeeklyTrendChart(isDarkMode: d, data: _data),
                                  const SizedBox(height: 16),
                                  _StreakCard(isDarkMode: d, data: _data),
                                  const SizedBox(height: 16),
                                  _WeeklyMetricsEntryCard(isDarkMode: d),
                                  const SizedBox(height: 16),
                                  _BodyMetricsCard(isDarkMode: d, data: _data),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        width: bannerWidth,
                        padding: const EdgeInsets.only(
                            top: 24, right: 24, bottom: 24),
                        child: Container(
                          color: d ? const Color(0xFF1E1E1E) : Colors.white,
                          child: Center(
                            child: Text(
                              'Banner Area\n40% Width',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: d ? Colors.white54 : Colors.black54,
                                fontSize: 16,
                              ),
                            ),
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
}

// ---------------------------------------------------------------------------
// Not signed in banner
// ---------------------------------------------------------------------------
class _NotSignedInBanner extends StatelessWidget {
  final bool isDarkMode;
  const _NotSignedInBanner({required this.isDarkMode});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Column(children: [
        Icon(Icons.lock_outline,
            size: 40, color: isDarkMode ? Colors.white38 : Colors.black38),
        const SizedBox(height: 12),
        Text('Sign in to view your progress',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 4),
        Text('Complete the quiz to generate your personalised plan.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white38 : Colors.grey)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Program Completion Card
// ---------------------------------------------------------------------------
class _ProgramCompletionCard extends StatelessWidget {
  final bool isDarkMode;
  final _ProgressData? data;
  final bool loading;

  const _ProgramCompletionCard({
    required this.isDarkMode,
    required this.data,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isMobile
        ? (isDarkMode ? Colors.white : Colors.black)
        : (isDarkMode ? Colors.white12 : Colors.black12);

    // Derive stats from data
    final int totalDays = data != null ? data!.durationWeeks * 7 : 0;
    final int elapsedDays = data?.elapsedDays ?? 0;

    // ── Workout stats ──────────────────────────────────────────────────────
    final int trainingDays = data?.trainingDaysPerWeek ?? 4;
    final int restDaysPerWeek = 7 - trainingDays;

    // Exact counts
    final int wTotal = (data?.durationWeeks ?? 0) * trainingDays;
    final int totalRestDays = (data?.durationWeeks ?? 0) * restDaysPerWeek;

    final int wCompleted = data?.completedWorkoutDays.length ?? 0;

    // ── Meal stats ─────────────────────────────────────────────────────────
    // totalMealDays is always durationWeeks * 7 (fixed in _loadAll)
    final int mTotal = data?.totalMealDays ?? 0;
    final int mCompleted = data?.eatenDays.length ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Program Completion',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black)),
              ),
              if (loading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFFF0000))),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(
              icon: Icons.fitness_center,
              label: 'Workout Plan',
              color: const Color(0xFFFF0000),
              isDarkMode: isDarkMode),
          const SizedBox(height: 12),
          _MetricGrid(isDarkMode: isDarkMode, metrics: [
            _MetricData(
                label: 'Total Days',
                value: loading ? '--' : '$wTotal',
                subtext: '(no rest days)',
                icon: Icons.calendar_month,
                color: const Color(0xFFFF0000)),
            _MetricData(
                label: 'Completed',
                value: loading ? '--' : '$wCompleted',
                icon: Icons.check_circle,
                color: Colors.green),
          ]),
          const SizedBox(height: 16),
          _buildProgressBar('Workout Completion', wCompleted, wTotal,
              const Color(0xFFFF0000), isDarkMode),
          const SizedBox(height: 20),
          Divider(
              height: 1,
              color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
          const SizedBox(height: 20),
          _SectionLabel(
              icon: Icons.restaurant_menu,
              label: 'Meal Plan',
              color: Colors.orange,
              isDarkMode: isDarkMode),
          const SizedBox(height: 12),
          _MetricGrid(isDarkMode: isDarkMode, metrics: [
            _MetricData(
                label: 'Total Days',
                value: loading ? '--' : '$mTotal',
                icon: Icons.calendar_month,
                color: Colors.orange),
            _MetricData(
                label: 'Completed',
                value: loading ? '--' : '$mCompleted',
                icon: Icons.check_circle,
                color: Colors.green),
          ]),
          const SizedBox(height: 16),
          _buildProgressBar('Meal Plan Completion', mCompleted, mTotal,
              Colors.orange, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
      String title, int completed, int total, Color color, bool isDark) {
    final pct = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87)),
            Text('${(pct * 100).round()}%',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// Helper section label row
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// Data class for a metric tile
class _MetricData {
  final String label;
  final String value;
  final String? subtext;
  final IconData icon;
  final Color color;
  const _MetricData({
    required this.label,
    required this.value,
    this.subtext,
    required this.icon,
    required this.color,
  });
}

// 2x2 grid of metric cards
class _MetricGrid extends StatelessWidget {
  final bool isDarkMode;
  final List<_MetricData> metrics;
  const _MetricGrid({required this.isDarkMode, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final aspectRatio = screenWidth < 360 ? 1.7 : (screenWidth < 400 ? 1.9 : 2.2);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (_, i) => _MetricTile(
        data: metrics[i],
        isDarkMode: isDarkMode,
      ),
    );
  }
}

// Single metric tile
class _MetricTile extends StatelessWidget {
  final _MetricData data;
  final bool isDarkMode;
  const _MetricTile({required this.data, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : data.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : data.color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 16, color: data.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                      height: 1.1,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (data.subtext != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    data.subtext!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Weekly Trend Chart
// ---------------------------------------------------------------------------
class _WeeklyTrendChart extends StatelessWidget {
  final bool isDarkMode;
  final _ProgressData? data;
  const _WeeklyTrendChart({required this.isDarkMode, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    // Build bar data from currentWeekEaten (weekday 1=Mon..7=Sun -> slot count)
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final eaten = data?.currentWeekEaten ?? {};
    // Max slots per day (for normalising height)
    final maxSlots =
        eaten.values.isEmpty ? 1 : eaten.values.reduce((a, b) => a > b ? a : b);
    final maxH = maxSlots < 1 ? 1 : maxSlots;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile
              ? (isDarkMode ? Colors.white : Colors.black)
              : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meal Adherence – This Week',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 4),
          Text('Meals eaten per day of the current program week',
              style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white38 : Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final count = eaten[i + 1] ?? 0;
              final factor = count > 0 ? (count / maxH).clamp(0.05, 1.0) : 0.0;
              return _BarColumn(
                  day: dayLabels[i],
                  heightFactor: factor.toDouble(),
                  isDarkMode: isDarkMode,
                  label: count > 0 ? '$count' : '');
            }),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final String day;
  final double heightFactor;
  final bool isDarkMode;
  final String label;

  const _BarColumn({
    required this.day,
    required this.heightFactor,
    required this.isDarkMode,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (label.isNotEmpty)
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF0000))),
        const SizedBox(height: 2),
        Container(
          width: 12,
          height: 80,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white10 : const Color(0xFFFFE5E5),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: heightFactor > 0 ? heightFactor : 0.01,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day,
            style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.white54 : Colors.grey)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Streak Card
// ---------------------------------------------------------------------------
class _StreakCard extends StatelessWidget {
  final bool isDarkMode;
  final _ProgressData? data;
  const _StreakCard({required this.isDarkMode, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final streak = data?.streakDays ?? 0;
    final eaten = data?.currentWeekEaten ?? {};
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile
              ? (isDarkMode ? Colors.white : Colors.black)
              : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Consistency Streak',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text('$streak ${streak == 1 ? 'day' : 'days'}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDarkMode ? Colors.white : Colors.black)),
          Text(
              streak > 0
                  ? 'Meals logged consecutively. Keep it up! 🔥'
                  : 'Log a meal today to start your streak.',
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.grey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                7,
                (i) => _StreakBubble(
                      day: dayLabels[i],
                      isActive: (eaten[i + 1] ?? 0) > 0,
                    )),
          ),
        ],
      ),
    );
  }
}

class _StreakBubble extends StatelessWidget {
  final String day;
  final bool isActive;

  const _StreakBubble({required this.day, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFF0000) : Colors.transparent,
        shape: BoxShape.circle,
        border: isActive
            ? null
            : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        day,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Body Metrics Card
// ---------------------------------------------------------------------------
class _BodyMetricsCard extends StatelessWidget {
  final bool isDarkMode;
  final _ProgressData? data;
  const _BodyMetricsCard({required this.isDarkMode, required this.data});

  String _fmt(double? v, {int dp = 1}) =>
      v != null ? v.toStringAsFixed(dp) : '—';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;

    final startW = data?.startWeightKg;
    final curW = data?.currentWeightKg;
    final heightM = data?.heightCm != null ? (data!.heightCm! / 100.0) : null;

    // Weight change
    final change = (startW != null && curW != null) ? curW - startW : null;
    final weeks = data?.durationWeeks ?? 1;
    final elapsedWks = data?.elapsedDays != null
        ? (data!.elapsedDays / 7.0).clamp(1, weeks)
        : 1.0;
    final rate = change != null ? change / elapsedWks : null;

    // BMI
    double? bmi;
    String bmiLabel = '';
    Color bmiColor = Colors.green;
    if (heightM != null && heightM > 0 && curW != null) {
      bmi = curW / (heightM * heightM);
      if (bmi < 18.5) {
        bmiLabel = 'Underweight';
        bmiColor = Colors.blue;
      } else if (bmi < 25) {
        bmiLabel = 'Normal';
        bmiColor = Colors.green;
      } else if (bmi < 30) {
        bmiLabel = 'Overweight';
        bmiColor = Colors.orange;
      } else {
        bmiLabel = 'Obese';
        bmiColor = Colors.red;
      }
    }

    final changeStr =
        change != null ? '${change >= 0 ? '+' : ''}${_fmt(change)} kg' : '—';
    final rateStr =
        rate != null ? '${rate >= 0 ? '+' : ''}${_fmt(rate)} kg/week' : '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile
              ? (isDarkMode ? Colors.white : Colors.black)
              : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Body Metrics',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black)),
          if (data == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Log your weekly weight to see body metrics.',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white38 : Colors.grey)),
            )
          else
            ...([
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _WeightStat(
                      label: 'Start',
                      value: startW != null ? '${_fmt(startW, dp: 1)} kg' : '—',
                      isDarkMode: isDarkMode),
                  _WeightStat(
                      label: 'Current',
                      value: curW != null ? '${_fmt(curW, dp: 1)} kg' : '—',
                      isDarkMode: isDarkMode,
                      isHighlight: true),
                  _WeightStat(
                      label: 'Target', value: '—', isDarkMode: isDarkMode),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 40,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: CustomPaint(
                    painter: _MiniChartPainter(color: const Color(0xFFFF0000))),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text(changeStr,
                    style: const TextStyle(
                        color: Color(0xFFFF0000),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(rateStr.isNotEmpty ? ' • $rateStr' : '',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.grey,
                        fontSize: 13)),
              ]),
              if (bmi != null) ...[
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BMI',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(_fmt(bmi, dp: 1),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: bmiColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(bmiLabel,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: bmiColor)),
                            ),
                          ]),
                        ]),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Healthy range',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey)),
                          const SizedBox(height: 4),
                          Text('18.5 – 25',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black87)),
                        ]),
                  ],
                ),
              ],
            ]),
        ],
      ),
    );
  }
}

class _WeightStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;
  final bool isHighlight;

  const _WeightStat({
    required this.label,
    required this.value,
    required this.isDarkMode,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? const Color(0xFFFF0000)
                : (isDarkMode ? Colors.white : Colors.black),
          ),
        ),
      ],
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final Color color;
  _MiniChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.8,
        size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.2, size.width, size.height * 0.6);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 7. Nutrition Progress Card
// ---------------------------------------------------------------------------
class _NutritionProgressCard extends StatelessWidget {
  final bool isDarkMode;
  final _ProgressData? data;
  const _NutritionProgressCard({required this.isDarkMode, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;

    final elapsed = data?.elapsedDays ?? 0;
    final eatenDays = data?.eatenDays.length ?? 0;
    // Adherence = % of elapsed days that had at least 1 meal eaten
    final adherence = elapsed > 0 ? (eatenDays / elapsed).clamp(0.0, 1.0) : 0.0;
    final pctStr = '${(adherence * 100).round()}%';
    final logLabel = elapsed > 0
        ? 'Logged meals on $eatenDays of $elapsed elapsed days'
        : 'No data yet – complete the quiz to start tracking';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile
              ? (isDarkMode ? Colors.white : Colors.black)
              : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nutrition Progress',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 20),
          Text('Meal Adherence',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: adherence,
                  backgroundColor:
                      isDarkMode ? Colors.white10 : Colors.grey[200],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(pctStr,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black)),
          ]),
          const SizedBox(height: 4),
          Text(logLabel,
              style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white38 : Colors.grey)),
          const SizedBox(height: 20),
          Text('Macro Balance (Avg)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroRing(
                  label: 'Protein',
                  percent: adherence.clamp(0.0, 1.0),
                  color: Colors.blue,
                  isDarkMode: isDarkMode),
              _MacroRing(
                  label: 'Carbs',
                  percent: adherence.clamp(0.0, 1.0),
                  color: Colors.orange,
                  isDarkMode: isDarkMode),
              _MacroRing(
                  label: 'Fat',
                  percent: adherence.clamp(0.0, 1.0),
                  color: Colors.purple,
                  isDarkMode: isDarkMode),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              elapsed > 0
                  ? 'Overall plan adherence: $pctStr'
                  : 'Complete the quiz to start tracking nutrition.',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFFF0000),
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.edit_calendar,
                    color: Color(0xFFFF0000), size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Consistent Logging',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black)),
                Text(logLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white54 : Colors.grey)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final bool isDarkMode;

  const _MacroRing({
    required this.label,
    required this.percent,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: percent,
            strokeWidth: 4,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white54 : Colors.grey,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Weekly Metrics Entry Card
// ---------------------------------------------------------------------------
class _WeeklyMetricsEntryCard extends StatefulWidget {
  final bool isDarkMode;
  const _WeeklyMetricsEntryCard({required this.isDarkMode});

  @override
  State<_WeeklyMetricsEntryCard> createState() =>
      _WeeklyMetricsEntryCardState();
}

class _WeeklyMetricsEntryCardState extends State<_WeeklyMetricsEntryCard> {
  bool _isKg = true;
  bool _loading = true;
  int _durationWeeks = 0;
  int _selectedWeek = 1; // which week the user is logging for
  final Map<int, double> _weekWeights = {}; // week number -> weight in kg
  final TextEditingController _weightController = TextEditingController();
  bool _saving = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Get plan duration
      final prefs = await _supabase
          .from('user_preferences')
          .select('duration_weeks, created_at')
          .eq('user_id', user.id)
          .maybeSingle();

      final weeks = (prefs?['duration_weeks'] as int?) ?? 0;

      // 2. Get saved weekly weights
      final rows = await _supabase
          .from('user_weekly_weights')
          .select('week_number, weight_kg')
          .eq('user_id', user.id)
          .order('week_number');

      final Map<int, double> loaded = {};
      for (final r in (rows as List)) {
        final wn = r['week_number'] as int;
        final wkg = (r['weight_kg'] as num).toDouble();
        loaded[wn] = wkg;
      }

      // Determine current week from plan start date
      DateTime? planStart;
      if (prefs?['created_at'] != null) {
        planStart = DateTime.tryParse(prefs!['created_at'].toString());
      }
      int currentWeek = 1;
      if (planStart != null) {
        final daysPassed = DateTime.now().difference(planStart).inDays;
        currentWeek = (daysPassed ~/ 7) + 1;
        currentWeek = currentWeek.clamp(1, weeks > 0 ? weeks : 1);
      }

      setState(() {
        _durationWeeks = weeks;
        _weekWeights.addAll(loaded);
        _selectedWeek = currentWeek;
        _loading = false;
        // Pre-fill input if current week already has a weight
        if (loaded.containsKey(currentWeek)) {
          final val =
              _isKg ? loaded[currentWeek]! : loaded[currentWeek]! * 2.20462;
          _weightController.text = val.toStringAsFixed(1);
        }
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _logWeight() async {
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final kgValue = _isKg ? raw : raw / 2.20462;
    final finalWeight = double.parse(kgValue.toStringAsFixed(2));

    setState(() => _saving = true);
    
    try {
      // 1. Check if record exists
      final existing = await _supabase
          .from('user_weekly_weights')
          .select('id')
          .eq('user_id', user.id)
          .eq('week_number', _selectedWeek)
          .maybeSingle();

      if (existing != null) {
        // 2a. Update existing
        await _supabase
            .from('user_weekly_weights')
            .update({'weight_kg': finalWeight})
            .eq('id', existing['id']);
      } else {
        // 2b. Insert new
        await _supabase
            .from('user_weekly_weights')
            .insert({
          'user_id': user.id,
          'week_number': _selectedWeek,
          'weight_kg': finalWeight,
        });
      }

      if (mounted) {
        setState(() {
          _weekWeights[_selectedWeek] = kgValue;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weight logged successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        
        // Let the parent refresh data if needed
        if (context.findAncestorStateOfType<ProgressPageState>() != null) {
          context.findAncestorStateOfType<ProgressPageState>()!.refresh();
        }
      }
    } catch (e) {
      print('Error logging weight: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not save weight.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _displayWeight(double kg) {
    if (_isKg) return '${kg.toStringAsFixed(1)} kg';
    return '${(kg * 2.20462).toStringAsFixed(1)} lbs';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final dimColor = widget.isDarkMode ? Colors.white12 : Colors.black12;
    final subColor = widget.isDarkMode ? Colors.white38 : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile
              ? (widget.isDarkMode ? Colors.white : Colors.black)
              : (widget.isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log Weekly Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          if (_durationWeeks > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Logging for Week $_selectedWeek of $_durationWeeks',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
          ],
          const SizedBox(height: 16),
          // Weight input row with unit toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _showWeightPicker(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isDarkMode
                            ? Colors.white24
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _weightController.text.isEmpty
                          ? 'Weight'
                          : _weightController.text,
                      style: TextStyle(
                        color: _weightController.text.isEmpty
                            ? subColor
                            : (widget.isDarkMode ? Colors.white : Colors.black),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.white10
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isKg = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isKg
                              ? const Color(0xFFFF0000)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'kg',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isKg
                                ? Colors.white
                                : (widget.isDarkMode
                                    ? Colors.white54
                                    : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isKg = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isKg
                              ? const Color(0xFFFF0000)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'lbs',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !_isKg
                                ? Colors.white
                                : (widget.isDarkMode
                                    ? Colors.white54
                                    : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Log button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _logWeight,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                disabledBackgroundColor: Colors.red.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Log',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          // ── Weekly weights list ──────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFF0000), strokeWidth: 2)),
            )
          else if (_durationWeeks > 0) ...[
            const SizedBox(height: 20),
            Divider(color: dimColor, height: 1),
            const SizedBox(height: 12),
            Text(
              'Each Week Weight',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(_durationWeeks, (i) {
              final weekNum = i + 1;
              final hasWeight = _weekWeights.containsKey(weekNum);
              final isSelected = _selectedWeek == weekNum;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedWeek = weekNum;
                    if (hasWeight) {
                      final val = _isKg
                          ? _weekWeights[weekNum]!
                          : _weekWeights[weekNum]! * 2.20462;
                      _weightController.text = val.toStringAsFixed(1);
                    } else {
                      _weightController.clear();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF0000).withOpacity(0.08)
                        : (widget.isDarkMode
                            ? Colors.white.withOpacity(0.04)
                            : const Color(0xFFF8F8F8)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF0000)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF0000)
                              : (hasWeight
                                  ? const Color(0xFFFF0000).withOpacity(0.12)
                                  : (widget.isDarkMode
                                      ? Colors.white10
                                      : Colors.grey.withOpacity(0.15))),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$weekNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (hasWeight
                                    ? const Color(0xFFFF0000)
                                    : (widget.isDarkMode
                                        ? Colors.white38
                                        : Colors.grey)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Week $weekNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: widget.isDarkMode
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        hasWeight
                            ? _displayWeight(_weekWeights[weekNum]!)
                            : '—',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasWeight
                              ? const Color(0xFFFF0000)
                              : (widget.isDarkMode
                                  ? Colors.white24
                                  : Colors.black26),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.edit_outlined,
                            size: 14, color: Color(0xFFFF0000)),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showWeightPicker(BuildContext context) {
    // Determine initial values based on current input or defaults
    double initialWeight = 70.0;
    if (_weightController.text.isNotEmpty) {
      initialWeight = double.tryParse(_weightController.text) ?? 70.0;
    } else if (_isKg == false) {
      initialWeight = 154.0;
    }

    int integerPart = initialWeight.truncate();
    int decimalPart = ((initialWeight - integerPart) * 10).round();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
                  widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                'Select Weight',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                height: 150,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Integer part picker
                      SizedBox(
                        width: 60,
                        child: ListWheelScrollView.useDelegate(
                          itemExtent: 40,
                          perspective: 0.005,
                          physics: const FixedExtentScrollPhysics(),
                          controller: FixedExtentScrollController(
                              initialItem: integerPart),
                          onSelectedItemChanged: (index) {
                            setDialogState(() {
                              integerPart = index;
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _isKg ? 300 : 660, // Arbitrary max
                            builder: (context, index) {
                              final isSelected = index == integerPart;
                              return Center(
                                child: Text(
                                  '$index',
                                  style: TextStyle(
                                    fontSize: isSelected ? 24 : 18,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFFFF0000)
                                        : (widget.isDarkMode
                                            ? Colors.white38
                                            : Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Text(
                        '.',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      // Decimal part picker
                      SizedBox(
                        width: 60,
                        child: ListWheelScrollView.useDelegate(
                          itemExtent: 40,
                          perspective: 0.005,
                          physics: const FixedExtentScrollPhysics(),
                          controller: FixedExtentScrollController(
                              initialItem: decimalPart),
                          onSelectedItemChanged: (index) {
                            setDialogState(() {
                              decimalPart = index;
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 10, // 0-9
                            builder: (context, index) {
                              final isSelected = index == decimalPart;
                              return Center(
                                child: Text(
                                  '$index',
                                  style: TextStyle(
                                    fontSize: isSelected ? 24 : 18,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFFFF0000)
                                        : (widget.isDarkMode
                                            ? Colors.white38
                                            : Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _weightController.text = '$integerPart.$decimalPart';
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      color: Color(0xFFFF0000),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
