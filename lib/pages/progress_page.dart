import 'package:flutter/material.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF0005);
    const orange = Color(0xFFFF8C42);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pageBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [red, orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day streak card
                    _StreakCard(isDarkMode: isDarkMode),

                    const SizedBox(height: 20),

                    // This week calendar
                    _SectionTitle('This Week', isDarkMode: isDarkMode),
                    const SizedBox(height: 8),
                    _WeekCalendar(isDarkMode: isDarkMode),

                    const SizedBox(height: 20),

                    // Quick stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '4',
                            label: 'Workouts This Week',
                            isDarkMode: isDarkMode,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            value: '1,850',
                            label: 'Calories Burned',
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Plan progress
                    _SectionTitle('Your Custom Plan', isDarkMode: isDarkMode),
                    const SizedBox(height: 8),
                    _PlanCard(isDarkMode: isDarkMode),

                    const SizedBox(height: 24),

                    // Calories
                    _SectionTitle('Calories This Week', isDarkMode: isDarkMode),
                    const SizedBox(height: 8),
                    _CaloriesCard(isDarkMode: isDarkMode),

                    const SizedBox(height: 24),

                    // Unit toggle
                    _UnitToggle(isDarkMode: isDarkMode),

                    const SizedBox(height: 20),

                    // Weight progress
                    _SectionTitle('Weight Progress', isDarkMode: isDarkMode),
                    const SizedBox(height: 8),
                    _WeightProgressCard(isDarkMode: isDarkMode),

                    const SizedBox(height: 16),

                    // Update weight
                    _UpdateWeightCard(isDarkMode: isDarkMode),

                    const SizedBox(height: 24),

                    // Chart placeholder
                    _SectionTitle('Weekly Progress Chart', isDarkMode: isDarkMode),
                    const SizedBox(height: 8),
                    _ChartPlaceholder(isDarkMode: isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),


    );
  }
}

/* ---------------------- Small UI widgets ---------------------- */

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDarkMode;
  const _SectionTitle(this.text, {this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : const Color(0xFF333333),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final bool isDarkMode;
  const _StreakCard({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF0005);
    const orange = Color(0xFFFF8C42);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [red, orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: red.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                '5',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '🔥',
                style: TextStyle(fontSize: 42),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Day Streak!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white24,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _PlanInfoItem(
                  label: 'Current Plan',
                  value: 'Plan 3 of 12',
                ),
                SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    color: Colors.white38,
                    thickness: 1,
                    width: 28,
                  ),
                ),
                _PlanInfoItem(
                  label: 'Days Remaining',
                  value: '63 Days',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanInfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _PlanInfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  final bool isDarkMode;
  const _WeekCalendar({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    final days = [
      {'label': 'M', 'completed': true, 'text': '✓'},
      {'label': 'T', 'completed': true, 'text': '✓'},
      {'label': 'W', 'completed': true, 'text': '✓'},
      {'label': 'T', 'completed': true, 'text': '✓'},
      {'label': 'F', 'completed': true, 'text': '✓'},
      {'label': 'S', 'completed': false, 'text': '29'},
      {'label': 'S', 'completed': false, 'text': '30'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days
            .map(
              (d) => Column(
                children: [
                  Text(
                    d['label']! as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (d['completed'] as bool)
                          ? const Color(0xFF10B981)
                          : (isDarkMode ? Colors.white24 : const Color(0xFFE5E7EB)),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      d['text']! as String,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: (d['completed'] as bool)
                            ? Colors.white
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool isDarkMode;
  const _StatCard({required this.value, required this.label, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF0005),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final bool isDarkMode;
  const _PlanCard({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Full Body Transformation',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Week 3 of 12',
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white70 : const Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 10),
          _LinearBar(progress: 0.25),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '25%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
              Text(
                '21 days completed',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  final bool isDarkMode;
  const _CaloriesCard({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Goal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              Text(
                '12,950',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Target: 15,400 kcal',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 10),
          _LinearBar(progress: 0.84),
          const SizedBox(height: 14),
          Row(
            children: [
              _MacroItem(value: '875g', label: 'Protein', isDarkMode: isDarkMode),
              const SizedBox(width: 10),
              _MacroItem(value: '1,260g', label: 'Carbs', isDarkMode: isDarkMode),
              const SizedBox(width: 10),
              _MacroItem(value: '455g', label: 'Fats', isDarkMode: isDarkMode),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroItem extends StatelessWidget {
  final String value;
  final String label;
  final bool isDarkMode;
  const _MacroItem({required this.value, required this.label, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white10 : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF0005),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final bool isDarkMode;
  const _UnitToggle({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Weight Unit:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF333333),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _ToggleChip(label: 'lbs', isActive: true, isDarkMode: isDarkMode),
                _ToggleChip(label: 'kg', isActive: false, isDarkMode: isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDarkMode;
  const _ToggleChip({required this.label, required this.isActive, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFF0005) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.white : (isDarkMode ? Colors.white70 : const Color(0xFF666666)),
        ),
      ),
    );
  }
}

class _WeightProgressCard extends StatelessWidget {
  final bool isDarkMode;
  const _WeightProgressCard({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _WeightItem(label: 'Start', value: '185 lbs', isDarkMode: isDarkMode),
              _WeightItem(label: 'Current', value: '178 lbs', isDarkMode: isDarkMode),
              _WeightItem(label: 'Target', value: '170 lbs', isDarkMode: isDarkMode),
            ],
          ),
          const SizedBox(height: 14),
          const _LinearBar(progress: 0.47),
          const SizedBox(height: 8),
          const Text(
            '7 lbs lost • 8 lbs to go',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WeightItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;
  const _WeightItem({required this.label, required this.value, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : const Color(0xFF333333),
          ),
        ),
      ],
    );
  }
}

class _UpdateWeightCard extends StatelessWidget {
  final bool isDarkMode;
  const _UpdateWeightCard({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Update This Week's Weight",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Enter weight',
                    hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFFF0005), width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                  color: isDarkMode ? Colors.white10 : Colors.white,
                ),
                child: Text(
                  'lbs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  // no logic yet – design only
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0005),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final bool isDarkMode;
  const _ChartPlaceholder({this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Center(
        child: Text(
          'Weight chart (UI placeholder)',
          style: TextStyle(
            color: isDarkMode ? Colors.white38 : const Color(0xFF999999),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LinearBar extends StatelessWidget {
  final double progress; // 0–1
  const _LinearBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
            ),
          ),
        ),
      ),
    );
  }
}
