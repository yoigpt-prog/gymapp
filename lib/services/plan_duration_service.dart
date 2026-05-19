import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanDurationService {
  static final PlanDurationService _instance = PlanDurationService._internal();
  factory PlanDurationService() => _instance;
  PlanDurationService._internal();

  /// Loads preferred plan duration weeks from SharedPreferences or Supabase DB.
  /// Standardizes fallbacks so both pages get the identical result.
  Future<int> getPreferredDurationWeeks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. INTEGER FAST PATH (Set during quiz completion)
      final intVal = prefs.getInt('duration_weeks_int');
      if (intVal != null && intVal > 0) {
        return intVal.clamp(1, 999);
      }

      // 2. STRING FALLBACK (For older app installs)
      final localDuration = prefs.getString('plan_duration');
      if (localDuration != null && localDuration.isNotEmpty) {
        final weekMatch = RegExp(r'(\d+)\s*[Ww]eeks?').firstMatch(localDuration);
        if (weekMatch != null) {
          final val = int.parse(weekMatch.group(1)!).clamp(1, 999);
          // Back-fill integer key for faster future access
          await prefs.setInt('duration_weeks_int', val);
          return val;
        }
      }

      // 3. SUPABASE DB FALLBACK (Covers fresh installs before quiz completion)
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('user_preferences')
            .select('duration_weeks')
            .eq('user_id', user.id)
            .limit(1);
        if (response.isNotEmpty && response.first['duration_weeks'] != null) {
          final dbVal = (response.first['duration_weeks'] as int).clamp(1, 999);
          // Back-fill local cache keys
          await prefs.setInt('duration_weeks_int', dbVal);
          await prefs.setBool('hasCompletedQuiz', true);
          return dbVal;
        }
      }
    } catch (e) {
      debugPrint('[PlanDurationService] Error loading preferred duration weeks: $e');
    }
    // Default fallback
    return 4;
  }

  /// Calculates the 1-based global day index for a specific date given a plan's start/creation date.
  int getGlobalDayIndex({
    required DateTime selectedDate,
    required DateTime? planCreationDate,
  }) {
    final DateTime planStartDate;
    if (planCreationDate != null) {
      planStartDate = planCreationDate;
    } else {
      // Default fallback if no creation date is present (start of current week)
      final now = DateTime.now();
      final currentMonday = now.subtract(Duration(days: now.weekday - 1));
      planStartDate = DateTime(currentMonday.year, currentMonday.month, currentMonday.day);
    }

    final normalizedStart = DateTime(planStartDate.year, planStartDate.month, planStartDate.day);
    final normalizedSelected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final diffDays = normalizedSelected.difference(normalizedStart).inDays;
    return diffDays < 0 ? 1 : diffDays + 1;
  }
}
