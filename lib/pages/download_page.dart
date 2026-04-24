import 'package:flutter/material.dart';
import 'package:seo/seo.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/legal_page_layout.dart';

class DownloadPage extends StatelessWidget {
  final VoidCallback? toggleTheme;

  const DownloadPage({Key? key, this.toggleTheme}) : super(key: key);

  Future<void> _launchURL(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Seo.head(
      tags: const [
        MetaTag(
            name: 'title',
            content: 'Download Gym Guide – Custom Workout & Meal Plan App'),
        MetaTag(
            name: 'description',
            content:
                'Download Gym Guide and get a personalized fitness plan based on your goals. Build muscle, lose fat, and stay fit.'),
      ],
      child: LegalPageLayout(
        title: 'Download Gym Guide',
        isDarkMode: isDark,
        onToggleTheme: toggleTheme,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Seo.text(
                text: "Transform Your Body Today",
                style: TextTagStyle.h1,
                child: Text(
                  "Transform Your Body Today",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Seo.text(
                text:
                    "Download Gym Guide and get a personalized fitness plan based on your goals. Build muscle, lose fat, and stay fit with our custom workout and meal plan app.",
                style: TextTagStyle.p,
                child: Text(
                  "Download Gym Guide and get a personalized fitness plan based on your goals. Build muscle, lose fat, and stay fit with our custom workout and meal plan app.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: subTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                "Choose Your Platform",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              _buildStoreButton(
                context: context,
                assetPath: 'assets/svg/logo/appstorev2.png',
                url:
                    'https://apps.apple.com/app/gym-guide-workout-meal-plan/id6739972300',
                alt: 'Download on the App Store',
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildStoreButton(
                context: context,
                assetPath: 'assets/svg/logo/playstore.png',
                url:
                    'https://play.google.com/store/apps/details?id=com.gymguide.app',
                alt: 'Get it on Google Play',
                isDark: isDark,
              ),
              const SizedBox(height: 48),
              Seo.text(
                text:
                    "Join thousands of users achieving their dream physique with GymGuide's intelligent workout routines and customized meal plans.",
                style: TextTagStyle.p,
                child: Text(
                  "Join thousands of users achieving their dream physique with GymGuide's intelligent workout routines and customized meal plans.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: subTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreButton({
    required BuildContext context,
    required String assetPath,
    required String url,
    required String alt,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Seo.image(
              src: assetPath,
              alt: alt,
              child: Image.asset(
                assetPath,
                height: 40,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.download, size: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
