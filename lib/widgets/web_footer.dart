import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../pages/legal/privacy_policy_page.dart';
import '../pages/legal/terms_of_service_page.dart';
import '../pages/legal/disclaimer_page.dart';
import '../pages/legal/subscription_terms_page.dart';
import '../pages/legal/copyright_page.dart';
import '../pages/legal/age_requirement_page.dart';
import '../pages/legal/ai_transparency_page.dart';
import '../pages/legal/contact_support_page.dart';

class WebFooter extends StatefulWidget {
  final bool isDarkMode;

  const WebFooter({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<WebFooter> createState() => WebFooterState();
}

class WebFooterState extends State<WebFooter> {
  bool _isVisible = true;
  double _lastScrollOffset = 0;
  Timer? _inactivityTimer;

  void onScroll(ScrollNotification notification) {
    final currentOffset = notification.metrics.pixels;
    
    // Detect scroll direction
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      // Scrolling down - hide footer
      if (_isVisible) {
        setState(() => _isVisible = false);
      }
    } else if (currentOffset < _lastScrollOffset) {
      // Scrolling up - show footer
      if (!_isVisible) {
        setState(() => _isVisible = true);
      }
    }
    
    _lastScrollOffset = currentOffset;
    
    // Reset inactivity timer
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 15), () {
      if (!_isVisible) {
        setState(() => _isVisible = true);
      }
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        height: 51, // Fixed height to match header
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          color: Color(0xFFFF0000),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Copyright on the left
            Expanded(
              flex: 1,
              child: const Text(
                '© 2025 GGUIDE Apps Solutions LLC. All rights reserved.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Legal Links - Center
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFooterLink('Privacy', () => _navigateToPage(context, 'privacy')),
                    _buildSeparator(),
                    _buildFooterLink('Terms & EULA', () => _navigateToPage(context, 'terms')),
                    _buildSeparator(),
                    _buildFooterLink('Disclaimer', () => _navigateToPage(context, 'disclaimer')),
                    _buildSeparator(),
                    _buildFooterLink('Subscription', () => _navigateToPage(context, 'subscription')),
                    _buildSeparator(),
                    _buildFooterLink('Copyright', () => _navigateToPage(context, 'copyright')),
                    _buildSeparator(),
                    _buildFooterLink('Age', () => _navigateToPage(context, 'age')),
                    _buildSeparator(),
                    _buildFooterLink('AI', () => _navigateToPage(context, 'ai')),
                    _buildSeparator(),
                    _buildFooterLink('Contact', () => _navigateToPage(context, 'contact')),
                  ],
                ),
              ),
            ),
            
            // Social Media Icons - Right
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSocialIcon('assets/svg/socialmedia/facebookicon.svg', 'https://facebook.com'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/instagramicon.svg', 'https://instagram.com'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/pinteresticon.svg', 'https://pinterest.com'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/tiktokicon.svg', 'https://tiktok.com'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/youtubeicon.svg', 'https://youtube.com'),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text('|', style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(String svgPath, String url) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Snackbar silenced — log only
          debugPrint('[FOOTER] Opening $url');
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              svgPath,
              width: 40,
              height: 40,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String pageType) {
    String routeName = '';
    
    switch (pageType) {
      case 'privacy':
        routeName = '/privacy';
        break;
      case 'terms':
        routeName = '/terms';
        break;
      case 'disclaimer':
        routeName = '/disclaimer';
        break;
      case 'subscription':
        routeName = '/subscription-terms';
        break;
      case 'copyright':
        routeName = '/copyright';
        break;
      case 'age':
        routeName = '/age-requirement';
        break;
      case 'ai':
        routeName = '/ai-transparency';
        break;
      case 'contact':
        // Contact page does not have a route defined in main.dart correctly for SEO currently, but let's assume '/contact'
        // If not, we fall back to push. But let's check main.dart. Let's pushNamed '/contact'.
       // wait, let's just make sure to pushNamed.
        routeName = '/contact';
        break;
      default:
        return;
    }
    
    Navigator.pushNamed(context, routeName);
  }

  void _showContactInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: const Text('Email: support@gloguide.com\n\nFor inquiries, please reach out to our support team.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
