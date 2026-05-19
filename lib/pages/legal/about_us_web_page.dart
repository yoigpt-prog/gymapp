import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import 'package:seo/seo.dart';

class AboutUsWebPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const AboutUsWebPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Seo.head(
      tags: const [
        MetaTag(name: 'title', content: 'About Us | GymGuide'),
        MetaTag(
            name: 'description',
            content:
                'Learn about the story behind GymGuide, our mission, and how we aim to make fitness practical and straightforward for real people.'),
      ],
      child: LegalPageLayout(
        onToggleTheme: toggleTheme,
        title: 'About GymGuide',
        isDarkMode: isDarkMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Built From a Simple Problem',
              'GymGuide started from a very simple frustration.\n\n'
                  'Most fitness apps either feel too complicated, too expensive, too generic, or filled with unrealistic promises. Many people begin their fitness journey motivated and excited, but quickly become overwhelmed by confusing workout plans, conflicting nutrition advice, and information scattered across dozens of websites and social media accounts.\n\n'
                  'At the same time, beginners often feel intimidated by gym culture, while experienced users waste time searching for organized exercise information, reliable workout structures, or practical tools that actually help them stay consistent.\n\n'
                  'GymGuide was created to solve that problem.\n\n'
                  'The idea behind GymGuide was never to create just another workout app. The goal was to build a fitness platform that feels practical, simple, modern, and genuinely useful for everyday people trying to improve their health, confidence, and lifestyle.',
              isDarkMode,
            ),
            _buildSection(
              'A Platform Designed for Real People',
              'Not everyone is training to become a professional athlete or bodybuilder.\n\n'
                  'Some people simply want to:\n\n'
                  '• lose weight\n'
                  '• gain confidence\n'
                  '• build muscle\n'
                  '• stay active\n'
                  '• improve mobility\n'
                  '• develop healthier habits\n'
                  '• feel better mentally and physically\n\n'
                  'GymGuide is built for those real-life goals.\n\n'
                  'We understand that most people are balancing fitness with work, school, family responsibilities, stress, and busy schedules. Because of that, the platform focuses on realistic progress instead of extreme expectations.\n\n'
                  'We believe consistency matters more than perfection.',
              isDarkMode,
            ),
            _buildSection(
              'What GymGuide Provides',
              'GymGuide combines fitness tools, educational content, and workout guidance into one growing platform.\n\n'
                  'The platform currently includes:\n\n'
                  '• 1800+ exercise demonstrations\n'
                  '• muscle-focused exercise browsing\n'
                  '• workout planning tools\n'
                  '• meal planning support\n'
                  '• calorie and macro calculators\n'
                  '• body composition calculators\n'
                  '• progress tracking features\n'
                  '• fitness education articles\n'
                  '• mobile-friendly fitness access\n\n'
                  'Every feature is designed to make fitness feel more organized and easier to follow.',
              isDarkMode,
            ),
            _buildSection(
              'Why Exercise Education Matters',
              'One of the biggest problems in the fitness industry is misinformation.\n\n'
                  'People are constantly exposed to:\n\n'
                  '• unrealistic transformation claims\n'
                  '• extreme diets\n'
                  '• confusing training advice\n'
                  '• misleading social media content\n'
                  '• fake shortcuts and “magic” solutions\n\n'
                  'GymGuide takes a different approach.\n\n'
                  'Instead of promoting unrealistic promises, the platform focuses on education, structure, and sustainable improvement. We believe users should understand why they are performing certain exercises, how muscles work, how nutrition impacts results, and how consistency creates long-term progress.\n\n'
                  'That is why GymGuide includes detailed exercise instructions, target muscle information, workout education, and practical fitness articles designed to help users learn while training.',
              isDarkMode,
            ),
            _buildSection(
              'Designed to Keep Improving',
              'GymGuide is continuously evolving.\n\n'
                  'The vision is to expand beyond a simple workout database and become a smarter fitness ecosystem that helps users stay motivated, informed, and consistent throughout their journey.\n\n'
                  'Future improvements may include:\n\n'
                  '• smarter personalized recommendations\n'
                  '• enhanced workout customization\n'
                  '• transformation tracking tools\n'
                  '• AI-assisted fitness guidance\n'
                  '• improved nutrition systems\n'
                  '• deeper progress analytics\n'
                  '• community-focused features\n\n'
                  'The goal is not to replace coaches or healthcare professionals, but to create tools that help users make better decisions and stay committed to healthier habits.',
              isDarkMode,
            ),
            _buildSection(
              'A Focus on Simplicity',
              'One of the core ideas behind GymGuide is simplicity.\n\n'
                  'Fitness already feels difficult enough for many people. Apps should reduce friction, not create more of it.\n\n'
                  'That is why GymGuide aims to provide:\n\n'
                  '• clean navigation\n'
                  '• organized workout information\n'
                  '• easy exercise discovery\n'
                  '• practical tools\n'
                  '• accessible design\n'
                  '• simple fitness education\n\n'
                  'The platform is intentionally built to feel straightforward and easy to use, even for beginners.',
              isDarkMode,
            ),
            _buildSection(
              'Realistic Expectations',
              'Fitness is a long-term process.\n\n'
                  'Real transformation takes time, patience, discipline, and consistency. There are no instant shortcuts, and no app can replace effort and healthy decision-making.\n\n'
                  'GymGuide exists to support users during that process by providing tools, structure, and educational resources that make the journey more manageable.\n\n'
                  'Every person progresses differently, and sustainable improvement will always matter more than temporary motivation.',
              isDarkMode,
            ),
            _buildSection(
              'Important Disclaimer',
              'GymGuide provides general fitness, nutrition, and wellness information intended for educational purposes only. Exercise recommendations, calorie estimates, meal suggestions, and AI-powered guidance may not always be perfectly accurate or suitable for every individual.\n\n'
                  'Users should always apply personal judgment and consult qualified healthcare or fitness professionals before beginning any exercise, nutrition, or wellness program.',
              isDarkMode,
            ),
            _buildSection(
              'Thank You',
              'Every workout completed, every habit improved, and every small step toward better health matters.\n\n'
                  'Thank you for being part of the GymGuide journey.',
              isDarkMode,
            ),
            _buildSection(
              'Contact',
              'Website: https://www.gymguide.co\n'
                  'Support: contact@gymguide.co',
              isDarkMode,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildText(content, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildText(String text, bool isDarkMode) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        height: 1.6,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
