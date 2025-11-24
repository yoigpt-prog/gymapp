import 'package:flutter/material.dart';

class MorePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MorePage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool notificationsOn = true;

  // Colors used in the design
  final Color _red = const Color(0xFFFF0000);
  final Color _lightGreyBg = const Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGreyBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildActivePlanSection(),
                    _buildAccountSection(),
                    _buildLegalSection(),
                    _buildSubscriptionSection(),
                    _buildDangerZoneSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage your account settings',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- SECTIONS ----------------

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ---- Active Plan ----

  Widget _buildActivePlanSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('My Active Plans'),
          _buildMenuItem(
            iconEmoji: '💪',
            label: 'Current Workout Plan',
            description: 'Full Body Strength Training',
            trailing: IconButton(
              onPressed: () => _confirmDeletePlan('workout'),
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Delete plan',
            ),
            onTap: () {
              _showMessage('Opening workout plan details…');
            },
          ),
        ],
      ),
    );
  }

  // ---- Account ----

  Widget _buildAccountSection() {
    return _buildCard(
      child: Column(
        children: [
          _buildMenuItem(
            iconEmoji: '👤',
            label: 'My Account',
            description: 'View and edit your profile',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMessage('Open: ACCOUNT'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '🔔',
            label: 'Notifications',
            description: 'Manage notification preferences',
            trailing: Switch(
              value: notificationsOn,
              activeColor: Colors.white,
              activeTrackColor: _red,
              onChanged: (value) {
                setState(() => notificationsOn = value);
                _showMessage(
                    'Notifications turned ${value ? 'ON' : 'OFF'}');
              },
            ),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: widget.isDarkMode ? '🌙' : '☀️',
            label: 'Dark Mode',
            description: widget.isDarkMode ? 'Dark mode is on' : 'Light mode is on',
            trailing: Switch(
              value: widget.isDarkMode,
              activeColor: Colors.white,
              activeTrackColor: _red,
              onChanged: (value) {
                widget.toggleTheme();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Legal & Privacy ----

  Widget _buildLegalSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Legal & Privacy'),
          _buildMenuItem(
            iconEmoji: '📄',
            label: 'EULA',
            description: 'End User License Agreement',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMessage('Open: EULA'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '🔒',
            label: 'Privacy Policy',
            description: 'How we protect your data',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMessage('Open: PRIVACY POLICY'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '⚠️',
            label: 'Disclaimer',
            description: 'Legal information',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMessage('Open: DISCLAIMER'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '©️',
            label: 'Copyright',
            description: 'Intellectual property info',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMessage('Open: COPYRIGHT'),
          ),
        ],
      ),
    );
  }

  // ---- Subscription ----

  Widget _buildSubscriptionSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Subscription'),
          _buildMenuItem(
            iconEmoji: '💳',
            label: 'Manage Subscription',
            description: 'Cancel trial or subscription',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMessage('Open: SUBSCRIPTION'),
          ),
        ],
      ),
    );
  }

  // ---- Danger Zone ----

  Widget _buildDangerZoneSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Danger Zone'),
          _buildMenuItem(
            iconEmoji: '🗑️',
            label: 'Delete Account',
            description: 'Permanently delete your data',
            isDanger: true,
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }

  // ---------------- MENU ITEM ----------------

  Widget _buildMenuItem({
    required String iconEmoji,
    required String label,
    required String description,
    Widget? trailing,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    final Color labelColor = isDanger ? _red : const Color(0xFF1A1A1A);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDanger ? const Color(0xFFFFE5E5) : const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                iconEmoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDeletePlan(String planType) async {
    final planName = planType == 'workout'
        ? 'Full Body Strength Training'
        : 'Your plan';

    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: Text(
          'Are you sure you want to delete:\n\n$planName\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (first != true) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'This is your last chance!\n\n'
          'Click DELETE to permanently remove this plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Plan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (second == true) {
      _showMessage('Plan deleted successfully!');
      // TODO: call your backend to delete the plan
    } else {
      _showMessage('Deletion cancelled. Your plan is safe!');
    }
  }

  void _confirmDeleteAccount() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          'This will permanently delete:\n'
          '• All workout data\n'
          '• Meal plans\n'
          '• Progress history\n'
          '• Account settings\n\n'
          'This action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (first != true) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Warning'),
        content: const Text(
          'This is your LAST CHANCE to cancel!\n\n'
          'Click DELETE to permanently delete your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (second == true) {
      _showMessage('Account deletion initiated. Your account will be deleted within 24 hours.');
      // TODO: call your backend to delete account
    } else {
      _showMessage('Account deletion cancelled. Your account is safe!');
    }
  }
}
