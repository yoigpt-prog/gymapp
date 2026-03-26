import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class AgeRequirementPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const AgeRequirementPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'Age Requirement & Eligibility',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildText(
            'GymGuide is intended for use by individuals who meet the minimum age requirements outlined below.\n\n'
            'By accessing or using GymGuide, you confirm that you meet these requirements.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. Minimum Age',
            'You must be at least 13 years old to use GymGuide.\n\n'
            'If you are under 13, you are NOT permitted to use the app or provide any personal information.',
            isDarkMode,
          ),
          _buildSection(
            '2. Users Under 18',
            'If you are between 13 and 17 years old:\n\n'
            '• You must have permission from a parent or legal guardian\n'
            '• You should use the app under adult supervision\n'
            '• You should not make independent health or fitness decisions without guidance\n\n'
            'Parents or guardians are responsible for supervising the use of the app by minors.',
            isDarkMode,
          ),
          _buildSection(
            '3. Children\'s Privacy Protection',
            'GymGuide is not directed toward children under 13, and we do not knowingly collect personal data from them.\n\n'
            'If we become aware that a child under 13 has provided personal data:\n\n'
            '• We will delete the data immediately\n'
            '• We will disable the associated account\n\n'
            'Parents or guardians who believe their child has provided data may contact us at:\nsupport@gymguide.co',
            isDarkMode,
          ),
          _buildSection(
            '4. Health & Safety for Minors',
            'Fitness and nutrition recommendations may not be appropriate for all age groups.\n\n'
            'Users under 18 should:\n\n'
            '• Consult a parent, guardian, or qualified professional before following plans\n'
            '• Avoid intense or restrictive programs without supervision\n'
            '• Use caution when performing exercises',
            isDarkMode,
          ),
          _buildSection(
            '5. Account Responsibility',
            'By using GymGuide, you confirm that:\n\n'
            '• You meet the minimum age requirement\n'
            '• Any information you provide is accurate\n'
            '• You are legally permitted to use the app in your region',
            isDarkMode,
          ),
          _buildSection(
            '6. Misrepresentation of Age',
            'If we discover that a user has provided false age information:\n\n'
            '• We may suspend or terminate the account\n'
            '• We may delete associated data',
            isDarkMode,
          ),
          _buildSection(
            '7. Regional Compliance',
            'GymGuide complies with applicable child protection and privacy laws, including regulations related to minors and data collection.',
            isDarkMode,
          ),
          _buildSection(
            '8. Changes to This Policy',
            'We may update this Age Requirement page as needed.\n\n'
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

  Widget _buildText(String text, bool isDarkMode, {bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
