import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class SubscriptionTermsPage extends StatelessWidget {
  const SubscriptionTermsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LegalPageLayout(
      title: 'Subscription Terms',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription Terms & Auto-Renewal Notice',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          _buildText(
            'GymGuide offers premium features through in-app subscriptions.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Billing',
            '• Payments are processed by Apple/Google\n'
            '• Auto-renewal occurs unless cancelled\n'
            '• Subscriptions can be managed via:\n'
            '  - App Store → Profile → Subscriptions\n'
            '  - Google Play → Payments & Subscriptions',
            isDarkMode,
          ),
          _buildSection(
            'Trials',
            'Free trials convert to paid subscriptions unless cancelled before the trial ends.',
            isDarkMode,
          ),
          _buildSection(
            'Refunds',
            'Refunds are handled directly by Apple/Google according to their policies.',
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
              fontSize: 16,
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
