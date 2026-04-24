import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import 'package:seo/seo.dart';

class PrivacyPolicyPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const PrivacyPolicyPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Seo.head(
      tags: const [
        MetaTag(name: 'title', content: 'Privacy Policy | GymGuide'),
        MetaTag(name: 'description', content: 'Read the GymGuide Privacy Policy to understand how we protect and manage your data while using our fitness app.'),
      ],
      child: LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'Privacy Policy',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMeta('Last Updated: January 2026', isDarkMode),
          _buildMeta('Company: GGUIDE Apps Solutions LLC', isDarkMode),
          _buildMeta('Website: https://gymguide.co', isDarkMode),
          _buildMeta('Email: support@gymguide.co', isDarkMode),
          const SizedBox(height: 20),
          _buildText(
            'This Privacy Policy explains how GymGuide ("we", "our", "us") collects, uses, stores, and protects your personal information.',
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
            'When using GymGuide, you may provide:\n\n'
            '• Account details (email address, login credentials)\n'
            '• Fitness goals (weight loss, muscle gain, etc.)\n'
            '• Health-related inputs (quiz responses, preferences)\n'
            '• Meal preferences and dietary restrictions\n'
            '• Progress data (weight, measurements, workout history)',
            isDarkMode,
          ),
          _buildSubSection(
            'B. Automatically Collected Information',
            'We automatically collect certain data, including:\n\n'
            '• Device information (model, OS version, device identifiers)\n'
            '• IP address and general location\n'
            '• App usage behavior and analytics\n'
            '• Performance and crash data\n'
            '• Subscription status via Apple App Store or Google Play',
            isDarkMode,
          ),
          _buildSection(
            '2. How We Use Your Information',
            'We use collected data to:\n\n'
            '• Provide personalized workout and meal plans\n'
            '• Improve app functionality and user experience\n'
            '• Monitor performance and fix technical issues\n'
            '• Manage subscriptions and billing\n'
            '• Provide customer support\n'
            '• Ensure security and prevent misuse',
            isDarkMode,
          ),
          _buildSection(
            '3. AI Data Processing',
            'GymGuide uses AI systems to generate personalized recommendations.\n\n'
            '• AI processes your inputs automatically\n'
            '• Outputs are generated without human intervention\n'
            '• We do NOT use your personal data to train AI models\n'
            '• AI responses may not always be accurate',
            isDarkMode,
          ),
          _buildSection(
            '4. Legal Basis for Processing',
            'We process your data based on:\n\n'
            '• Your consent\n'
            '• Performance of our services\n'
            '• Legal obligations\n'
            '• Legitimate business interests (app improvement, security)',
            isDarkMode,
          ),
          _buildSection(
            '5. Data Sharing',
            'We do NOT sell your personal data.\n\n'
            'We may share data only when necessary:\n\n'
            '• With service providers (hosting, analytics, payments)\n'
            '• With Apple or Google for subscription processing\n'
            '• When required by law or legal requests',
            isDarkMode,
          ),
          _buildSection(
            '6. Third-Party Services',
            'GymGuide uses trusted third-party providers:\n\n'
            '• Supabase – database and authentication\n'
            '• Cloudflare R2 – media storage\n'
            '• RevenueCat / Apple / Google – payments and subscriptions\n'
            '• AI providers – plan generation\n\n'
            'Each third party operates under its own privacy policies.',
            isDarkMode,
          ),
          _buildSection(
            '7. Data Retention',
            'We retain your data only as long as necessary to:\n\n'
            '• Provide services\n'
            '• Comply with legal obligations\n'
            '• Resolve disputes\n\n'
            'You may request deletion at any time.',
            isDarkMode,
          ),
          _buildSection(
            '8. Your Rights',
            'Depending on your region, you may have the right to:\n\n'
            '• Access your data\n'
            '• Correct inaccurate data\n'
            '• Delete your data\n'
            '• Restrict or object to processing\n'
            '• Withdraw consent\n\n'
            'To exercise your rights, contact: support@gymguide.co',
            isDarkMode,
          ),
          _buildSection(
            '9. Account Deletion',
            'You can request deletion of your account and data:\n\n'
            '• Through in-app settings (if available)\n'
            '• By contacting support\n\n'
            'We will process deletion within a reasonable timeframe.',
            isDarkMode,
          ),
          _buildSection(
            '10. Security',
            'We use industry-standard measures to protect your data, including encryption and secure storage.\n\n'
            'However, no system is completely secure.',
            isDarkMode,
          ),
          _buildSection(
            '11. Children\'s Privacy',
            'GymGuide does not knowingly collect data from children under 13.\n\n'
            'If such data is identified, it will be deleted promptly.',
            isDarkMode,
          ),
          _buildSection(
            '12. International Data Transfers',
            'Your data may be processed in different countries. We ensure appropriate safeguards are in place.',
            isDarkMode,
          ),
          _buildSection(
            '13. Changes to This Policy',
            'We may update this Privacy Policy periodically.\n\n'
            'Continued use of the app indicates acceptance of the updated policy.',
            isDarkMode,
          ),
          const SizedBox(height: 40),
        ],
      ),
      ),
    );
  }

  Widget _buildMeta(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
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
        height: 1.6,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
