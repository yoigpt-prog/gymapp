import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CalculatorSeoContent extends StatelessWidget {
  final String calculatorName;
  final String whatIsDescription;
  final List<Map<String, String>> howItWorksSteps;
  final String whyMattersDescription;
  final List<Map<String, String>> healthyTips;
  final List<Map<String, String>> faqs;
  final bool isDarkMode;

  const CalculatorSeoContent({
    Key? key,
    required this.calculatorName,
    required this.whatIsDescription,
    required this.howItWorksSteps,
    required this.whyMattersDescription,
    required this.healthyTips,
    required this.faqs,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final mutedTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = const Color(0xFFFF0000);

    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          _buildDivider(accentColor),
          const SizedBox(height: 60),

          // What Is section
          _buildHeader("What Is $calculatorName?", accentColor),
          const SizedBox(height: 16),
          Text(
            whatIsDescription,
            style: GoogleFonts.outfit(
              fontSize: 18,
              height: 1.7,
              color: mutedTextColor,
            ),
          ),
          const SizedBox(height: 60),

          // How It Works section
          _buildHeader("How It Works", accentColor),
          const SizedBox(height: 24),
          _buildStepGrid(howItWorksSteps, cardColor, textColor, accentColor),
          const SizedBox(height: 60),

          // Why This Matters section
          _buildHeader("Why This Matters", accentColor),
          const SizedBox(height: 16),
          Text(
            whyMattersDescription,
            style: GoogleFonts.outfit(
              fontSize: 18,
              height: 1.7,
              color: mutedTextColor,
            ),
          ),
          const SizedBox(height: 60),

          // Healthy Tips section
          _buildHeader("Healthy Tips", accentColor),
          const SizedBox(height: 24),
          _buildTipsGrid(healthyTips, cardColor, textColor, accentColor),
          const SizedBox(height: 60),

          // FAQ Section
          _buildHeader("Frequently Asked Questions", accentColor),
          const SizedBox(height: 16),
          ...faqs.map((faq) => _buildFaqItem(faq['q']!, faq['a']!, cardColor, textColor, accentColor)).toList(),
          const SizedBox(height: 60),

          // Disclaimer Box
          _buildDisclaimerBox(cardColor, mutedTextColor, accentColor),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Center(
      child: Container(
        width: 60,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, Color accentColor) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildStepGrid(List<Map<String, String>> steps, Color cardColor, Color textColor, Color accentColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: steps.map((step) {
            final index = steps.indexOf(step) + 1;
            return Container(
              width: isMobile ? constraints.maxWidth : (constraints.maxWidth - 16) / 2,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$index",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title']!,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['description']!,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTipsGrid(List<Map<String, String>> tips, Color cardColor, Color textColor, Color accentColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: tips.map((tip) {
            return Container(
              width: isMobile ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 32) / 3,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(tip['icon'] == 'water' ? Icons.water_drop :
                       tip['icon'] == 'track' ? Icons.analytics :
                       tip['icon'] == 'consistency' ? Icons.repeat :
                       Icons.fitness_center, color: accentColor, size: 28),
                  const SizedBox(height: 12),
                  Text(
                    tip['text']!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFaqItem(String question, String answer, Color cardColor, Color textColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        iconColor: accentColor,
        collapsedIconColor: accentColor,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: GoogleFonts.outfit(
                fontSize: 15,
                height: 1.5,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBox(Color cardColor, Color mutedTextColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: accentColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "GymGuide provides general fitness and wellness estimates for informational purposes only. Results may not always be perfectly accurate and should not replace professional medical advice.",
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: mutedTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
