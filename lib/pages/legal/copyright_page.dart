import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class CopyrightPage extends StatelessWidget {
  const CopyrightPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LegalPageLayout(
      title: 'Copyright',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '© 2025 GGUIDE Apps Solutions LLC',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          _buildText(
            'All rights reserved.\\n\\n'
            'GymGuide, including all content, workout plans, meal plans, graphics, user interface, and code, is the exclusive property of GGUIDE Apps Solutions LLC.\\n\\n'
            'Unauthorized reproduction, distribution, or commercial use is prohibited.',
            isDarkMode,
          ),
          const SizedBox(height: 40),
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
