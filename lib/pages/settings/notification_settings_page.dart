import 'package:flutter/material.dart';
import '../../services/notification_sync_service.dart';
import '../../services/notification_permission_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _isLoading = true;
  
  bool _workoutReminders = true;
  bool _mealReminders = true;
  bool _hydrationReminders = true;
  bool _sleepReminders = true;
  bool _motivationReminders = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await NotificationSyncService().getNotificationPreferences();
    if (prefs != null && mounted) {
      setState(() {
        _workoutReminders = prefs['workout_reminders'] ?? true;
        _mealReminders = prefs['meal_reminders'] ?? true;
        _hydrationReminders = prefs['hydration_reminders'] ?? true;
        _sleepReminders = prefs['sleep_reminders'] ?? true;
        _motivationReminders = prefs['motivation_reminders'] ?? true;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    // Optimistic UI update
    setState(() {
      if (key == 'workout_reminders') _workoutReminders = value;
      if (key == 'meal_reminders') _mealReminders = value;
      if (key == 'hydration_reminders') _hydrationReminders = value;
      if (key == 'sleep_reminders') _sleepReminders = value;
      if (key == 'motivation_reminders') _motivationReminders = value;
    });

    if (value) {
      // Ensure we have push permissions if they are turning something ON
      await NotificationPermissionService().requestPermission(context);
    }

    await NotificationSyncService().updateNotificationPreferences({key: value});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.red))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle('Reminders', isDark),
              _buildSwitchCard(
                title: 'Workout Reminders',
                subtitle: 'Get notified for your scheduled workouts.',
                value: _workoutReminders,
                onChanged: (v) => _updatePreference('workout_reminders', v),
                isDark: isDark,
              ),
              _buildSwitchCard(
                title: 'Meal Reminders',
                subtitle: 'Never miss a meal from your plan.',
                value: _mealReminders,
                onChanged: (v) => _updatePreference('meal_reminders', v),
                isDark: isDark,
              ),
              _buildSwitchCard(
                title: 'Hydration Reminders',
                subtitle: 'Stay hydrated throughout the day.',
                value: _hydrationReminders,
                onChanged: (v) => _updatePreference('hydration_reminders', v),
                isDark: isDark,
              ),
              _buildSwitchCard(
                title: 'Sleep Reminders',
                subtitle: 'Get reminded to wind down for recovery.',
                value: _sleepReminders,
                onChanged: (v) => _updatePreference('sleep_reminders', v),
                isDark: isDark,
              ),
              _buildSectionTitle('General', isDark),
              _buildSwitchCard(
                title: 'Motivation & Tips',
                subtitle: 'Daily AI coaching and motivation.',
                value: _motivationReminders,
                onChanged: (v) => _updatePreference('motivation_reminders', v),
                isDark: isDark,
              ),
            ],
          ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isDark,
  }) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
        value: value,
        activeColor: Colors.white,
        activeTrackColor: const Color(0xFFE53935),
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
