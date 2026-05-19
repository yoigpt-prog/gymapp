import 'package:flutter/material.dart';
import '../config/env_config.dart';

/// Wraps the entire app with a visible yellow STAGING banner.
/// Renders nothing extra in production — zero overhead.
class StagingBanner extends StatelessWidget {
  final Widget child;
  const StagingBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (EnvConfig.isProduction) return child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
      children: [
        child,
        // Banner pinned to the very top of the screen
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFFFD600), // vivid yellow
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: Color(0xFF5C3A00)),
                    SizedBox(width: 6),
                    Text(
                      '⚠  STAGING MODE — Not production data',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5C3A00),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: Color(0xFF5C3A00)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ), // Stack
    ); // Directionality
  }
}
