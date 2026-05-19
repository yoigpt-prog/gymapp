/// WorkoutEngineService
///
/// Client-side mirror of the new SQL workout generation engine.
/// Provides constants and helpers for display logic ONLY — no DB calls.
///
/// Architecture:
///   quiz → user_preferences → generate_user_workout_plan (SQL)
///     → ai_plans.schedule_json → WorkoutPage reads schedule_json
///     → WorkoutEngineService provides labels/metadata for UI display
library workout_engine_service;

// Supported day types (must match SQL engine values exactly)
const kDayTypePush     = 'push';
const kDayTypePull     = 'pull';
const kDayTypeLegs     = 'legs';
const kDayTypeUpper    = 'upper';
const kDayTypeLower    = 'lower';
const kDayTypeFullbody = 'fullbody';
const kDayTypeCardio   = 'cardio';
const kDayTypeRecovery = 'recovery';
const kDayTypeRest     = 'rest';

/// All day types that are treated as "active rest" (no exercises loaded)
const kRestDayTypes = {kDayTypeRest, kDayTypeRecovery};

class WorkoutEngineService {
  // Singleton
  static final WorkoutEngineService _instance =
      WorkoutEngineService._internal();
  factory WorkoutEngineService() => _instance;
  WorkoutEngineService._internal();

  // ── Weekly Split Logic (mirrors SQL resolve_weekly_split) ──────────────────

  /// Returns the 7-day split for a given goal and training days per week.
  /// Index 0 = Monday, index 6 = Sunday.
  List<String> resolveWeeklySplit(String goal, int trainingDays) {
    final g = goal.toLowerCase().trim();
    final d = trainingDays.clamp(3, 7);

    if (g == 'build_muscle' || g == 'muscle_gain') {
      switch (d) {
        case 3:
          return [kDayTypePush, kDayTypeRest, kDayTypePull,
                  kDayTypeRest, kDayTypeLegs, kDayTypeRest, kDayTypeRest];
        case 4:
          return [kDayTypeUpper, kDayTypeLower, kDayTypeRest,
                  kDayTypeUpper, kDayTypeLower, kDayTypeRest, kDayTypeRest];
        case 5:
          return [kDayTypePush, kDayTypePull, kDayTypeRest,
                  kDayTypeLegs, kDayTypeUpper, kDayTypeFullbody, kDayTypeRest];
        case 6:
          return [kDayTypePush, kDayTypePull, kDayTypeLegs,
                  kDayTypeRest, kDayTypePush, kDayTypePull, kDayTypeLegs];
        case 7:
          return [kDayTypePush, kDayTypePull, kDayTypeLegs,
                  kDayTypePush, kDayTypePull, kDayTypeLegs, kDayTypeCardio];
        default:
          return [kDayTypePush, kDayTypeRest, kDayTypePull,
                  kDayTypeRest, kDayTypeLegs, kDayTypeRest, kDayTypeRest];
      }
    }

    if (g == 'fat_loss') {
      switch (d) {
        case 3:
          return [kDayTypeFullbody, kDayTypeRest, kDayTypeCardio,
                  kDayTypeRest, kDayTypeFullbody, kDayTypeRest, kDayTypeRest];
        case 4:
          return [kDayTypeUpper, kDayTypeLower, kDayTypeRest,
                  kDayTypeCardio, kDayTypeFullbody, kDayTypeRest, kDayTypeRest];
        case 5:
          return [kDayTypeUpper, kDayTypeLower, kDayTypeRest,
                  kDayTypeCardio, kDayTypeFullbody, kDayTypeCardio, kDayTypeRest];
        case 6:
          return [kDayTypePush, kDayTypePull, kDayTypeLegs,
                  kDayTypeRest, kDayTypeCardio, kDayTypeFullbody, kDayTypeCardio];
        case 7:
          return [kDayTypeUpper, kDayTypeLower, kDayTypeCardio,
                  kDayTypeFullbody, kDayTypeCardio, kDayTypeRecovery, kDayTypeCardio];
        default:
          return [kDayTypeUpper, kDayTypeLower, kDayTypeRest,
                  kDayTypeCardio, kDayTypeFullbody, kDayTypeRest, kDayTypeRest];
      }
    }

    // Default fallback
    return [kDayTypePush, kDayTypeRest, kDayTypePull,
            kDayTypeRest, kDayTypeLegs, kDayTypeRest, kDayTypeRest];
  }

