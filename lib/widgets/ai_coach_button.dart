import 'package:flutter/material.dart';

/// Floating AI Coach bubble — draggable, dismissable (runtime-only state).
///
/// HIDE/DISABLE: Return const SizedBox.shrink() globally across the entire app.
class AiCoachButton extends StatelessWidget {
  final double initialBottom;
  final double minBottom;

  const AiCoachButton({
    super.key,
    this.initialBottom = 80.0,
    this.minBottom = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
