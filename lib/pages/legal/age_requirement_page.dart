import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class AgeRequirementPage extends StatelessWidget {
  const AgeRequirementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LegalPageLayout(
      title: 'Age Requirement',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildText(
            'You must be 13 years or older to use GymGuide.',
            isDarkMode,
            bold: true,
          ),
          const SizedBox(height: 20),
          _buildText(
            'If you are under 18, parental consent is required.',
            isDarkMode,
          ),
          const SizedBox(height: 20),
          _buildText(
            'GymGuide does not knowingly collect data from children under 13.',
            isDarkMode,
          ),
          const SizedBox(height: 40),
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
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
