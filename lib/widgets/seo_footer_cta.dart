import 'package:flutter/material.dart';
import 'package:seo/seo.dart';

class SeoFooterCTA extends StatelessWidget {
  final bool isDarkMode;

  const SeoFooterCTA({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Seo.text(
          text: "Get your personalized workout & meal plan",
          style: TextTagStyle.h2,
          child: const SizedBox.shrink(),
        ),
        Seo.image(
          alt: "Download GymGuide on the App Store",
          src: "assets/svg/logo/appstorev2.png",
          child: const SizedBox.shrink(),
        ),
        Seo.image(
          alt: "Get GymGuide on Google Play",
          src: "assets/svg/logo/playstore.png",
          child: const SizedBox.shrink(),
        ),
        _buildInternalLink('Home', '/'),
        _buildInternalLink('Try our BMI calculator', '/calculators/bmi'),
        _buildInternalLink(
            'Try our Calorie calculator', '/calculators/calorie'),
        _buildInternalLink('Try our Macro calculator', '/calculators/macro'),
        _buildInternalLink(
            'Try our Body Fat calculator', '/calculators/body-fat'),
        _buildInternalLink('Try our 1RM calculator', '/calculators/one-rm'),
        _buildInternalLink('Get your custom workout plan', '/download'),
        _buildInternalLink('Download Gym Guide', '/download'),
        _buildInternalLink('Privacy Policy', '/privacy'),
        _buildInternalLink('Terms of Service', '/terms'),
      ],
    );
  }

  Widget _buildInternalLink(String title, String path) {
    return Seo.link(
      href: 'https://www.gymguide.co$path',
      anchor: title,
      child: const SizedBox.shrink(),
    );
  }
}
