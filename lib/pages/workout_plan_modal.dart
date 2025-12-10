import 'package:flutter/material.dart';

class WorkoutPlanModal extends StatelessWidget {
  const WorkoutPlanModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: const Color(0xFFFF0000),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Workout Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Weekly plan
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEK 1',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Workout days
                  _buildWorkoutDay(
                    'Mon, Nov 25 - Day 1',
                    '6 exercises',
                    completed: true,
                    isToday: false,
                  ),
                  _buildWorkoutDay(
                    'Tue, Nov 26 - Day 2',
                    '5 exercises',
                    completed: true,
                    isToday: false,
                  ),
                  _buildWorkoutDay(
                    'Wed, Nov 27 - Day 3',
                    '6 exercises',
                    completed: true,
                    isToday: false,
                  ),
                  _buildWorkoutDay(
                    'Thu, Nov 28 - Day 4',
                    '7 exercises',
                    completed: true,
                    isToday: false,
                  ),
                  _buildWorkoutDay(
                    'Fri, Nov 29 - Day 5',
                    '6 exercises',
                    completed: false,
                    isToday: true,
                  ),
                  _buildWorkoutDay(
                    'Sat, Nov 30 - Day 6',
                    '5 exercises',
                    completed: false,
                    isToday: false,
                  ),
                  _buildWorkoutDay(
                    'Sun, Dec 1 - Day 7',
                    '4 exercises',
                    completed: false,
                    isToday: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutDay(
    String title,
    String subtitle, {
    required bool completed,
    required bool isToday,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFFE5E5) : (completed ? Colors.green.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? const Color(0xFFFF0000)
              : (completed ? Colors.green : Colors.grey.shade300),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          if (completed && !isToday)
            Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                const SizedBox(width: 4),
                Text(
                  'Completed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          if (!completed && !isToday)
            Text(
              'Upcoming',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}
