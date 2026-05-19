import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/legal_page_layout.dart';

class SitemapPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const SitemapPage({super.key, this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFF0000);

    return LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'Sitemap',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Directory of GymGuide Resources",
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          _buildWebSitemapStructure(context, isDarkMode, primaryColor),
          const SizedBox(height: 80),
          Divider(color: isDarkMode ? Colors.white10 : Colors.black12),
          const SizedBox(height: 40),
          _buildFooterNote(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildWebSitemapStructure(BuildContext context, bool isDarkMode, Color primaryColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int columns = width > 1000 ? 4 : (width > 700 ? 2 : 1);
        final double columnWidth = (width - (columns - 1) * 40) / columns;
        
        return Wrap(
          spacing: 40,
          runSpacing: 60,
          children: [
            _buildSitemapColumn(
              context,
              "Main Navigation",
              [
                {'title': 'Home', 'route': '/'},
                {'title': 'Blog', 'route': '/Blog'},
                {'title': 'About Us', 'route': '/about'},
                {'title': 'Contact', 'route': '/contact'},
              ],
              isDarkMode,
              primaryColor,
              width: columnWidth,
            ),
            _buildSitemapColumn(
              context,
              "Health Tools",
              [
                {'title': 'BMI Calculator', 'route': '/calculators/bmi'},
                {'title': 'TDEE & Calorie Calculator', 'route': '/calculators/calorie'},
                {'title': 'Macro Nutrient Splitter', 'route': '/calculators/macro'},
                {'title': 'Body Fat Percentage', 'route': '/calculators/body-fat'},
                {'title': 'One Rep Max (1RM)', 'route': '/calculators/one-rm'},
                {'title': 'Ideal Weight Calculator', 'route': '/calculators/ideal-weight'},
              ],
              isDarkMode,
              primaryColor,
              width: columnWidth,
            ),
            _buildSitemapColumn(
              context,
              "Education & Support",
              [
                {'title': 'Fitness Blog', 'route': '/Blog'},
                {'title': 'Knowledge Base / FAQ', 'route': '/faq'},
                {'title': 'About Our Mission', 'route': '/about'},
                {'title': 'Contact & Support', 'route': '/contact'},
                {'title': 'AI Training Guide', 'route': '/ai-guide'},
                {'title': 'Community Guidelines', 'route': '/community'},
              ],
              isDarkMode,
              primaryColor,
              width: columnWidth,
            ),
            _buildSitemapColumn(
              context,
              "Legal & Privacy",
              [
                {'title': 'Privacy Policy', 'route': '/privacy'},
                {'title': 'Terms & Conditions', 'route': '/terms'},
                {'title': 'Medical Disclaimer', 'route': '/disclaimer'},
                {'title': 'Subscription Terms', 'route': '/subscription'},
                {'title': 'Cookie Settings', 'route': '/cookies'},
                {'title': 'AI Transparency', 'route': '/ai-transparency'},
                {'title': 'Copyright Information', 'route': '/copyright'},
              ],
              isDarkMode,
              primaryColor,
              width: columnWidth,
            ),
            _buildSitemapColumn(
              context,
              "Popular Guides",
              [
                {'title': 'PPL Routine for Beginners', 'route': '/blog/best-push-pull-legs-routine-for-beginners-full-guide'},
                {'title': 'Fat Loss Calorie Guide', 'route': '/blog/how-many-calories-should-you-eat-to-lose-fat'},
                {'title': 'Top 10 Gym Mistakes', 'route': '/blog/top-10-mistakes-beginners-make-in-the-gym'},
                {'title': 'Step Count for Weight Loss', 'route': '/blog/how-many-steps-per-day-to-lose-weight'},
                {'title': 'Muscle Growth Secrets', 'route': '/blog/the-hidden-science-of-muscle-growth'},
              ],
              isDarkMode,
              primaryColor,
              width: columnWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSitemapColumn(
    BuildContext context,
    String title,
    List<Map<String, String>> links,
    bool isDarkMode,
    Color primaryColor,
    {required double width}
  ) {
    return SizedBox(
      width: width > 0 ? width : 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: primaryColor,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ...links.map((link) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, link['route']!),
              child: Text(
                link['title']!,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDarkMode ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.75),
                  height: 1.2,
                ),
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildFooterNote(bool isDarkMode) {
    return Text(
      "© 2025 GymGuide App Solutions LLC. All rights reserved. For help with navigation or to report an issue, please contact our support team.",
      style: GoogleFonts.outfit(
        fontSize: 14,
        color: isDarkMode ? Colors.white30 : Colors.black26,
      ),
    );
  }
}
