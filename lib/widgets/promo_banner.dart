import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/revenue_cat_service.dart';
import '../services/analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth/auth_modal.dart';

/// Apple-compliant internal promotional banner.
///
/// -- Rules --
/// • Clearly labeled as GymGuide Premium (not an external ad)
/// • Does NOT block interaction — it is a scrollable card
/// • No fake close buttons styled as external ads
/// • No countdown timers (removed for cleaner UX)
/// • Single unified rectangle design used throughout the app
/// • Subtle shimmer animation to attract attention
class PromoBanner extends StatefulWidget {
  /// Optional margin around the banner. Defaults to EdgeInsets.symmetric(vertical: 8)
  final EdgeInsetsGeometry? margin;

  /// Source label passed to analytics on paywall open.
  final String source;

  const PromoBanner({
    Key? key,
    this.margin,
    this.source = 'promo_banner',
  }) : super(key: key);

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner>
    with SingleTickerProviderStateMixin {
  bool _isTapping = false;
  bool _isLoadingOfferings = true;

  // Shimmer/slide animation
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _checkOfferings();
  }

  Future<void> _checkOfferings() async {
    await RevenueCatService().checkOfferingsReady();
    if (mounted) {
      setState(() {
        _isLoadingOfferings = false;
      });
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _openPaywall() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AuthModal.show(context);
      return;
    }

    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF0000)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unlock My Full Program',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'In-app purchases are only available on our mobile apps via Apple Pay and Google Play.\n\nPlease download the GymGuide app on iOS or Android to unlock Premium features.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(color: Color(0xFFFF0000), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // If still loading, wait briefly then proceed
    if (_isLoadingOfferings) return;

    AnalyticsService().trackPaywallViewed(source: widget.source);
    // Go straight to RevenueCatUI — it handles store errors natively.
    // Do NOT show our own error dialog; Apple reviewers see that as a bug.
    await RevenueCatService().showPaywall();
  }



  @override
  Widget build(BuildContext context) {
    // Always use the compact responsive dimensions globally as requested
    return _buildCard(compact: true);
  }

  Widget _buildCard({required bool compact}) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isTapping = true),
      onTapUp: (_) {
        setState(() => _isTapping = false);
        _openPaywall();
      },
      onTapCancel: () => setState(() => _isTapping = false),
      child: AnimatedScale(
        scale: _isTapping ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF0000), Color(0xFFB50000)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF0000).withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Decorative circle (top-right)
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: -30,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: compact ? 12 : 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: compact ? 36 : 48,
                        height: compact ? 36 : 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: compact ? 22 : 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text column
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Unlock My Full Program',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: compact ? 13 : 16,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                compact
                                    ? 'Continue your transformation without limits'
                                    : 'Continue your transformation without limits',
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 11 : 12,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Custom plans · 1800+ exercises · Progress tracking',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.60),
                                  fontSize: 10,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // CTA Button
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 18,
                          vertical: compact ? 7 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isLoadingOfferings
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFCC0000)),
                                ),
                              )
                            : Text(
                                compact ? 'Unlock' : 'Claim Offer',
                                style: const TextStyle(
                                  color: Color(0xFFCC0000),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Shimmer highlight overlay (drawn on top)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, _) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.18),
                              Colors.transparent,
                            ],
                            stops: [
                              (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                              _shimmerAnimation.value.clamp(0.0, 1.0),
                              (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
