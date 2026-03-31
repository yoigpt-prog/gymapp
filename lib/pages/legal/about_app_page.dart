import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AboutAppPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const AboutAppPage({super.key, this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white60 : Colors.black45;
    const red = Color(0xFFFF0000);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textColor, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'About App',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  children: [
                    // ── Hero card ──────────────────────────────────
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 40, horizontal: 24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF0D0D), Color(0xFFB30000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: red.withOpacity(0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: -40,
                                top: -20,
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  size: 140,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                              Positioned(
                                left: -30,
                                bottom: -30,
                                child: Icon(
                                  Icons.bar_chart_rounded,
                                  size: 100,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                              Column(
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(18.0),
                                      child: Image.asset(
                                        'assets/svg/logo/logoaboutpg.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Gym Guide',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      'Version 1.0.0',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Your Personal App Fitness Coach',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Feature pills ──────────────────────────────
                    Row(
                      children: [
                        _pill(Icons.bolt_rounded, 'AI Powered', red, cardBg, textColor, isDark),
                        const SizedBox(width: 12),
                        _pill(Icons.restaurant_menu_rounded, 'Meal Plans', red, cardBg, textColor, isDark),
                        const SizedBox(width: 12),
                        _pill(Icons.fitness_center_rounded, 'Workouts', red, cardBg, textColor, isDark),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Info card ──────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _infoTile(
                            icon: Icons.business_rounded,
                            label: 'Developer',
                            value: 'GGUIDE Apps Solutions LLC',
                            textColor: textColor,
                            subColor: subColor,
                            isDark: isDark,
                            isFirst: true,
                          ),
                          _divider(isDark),
                          _infoTile(
                            icon: Icons.language_rounded,
                            label: 'Website',
                            value: 'gymguide.co',
                            textColor: red,
                            subColor: subColor,
                            isDark: isDark,
                            onTap: () => launchUrl(
                                Uri.parse('https://gymguide.co'),
                                mode: LaunchMode.externalApplication),
                          ),
                          _divider(isDark),
                          _infoTile(
                            icon: Icons.mail_outline_rounded,
                            label: 'Contact',
                            value: 'support@gymguide.co',
                            textColor: red,
                            subColor: subColor,
                            isDark: isDark,
                            onTap: () => launchUrl(
                                Uri.parse(
                                    'mailto:support@gymguide.co?subject=GymGuide Support'),
                                mode: LaunchMode.externalApplication),
                          ),
                          _divider(isDark),
                          _infoTile(
                            icon: Icons.tag_rounded,
                            label: 'Build',
                            value: '2026/01/05',
                            textColor: textColor,
                            subColor: subColor,
                            isDark: isDark,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── About section ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.info_outline_rounded,
                                    color: red, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'About Gym Guide',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Gym Guide is your all-in-one fitness app designed to help you train smarter and stay consistent.\n\n'
                            'Get personalized workout plans, track your progress, and manage your nutrition — all in one place.\n\n'
                            'Whether your goal is to lose weight, build muscle, or stay fit, Gym Guide guides you every step of the way.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.7,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Footer note ────────────────────────────────
                    Text(
                      '© 2024 GGUIDE Apps Solutions LLC\nAll rights reserved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: subColor,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color accent, Color cardBg,
      Color textColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subColor,
    required bool isDark,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    const red = Color(0xFFFF0000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: red, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: subColor),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded, size: 14, color: subColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: isDark ? Colors.white10 : Colors.black12,
    );
  }
}
