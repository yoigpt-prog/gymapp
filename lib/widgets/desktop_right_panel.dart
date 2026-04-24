import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DesktopRightPanel extends StatelessWidget {
  final bool isDarkMode;

  const DesktopRightPanel({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final adAsset = isDarkMode
        ? 'assets/banner/adblackmode.png'
        : 'assets/banner/adwhitemode.png';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 50),
            child: Image.asset(
              adAsset,
              key: ValueKey(adAsset),
              fit: BoxFit.fill,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
          );
        },
      ),
    );
  }
}
