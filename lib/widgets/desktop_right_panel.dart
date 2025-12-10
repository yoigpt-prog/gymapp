import 'package:flutter/material.dart';

class DesktopRightPanel extends StatelessWidget {
  final bool isDarkMode;

  const DesktopRightPanel({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Image.asset(
          'assets/banner/adbanner.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
