import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/red_header.dart';
import 'legal/privacy_policy_page.dart';
import 'legal/terms_of_service_page.dart';
import 'legal/disclaimer_page.dart';
import 'legal/copyright_page.dart';
import 'legal/age_requirement_page.dart';
import 'legal/subscription_terms_page.dart';
import 'legal/data_export_page.dart';
import 'legal/delete_account_page.dart';
import 'legal/ai_transparency_page.dart';
import 'legal/ai_transparency_page.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/revenue_cat_service.dart';
import '../widgets/desktop_right_panel.dart';

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

  static const Color _red = Color(0xFFE53935);
  static const Color _redLight = Color(0xFFFFEBEE);

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        if (isDesktop) {
          return _buildWebLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  // ─── WEB LAYOUT (new redesign) ───────────────

  Widget _buildWebLayout() {
    final bg = widget.isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RedHeader(
              title: 'Settings',
              subtitle: 'Account, billing & preferences',
              onToggleTheme: widget.toggleTheme,
              isDarkMode: widget.isDarkMode,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive ad panel: 22% of screen width, clamped to [200, 320]
                  final adPanelWidth = (constraints.maxWidth * 0.22).clamp(200.0, 320.0);

                  const double spacing = 16.0;

                  return Stack(
                    children: [
                      // Layer 1: Scrollable Content with Scrollbar on far right
                      Positioned.fill(
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(spacing),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight - (spacing * 2),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _sectionLabel('Account'),
                                          _buildAccountSection(),
                                          const SizedBox(height: 12),
                                          _sectionLabel('Subscription'),
                                          _buildSubscriptionSection(),
                                          const SizedBox(height: 12),
                                          _sectionLabel('Preferences'),
                                          _buildPreferencesSection(),
                                          const SizedBox(height: 12),
                                          _sectionLabel('Legal & Support'),
                                          _buildLegalPrivacyCard(),
                                          const SizedBox(height: 12),
                                          _buildSupportInfoCard(),
                                          const SizedBox(height: 32),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: spacing),
                                SizedBox(width: adPanelWidth), // Spacer for Ad
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Layer 2: Fixed Ad Panel
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(spacing),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(child: SizedBox()), // Allows clicks to pass through
                              const SizedBox(width: spacing),
                              SizedBox(
                                width: adPanelWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                    border: Border.all(
                                      color: widget.isDarkMode ? Colors.white : Colors.black,
                                      width: 1.0,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: DesktopRightPanel(isDarkMode: widget.isDarkMode),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  // ─── MOBILE LAYOUT (original) ────────────────

  Widget _buildMobileLayout() {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    Widget section(String title, List<Widget> items) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: widget.isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            ...items,
          ],
        ),
      );
    }

    Widget mobileItem({
      required IconData icon,
      required String label,
      required String sub,
      Color? labelColor,
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      final lc = labelColor ?? (widget.isDarkMode ? Colors.white : const Color(0xFF1A1A1A));
      return Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: labelColor ?? (widget.isDarkMode ? Colors.white60 : Colors.black54)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: lc)),
                        Text(sub, style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                  ),
                  trailing ?? Icon(Icons.chevron_right, size: 20, color: widget.isDarkMode ? Colors.white24 : Colors.black26),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
        foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.wb_sunny_outlined),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('Preferences', [
              mobileItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                sub: notificationsOn ? 'On' : 'Off',
                trailing: Switch(
                  value: notificationsOn,
                  activeTrackColor: const Color(0xFFE53935),
                  activeColor: Colors.white,
                  onChanged: (v) => setState(() => notificationsOn = v),
                ),
              ),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(
                icon: widget.isDarkMode ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
                label: 'Dark Mode',
                sub: widget.isDarkMode ? 'On' : 'Off',
                trailing: Switch(
                  value: widget.isDarkMode,
                  activeTrackColor: const Color(0xFFE53935),
                  activeColor: Colors.white,
                  onChanged: (_) => widget.toggleTheme(),
                ),
              ),
            ]),
            section('Subscription', [
              mobileItem(
                icon: Icons.workspace_premium_outlined,
                label: 'Upgrade to Premium',
                sub: 'Unlock personalized plans',
                onTap: () async => await RevenueCatService().showPaywall(),
              ),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Manage Subscription',
                sub: 'Cancel or upgrade your plan',
                onTap: _openCustomerCenter,
              ),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(
                icon: Icons.restore_outlined,
                label: 'Restore Purchases',
                sub: 'Restore previous purchases',
                onTap: _restorePurchases,
              ),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(
                icon: Icons.description_outlined,
                label: 'Subscription Terms',
                sub: 'Billing and auto-renewal terms',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionTermsPage())),
              ),
            ]),
            section('Account & Data', [
              mobileItem(
                icon: Icons.download_outlined,
                label: 'Download My Data',
                sub: 'Export your personal data',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataExportPage())),
              ),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(
                icon: Icons.delete_outline,
                label: 'Delete Account',
                sub: 'Permanently delete your account',
                labelColor: const Color(0xFFE53935),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFE53935)),
                onTap: _showDeleteAccountDialog,
              ),
            ]),
            section('Legal', [
              mobileItem(icon: Icons.lock_outline, label: 'Privacy Policy', sub: 'How we protect your data',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()))),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(icon: Icons.gavel_outlined, label: 'Terms & EULA', sub: 'Terms of Service',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServicePage()))),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(icon: Icons.health_and_safety_outlined, label: 'Health Disclaimer', sub: 'Health & safety info',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisclaimerPage()))),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(icon: Icons.copyright_outlined, label: 'Copyright', sub: 'Intellectual property',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CopyrightPage()))),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(icon: Icons.person_off_outlined, label: 'Age Requirement', sub: 'Minimum age policy',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgeRequirementPage()))),
              Divider(height: 1, indent: 52, color: widget.isDarkMode ? Colors.white12 : Colors.black12),
              mobileItem(icon: Icons.smart_toy_outlined, label: 'AI Disclosure', sub: 'How AI is used',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AITransparencyPage()))),
            ]),
            section('Support', [
              mobileItem(
                icon: Icons.logout,
                label: 'Sign Out',
                sub: 'Log out of your account',
                labelColor: const Color(0xFFE53935),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFE53935)),
                onTap: _confirmSignOut,
              ),
            ]),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© 2026 GGUIDE Apps Solutions LLC. All rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: widget.isDarkMode ? Colors.white30 : Colors.black38),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SECTION LABEL
  // ─────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: widget.isDarkMode ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CARD SHELL
  // ─────────────────────────────────────────────

  Widget _card(List<Widget> items) {
    final cardColor = widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = widget.isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              items[i],
              if (i < items.length - 1)
                Divider(height: 1, thickness: 1, color: dividerColor, indent: 68),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MENU TILE
  // ─────────────────────────────────────────────

  Widget _tile({
    required IconData icon,
    required String label,
    required String subtitle,
    Color? iconBg,
    Color? iconColor,
    Color? labelColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = widget.isDarkMode;
    final resolvedLabelColor = labelColor ?? (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final resolvedIconBg = iconBg ?? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7));
    final resolvedIconColor = iconColor ?? (isDark ? Colors.white70 : const Color(0xFF444444));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _red.withOpacity(0.08),
        highlightColor: _red.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: resolvedIconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: resolvedIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: resolvedLabelColor,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black45,
                        )),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 1. ACCOUNT
  // ─────────────────────────────────────────────

  Widget _buildAccountSection() {
    return _card([
      _tile(
        icon: Icons.download_outlined,
        label: 'Download My Data',
        subtitle: 'Export your personal data',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/data-export');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DataExportPage()));
          }
        },
      ),
      _tile(
        icon: Icons.delete_outline,
        label: 'Delete Account',
        subtitle: 'Permanently delete your account and data',
        iconBg: const Color(0xFFFFEBEE),
        iconColor: _red,
        labelColor: _red,
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFE53935)),
        onTap: _showDeleteAccountDialog,
      ),
    ]);
  }

  void _showDeleteAccountDialog() {
    final TextEditingController typeController = TextEditingController();
    bool canDelete = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 22),
                const SizedBox(width: 8),
                Text('Delete Account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    )),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to permanently delete your account?\n\nThis will delete:\n• Your profile\n• Workout and meal plans\n• Progress and history\n\nThis action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Type DELETE to confirm:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: typeController,
                  autofocus: false,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(
                      color: widget.isDarkMode ? Colors.white30 : Colors.black26,
                    ),
                    filled: true,
                    fillColor: widget.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      canDelete = val.trim() == 'DELETE';
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                    )),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canDelete ? _red : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: canDelete
                    ? () async {
                        // Show loading indicator
                        showDialog(
                          context: ctx,
                          barrierDismissible: false,
                          builder: (c) => const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          // Call backend RPC to delete account
                          await Supabase.instance.client.rpc('delete_current_user');
                          // Sign out locally
                          await Supabase.instance.client.auth.signOut();
                          
                          debugPrint('[ACCOUNT] Account deletion successful');

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop(); // pop loading
                            Navigator.of(ctx).pop(); // pop delete dialog
                            // Return to home/auth
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        } catch (error) {
                          debugPrint('[ACCOUNT] Error deleting account: $error');
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop(); // pop loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to delete account. Please try again or contact support.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    : null,
                child: const Text('Delete Account'),
              ),
            ],
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────
  // 2. SUBSCRIPTION
  // ─────────────────────────────────────────────

  Widget _buildSubscriptionSection() {
    return _card([
      _tile(
        icon: Icons.workspace_premium_outlined,
        label: 'Upgrade to Premium',
        subtitle: 'Unlock personalized plans and advanced features',
        iconBg: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFF57C00),
        trailing: const Icon(Icons.star_rounded, color: Color(0xFFF57C00), size: 22),
        onTap: () async {
          await RevenueCatService().showPaywall();
        },
      ),
      _tile(
        icon: Icons.receipt_long_outlined,
        label: 'Subscription Status',
        subtitle: 'Check your current plan',
        onTap: () => _showMessage('Checking subscription status...'),
      ),
      _tile(
        icon: Icons.manage_accounts_outlined,
        label: 'Manage Subscription',
        subtitle: kIsWeb ? 'Manage via App Store or Google Play' : 'Cancel, upgrade or view your plan',
        onTap: _openCustomerCenter,
      ),
      _tile(
        icon: Icons.restore_outlined,
        label: 'Restore Purchases',
        subtitle: 'Restore previous purchases (App Store requirement)',
        onTap: _restorePurchases,
      ),
      _tile(
        icon: Icons.description_outlined,
        label: 'Subscription Terms',
        subtitle: 'View billing and auto-renewal terms',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/subscription-terms');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubscriptionTermsPage()));
          }
        },
      ),
    ]);
  }

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
      _showMessage(hasActive ? 'Purchases restored!' : 'No previous purchases found');
    } catch (e) {
      debugPrint('[RevenueCat] Restore error: $e');
      _showMessage('Restore failed — please try again');
    }
  }

  // ─────────────────────────────────────────────
  // 3. PREFERENCES
  // ─────────────────────────────────────────────

  Widget _buildPreferencesSection() {
    return _card([
      _tile(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        subtitle: notificationsOn ? 'Notifications are on' : 'Notifications are off',
        trailing: Switch(
          value: notificationsOn,
          activeColor: Colors.white,
          activeTrackColor: _red,
          onChanged: (val) => setState(() => notificationsOn = val),
        ),
        onTap: null,
      ),
      _tile(
        icon: widget.isDarkMode ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
        label: 'Dark Mode',
        subtitle: widget.isDarkMode ? 'Dark theme is on' : 'Light theme is on',
        trailing: Switch(
          value: widget.isDarkMode,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFFE53935),
          onChanged: (_) => widget.toggleTheme(),
        ),
        onTap: widget.toggleTheme,
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  // 4A. LEGAL & PRIVACY
  // ─────────────────────────────────────────────

  Widget _buildLegalPrivacyCard() {
    return _card([
      _tile(
        icon: Icons.lock_outline,
        label: 'Privacy Policy',
        subtitle: 'How we collect and protect your data',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/privacy');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
          }
        },
      ),
      _tile(
        icon: Icons.gavel_outlined,
        label: 'Terms & EULA',
        subtitle: 'Terms of Service and End User License Agreement',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/eula');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()));
          }
        },
      ),
      _tile(
        icon: Icons.health_and_safety_outlined,
        label: 'Health Disclaimer',
        subtitle: 'Important health and safety information',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/disclaimer');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DisclaimerPage()));
          }
        },
      ),
      _tile(
        icon: Icons.copyright_outlined,
        label: 'Copyright',
        subtitle: 'Intellectual property notice',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/copyright');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CopyrightPage()));
          }
        },
      ),
      _tile(
        icon: Icons.person_off_outlined,
        label: 'Age Requirement',
        subtitle: 'Minimum age and eligibility policy',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/age-requirement');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AgeRequirementPage()));
          }
        },
      ),
      _tile(
        icon: Icons.smart_toy_outlined,
        label: 'AI Assistance Disclosure',
        subtitle: 'How AI is used in GymGuide',
        onTap: () {
          if (kIsWeb) {
            Navigator.pushNamed(context, '/ai-transparency');
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AITransparencyPage()));
          }
        },
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  // 4B. SUPPORT & INFO
  // ─────────────────────────────────────────────

  Widget _buildSupportInfoCard() {
    return _card([
      _tile(
        icon: Icons.support_agent_outlined,
        label: 'Contact Support',
        subtitle: 'support@gymguide.co',
        iconBg: widget.isDarkMode ? const Color(0xFF1E2E1E) : const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF388E3C),
        onTap: () async {
          final uri = Uri.parse('mailto:support@gymguide.co?subject=GymGuide%20Support');
          try {
            await launchUrl(uri);
          } catch (_) {
            _showMessage('Could not open email client');
          }
        },
      ),
      _tile(
        icon: Icons.info_outline,
        label: 'About GymGuide',
        subtitle: 'Version info and company details',
        onTap: () => _showAboutDialog(),
      ),
      _tile(
        icon: Icons.logout,
        label: 'Sign Out',
        subtitle: 'Log out of your account',
        iconBg: const Color(0xFFFFEBEE),
        iconColor: _red,
        labelColor: _red,
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFE53935)),
        onTap: _confirmSignOut,
      ),
    ]);
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('About GymGuide',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _aboutRow('App', 'GymGuide'),
            _aboutRow('Company', 'GGUIDE Apps Solutions LLC'),
            _aboutRow('Version', '1.0.0'),
            _aboutRow('Website', 'gymguide.co'),
            _aboutRow('Support', 'support@gymguide.co'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white54 : Colors.black45,
                )),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                )),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FOOTER
  // ─────────────────────────────────────────────

  Widget _buildFooter() {
    final color = widget.isDarkMode ? Colors.white30 : Colors.black38;
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Text(
          '© 2026 GGUIDE Apps Solutions LLC. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: color),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            _footerLink('Privacy', '/privacy', null),
            Text('|', style: TextStyle(color: color, fontSize: 12)),
            _footerLink('Terms', '/eula', null),
            Text('|', style: TextStyle(color: color, fontSize: 12)),
            _footerLink('Subscription', '/subscription-terms', null),
            Text('|', style: TextStyle(color: color, fontSize: 12)),
            _footerLink('Disclaimer', '/disclaimer', null),
            Text('|', style: TextStyle(color: color, fontSize: 12)),
            _footerLink('Contact', null, 'mailto:support@gymguide.co'),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _footerLink(String label, String? route, String? mailtoUri) {
    return GestureDetector(
      onTap: () async {
        if (route != null) {
          if (kIsWeb) {
            Navigator.pushNamed(context, route);
          }
        } else if (mailtoUri != null) {
          try {
            await launchUrl(Uri.parse(mailtoUri));
          } catch (_) {}
        }
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: widget.isDarkMode ? Colors.white54 : Colors.black54,
          decoration: TextDecoration.underline,
          decorationColor: widget.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  void _showMessage(String message) {
    debugPrint('[SETTINGS] $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFF1A1A1A),
      ),
    );
  }

  void _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            )),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(
                    color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showMessage('Signing out...');
      // TODO: call your sign-out backend
    }
  }
}
