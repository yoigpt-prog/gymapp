import 'package:flutter/material.dart';

void main() {
  runApp(const MacroCardDemo());
}

class MacroCardDemo extends StatelessWidget {
  const MacroCardDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  Widget _buildMacroItem(String value, String label, bool isDarkMode) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Nutrition Summary Card'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDarkMode ? Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
              left: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
            ) : null,
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Macros row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroItem('1895', 'Calories', isDarkMode),
                  _buildMacroItem('120g', 'Protein', isDarkMode),
                  _buildMacroItem('190g', 'Carbs', isDarkMode),
                  _buildMacroItem('70g', 'Fat', isDarkMode),
                ],
              ),
              const SizedBox(height: 24),
              // Progress section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '1/5 meals',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.2, // 1/5 = 20%
                  backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
