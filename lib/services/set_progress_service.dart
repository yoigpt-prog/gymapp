import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents the saved progress for a single set.
class SetProgress {
  final int setIndex;
  int reps;
  bool isCompleted;
  DateTime? completedAt;

  SetProgress({
    required this.setIndex,
    required this.reps,
    required this.isCompleted,
    this.completedAt,
  });

  factory SetProgress.fromJson(Map<String, dynamic> json) {
    return SetProgress(
      setIndex: (json['set_index'] as int? ?? 0),
      reps: (json['reps'] as int? ?? 10),
      isCompleted: (json['is_completed'] as bool? ?? false),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }
}

/// Handles all Supabase I/O for per-set workout progress.
///
/// Table: user_exercise_set_progress
/// Unique key: (user_id, plan_id, week_number, day_number, exercise_id, set_index)
///
/// NOTE: plan_id is always non-null in practice. When the caller has no
/// ai_plans id (e.g. guest before quiz), pass the user's own UUID as planId
/// so the unique constraint always has a concrete value.
class SetProgressService {
  static final SetProgressService _instance = SetProgressService._internal();
  factory SetProgressService() => _instance;
  SetProgressService._internal();

  final _client = Supabase.instance.client;

  String? _parsePlanId(String planId) {
    final clean = planId.trim();
    final regExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (regExp.hasMatch(clean)) return clean;
    final user = _client.auth.currentUser;
    if (user != null) return user.id;
    return null;
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  /// Loads all saved set rows for a specific exercise on a specific day.
  /// Returns a map of setIndex → SetProgress (empty map if nothing saved yet).
  Future<Map<int, SetProgress>> loadSetProgress({
    required String planId,   // never null — use user.id as fallback if no plan
    required int weekNumber,
    required int dayNumber,
    required String exerciseId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    try {
      final parsedPlanId = _parsePlanId(planId) ?? user.id;
      debugPrint('[SETS] loading saved progress for exercise_id=$exerciseId '
          'week=$weekNumber day=$dayNumber planId=$parsedPlanId');

      final rows = await _client
          .from('user_exercise_set_progress')
          .select('set_index, reps, is_completed, completed_at')
          .eq('user_id', user.id)
          .eq('plan_id', parsedPlanId)
          .eq('week_number', weekNumber)
          .eq('day_number', dayNumber)
          .eq('exercise_id', exerciseId) as List<dynamic>;

      final Map<int, SetProgress> result = {};
      for (final row in rows) {
        final sp = SetProgress.fromJson(row as Map<String, dynamic>);
        result[sp.setIndex] = sp;
      }

      debugPrint('[SETS] restored completed sets: '
          '${result.values.where((s) => s.isCompleted).length}/${result.length} '
          'for exercise_id=$exerciseId');

      return result;
    } catch (e) {
      debugPrint('[SETS] ERROR loading set progress for exercise_id=$exerciseId: $e');
      return {};
    }
  }

  /// Loads all saved set rows for an entire day to prevent N+1 queries.
  /// Returns a map of exerciseId -> list of SetProgress
  Future<Map<String, List<SetProgress>>> loadDaySetProgress({
    required String planId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    try {
      final parsedPlanId = _parsePlanId(planId) ?? user.id;
      final rows = await _client
          .from('user_exercise_set_progress')
          .select('exercise_id, set_index, reps, is_completed, completed_at')
          .eq('user_id', user.id)
          .eq('plan_id', parsedPlanId)
          .eq('week_number', weekNumber)
          .eq('day_number', dayNumber) as List<dynamic>;

      final Map<String, List<SetProgress>> result = {};
      for (final row in rows) {
        final exId = row['exercise_id'] as String;
        final sp = SetProgress.fromJson(row as Map<String, dynamic>);
        result.putIfAbsent(exId, () => []).add(sp);
      }
      return result;
    } catch (e) {
      debugPrint('[SETS] ERROR loading day set progress: $e');
      return {};
    }
  }

  // ── Save single set ─────────────────────────────────────────────────────────

  /// Persists a single set's state immediately (optimistic UI — caller updates
  /// UI before calling this, and handles failure gracefully).
  Future<bool> saveSet({
    required String planId,
    required int weekNumber,
    required int dayNumber,
    required String exerciseId,
    required int setIndex,
    required int reps,
    required bool isCompleted,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final parsedPlanId = _parsePlanId(planId) ?? user.id;
      final now = DateTime.now().toUtc().toIso8601String();

      await _client.from('user_exercise_set_progress').upsert({
        'user_id': user.id,
        'plan_id': parsedPlanId,
        'week_number': weekNumber,
        'day_number': dayNumber,
        'exercise_id': exerciseId,
        'set_index': setIndex,
        'reps': reps,
        'is_completed': isCompleted,
        'completed_at': isCompleted ? now : null,
        'updated_at': now,
      }, onConflict: 'user_id, plan_id, week_number, day_number, exercise_id, set_index');

      debugPrint('[SETS] saved set completion → exercise_id=$exerciseId '
          'setIndex=$setIndex isCompleted=$isCompleted reps=$reps');
      return true;
    } catch (e) {
      debugPrint('[SETS] ERROR saving set index=$setIndex for exercise_id=$exerciseId: $e');
      return false;
    }
  }

  // ── Save reps change ────────────────────────────────────────────────────────

  /// Persists a reps change only (completion state unchanged).
  Future<void> saveReps({
    required String planId,
    required int weekNumber,
    required int dayNumber,
    required String exerciseId,
    required int setIndex,
    required int reps,
    required bool isCompleted,
  }) async {
    await saveSet(
      planId: planId,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
      exerciseId: exerciseId,
      setIndex: setIndex,
      reps: reps,
      isCompleted: isCompleted,
    );
    debugPrint('[SETS] saved reps change → exercise_id=$exerciseId '
        'setIndex=$setIndex reps=$reps');
  }

  // ── Save all sets (bulk) ────────────────────────────────────────────────────

  /// Saves all sets for an exercise at once (used by "Mark Complete & Continue").
  Future<void> saveAllSets({
    required String planId,
    required int weekNumber,
    required int dayNumber,
    required String exerciseId,
    required List<bool> completedSets,
    required List<int> repsPerSet,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final parsedPlanId = _parsePlanId(planId) ?? user.id;
      final now = DateTime.now().toUtc().toIso8601String();
      final List<Map<String, dynamic>> rows = [];

      for (int i = 0; i < completedSets.length; i++) {
        rows.add({
          'user_id': user.id,
          'plan_id': parsedPlanId,
          'week_number': weekNumber,
          'day_number': dayNumber,
          'exercise_id': exerciseId,
          'set_index': i,
          'reps': repsPerSet.length > i ? repsPerSet[i] : 10,
          'is_completed': completedSets[i],
          'completed_at': completedSets[i] ? now : null,
          'updated_at': now,
        });
      }

      await _client.from('user_exercise_set_progress').upsert(
        rows,
        onConflict: 'user_id, plan_id, week_number, day_number, exercise_id, set_index',
      );

      debugPrint('[SETS] saved all ${rows.length} sets for exercise_id=$exerciseId');
    } catch (e) {
      debugPrint('[SETS] ERROR saving all sets for exercise_id=$exerciseId: $e');
    }
  }

  // ── Exercise complete check ─────────────────────────────────────────────────

  /// Returns true if every set for this exercise has is_completed = true.
  Future<bool> isExerciseComplete({
    required String planId,
    required int weekNumber,
    required int dayNumber,
    required String exerciseId,
    required int totalSets,
  }) async {
    if (totalSets == 0) return false;

    final progress = await loadSetProgress(
      planId: planId,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
      exerciseId: exerciseId,
    );

    if (progress.length < totalSets) return false;
    final completed = progress.values.where((s) => s.isCompleted).length;
    final result = completed >= totalSets;
    debugPrint('[SETS] exercise complete status updated → '
        'exercise_id=$exerciseId completed=$completed/$totalSets → isComplete=$result');
    return result;
  }
}
