import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class AITransparencyPage extends StatelessWidget {
  final VoidCallback? toggleTheme;
  const AITransparencyPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LegalPageLayout(
      onToggleTheme: toggleTheme,
      title: 'AI Assistance Disclosure',
      isDarkMode: isDarkMode,
      showBanner: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'GymGuide uses artificial intelligence to:',
            '• Analyze your quiz answers and preferences\n'
            '• Generate personalized workout plans\n'
            '• Generate personalized meal plans\n'
            '• Suggest calorie targets and exercise difficulty',
            isDarkMode,
          ),
          _buildSection(
            'AI limitations:',
            '• May produce inaccurate recommendations\n'
            '• Cannot evaluate medical conditions\n'
            '• May misinterpret user input',
            isDarkMode,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF4A1A1A) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'AI does not replace professional medical advice.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFFC62828),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildText(
            'You may request deletion of all AI-processed data at any time.',
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
