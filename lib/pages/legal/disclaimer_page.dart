import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class DisclaimerPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const DisclaimerPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'Health & Safety Disclaimer',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildText(
            'GymGuide provides general fitness and nutrition guidance for informational purposes only.',
            isDarkMode,
            bold: true,
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Not Medical Advice',
            'GymGuide is NOT a medical service.\n\n'
            'Nothing in the app should be considered:\n\n'
            '• Medical advice\n'
            '• Diagnosis\n'
            '• Treatment',
            isDarkMode,
          ),
          _buildSection(
            'Before Using the App',
            'Consult a licensed healthcare professional before:\n\n'
            '• Starting a new exercise program\n'
            '• Changing your diet\n'
            '• Following any plan if you have medical conditions',
            isDarkMode,
          ),
          _buildSection(
            'During Use',
            'Stop immediately and seek medical attention if you experience:\n\n'
            '• Pain or injury\n'
            '• Dizziness or fainting\n'
            '• Shortness of breath\n'
            '• Chest pain or discomfort',
            isDarkMode,
          ),
          _buildSection(
            'Personal Responsibility',
            'You acknowledge that:\n\n'
            '• You are responsible for your own health\n'
            '• You use the app at your own risk\n'
            '• Results are not guaranteed',
            isDarkMode,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF4A1A1A) : const Color(0xFFFFE5E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Liability Waiver\n\nGymGuide and GGUIDE Apps Solutions LLC are not responsible for:\n\n'
              '• Injuries\n'
              '• Health complications\n'
              '• Misuse of recommendations\n\n'
              'Use at your own risk.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDarkMode ? Colors.white : const Color(0xFFB71C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
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
