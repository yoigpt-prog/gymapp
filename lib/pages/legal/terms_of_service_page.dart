import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LegalPageLayout(
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
            'Last Updated: December 2025',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _buildText(
            'By using GymGuide, you agree to these Terms, provided by GGUIDE Apps Solutions LLC.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. License',
            'You are granted a personal, non-transferable license to use the App for personal fitness purposes.\n\n'
            'You may not:\n'
            '• Reverse-engineer\n'
            '• Copy content\n'
            '• Resell workout plans or diet content\n'
            '• Circumvent subscription paywalls',
            isDarkMode,
          ),
          _buildSection(
            '2. Health & Safety',
            'GymGuide provides general fitness information.\n'
            'The App does NOT replace professional medical advice.\n\n'
            'You agree:\n'
            '• You are physically able to exercise\n'
            '• You will consult a doctor before starting any fitness program\n'
            '• You are responsible for your own health and safety\n'
            '• You will stop if you feel pain, dizziness, or discomfort',
            isDarkMode,
          ),
          _buildSection(
            '3. AI-Generated Content',
            'Plans, suggestions, calorie counts, and workout intensities may be AI-generated and can contain mistakes.\n\n'
            'GymGuide does not guarantee:\n'
            '• Accuracy\n'
            '• Specific results\n'
            '• Perfect personalization\n\n'
            'Use at your own discretion.',
            isDarkMode,
          ),
          _buildSection(
            '4. User Responsibilities',
            'You agree not to:\n'
            '• Misuse the app\n'
            '• Upload harmful content\n'
            '• Use the app for medical diagnosis\n'
            '• Share paid content publicly',
            isDarkMode,
          ),
          _buildSection(
            '5. Subscriptions & Billing',
            '• Payments are handled by Apple App Store and Google Play Store\n'
            '• Subscriptions automatically renew unless cancelled\n'
            '• Refunds are only issued by Apple/Google\n'
            '• Free trials automatically convert to paid subscriptions unless cancelled in time',
            isDarkMode,
          ),
          _buildSection(
            '6. Termination',
            'You may delete your account at any time.\n'
            'We may suspend accounts violating our terms.',
            isDarkMode,
          ),
          _buildSection(
            '7. Liability Limitation',
            'GymGuide is not liable for:\n'
            '• Injuries resulting from exercises\n'
            '• Incorrect AI-generated suggestions\n'
            '• Damages from misuse\n\n'
            'Your use of GymGuide is at your own risk.',
            isDarkMode,
          ),
          _buildSection(
            '8. Contact',
            'support@gymguide.co',
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
        height: 1.5,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
