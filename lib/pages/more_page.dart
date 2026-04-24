import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
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
import '../widgets/auth/auth_modal.dart';

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
        final isDesktop = constraints.maxWidth > 800 && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android;
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
                  const double spacing = 16.0;

                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(spacing),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 800,
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
                    ),
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
                onTap: () async {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) {
                    AuthModal.show(context);
                    return;
                  }

                  // Go straight to RevenueCatUI — it handles store errors natively.
                  await RevenueCatService().showPaywall();
                },
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
    // Web gets a dedicated premium download card
    if (kIsWeb) return _buildWebSubscriptionCard();

    // Mobile: original tile list
    return _card([
      _tile(
        icon: Icons.workspace_premium_outlined,
        label: 'Upgrade to Premium',
        subtitle: 'Unlock personalized plans and advanced features',
        iconBg: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFF57C00),
        trailing: const Icon(Icons.star_rounded, color: Color(0xFFF57C00), size: 22),
        onTap: () async {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) {
            AuthModal.show(context);
            return;
          }

          // Go straight to RevenueCatUI — it handles store errors natively.
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
        subtitle: 'Cancel, upgrade or view your plan',
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
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SubscriptionTermsPage())),
      ),
    ]);
  }

  // ── Web-specific premium subscription card ──────────────────────────────
  Widget _buildWebSubscriptionCard() {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gradient header ──────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF0000), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '⭐  PREMIUM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Unlock Your Full\nFitness Potential',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Get personalized workout & meal plans,\nunlimited AI coaching and more.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ],
            ),
          ),

          // ── Features list ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT YOU GET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _featureChip('🏋️  Custom Workout Plans', isDark),
                    _featureChip('🥗  Personalised Meal Plans', isDark),
                    _featureChip('📈  Progress Tracking', isDark),
                    _featureChip('🤖  AI Coaching', isDark),
                    _featureChip('🔓  1800+ Exercises', isDark),
                    _featureChip('⚡  New Workouts Weekly', isDark),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 32, indent: 24, endIndent: 24),

          // ── Mobile-only notice ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone_iphone_rounded,
                    size: 18, color: Color(0xFFFF0000)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Subscriptions are available via the mobile app (Apple Pay & Google Play). '
                    'Download GymGuide on your phone to unlock Premium.',
                    style: TextStyle(
                        fontSize: 13, color: textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          // ── Download buttons ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: _storeButton(
                    label: 'App Store',
                    sub: 'Download on the',
                    icon: Icons.apple,
                    url:
                        'https://apps.apple.com/us/app/gym-guide-app/id6760553535',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _storeButton(
                    label: 'Google Play',
                    sub: 'Get it on',
                    icon: Icons.android,
                    url:
                        'https://play.google.com/store/apps/details?id=com.gymguide.app',
                    isDark: isDark,
                    isPlay: true,
                  ),
                ),
              ],
            ),
          ),

          // ── Subscription Terms link ──────────────────────
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/subscription-terms'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 16, color: textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'View Subscription Terms',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: textSecondary,
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

  Widget _featureChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _storeButton({
    required String label,
    required String sub,
    required IconData icon,
    required String url,
    required bool isDark,
    bool isPlay = false,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isPlay
                  ? const Color(0xFF34A853)
                  : (isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      // ── Share App ──────────────────────────────
      _tile(
        icon: Icons.share_outlined,
        label: 'Share GymGuide',
        subtitle: kIsWeb
            ? 'Share the app with friends & family'
            : 'Invite friends & family to GymGuide',
        iconBg: widget.isDarkMode ? const Color(0xFF1A2A3A) : const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1976D2),
        trailing: kIsWeb
            ? const Icon(Icons.ios_share_outlined, size: 18, color: Color(0xFF1976D2))
            : null,
        onTap: _shareApp,
      ),
      // ── Rate App ───────────────────────────────
      _tile(
        icon: Icons.star_outline_rounded,
        label: 'Rate GymGuide',
        subtitle: kIsWeb
            ? 'Rate us on the App Store or Google Play'
            : 'Love the app? Leave us a review ⭐',
        iconBg: widget.isDarkMode ? const Color(0xFF2A2010) : const Color(0xFFFFF8E1),
        iconColor: const Color(0xFFFFA000),
        trailing: const Icon(Icons.open_in_new, size: 18, color: Color(0xFFFFA000)),
        onTap: _rateApp,
      ),
      // ── Contact Support ────────────────────────
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

  // ─── Share App ──────────────────────────────────
  Future<void> _shareApp() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.gymguide.app';
    const appStoreUrl = 'https://apps.apple.com/us/app/gym-guide-app/id6760553535';

    if (kIsWeb) {
      _showWebShareDialog(appStoreUrl: appStoreUrl, playStoreUrl: playStoreUrl);
      return;
    }

    const message =
        'Check out GymGuide — your AI-powered personal trainer app!\n'
        'Download it here:\nAndroid: $playStoreUrl\niOS: $appStoreUrl';
    try {
      await SharePlus.instance.share(ShareParams(text: message, subject: 'Try GymGuide!'));
    } catch (e) {
      debugPrint('[SHARE] Error: $e');
      _showMessage('Could not share — try again');
    }
  }

  void _showWebShareDialog({required String appStoreUrl, required String playStoreUrl}) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;
    final fieldBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2A3A) : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share_outlined, color: Color(0xFF1976D2), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Share GymGuide', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
                  Text('Copy a link and share it anywhere', style: TextStyle(fontSize: 12, color: textSecondary)),
                ])),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 24),
              Text('iOS — App Store', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              _webShareLinkRow(appStoreUrl, isDark, fieldBg, textSecondary),
              const SizedBox(height: 16),
              Text('Android — Google Play', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              _webShareLinkRow(playStoreUrl, isDark, fieldBg, textSecondary),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _storeButton(label: 'App Store', sub: 'Download on the', icon: Icons.apple, url: appStoreUrl, isDark: isDark)),
                const SizedBox(width: 10),
                Expanded(child: _storeButton(label: 'Google Play', sub: 'Get it on', icon: Icons.android, url: playStoreUrl, isDark: isDark, isPlay: true)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webShareLinkRow(String url, bool isDark, Color fieldBg, Color textSecondary) {
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(url, style: TextStyle(fontSize: 12, color: textSecondary), overflow: TextOverflow.ellipsis),
        )),
        InkWell(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Link copied!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1976D2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ));
            }
          },
          borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.12),
              borderRadius: const BorderRadius.only(topRight: Radius.circular(9), bottomRight: Radius.circular(9)),
            ),
            child: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF1976D2)),
          ),
        ),
      ]),
    );
  }

  // ─── Rate App ───────────────────────────────────
  Future<void> _rateApp() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.gymguide.app&reviewId=0';
    const appStoreUrl =
        'https://apps.apple.com/us/app/gym-guide-app/id6760553535?action=write-review';

    if (kIsWeb) {
      _showWebRateDialog(appStoreUrl: appStoreUrl, playStoreUrl: playStoreUrl);
      return;
    }

    final url = defaultTargetPlatform == TargetPlatform.android ? playStoreUrl : appStoreUrl;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('Could not open store — please try manually');
      }
    } catch (e) {
      debugPrint('[RATE] Error: $e');
      _showMessage('Could not open the store');
    }
  }

  void _showWebRateDialog({required String appStoreUrl, required String playStoreUrl}) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2010) : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rate GymGuide', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
                  Text('Your review means a lot to us', style: TextStyle(fontSize: 12, color: textSecondary)),
                ])),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 32)),
              ),
              const SizedBox(height: 12),
              Text('Choose your platform to leave a review:', style: TextStyle(fontSize: 13, color: textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _rateStoreButton(
                  label: 'App Store', sub: 'Rate on', icon: Icons.apple,
                  url: appStoreUrl, isDark: isDark, color: isDark ? Colors.white : Colors.black,
                )),
                const SizedBox(width: 12),
                Expanded(child: _rateStoreButton(
                  label: 'Google Play', sub: 'Rate on', icon: Icons.android,
                  url: playStoreUrl, isDark: isDark, color: const Color(0xFF34A853),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rateStoreButton({
    required String label, required String sub, required IconData icon,
    required String url, required bool isDark, required Color color,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(isDark ? 0.18 : 0.10), color.withOpacity(isDark ? 0.08 : 0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
        ]),
      ),
    );
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

