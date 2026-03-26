import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class TermsOfServicePage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const TermsOfServicePage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'Terms & EULA',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms of Service & End User License Agreement (EULA)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last Updated: January 2026',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _buildText(
            'By downloading or using GymGuide, you agree to these Terms.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. License Grant',
            'GymGuide grants you a limited, non-exclusive, non-transferable license to use the app for personal, non-commercial purposes.',
            isDarkMode,
          ),
          _buildSection(
            '2. Restrictions',
            'You may NOT:\n\n'
            '• Copy, modify, or distribute app content\n'
            '• Reverse engineer or decompile the app\n'
            '• Resell workout or meal plans\n'
            '• Attempt to bypass subscription systems\n'
            '• Use the app for illegal or harmful purposes',
            isDarkMode,
          ),
          _buildSection(
            '3. Health Disclaimer',
            'GymGuide provides general fitness information only.\n\n'
            'We do NOT provide medical advice.\n\n'
            'You agree that:\n\n'
            '• You are responsible for your own health decisions\n'
            '• You are physically able to participate in exercise\n'
            '• You will consult a doctor when necessary',
            isDarkMode,
          ),
          _buildSection(
            '4. AI-Generated Content',
            'Some features use AI to generate plans.\n\n'
            'We do NOT guarantee:\n\n'
            '• Accuracy of recommendations\n'
            '• Specific results\n'
            '• Suitability for your condition',
            isDarkMode,
          ),
          _buildSection(
            '5. Subscriptions',
            '• Subscriptions are processed via Apple or Google\n'
            '• They automatically renew unless canceled\n'
            '• Pricing is shown before purchase',
            isDarkMode,
          ),
          _buildSection(
            '6. Free Trials',
            'Free trials automatically convert to paid subscriptions unless canceled before the end of the trial period.',
            isDarkMode,
          ),
          _buildSection(
            '7. Refunds',
            'All refunds are handled by Apple App Store or Google Play.\n\n'
            'GymGuide cannot issue refunds directly.',
            isDarkMode,
          ),
          _buildSection(
            '8. Account Termination',
            'We may suspend or terminate accounts that violate these Terms.',
            isDarkMode,
          ),
          _buildSection(
            '9. Limitation of Liability',
            'To the maximum extent permitted by law:\n\n'
            'GymGuide is NOT liable for:\n\n'
            '• Injuries or health issues\n'
            '• Incorrect recommendations\n'
            '• Loss of data or results',
            isDarkMode,
          ),
          _buildSection(
            '10. Indemnification',
            'You agree to indemnify and hold GymGuide harmless from any claims arising from your use of the app.',
            isDarkMode,
          ),
          _buildSection(
            '11. Changes',
            'We may update these Terms at any time.\n\n'
            'Continued use means acceptance.',
            isDarkMode,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _buildText(content, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildText(String text, bool isDarkMode) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
