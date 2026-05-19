import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms (Android / iOS).
/// Renders nothing — zero size, zero cost.
class AdSenseWidget extends StatelessWidget {
  final String adSlot;
  final String adFormat;
  final double minHeight;
  final EdgeInsets? margin;

  const AdSenseWidget({
    Key? key,
    required this.adSlot,
    this.adFormat = 'auto',
    this.minHeight = 100,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
