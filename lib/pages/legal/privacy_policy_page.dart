import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LegalPageLayout(
      title: 'Privacy Policy',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'Last Updated: December 2025',
            '',
            isDarkMode,
            isSubtitle: true,
          ),
          _buildSection(
            'Company: GGUIDE Apps Solutions LLC',
            'Website: https://gymguide.co\nEmail: support@gymguide.co',
            isDarkMode,
            isSubtitle: true,
          ),
          const SizedBox(height: 20),
          _buildText(
            'This Privacy Policy explains how GymGuide ("App", "we", "our", "us") collects, uses, and protects your information when you use our mobile applications, website, and related services.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. Information We Collect',
            '',
            isDarkMode,
          ),
          _buildSubSection(
            'A. Information You Provide',
            '• Account details (email, password, profile data)\n'
            '• Workout goals, health-related quiz answers\n'
            '• Exercise preferences and experience level\n'
            '• Meal preferences, allergies, dietary restrictions\n'
            '• Progress data (weight, measurements, workout history)',
            isDarkMode,
          ),
          _buildSubSection(
            'B. Automatically Collected Information',
            '• Device type, OS, IP address\n'
            '• Usage analytics\n'
            '• App performance data\n'
            '• Subscription status from Apple/Google',
            isDarkMode,
          ),
          _buildSubSection(
            'C. AI Data Processing',
            'Your quiz answers and profile details are processed using AI to generate personalized workout & meal plans.\n\n'
            '• We do not sell your data.\n'
            '• AI models do not train on your personal data.',
            isDarkMode,
          ),
          _buildSubSection(
            'D. Third-Party Services',
            'GymGuide uses:\n\n'
            '• Supabase (database & authentication)\n'
            '• Cloudflare R2 (media storage)\n'
            '• Stripe/Apple/Google (payments)\n'
            '• OpenAI / Anthropic (AI plan generation)\n\n'
            'Each third party has its own privacy policies.',
            isDarkMode,
          ),
          _buildSection(
            '2. How We Use Your Information',
            '• Generate personalized workout & meal plans\n'
            '• Provide app features and progress tracking\n'
            '• Improve app performance and quality\n'
            '• Maintain user accounts and security\n'
            '• Process payments & subscriptions\n'
            '• Customer support',
            isDarkMode,
          ),
          _buildSection(
            '3. How We Protect Your Information',
            '• Encryption at rest & in transit\n'
            '• Secure Supabase authentication\n'
            '• Role-based access controls\n'
            '• No unauthorized data sharing',
            isDarkMode,
          ),
          _buildSection(
            '4. Data Retention',
            'We store your data as long as your account is active.\n\n'
            'If you delete your account:\n'
            '• All personal data is permanently deleted within 30 days\n'
            '• Subscription data remains with Apple/Google but cannot identify you',
            isDarkMode,
          ),
          _buildSection(
            '5. Your Rights',
            'You may:\n\n'
            '• Request your data export\n'
            '• Delete your account\n'
            '• Update your personal information\n'
            '• Withdraw consent for processing\n'
            '• Request correction of inaccurate data\n\n'
            'Contact: support@gymguide.co',
            isDarkMode,
          ),
          _buildSection(
            '6. Children',
            'GymGuide is not intended for children under 13.\n'
            'We do not knowingly collect data from children.',
            isDarkMode,
          ),
          _buildSection(
            '7. Changes',
            'We may update this policy and will notify users when changes occur.',
            isDarkMode,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDarkMode, {bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSubtitle ? 14 : 18,
              fontWeight: isSubtitle ? FontWeight.w500 : FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildText(content, isDarkMode),
          ],
        ],
      ),
    );
  }

  Widget _buildSubSection(String title, String content, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white.withOpacity(0.87) : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
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
        height: 1.5,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
