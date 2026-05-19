/// Environment configuration — selected at compile time via:
///   flutter run  --dart-define=ENV=staging
///   flutter build web --dart-define=ENV=staging
///
/// Omitting the flag (or passing ENV=production) always targets production.
/// No runtime switching — the environment is baked into the binary.
library;

// ── Environment enum ──────────────────────────────────────────────────────────

enum AppEnv { production, staging }

// ── Config class ──────────────────────────────────────────────────────────────

class EnvConfig {
  EnvConfig._(); // prevent instantiation

  /// Value injected by --dart-define=ENV=staging (defaults to 'production')
  static const _envName =
      String.fromEnvironment('ENV', defaultValue: 'production');

  static AppEnv get environment =>
      _envName == 'staging' ? AppEnv.staging : AppEnv.production;

  static bool get isStaging => environment == AppEnv.staging;
  static bool get isProduction => environment == AppEnv.production;

  // ── Supabase ────────────────────────────────────────────────────────────────

  static String get supabaseUrl => isStaging
      ? 'https://vniisqetezmbwovwbxnt.supabase.co'      // staging project
      : 'https://wewztpamzhrzbbgyutyf.supabase.co';     // production project

  static String get supabaseAnonKey => isStaging
      ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
        '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuaWlzcWV0ZXptYndvdndieG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyMDE5MDUsImV4cCI6MjA5Mzc3NzkwNX0'
        '.RZgIWpUqVRnT2fMmZ-S8U9YRR9H-PLmPN07cwcV5EQA'
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
        '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0'
        '.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws';

  // ── Display name (useful for logging / banner) ──────────────────────────────

  static String get displayName =>
      isStaging ? 'STAGING' : 'PRODUCTION';
}
