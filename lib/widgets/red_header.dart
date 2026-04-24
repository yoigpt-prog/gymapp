import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable red header widget used across all pages for consistency
class RedHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? rightWidget;
  final double? height;
  final bool showBack;
  final VoidCallback? onToggleTheme;
  final bool? isDarkMode;
  final ValueChanged<String>? onSearch;
  final TextEditingController? searchController;

  const RedHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.rightWidget,
    this.height,
    this.showBack = false,
    this.onToggleTheme,
    this.isDarkMode,
    this.onSearch,
    this.searchController,
  }) : super(key: key);

  @override
  State<RedHeader> createState() => _RedHeaderState();
}

class _RedHeaderState extends State<RedHeader> {
  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          isWeb ? 12 : 16,
          isWeb ? 8 : 12,
          isWeb ? 12 : 16,
          isWeb ? 8 : 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFF0000),
        ),
        child: isWeb ? _buildWebHeader(context) : _buildMobileHeader(context),
      ),
    );
  }

  // Web layout with logo, search, and settings
  Widget _buildWebHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
          child: SvgPicture.asset(
            'assets/svg/logo/gymguideicon.svg',
            height: 35,
          ),
        ),
        const SizedBox(width: 20),

        // Spacer
        const Spacer(),

        // App Store Icons
        GestureDetector(
          onTap: () => _launchStore(
            'https://apps.apple.com/us/app/gym-guide-app/id6760553535',
          ),
          child: _buildAppleStoreIcon(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _launchStore(
            'https://play.google.com/store/apps/details?id=com.gymguide.app',
          ),
          child: _buildPlayStoreIcon(),
        ),
        const SizedBox(width: 20),

        // Search bar
        Container(
          width: 280,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: widget.searchController,
            onChanged: widget.onSearch,
            decoration: InputDecoration(
              hintText: 'Explore 1800+ exercises (free & premium)',
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[600],
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Dark mode toggle
        InkWell(
          onTap: widget.onToggleTheme,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              widget.isDarkMode == true ? Icons.dark_mode : Icons.wb_sunny_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // Mobile layout (original design)
  Widget _buildMobileHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back button (if needed)
        if (widget.showBack)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),

        // Logo instead of title
        Flexible(
          flex: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: SvgPicture.asset(
                'assets/svg/logo/gymguideicon.svg',
                height: 40,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // App Store Icons & Right widget (responsive)
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _launchStore(
                    'https://apps.apple.com/us/app/gym-guide-app/id6760553535',
                  ),
                  child: _buildAppleStoreIcon(),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _launchStore(
                    'https://play.google.com/store/apps/details?id=com.gymguide.app',
                  ),
                  child: _buildPlayStoreIcon(),
                ),
                const SizedBox(width: 2),
                if (widget.rightWidget != null) widget.rightWidget!,
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens a store URL in an external browser
  Future<void> _launchStore(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[RedHeader] Could not launch store: $e');
    }
  }

  /// Apple Store icon
  Widget _buildAppleStoreIcon() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.2), // Static glow
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/svg/logo/appleminiicon.png',
            color: Colors.white,
            height: 20,
          ),
          const SizedBox(width: 6),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download on the',
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  color: Colors.white,
                  fontSize: 8,
                  height: 1.0,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
              Text(
                'App Store',
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Play Store icon
  Widget _buildPlayStoreIcon() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.2), // Static glow
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/svg/logo/playminiicon.png',
            height: 20,
          ),
          const SizedBox(width: 6),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GET IT ON',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
                  fontSize: 8,
                  height: 1.0,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
              Text(
                'Google Play',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
