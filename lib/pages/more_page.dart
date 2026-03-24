import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/red_header.dart';
import 'legal/privacy_policy_page.dart';
import 'legal/terms_of_service_page.dart';
import 'legal/disclaimer_page.dart';
import 'legal/copyright_page.dart';
import 'legal/age_requirement_page.dart';
import 'legal/subscription_terms_page.dart';
import 'legal/data_export_page.dart';
import 'legal/delete_account_page.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/revenue_cat_service.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const SettingsPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsOn = true;

  // Colors used in the design
  final Color _red = const Color(0xFFFF0000);
  final Color _lightGreyBg = Colors.white;

  // Scroll controller for hiding header
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final backgroundColor =
            widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);

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
                          title: 'Settings',
                          subtitle: 'Manage your preferences',
                          onToggleTheme: widget.toggleTheme,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    ),
                  Expanded(
                    child: isDesktop
                        ? _buildDesktopLayout()
                        : _buildMobileLayout(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGeneralSection(),
          _buildPersonalDataSection(),
          _buildLegalSection(),
          _buildHealthSafetySection(),
          _buildSubscriptionSection(),
          _buildAccountSection(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scrollbar(
      thumbVisibility: true,
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Preferences',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildGeneralSection(),
                          _buildSubscriptionSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildPersonalDataSection(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Legal & Support',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildLegalSection(),
                          _buildAccountSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildHealthSafetySection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- SECTIONS ----------------

  Widget _buildCard({required Widget child}) {
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.black26
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    final titleColor = widget.isDarkMode ? Colors.white60 : Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: titleColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ---- General ----

  Widget _buildGeneralSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('General'),
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
                _showMessage('Notifications turned ${value ? 'ON' : 'OFF'}');
              },
            ),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: widget.isDarkMode ? '🌙' : '☀️',
            label: 'Dark Mode',
            description:
                widget.isDarkMode ? 'Dark mode is on' : 'Light mode is on',
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

  // ---- Personal Data ----

  Widget _buildPersonalDataSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Data'),
          _buildMenuItem(
            iconEmoji: '📥',
            label: 'Download My Data',
            description: 'Export your personal data',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/data-export');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DataExportPage()));
              }
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '🗑️',
            label: 'Delete Account',
            description: 'Permanently delete your data',
            isDanger: true,
            trailing: const Icon(Icons.chevron_right, color: Color(0xFFFF0000)),
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/delete-account');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DeleteAccountPage()));
              }
            },
          ),
        ],
      ),
    );
  }

  // ---- AI Transparency ----

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
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/terms');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TermsOfServicePage()));
              }
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '🔒',
            label: 'Privacy Policy',
            description: 'How we protect your data',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/privacy');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyPage()));
              }
            },
          ),
        ],
      ),
    );
  }

  // ---- Health & Safety ----

  Widget _buildHealthSafetySection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Health & Safety'),
          _buildMenuItem(
            iconEmoji: '⚠️',
            label: 'Disclaimer',
            description: 'Legal information',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/disclaimer');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DisclaimerPage()));
              }
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '©️',
            label: 'Copyright',
            description: 'Intellectual property info',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/copyright');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CopyrightPage()));
              }
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '🔞',
            label: 'Age Requirement',
            description: 'Minimum age to use this app',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/age-requirement');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AgeRequirementPage()));
              }
            },
          ),
        ],
      ),
    );
  }

  // ---- Subscription ----

  Future<void> _openCustomerCenter() async {
    if (kIsWeb) {
      _showMessage('Subscription management is not available on Web');
      return;
    }
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint('[RevenueCat] CustomerCenter error: $e');
      _showMessage('Could not open subscription manager');
    }
  }

  Future<void> _restorePurchases() async {
    if (kIsWeb) {
      _showMessage('Restore is not available on Web');
      return;
    }
    try {
      final info = await RevenueCatService().restorePurchases();
      final hasActive = info?.entitlements.active.isNotEmpty ?? false;
      _showMessage(
          hasActive ? 'Purchases restored!' : 'No previous purchases found');
    } catch (e) {
      debugPrint('[RevenueCat] Restore error: $e');
      _showMessage('Restore failed — please try again');
    }
  }

  Widget _buildSubscriptionSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Subscription'),
          _buildMenuItem(
            iconEmoji: '⭐',
            label: 'Go Premium',
            description: 'Unlock all features and custom plans',
            trailing: const Icon(Icons.star, color: Color(0xFFFF0000)),
            onTap: () async {
              await RevenueCatService().showPaywall();
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '💳',
            label: 'Manage Subscription',
            description: kIsWeb
                ? 'Available on iOS & Android'
                : 'Cancel, upgrade or view your plan',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _openCustomerCenter,
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '🔄',
            label: 'Restore Purchases',
            description: 'Recover your previous subscription',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _restorePurchases,
          ),
          const Divider(height: 1),
          _buildMenuItem(
            iconEmoji: '📋',
            label: 'Subscription Terms',
            description: 'View terms and conditions',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              if (kIsWeb) {
                Navigator.pushNamed(context, '/subscription-terms');
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SubscriptionTermsPage()));
              }
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Account'),
          _buildMenuItem(
            iconEmoji: '🚪',
            label: 'Sign Out',
            description: 'Log out of your account',
            isDanger: true,
            trailing: const Icon(Icons.chevron_right, color: Color(0xFFFF0000)),
            onTap: _confirmSignOut,
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
    final Color labelColor = isDanger
        ? const Color(0xFFFF0000)
        : (widget.isDarkMode ? Colors.white : const Color(0xFF1A1A1A));
    final Color descriptionColor =
        widget.isDarkMode ? Colors.white60 : Colors.grey;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDanger
                    ? const Color(0xFFFFE5E5)
                    : const Color(0xFFFFF0F0),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: descriptionColor,
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
    // Snackbar silenced — log only
    debugPrint('[SETTINGS] $message');
  }

  void _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out',
                style: TextStyle(color: Color(0xFFFF0000))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showMessage('Signing out...');
      // TODO: call your backend to sign out
    }
  }
}
