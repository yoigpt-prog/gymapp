import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopSidePanel extends StatelessWidget {
  final bool isDarkMode;
  final double width;

  const DesktopSidePanel({
    Key? key,
    required this.isDarkMode,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. AdSense Placeholder Banner
        const AdSensePlaceholderBanner(),
        const SizedBox(height: 16),

        // 2. Featured Content Card
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border.all(
              color: isDarkMode ? Colors.white : Colors.black,
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FEATURED CONTENT',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              _buildArticleItem(
                context: context,
                title: 'Best Protein Foods For Muscle Growth',
                imagePath: 'assets/blogassets/img5.png',
                slug: 'best-high-protein-foods-for-muscle-growth-and-fat-loss',
              ),
              const SizedBox(height: 16),
              _buildArticleItem(
                context: context,
                title: '7-Day Full Body Workout Plan',
                imagePath: 'assets/blogassets/img1.png',
                slug: 'best-push-pull-legs-routine-for-beginners-full-guide',
              ),
              const SizedBox(height: 16),
              _buildArticleItem(
                context: context,
                title: 'How to Stay Consistent With Fitness',
                imagePath: 'assets/blogassets/img3.png',
                slug: 'how-to-stay-consistent-with-fitness-and-stop-quitting',
              ),
              const SizedBox(height: 20),
              HoverableButton(
                text: 'View All Articles',
                fullWidth: true,
                fontSize: 13,
                onTap: () {
                  Navigator.pushNamed(context, '/Blog');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArticleItem({
    required BuildContext context,
    required String title,
    required String imagePath,
    required String slug,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail Image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            imagePath,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              HoverableButton(
                text: 'Read More',
                onTap: () {
                  Navigator.pushNamed(context, '/blog/$slug');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdSensePlaceholderBanner extends StatelessWidget {
  const AdSensePlaceholderBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border.all(
            color: isDarkMode ? Colors.white : Colors.black,
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            'Advertisement Space',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white38 : Colors.black38,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class HoverableButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final double fontSize;
  final bool fullWidth;

  const HoverableButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.fontSize = 11,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  State<HoverableButton> createState() => _HoverableButtonState();
}

class _HoverableButtonState extends State<HoverableButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: widget.fullWidth ? 16 : 10,
            vertical: widget.fullWidth ? 10 : 4,
          ),
          alignment: widget.fullWidth ? Alignment.center : null,
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFFF0000) : Colors.transparent,
            border: Border.all(
              color: const Color(0xFFFF0000),
              width: _isHovered ? 1.5 : 1.2,
            ),
            borderRadius: BorderRadius.circular(widget.fullWidth ? 8 : 6),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            widget.text,
            style: GoogleFonts.outfit(
              color: _isHovered ? Colors.white : const Color(0xFFFF0000),
              fontSize: widget.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
