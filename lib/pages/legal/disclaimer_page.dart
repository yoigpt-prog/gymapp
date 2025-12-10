import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LegalPageLayout(
      title: 'Health & Safety Disclaimer',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildText(
            'GymGuide provides general fitness and nutrition guidance.\n'
            'GymGuide is not a medical service and does not provide medical advice.',
            isDarkMode,
            bold: true,
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Always consult a licensed physician before:',
            '• Starting a new workout\n'
            '• Changing your diet\n'
            '• Following nutrition plans\n'
            '• Training with pre-existing conditions',
            isDarkMode,
          ),
          _buildSection(
            'Stop immediately if you feel:',
            '• Pain\n'
            '• Shortness of breath\n'
            '• Dizziness\n'
            '• Chest tightness',
            isDarkMode,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'GymGuide and GGUIDE Apps Solutions LLC are not responsible for injuries or damages resulting from your use of the app.\n\nUse at your own risk.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFFB71C1C),
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

  Widget _buildText(String text, bool isDarkMode, {bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