  // ── Display Helpers ────────────────────────────────────────────────────────

  /// Human-readable label for a day type
  String getDayLabel(String? dayType) {
    switch (dayType?.toLowerCase().trim()) {
      case kDayTypePush:
        return 'Push Day';
      case kDayTypePull:
        return 'Pull Day';
      case kDayTypeLegs:
        return 'Legs Day';
      case kDayTypeUpper:
        return 'Upper Body';
      case kDayTypeLower:
        return 'Lower Body';
      case kDayTypeFullbody:
        return 'Full Body';
      case kDayTypeCardio:
        return 'Cardio Day';
      case kDayTypeRecovery:
        return 'Recovery Day';
      case kDayTypeRest:
        return 'Rest Day';
      default:
        return 'Workout Day';
    }
  }

  /// Emoji for a day type (used in headers and day grid chips)
  String getDayEmoji(String? dayType) {
    switch (dayType?.toLowerCase().trim()) {
      case kDayTypePush:
        return '🏋️';
      case kDayTypePull:
        return '💪';
      case kDayTypeLegs:
        return '🦵';
      case kDayTypeUpper:
        return '🔝';
      case kDayTypeLower:
        return '⬇️';
      case kDayTypeFullbody:
        return '⚡';
      case kDayTypeCardio:
        return '🏃';
      case kDayTypeRecovery:
        return '🧘';
      case kDayTypeRest:
        return '😴';
      default:
        return '💪';
    }
  }

  /// Short subtitle listing the target muscle groups for a day type
  String getMuscleSubtitle(String? dayType) {
    switch (dayType?.toLowerCase().trim()) {
      case kDayTypePush:
        return 'Chest · Shoulders · Triceps';
      case kDayTypePull:
        return 'Lats · Biceps · Traps · Lower Back';
      case kDayTypeLegs:
        return 'Quads · Hamstrings · Glutes · Calves';
      case kDayTypeUpper:
        return 'Chest · Back · Shoulders · Arms';
      case kDayTypeLower:
        return 'Quads · Hamstrings · Glutes · Calves';
      case kDayTypeFullbody:
        return 'Chest · Back · Legs · Arms';
      case kDayTypeCardio:
        return 'Cardiovascular Training';
      case kDayTypeRecovery:
        return 'Active Recovery · Mobility';
      case kDayTypeRest:
        return 'Rest & Recover';
      default:
        return '';
    }
  }

  /// Returns true if this day type should show the rest day UI
  bool isRestOrRecovery(String? dayType) {
    return kRestDayTypes.contains(dayType?.toLowerCase().trim());
  }

  /// Accent color per day type (for chips and badges)
  /// Returns hex color int
  int getDayAccentColor(String? dayType) {
    switch (dayType?.toLowerCase().trim()) {
      case kDayTypePush:
      case kDayTypePull:
      case kDayTypeLegs:
        return 0xFFCC0A16; // GymGuide red
      case kDayTypeUpper:
      case kDayTypeLower:
        return 0xFFB5060F;
      case kDayTypeFullbody:
        return 0xFFFF4444;
      case kDayTypeCardio:
        return 0xFFFF6B00; // orange-red for cardio
      case kDayTypeRecovery:
        return 0xFF4CAF50; // green for recovery
      case kDayTypeRest:
        return 0xFF888888; // grey for rest
      default:
        return 0xFFCC0A16;
    }
  }
}
