import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class SubscriptionTermsPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const SubscriptionTermsPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'Subscription Terms',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription Terms & Auto-Renewal Policy',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _buildText(
            'GymGuide offers optional premium features through paid subscriptions.\n\n'
            'This page explains how subscriptions, billing, and renewals work.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. Subscription Overview',
            'GymGuide provides access to premium features, including:\n\n'
            '• Personalized workout plans\n'
            '• Personalized meal plans\n'
            '• Advanced recommendations and tracking features\n\n'
            'Access to these features requires an active subscription.',
            isDarkMode,
          ),
          _buildSection(
            '2. Pricing & Payment',
            '• Subscription prices are clearly displayed before purchase\n'
            '• Prices may vary depending on your region and currency\n'
            '• Payment is charged to your Apple App Store or Google Play account at confirmation of purchase\n\n'
            'You will always see the full price before completing a transaction.',
            isDarkMode,
          ),
          _buildSection(
            '3. Auto-Renewal',
            'Subscriptions automatically renew unless canceled.\n\n'
            '• Renewal occurs automatically at the end of each billing period\n'
            '• Your account will be charged before the renewal date\n'
            '• The renewal price will be the same unless otherwise stated\n\n'
            'By subscribing, you agree to automatic renewal.',
            isDarkMode,
          ),
          _buildSection(
            '4. Billing Cycle',
            'Depending on the plan selected, subscriptions may be:\n\n'
            '• Weekly\n'
            '• Annual\n\n'
            'The billing cycle is shown before purchase and in your store account.',
            isDarkMode,
          ),
          _buildSection(
            '5. Free Trial',
            'GymGuide may offer free trial periods.\n\n'
            '• Free trials provide temporary access to premium features\n'
            '• At the end of the trial, the subscription automatically converts to a paid plan\n'
            '• You must cancel before the trial ends to avoid being charged',
            isDarkMode,
          ),
          _buildSection(
            '6. Managing Your Subscription',
            'Subscriptions must be managed through your device\'s app store:\n\n'
            'Apple (iOS):\nSettings → Apple ID → Subscriptions\n\n'
            'Google Play (Android):\nGoogle Play → Payments & Subscriptions → Subscriptions\n\n'
            'GymGuide does NOT have the ability to cancel subscriptions on your behalf.',
            isDarkMode,
          ),
          _buildSection(
            '7. Cancellation',
            '• You can cancel your subscription at any time\n'
            '• Cancellation takes effect at the end of the current billing period\n'
            '• You will continue to have access until the subscription expires\n\n'
            'No partial refunds are provided for unused time.',
            isDarkMode,
          ),
          _buildSection(
            '8. Refund Policy',
            'All payments are processed by Apple or Google.\n\n'
            '• Refund requests must be submitted directly to Apple App Store or Google Play\n'
            '• GymGuide cannot issue refunds or modify transactions\n\n'
            'Refund decisions are subject to the policies of the respective platform.',
            isDarkMode,
          ),
          _buildSection(
            '9. Price Changes',
            'We may change subscription prices in the future.\n\n'
            '• Any price changes will be communicated through the app or store\n'
            '• Changes will apply to future billing cycles\n'
            '• Continued use after the change indicates acceptance',
            isDarkMode,
          ),
          _buildSection(
            '10. Failed Payments',
            'If a payment fails:\n\n'
            '• Your subscription may be suspended or canceled\n'
            '• Access to premium features may be revoked',
            isDarkMode,
          ),
          _buildSection(
            '11. Promotional Offers',
            'We may offer discounts or promotions:\n\n'
            '• Offers may be limited in time or availability\n'
            '• Terms will be clearly presented before activation',
            isDarkMode,
          ),
          _buildSection(
            '12. User Responsibility',
            'By subscribing, you acknowledge that:\n\n'
            '• You understand the pricing and billing terms\n'
            '• You agree to automatic renewal\n'
            '• You are responsible for managing your subscription',
            isDarkMode,
          ),
          _buildSection(
            '13. Compliance with Platform Policies',
            'All subscriptions are handled in accordance with:\n\n'
            '• Apple App Store policies\n'
            '• Google Play Developer policies',
            isDarkMode,
          ),
          _buildSection(
            '14. Changes to Subscription Terms',
            'We may update these terms at any time.\n\n'
            'Continued use of GymGuide indicates acceptance of any updates.',
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
