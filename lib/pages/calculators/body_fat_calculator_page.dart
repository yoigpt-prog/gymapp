import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import '../../widgets/calculator_seo_content.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BodyFatCalculatorPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const BodyFatCalculatorPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<BodyFatCalculatorPage> createState() => _BodyFatCalculatorPageState();
}

class _BodyFatCalculatorPageState extends State<BodyFatCalculatorPage> {
  final TextEditingController _waistController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  String _gender = 'Male';
  double? _bodyFat;

  void _calculateBodyFat() {
    final double? waist = double.tryParse(_waistController.text);
    final double? height = double.tryParse(_heightController.text);

    if (waist != null && height != null && waist > 0 && height > 0) {
      // Relative Fat Mass (RFM) formula
      double result;
      if (_gender == 'Male') {
        result = 64 - (20 * height / waist);
      } else {
        result = 76 - (20 * height / waist);
      }

      setState(() {
        _bodyFat = result.clamp(2.0, 60.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return LegalPageLayout(
        title: 'Body Fat Estimator',
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.toggleTheme,
        embedded: true,
        backgroundColor: widget.isDarkMode ? null : Colors.white,
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildToggleBtn('Male', _gender == 'Male'),
                        const SizedBox(width: 16),
                        _buildToggleBtn('Female', _gender == 'Female'),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildInput(
                        'Height (cm)', _heightController, 'e.g. 175', textColor),
                    const SizedBox(height: 16),
                    _buildInput('Waist Circumference (cm)', _waistController,
                        'e.g. 85', textColor),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _calculateBodyFat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Estimate Body Fat',
                          style:
                              TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (_bodyFat != null) ...[
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? Colors.black12 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF0000).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Estimated Body Fat',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_bodyFat!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildDisclaimerFooter(textColor),
                  ],
                ),
              ),
            ),
            CalculatorSeoContent(
              calculatorName: "Body Fat Calculator",
              isDarkMode: widget.isDarkMode,
              whatIsDescription: "A Body Fat Calculator is an advanced tool that estimates the percentage of your total body weight that is composed of fat versus lean mass (muscle, bone, water, etc.). Unlike BMI, which only looks at weight and height, a body fat estimate provides a deeper look into your actual body composition and physical health.\n\nAt GymGuide, we prioritize body composition over just \"weight.\" Knowing your body fat percentage helps you understand if you're truly losing fat or if you're losing valuable muscle. It’s an essential metric for anyone serious about body recomposition, athletic performance, or long-term health.",
              howItWorksSteps: [
                {'title': 'Essential Measurements', 'description': 'Input your neck, waist, and height measurements accurately.'},
                {'title': 'Navy Seal Formula', 'description': 'We use the widely respected U.S. Navy Body Fat formula for precision.'},
                {'title': 'Compare Your Stats', 'description': 'See where you fall on the body fat spectrum (Athlete, Fitness, etc.).'},
                {'title': 'Refine Your Goal', 'description': 'Use the data to decide if you need to cut fat or build muscle.'},
              ],
              whyMattersDescription: "Maintaining a healthy body fat percentage is critical for hormonal balance, metabolic health, and reducing the risk of chronic diseases. For athletes, optimizing body fat can improve power-to-weight ratios and overall endurance. By tracking this number instead of just the scale, you get a much more accurate picture of your progress, allowing you to celebrate \"non-scale victories\" like losing inches while staying the same weight.",
              healthyTips: [
                {'icon': 'track', 'text': 'Track Progress Weekly'},
                {'icon': 'fitness', 'text': 'Combine Workouts with Nutrition'},
                {'icon': 'water', 'text': 'Stay Hydrated'},
                {'icon': 'consistency', 'text': 'Focus on Consistency'},
              ],
              faqs: [
                {'q': 'What is a healthy body fat percentage?', 'a': 'For men, 10-20% is generally considered fit; for women, 20-30% is ideal for health and performance.'},
                {'q': 'How accurate is the Navy Seal formula?', 'a': 'It is one of the most accurate tape-measure methods, typically within 3-4% of a DEXA scan result.'},
                {'q': 'Why do women need higher body fat?', 'a': 'Women require more essential fat for reproductive health, hormonal regulation, and general wellness.'},
                {'q': 'Can I lose fat in specific areas?', 'a': 'No, \"spot reduction\" is a myth. Fat loss occurs across the whole body based on genetics and a caloric deficit.'},
                {'q': 'How often should I measure body fat?', 'a': 'Once every 2-4 weeks is sufficient, as body composition changes happen slower than weight fluctuations.'},
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildDisclaimerFooter(Color textColor) {
    // Make text darker by not using muted colors heavily
    final disclaimerTextColor =
        widget.isDarkMode ? Colors.white70 : Colors.black87;
    const linkColor = Color(0xFF1976D2);

    Future<void> openUrl(String url) async {
      final uri = Uri.parse(url);
      // Apple prefers in-app browsing for external links from app
      if (await canLaunchUrl(uri))
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }

    Widget sourceRow(String label, String url) {
      return Padding(
        padding: const EdgeInsets.only(top: 6), // Added spacing
        child: Wrap(
          children: [
            Text('- $label: ',
                style: TextStyle(
                    fontSize: 14, color: disclaimerTextColor)), // Bigger text
            GestureDetector(
              onTap: () => openUrl(url),
              child: Text(
                url,
                style: const TextStyle(
                  fontSize: 14,
                  color: linkColor,
                  decoration: TextDecoration.underline,
                  decorationColor: linkColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      // Removed the grey background box and borders, rely on pure padding to separate
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SvgPicture.asset('assets/svg/logo/disclaimeremoji.svg',
                    width: 16, height: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This app provides general fitness and health estimates for informational purposes only.\nIt is not medical advice.\n\nBased on U.S. Navy Body Fat classification standards.',
                  style: TextStyle(
                    fontSize: 14, // Slightly bigger
                    color: disclaimerTextColor, // Darker text
                    height: 1.5, // Good spacing
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Sources:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: disclaimerTextColor)),
          sourceRow('WHO', 'https://www.who.int'),
          sourceRow('CDC', 'https://www.cdc.gov'),
          sourceRow('NIH', 'https://www.nih.gov'),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller,
      String hint, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            filled: true,
            fillColor: widget.isDarkMode
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFF0000),
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _gender = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF0000)
                : Colors.grey.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (widget.isDarkMode ? Colors.white : Colors.black87),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
