import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../pages/main_scaffold.dart';
import '../services/analytics_service.dart';

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
  /// Called when the logo is tapped. Use this to reset page-level state
  /// (e.g. clear selected muscle on HomePage) before navigating to home tab.
  final VoidCallback? onLogoTap;

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
    this.onLogoTap,
  }) : super(key: key);

  @override
  State<RedHeader> createState() => _RedHeaderState();
}

class _RedHeaderState extends State<RedHeader> {
  // ── QR popup state ──────────────────────────────────────────────────────────
  final LayerLink _qrLayerLink = LayerLink();
  OverlayEntry? _qrOverlay;
  bool _isQrHovered = false;

  // ── Search bar state ────────────────────────────────────────────────────────
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        if (_searchFocusNode.hasFocus) {
          _isSearchExpanded = true;
        } else {
          // Collapse if empty
          if (widget.searchController?.text.isEmpty ?? true) {
            _isSearchExpanded = false;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _hideQrOverlay();
    super.dispose();
  }

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final showStores = availableWidth > 1050;
        final reducedSpacing = availableWidth < 1150;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            GestureDetector(
              onTap: () {
                widget.onLogoTap?.call();
                final scaffold = context.findAncestorStateOfType<MainScaffoldState>()
                    ?? MainScaffold.globalKey.currentState;
                if (scaffold != null) {
                  scaffold.changeTab(0);
                  Navigator.of(context).popUntil((route) => route.settings.name == '/' || route.isFirst);
                } else {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              child: SvgPicture.asset(
                'assets/svg/logo/gymguideicon.svg',
                height: 35,
              ),
            ),
            SizedBox(width: reducedSpacing ? 16 : 40),
            // Navigation Links
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeaderLink(context, 'Home', '/'),
                _buildHeaderSeparator(),
                _buildHeaderLink(context, 'Blog', '/Blog'),
                _buildHeaderSeparator(),
                _buildHeaderLink(context, 'About Us', '/about'),
                _buildHeaderSeparator(),
                _buildHeaderLink(context, 'Contact', '/contact'),
              ],
            ),
            // Spacer moved here
            const Spacer(),
            const SizedBox(width: 16),

            // App Store Icons
            if (showStores) ...[
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
              const SizedBox(width: 8),
            ],
            _buildQrCodeIconButton(context),
            const SizedBox(width: 20),

            // Search bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isSearchExpanded ? 280 : 36,
              height: 36,
              clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 280,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!_isSearchExpanded) {
                          FocusScope.of(context).requestFocus(_searchFocusNode);
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        color: Colors.transparent,
                        child: Icon(
                          Icons.search,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.searchController,
                        focusNode: _searchFocusNode,
                        onChanged: widget.onSearch,
                        decoration: InputDecoration(
                          hintText: 'Explore 1800+ Free Exercises...  ',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(
                            right: 16,
                            bottom: 12, // Adjusted vertically
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      },
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
                widget.onLogoTap?.call();
                final scaffold = context.findAncestorStateOfType<MainScaffoldState>()
                    ?? MainScaffold.globalKey.currentState;
                if (scaffold != null) {
                  scaffold.changeTab(0);
                  Navigator.of(context).popUntil((route) => route.settings.name == '/' || route.isFirst);
                } else {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
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

  // ── QR hover popup ─────────────────────────────────────────────────────────

  void _showQrOverlay(BuildContext context) {
    _qrOverlay?.remove();
    _qrOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          CompositedTransformFollower(
            link: _qrLayerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 10),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 200,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/banner/gymguide qrcode.png',
                          width: 172,
                          height: 172,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Scan to download GymGuide',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Available on iOS & Android',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF888888),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_qrOverlay!);
  }

  void _hideQrOverlay() {
    _qrOverlay?.remove();
    _qrOverlay = null;
  }

  Widget _buildQrCodeIconButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showText = screenWidth > 950;

    return CompositedTransformTarget(
      link: _qrLayerLink,
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            _isQrHovered = true;
          });
          _showQrOverlay(context);
        },
        onExit: (_) {
          setState(() {
            _isQrHovered = false;
          });
          _hideQrOverlay();
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (_qrOverlay == null) {
              _showQrOverlay(context);
            } else {
              _hideQrOverlay();
            }
          },
          child: AnimatedScale(
            scale: _isQrHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 38,
              width: showText ? null : 38,
              padding: showText 
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                  : null,
              decoration: BoxDecoration(
                color: _isQrHovered ? const Color(0xFF1A1A1A) : Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(_isQrHovered ? 0.5 : 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(_isQrHovered ? 0.3 : 0.2),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  if (showText) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Scan Me',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: '.SF Pro Display',
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens a store URL in an external browser
  Future<void> _launchStore(String url) async {
    if (url.contains('apple.com')) {
      await AnalyticsService().trackDownloadLinkClicked(store: 'app_store');
    } else if (url.contains('google.com')) {
      await AnalyticsService().trackDownloadLinkClicked(store: 'google_play');
    }
    final uri = Uri.parse(AnalyticsService().appendVisitorId(url));
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

  // ── Header Navigation Links ──────────────────────────────────────────────────

  Widget _buildHeaderLink(BuildContext context, String text, String route) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (route == '/') {
            // Handle home logic
            widget.onLogoTap?.call();
            final scaffold = context.findAncestorStateOfType<MainScaffoldState>()
                ?? MainScaffold.globalKey.currentState;
            if (scaffold != null) {
              scaffold.changeTab(0);
              Navigator.of(context).popUntil((r) => r.settings.name == '/' || r.isFirst);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
            }
          } else {
            Navigator.pushNamed(context, route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSeparator() {
    return const Text(
      '|',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 19,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

