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
          _buildText(
            'GymGuide integrates artificial intelligence ("AI") technologies to enhance user experience and provide personalized fitness and nutrition recommendations.\n\n'
            'This page explains how AI is used, its limitations, and your responsibilities when using AI-powered features.',
            isDarkMode,
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. How AI is Used in GymGuide',
            'Our AI systems analyze user-provided information to generate personalized recommendations, including but not limited to:\n\n'
            '• Workout plans tailored to your fitness goals, experience level, and preferences\n'
            '• Meal plans based on dietary preferences, calorie targets, and restrictions\n'
            '• Estimated calorie needs and macronutrient suggestions\n'
            '• Exercise difficulty adjustments and progress suggestions\n\n'
            'The AI operates using automated processes and does not involve human review of individual results.',
            isDarkMode,
          ),
          _buildSection(
            '2. Nature of AI-Generated Content',
            'All AI-generated content provided by GymGuide is:\n\n'
            '• Automatically generated based on patterns and algorithms\n'
            '• General in nature and not tailored to specific medical conditions\n'
            '• Subject to potential inaccuracies, errors, or omissions\n\n'
            'AI outputs should be considered informational guidance only.',
            isDarkMode,
          ),
          _buildSection(
            '3. Limitations of AI',
            'AI systems have important limitations, including:\n\n'
            '• Lack of awareness of your full medical history or physical condition\n'
            '• Inability to detect injuries, illnesses, or risk factors\n'
            '• Possible incorrect or outdated recommendations\n'
            '• Dependence on the accuracy of user-provided information\n\n'
            'GymGuide does NOT guarantee that AI-generated plans will be safe, effective, or suitable for your specific needs.',
            isDarkMode,
          ),
          _buildSection(
            '4. No Medical Advice',
            'GymGuide is NOT a medical application.\n\n'
            'The AI features do NOT provide:\n'
            '• Medical advice\n'
            '• Medical diagnosis\n'
            '• Treatment recommendations\n\n'
            'Nothing in the app should be interpreted as medical guidance.\n\n'
            'You should always consult a qualified healthcare professional before making decisions related to your health.',
            isDarkMode,
          ),
          _buildSection(
            '5. User Responsibility',
            'By using GymGuide, you acknowledge and agree that:\n\n'
            '• You are responsible for evaluating all recommendations before following them\n'
            '• You will use your own judgment when applying any workout or meal plan\n'
            '• You will stop immediately if you experience pain or discomfort\n'
            '• You will seek professional advice when necessary',
            isDarkMode,
          ),
          _buildSection(
            '6. Data Processing & Privacy',
            'To provide AI features, GymGuide processes:\n\n'
            '• Quiz responses\n'
            '• Fitness goals and preferences\n'
            '• Activity and progress data\n\n'
            'We are committed to responsible data use:\n\n'
            '• Your personal data is NOT sold\n'
            '• Your data is NOT used to train AI models\n'
            '• Data is processed only to deliver app functionality',
            isDarkMode,
          ),
          _buildSection(
            '7. Risk Acknowledgment',
            'By using AI-powered features, you understand and accept:\n\n'
            '• AI-generated content may contain inaccuracies\n'
            '• Results are not guaranteed\n'
            '• You use all recommendations at your own risk',
            isDarkMode,
          ),
          _buildSection(
            '8. Continuous Improvement',
            'We continuously improve our AI systems; however, improvements do not eliminate all risks or limitations.',
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
              'By continuing to use GymGuide, you acknowledge that you understand and accept this AI disclosure.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: isDarkMode ? Colors.white : const Color(0xFFC62828),
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
