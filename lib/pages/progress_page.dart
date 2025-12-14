import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/red_header.dart';

class ProgressPage extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const ProgressPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF0000);
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final screenWidth = MediaQuery.of(context).size.width;

    // Use desktop layout for screens wider than 800px
    if (screenWidth > 800) {
      return _buildDesktopLayout(context, bgColor);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // 1. Header
          RedHeader(
            title: 'Progress',
            subtitle: 'Week 3 of 8 • Plan: Lose belly fat',
            onToggleTheme: toggleTheme,
           isDarkMode: isDarkMode,
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 2. Overall Progress Card
                  _OverallPlanCard(isDarkMode: isDarkMode),
                  const SizedBox(height: 16),

                  // 3. This Week Stats
                  _ThisWeekStats(isDarkMode: isDarkMode),
                  const SizedBox(height: 16),



                  // 5. Weekly Metrics Entry
                  _WeeklyMetricsEntryCard(isDarkMode: isDarkMode),
                  const SizedBox(height: 16),

                  // 6. Body Metrics
                  _BodyMetricsCard(isDarkMode: isDarkMode),
                  const SizedBox(height: 16),

                  // 9. Recent Progress (Milestones)
                  _RecentProgressCard(isDarkMode: isDarkMode),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop layout with 40% banner
  Widget _buildDesktopLayout(BuildContext context, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          RedHeader(
            title: 'Progress',
            subtitle: 'Week 3 of 8 • Plan: Lose belly fat',
            onToggleTheme: toggleTheme,
            isDarkMode: isDarkMode,
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
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                _OverallPlanCard(isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _ThisWeekStats(isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _WeeklyTrendChart(isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _StreakCard(isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _WeeklyMetricsEntryCard(isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _BodyMetricsCard(isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _NutritionProgressCard(isDarkMode: isDarkMode),
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
                      padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            'Banner Area\n40% Width',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.black54,
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
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Overall Progress Card - Large Centered Design
// ---------------------------------------------------------------------------
class _OverallPlanCard extends StatefulWidget {
  final bool isDarkMode;
  const _OverallPlanCard({required this.isDarkMode});

  @override
  State<_OverallPlanCard> createState() => _OverallPlanCardState();
}

class _OverallPlanCardState extends State<_OverallPlanCard> {
  double _progressValue = 0.80; // 80% progress
  
  @override
  Widget build(BuildContext context) {
    final percentageText = '${(_progressValue * 100).toInt()}%';
    final isMobile = MediaQuery.of(context).size.width <= 800;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (widget.isDarkMode ? Colors.white : Colors.black) : (widget.isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                percentageText,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF0000),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: widget.isDarkMode ? Colors.white10 : const Color(0xFFFFE5E5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              minHeight: 16,
            ),
          ),
          const SizedBox(height: 12),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week 3 of 8',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDarkMode ? Colors.white54 : Colors.grey,
                ),
              ),
              Text(
                'Est. finish: Jan 24',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. This Week Stats - Comprehensive Weekly Overview
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// 3. This Week Stats - Data-Driven Dashboard
// ---------------------------------------------------------------------------

class UserProfile {
  final double weightKg;
  final double heightCm;
  final int age;
  final String gender;
  final double activityMultiplier; // 1.2 sedentary, 1.375 light, 1.55 moderate, 1.725 active
  final String goal; // 'Lose Weight', 'Maintain', 'Gain'

  const UserProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.gender,
    required this.activityMultiplier,
    required this.goal,
  });

  double get bmr {
    // Mifflin-St Jeor Equation
    double base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return gender == 'Male' ? base + 5 : base - 161;
  }

  double get tdee => bmr * activityMultiplier;
}

// Mock User Data
const mockUser = UserProfile(
  weightKg: 82.5,
  heightCm: 180.0,
  age: 28,
  gender: 'Male',
  activityMultiplier: 1.45, // Light-Moderate
  goal: 'Lose Weight',
);

class _ThisWeekStats extends StatefulWidget {
  final bool isDarkMode;
  const _ThisWeekStats({required this.isDarkMode});

  @override
  State<_ThisWeekStats> createState() => _ThisWeekStatsState();
}

class _ThisWeekStatsState extends State<_ThisWeekStats> {
  int _selectedTab = 0; // 0 = This Week, 1 = Overall

  // Simulation Data (Weekly)
  // In a real app, these would come from your database or state management
  final int _workoutsCompleted = 4;
  final int _workoutsPlanned = 5;
  final int _mealsLogged = 17;
  final int _mealsTotal = 21;
  
  // Weekly Macros (Actual)
  final int _proteinCurrent = 112 * 7; // Mocked weekly accumulation
  final int _carbsCurrent = 180 * 7;
  final int _fatCurrent = 45 * 7;
  
  // Targets (Daily * 7)
  final int _proteinTarget = 150 * 7;
  final int _carbsTarget = 250 * 7;
  final int _fatTarget = 65 * 7;

  // Workouts Burn (Actual/Estimated)
  final int _workoutBurn = 1850; 

  // Net Calories Logic
  // Intake = (P*4 + C*4 + F*9)
  int get _weeklyIntake => (_proteinCurrent * 4) + (_carbsCurrent * 4) + (_fatCurrent * 9);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    
    // 1. Calculate Basal Metrics
    final double dailyBMR = mockUser.bmr;
    final double weeklyBMR = dailyBMR * 7;
    
    // 2. Breakdown Calculations (Weekly)
    // Sleep: ~8 hours/day at 0.95 BMR (metabolic drop during sleep)
    final double sleepBurn = (dailyBMR / 24) * 8 * 0.95 * 7;
    
    // Breathing/Recovery (Resting Awake): ~16 hours/day (Remainder of BMR)
    final double breathingBurn = (dailyBMR / 24) * 16 * 1.05 * 7; // Slight bump for awake BMR
    
    // Activity (NEAT): TDEE - BMR (The movement part)
    // We use the multiplier to estimate non-exercise activity
    final double dailyActivityBurn = (mockUser.tdee - dailyBMR);
    final double activityBurn = dailyActivityBurn * 7;

    // Total Burned
    final int totalBurned = (_workoutBurn + activityBurn + sleepBurn + breathingBurn).toInt();
    
    // Net Calories
    final int netCalories = _weeklyIntake - totalBurned;
    final bool isDeficit = netCalories < 0;

    // Plan Adherence Calculation (Simple weighted average)
    final double workoutAdherence = (_workoutsCompleted / _workoutsPlanned).clamp(0.0, 1.0);
    final double mealAdherence = (_mealsLogged / _mealsTotal).clamp(0.0, 1.0);
    final double macroAdherence = 0.85; // Mocked consistency
    final double totalAdherence = (workoutAdherence * 0.4) + (mealAdherence * 0.4) + (macroAdherence * 0.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (widget.isDarkMode ? Colors.white : Colors.black) : (widget.isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------------------
          // 1. Header
          // -----------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on your body, plan, and activity',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDarkMode ? Colors.white54 : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildTabButton('This Week', 0),
                    _buildTabButton('Overall', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // -----------------------------------------------------------------
          // 2. Macros Section
          // -----------------------------------------------------------------
          Text(
            'Macros (Weekly Totals)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // We show daily averages in caption, but totals in bar
          _buildMacroRow('Protein', _proteinCurrent, _proteinTarget, 'g', const Color(0xFFFF0000)),
          const SizedBox(height: 12),
          _buildMacroRow('Carbs', _carbsCurrent, _carbsTarget, 'g', Colors.orange),
          const SizedBox(height: 12),
          _buildMacroRow('Fat', _fatCurrent, _fatTarget, 'g', Colors.purple),
          
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          
          // -----------------------------------------------------------------
          // 3. Calories Burned Breakdown
          // -----------------------------------------------------------------
          Text(
            'Calories Burned (Estimated)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // 4 Stacked Rows
          _buildBurnRow(
            icon: Icons.fitness_center,
            label: 'Workouts',
            value: _workoutBurn,
            color: const Color(0xFFFF0000),
            note: 'Actual logged',
          ),
          const SizedBox(height: 12),
          _buildBurnRow(
            icon: Icons.directions_walk,
            label: 'Daily Activity',
            value: activityBurn.toInt(),
            color: Colors.blue,
            note: 'Steps & movement',
          ),
          const SizedBox(height: 12),
          _buildBurnRow(
            icon: Icons.bedtime,
            label: 'Sleep',
            value: sleepBurn.toInt(),
            color: Colors.indigo,
            note: 'BMR est. (8h)',
          ),
          const SizedBox(height: 12),
          _buildBurnRow(
            icon: Icons.air,
            label: 'Breathing / Recovery',
            value: breathingBurn.toInt(),
            color: Colors.teal,
            note: 'BMR est. (16h)',
          ),
          
          const SizedBox(height: 20),
          
          // -----------------------------------------------------------------
          // 4. Total Burned & Net Calories
          // -----------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                // Total Burned
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department, color: const Color(0xFFFF0000), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Burned',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Personalized estimate',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: widget.isDarkMode ? Colors.white38 : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$totalBurned kcal',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF0000),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                
                // Net Calories
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isDeficit ? Icons.trending_down : Icons.trending_up,
                            color: isDeficit ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Net Calories',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: widget.isDarkMode ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDeficit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${netCalories > 0 ? '+' : ''}$netCalories kcal (${isDeficit ? 'deficit' : 'surplus'})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDeficit ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // 6. Plan Adherence
          // -----------------------------------------------------------------
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 'Plan Adherence',
                 style: TextStyle(
                   fontSize: 14,
                   fontWeight: FontWeight.w600,
                   color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                 ),
               ),
               Text(
                 '${(totalAdherence * 100).toInt()}%',
                 style: TextStyle(
                   fontSize: 14,
                   fontWeight: FontWeight.bold,
                   color: widget.isDarkMode ? Colors.white : Colors.black,
                 ),
               ),
             ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalAdherence,
              backgroundColor: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How closely you followed your plan this week',
            style: TextStyle(
              fontSize: 11,
              color: widget.isDarkMode ? Colors.white38 : Colors.grey,
            ),
          ),

          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // 7. Weekly Goals (Refined)
          // -----------------------------------------------------------------
          Text(
            'Weekly Goals',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildGoalRow(Icons.fitness_center, 'Complete 5 workouts', _workoutsCompleted, _workoutsPlanned, 'planned'),
          const SizedBox(height: 12),
          _buildGoalRow(Icons.restaurant, 'Log all meals', _mealsLogged, _mealsTotal, 'meals'),
          const SizedBox(height: 12),
          _buildGoalRow(Icons.local_fire_department, 'Burn 4,000 kcal', totalBurned, 4000, 'kcal'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : (widget.isDarkMode ? Colors.white54 : Colors.grey),
          ),
        ),
      ),
    );
  }

  // Updated Macro Row with dynamic "left/over" and daily avg caption
  Widget _buildMacroRow(String name, int intake, int goal, String unit, Color color) {
    final remaining = goal - intake;
    final progress = intake / goal;
    final isOver = remaining < 0;
    
    // Daily average for caption
    final int dailyAvg = (intake / 7).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                children: [
                  TextSpan(
                    text: '$intake$unit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: ' / $goal$unit',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                  ),
                  TextSpan(
                    text: '  •  ',
                    style: TextStyle(color: widget.isDarkMode ? Colors.white38 : Colors.grey[400]),
                  ),
                  TextSpan(
                    text: isOver ? '${remaining.abs()}$unit over' : '${remaining}$unit left',
                    style: TextStyle(
                      color: isOver ? Colors.red : color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.red : color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Daily avg: $dailyAvg$unit',
            style: TextStyle(
              fontSize: 10,
              color: widget.isDarkMode ? Colors.white38 : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  // New Burn Breakdown Row
  Widget _buildBurnRow({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required String note,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                note,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isDarkMode ? Colors.white38 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$value kcal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  // Not used anymore
  Widget _buildCalorieCard({
    required IconData icon,
    required String label,
    required String value,
    required String subLabel,
    required Color color,
  }) {
    return Container(); 
  }

  Widget _buildGoalRow(IconData icon, String goal, int current, int target, String unitSuffix) {
    final progress = current / target;
    final isComplete = current >= target;
    
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isComplete 
                ? const Color(0xFFFF0000) 
                : (widget.isDarkMode ? Colors.white10 : Colors.grey[100]),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isComplete ? Icons.check : icon,
            size: 14,
            color: isComplete ? Colors.white : (widget.isDarkMode ? Colors.white54 : Colors.grey),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? const Color(0xFFFF0000) : const Color(0xFFFF0000).withOpacity(0.6),
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$current / $target',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isComplete ? const Color(0xFFFF0000) : (widget.isDarkMode ? Colors.white54 : Colors.grey),
              ),
            ),
            Text(
              unitSuffix,
              style: TextStyle(
                fontSize: 9,
                color: widget.isDarkMode ? Colors.white38 : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// 4. Weekly Trend Chart
// ---------------------------------------------------------------------------
class _WeeklyTrendChart extends StatefulWidget {
  final bool isDarkMode;
  const _WeeklyTrendChart({required this.isDarkMode});

  @override
  State<_WeeklyTrendChart> createState() => _WeeklyTrendChartState();
}

class _WeeklyTrendChartState extends State<_WeeklyTrendChart> {
  int _selectedIndex = 0; // 0 = Workouts, 1 = Calories

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (widget.isDarkMode ? Colors.white : Colors.black) : (widget.isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.white10 : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      text: 'Workouts',
                      isSelected: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0),
                      isDarkMode: widget.isDarkMode,
                    ),
                    _TabButton(
                      text: 'Calories',
                      isSelected: _selectedIndex == 1,
                      onTap: () => setState(() => _selectedIndex = 1),
                      isDarkMode: widget.isDarkMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _BarColumn(day: 'Mon', heightFactor: 0.4, isDarkMode: widget.isDarkMode),
              _BarColumn(day: 'Tue', heightFactor: 0.6, isDarkMode: widget.isDarkMode),
              _BarColumn(day: 'Wed', heightFactor: 0.8, isDarkMode: widget.isDarkMode),
              _BarColumn(day: 'Thu', heightFactor: 0.5, isDarkMode: widget.isDarkMode),
              _BarColumn(day: 'Fri', heightFactor: 0.2, isDarkMode: widget.isDarkMode),
              _BarColumn(day: 'Sat', heightFactor: 0.0, isDarkMode: widget.isDarkMode), // Empty
              _BarColumn(day: 'Sun', heightFactor: 0.0, isDarkMode: widget.isDarkMode), // Empty
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? const Color(0xFFFF0000)
                : (isDarkMode ? Colors.white54 : Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final String day;
  final double heightFactor;
  final bool isDarkMode;

  const _BarColumn({
    required this.day,
    required this.heightFactor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 80,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white10 : const Color(0xFFFFE5E5),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: heightFactor > 0 ? heightFactor : 0.01, // Minimal height if 0
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
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
// 5. Streak Card
// ---------------------------------------------------------------------------
class _StreakCard extends StatelessWidget {
  final bool isDarkMode;
  const _StreakCard({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (isDarkMode ? Colors.white : Colors.black) : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consistency streak',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '5 days',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          Text(
            'Hitting both workout and calorie goals in a row.',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white54 : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StreakBubble(day: 'M', isActive: true),
              _StreakBubble(day: 'T', isActive: true),
              _StreakBubble(day: 'W', isActive: true),
              _StreakBubble(day: 'T', isActive: true),
              _StreakBubble(day: 'F', isActive: true),
              _StreakBubble(day: 'S', isActive: false),
              _StreakBubble(day: 'S', isActive: false),
            ],
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
// 6. Milestones List
// ---------------------------------------------------------------------------
class _MilestonesList extends StatelessWidget {
  final bool isDarkMode;
  const _MilestonesList({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (isDarkMode ? Colors.white : Colors.black) : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Milestones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _MilestoneItem(
            text: 'First week completed',
            isCompleted: true,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          _MilestoneItem(
            text: '10 workouts done',
            isCompleted: true,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          _MilestoneItem(
            text: '20 workouts completed',
            isCompleted: false,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          _MilestoneItem(
            text: '5 kg lost',
            isCompleted: false,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),
          Text(
            "We'll unlock more milestones as your personalized plan progresses.",
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white38 : Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final String text;
  final bool isCompleted;
  final bool isDarkMode;

  const _MilestoneItem({
    required this.text,
    required this.isCompleted,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFFFFE5E5)
                : (isDarkMode ? Colors.white10 : const Color(0xFFF5F5F5)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.lock,
            size: 14,
            color: isCompleted ? const Color(0xFFFF0000) : Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isCompleted ? FontWeight.w500 : FontWeight.w400,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Body Metrics Card
// ---------------------------------------------------------------------------
class _BodyMetricsCard extends StatelessWidget {
  final bool isDarkMode;
  const _BodyMetricsCard({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (isDarkMode ? Colors.white : Colors.black) : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Body Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _WeightStat(label: 'Start', value: '82 kg', isDarkMode: isDarkMode),
              _WeightStat(label: 'Current', value: '77.4 kg', isDarkMode: isDarkMode, isHighlight: true),
              _WeightStat(label: 'Target', value: '72 kg', isDarkMode: isDarkMode),
            ],
          ),
          const SizedBox(height: 12),
          // Mini Line Chart Placeholder
          Container(
            height: 40,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CustomPaint(
              painter: _MiniChartPainter(color: const Color(0xFFFF0000)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '-4.6 kg',
                style: TextStyle(
                  color: const Color(0xFFFF0000),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                ' • -0.6 kg/week',
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BMI',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '26.4',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Overweight',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Healthy range',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '20 – 25',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.8, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.2, size.width, size.height * 0.6);

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
  const _NutritionProgressCard({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (isDarkMode ? Colors.white : Colors.black) : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          
          // Calorie Adherence
          Text(
            'Calorie Adherence',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.71,
                    backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '71%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Last 14 days: 10 days on target',
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white38 : Colors.grey,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Macro Balance
          Text(
            'Macro Balance (Avg)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroRing(label: 'Protein', percent: 0.9, color: Colors.blue, isDarkMode: isDarkMode),
              _MacroRing(label: 'Carbs', percent: 0.6, color: Colors.orange, isDarkMode: isDarkMode),
              _MacroRing(label: 'Fat', percent: 0.8, color: Colors.purple, isDarkMode: isDarkMode),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Avg 112g protein / day • On target',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFFF0000),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Consistent Logging
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_calendar, color: Color(0xFFFF0000), size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consistent Logging',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'Logged meals 12 / 14 days',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
  State<_WeeklyMetricsEntryCard> createState() => _WeeklyMetricsEntryCardState();
}

class _WeeklyMetricsEntryCardState extends State<_WeeklyMetricsEntryCard> {
  bool _isKg = true; // true = kg, false = lbs

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (widget.isDarkMode ? Colors.white : Colors.black) : (widget.isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.08),
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
          const SizedBox(height: 16),
          // Weight input row with unit toggle
          Row(
            children: [
              // Weight text field
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Weight',
                    hintStyle: TextStyle(color: widget.isDarkMode ? Colors.white38 : Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.isDarkMode ? Colors.white24 : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.isDarkMode ? Colors.white24 : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFF0000)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // kg/lbs toggle
              Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isKg = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isKg ? const Color(0xFFFF0000) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'kg',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isKg ? Colors.white : (widget.isDarkMode ? Colors.white54 : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isKg = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isKg ? const Color(0xFFFF0000) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'lbs',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !_isKg ? Colors.white : (widget.isDarkMode ? Colors.white54 : Colors.grey),
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
          // Full-width Log button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Log',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Recent Progress Card (Milestones Timeline)
// ---------------------------------------------------------------------------
class _RecentProgressCard extends StatelessWidget {
  final bool isDarkMode;
  const _RecentProgressCard({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMobile ? (isDarkMode ? Colors.white : Colors.black) : (isDarkMode ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _ProgressMilestone(
            icon: Icons.flag,
            title: 'Started Plan',
            subtitle: 'April 5, 2025',
            status: 'Complete',
            statusColor: const Color(0xFFFF0000),
            isFirst: true,
            isDarkMode: isDarkMode,
          ),
          _ProgressMilestone(
            icon: Icons.calendar_today,
            title: 'First Week',
            subtitle: 'April 12, 2025',
            status: 'In Progress',
            statusColor: const Color(0xFFFF0000),
            isDarkMode: isDarkMode,
          ),
          _ProgressMilestone(
            icon: Icons.emoji_events,
            title: 'Reached Goal',
            subtitle: 'April 19, 2025',
            status: 'Pending',
            statusColor: Colors.grey,
            isDarkMode: isDarkMode,
          ),
          _ProgressMilestone(
            icon: Icons.verified,
            title: 'Maintain',
            subtitle: 'April 26, 2025',
            status: 'Pending',
            statusColor: Colors.grey,
            isLast: true,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }
}

class _ProgressMilestone extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final bool isFirst;
  final bool isLast;
  final bool isDarkMode;

  const _ProgressMilestone({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.isDarkMode,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF0000);
    final isComplete = status == 'Complete';
    final isInProgress = status == 'In Progress';
    
    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline indicator
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 12,
                  color: isComplete ? red : (isDarkMode ? Colors.white24 : Colors.grey[300]),
                ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isComplete 
                      ? red 
                      : (isInProgress 
                          ? red.withOpacity(0.15) 
                          : (isDarkMode ? Colors.white10 : Colors.grey[100])),
                  shape: BoxShape.circle,
                  border: isInProgress 
                      ? Border.all(color: red, width: 2) 
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isComplete 
                      ? Colors.white 
                      : (isInProgress ? red : Colors.grey),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isComplete ? red : (isDarkMode ? Colors.white24 : Colors.grey[300]),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
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
}

