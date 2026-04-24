import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_page.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0608);
const _kRed = Color(0xFFD4132A);
const _kRedGlow = Color(0xFFB5061C);
const _kGold = Color(0xFFFFBB00);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthPage(),
        transitionDuration: const Duration(milliseconds: 380),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final topPad = mq.padding.top;
    final botPad = mq.padding.bottom;
    final isWide = screenW > 680;
    final contentW = isWide ? 420.0 : screenW;
    // Hero image height: 40% of screen, capped so content always fits
    final heroH = (screenH * 0.40).clamp(160.0, 280.0);

    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Stack(
            children: [
              // ── Red radial glow (purely decorative, fully positioned) ────────
              Positioned(
                top: -screenH * 0.08,
                right: isWide
                    ? (screenW - contentW) / 2 - contentW * 0.25
                    : -screenW * 0.25,
                child: IgnorePointer(
                  child: Container(
                    width: contentW * 1.1,
                    height: screenH * 0.60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kRedGlow.withOpacity(0.75),
                          _kRedGlow.withOpacity(0.28),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                        radius: 0.55,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Scrollable content — NEVER overflows ─────────────────────────
              Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: contentW,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: topPad + 12,
                        bottom: botPad + 8,
                        left: 22,
                        right: 22,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            // Top badges row
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _BadgePill(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🏆',
                                            style: TextStyle(fontSize: 11)),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Built for Real Results',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _BadgePill(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            5,
                                            (i) => const Icon(
                                                Icons.star_rounded,
                                                color: _kGold,
                                                size: 13),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '4.9 Rating',
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Hero image — dynamic expanding
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, child) => Transform.scale(
                                  scale: _pulseAnim.value,
                                  alignment: Alignment.bottomCenter,
                                  child: child,
                                ),
                                child: Image.asset(
                                  'assets/quizimg.png',
                                  width: contentW,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Headline
                            Text(
                              'Build Your Dream Body',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize:
                                    (contentW * 0.072).clamp(20.0, 32.0),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'A personalized plan built just for\nyour body & goals',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: Colors.white.withOpacity(0.60),
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Features card
                            _FeaturesCard(),

                            const SizedBox(height: 14),

                            // CTA button
                            _CtaButton(onTap: _goNext),

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 72,
                                  height: 34,
                                  child: Stack(
                                    children: [
                                      Positioned(left: 0, child: _buildAvatar('assets/avatar1.png', 34)),
                                      Positioned(left: 20, child: _buildAvatar('assets/avatar2.png', 34)),
                                      Positioned(left: 40, child: _buildAvatar('assets/avatar3.png', 34)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Join 12,000+ users',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'already transforming their bodies',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}

// ─── Features card ────────────────────────────────────────────────────────────
class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  static const _features = [
    {
      'emoji': '🔥',
      'title': 'Personalized Workouts',
      'sub': 'Tailored to your fitness level'
    },
    {
      'emoji': '🥗',
      'title': 'Smart Meal Plans',
      'sub': 'Nutrition that fits your lifestyle'
    },
    {
      'emoji': '📊',
      'title': 'Track Your Progress',
      'sub': 'Stay motivated with real insights'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_features.length, (i) {
        final f = _features[i];
        final isLast = i == _features.length - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(f['emoji']!,
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      f['title']!.replaceFirst(' ', '\n'), // Max 2 lines
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── CTA Button ───────────────────────────────────────────────────────────────
class _CtaButton extends StatefulWidget {
  const _CtaButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(scale: _ctrl.value, child: child),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF1E40), Color(0xFFC8061B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1E40).withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'GET MY PLAN',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Badge pill ───────────────────────────────────────────────────────────────
class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: child,
    );
  }
}

// ─── Avatar helper ──────────────────────────────────────────────────────────────
Widget _buildAvatar(String asset, double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFCC0A16), width: 2),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)
      ],
    ),
    child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
  );
}
