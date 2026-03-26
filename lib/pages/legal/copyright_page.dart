import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class CopyrightPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const CopyrightPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'Copyright & Intellectual Property Notice',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '© 2026 GGUIDE Apps Solutions LLC. All rights reserved.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildText(
            'GymGuide and all associated content, features, and functionality are protected by applicable intellectual property laws, including copyright, trademark, and database rights.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. Ownership of Content',
            'All content available within GymGuide, including but not limited to:\n\n'
            '• Workout plans and exercise programs\n'
            '• Meal plans and nutritional recommendations\n'
            '• AI-generated fitness and diet content\n'
            '• Text, descriptions, and written materials\n'
            '• Graphics, logos, icons, and design elements\n'
            '• Videos, images, and illustrations\n'
            '• User interface (UI) and user experience (UX) design\n'
            '• Software code and application structure\n\n'
            'is the exclusive property of GGUIDE Apps Solutions LLC or its licensors.',
            isDarkMode,
          ),
          _buildSection(
            '2. AI-Generated Content Ownership',
            'GymGuide uses artificial intelligence to generate certain content.\n\n'
            'All AI-generated outputs within the app are:\n\n'
            '• Owned and controlled by GGUIDE Apps Solutions LLC\n'
            '• Provided to users under a limited personal-use license\n'
            '• Not transferable or resellable\n\n'
            'Users are granted access to AI-generated content solely for personal use within the app.',
            isDarkMode,
          ),
          _buildSection(
            '3. Limited License to Users',
            'By using GymGuide, you are granted a limited, non-exclusive, non-transferable license to:\n\n'
            '• Access and use content for personal fitness purposes\n'
            '• View and follow workout and meal plans\n\n'
            'This license does NOT grant ownership of any content.',
            isDarkMode,
          ),
          _buildSection(
            '4. Prohibited Uses',
            'You may NOT, without prior written permission:\n\n'
            '• Copy, reproduce, or distribute any content\n'
            '• Sell, sublicense, or commercially exploit content\n'
            '• Share premium or subscription-only content publicly\n'
            '• Use content to create competing services or apps\n'
            '• Modify, adapt, or create derivative works\n'
            '• Scrape, extract, or automate data collection\n\n'
            'Unauthorized use may result in legal action.',
            isDarkMode,
          ),
          _buildSection(
            '5. Trademarks',
            '"GymGuide" and all related branding elements are trademarks of GGUIDE Apps Solutions LLC.\n\n'
            'You may NOT use our trademarks without prior written consent.',
            isDarkMode,
          ),
          _buildSection(
            '6. User-Generated Content',
            'If you submit or upload any content (if applicable):\n\n'
            '• You grant GymGuide a non-exclusive, worldwide, royalty-free license to use it\n'
            '• You confirm that you own or have rights to that content\n\n'
            'We reserve the right to remove content that violates laws or policies.',
            isDarkMode,
          ),
          _buildSection(
            '7. Copyright Infringement (DMCA Notice)',
            'If you believe that any content in GymGuide infringes your copyright, you may submit a request including:\n\n'
            '• Your name and contact information\n'
            '• Description of the copyrighted work\n'
            '• Description of the infringing content\n'
            '• A statement of good faith belief\n'
            '• A statement under penalty of perjury\n\n'
            'Send requests to: support@gymguide.co\n\n'
            'We will respond and take appropriate action in accordance with applicable laws.',
            isDarkMode,
          ),
          _buildSection(
            '8. Enforcement',
            'We actively protect our intellectual property rights.\n\n'
            'Violations may result in:\n\n'
            '• Account suspension or termination\n'
            '• Legal claims and damages\n'
            '• Removal of access to the app',
            isDarkMode,
          ),
          _buildSection(
            '9. Updates',
            'This Copyright Notice may be updated periodically.\n\n'
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
