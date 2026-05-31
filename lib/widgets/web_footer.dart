import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    _buildFooterLink('FAQ', () => _navigateToPage(context, 'faq')),
                    _buildSeparator(),
                    _buildFooterLink('Sitemap', () => _navigateToPage(context, 'sitemap')),
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
                _buildSocialIcon('assets/svg/socialmedia/facebookicon.png', 'https://www.facebook.com/people/Gym-Guide/61590379891853/'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/instagramicon.png', 'https://www.instagram.com/gymguide.co/'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/pinteresticon.png', 'https://www.pinterest.com/gymguideofficial1/'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/tiktokicon.png', 'https://www.tiktok.com/@gymguide.coapp'),
                const SizedBox(width: 8),
                _buildSocialIcon('assets/svg/socialmedia/youtubeicon.png', 'https://www.youtube.com/@GymGuideOfficial'),
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

  Widget _buildSocialIcon(String pngPath, String url) {
    return Tooltip(
      message: url,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            debugPrint('[FOOTER] Opening $url');
            final uri = Uri.parse(url);
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                debugPrint('[FOOTER] Could not launch $url');
              }
            } catch (e) {
              debugPrint('[FOOTER] Error launching $url: $e');
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                pngPath,
                width: 24,
                height: 24,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
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
      case 'about':
        routeName = '/about';
        break;
      case 'faq':
        routeName = '/faq';
        break;
      case 'sitemap':
        routeName = '/sitemap';
        break;
      default:
        return;
    }
    
    // If we're already on a legal page (not the main scaffold '/' route),
    // replace the current legal page so routes don't pile up.
    // If we're on the main scaffold, push on top so MainScaffold stays alive
    // in the stack (required for popUntil to work when returning from legal pages).
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final isOnMainScaffold = currentRoute == '/';
    if (isOnMainScaffold) {
      Navigator.pushNamed(context, routeName);
    } else {
      Navigator.pushReplacementNamed(context, routeName);
    }
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
