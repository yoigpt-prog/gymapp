import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A promotional header that shows the GymGuide logo alongside
/// App Store and Play Store download buttons.
///
/// This widget is only visible on the **web** platform (`kIsWeb == true`).
/// On Android / iOS it renders [SizedBox.shrink] so it takes up no space.
class PromoHeaderWidget extends StatelessWidget {
  const PromoHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show on web — zero space on native platforms.
    if (!kIsWeb) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: const Color(0xFFFF0000),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // GymGuide logo
          SvgPicture.asset(
            'assets/svg/logo/gymguideicon.svg',
            height: 42,
          ),

          const Spacer(),

          // App Store button
          _StoreButton(
            svgAsset: 'assets/svg/logo/appleminiicon.svg',
            label: 'App Store',
            useOriginalColor: false,
          ),
          const SizedBox(width: 10),

          // Play Store button
          _StoreButton(
            svgAsset: 'assets/svg/logo/playminiicon.svg',
            label: 'Google Play',
            useOriginalColor: true,
          ),
        ],
      ),
    );
  }
}

/// Internal store-button widget used by [PromoHeaderWidget].
class _StoreButton extends StatelessWidget {
  final String svgAsset;
  final String label;
  final bool useOriginalColor;

  const _StoreButton({
    required this.svgAsset,
    required this.label,
    required this.useOriginalColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: SvgPicture.asset(
          svgAsset,
          // Keep Play Store icon in its original colours; force Apple icon white.
          colorFilter: useOriginalColor
              ? null
              : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
