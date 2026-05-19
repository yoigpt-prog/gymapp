import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import '../../widgets/calculator_seo_content.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MacroCalculatorPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MacroCalculatorPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<MacroCalculatorPage> createState() => _MacroCalculatorPageState();
}

class _MacroCalculatorPageState extends State<MacroCalculatorPage> {
  final TextEditingController _caloriesController = TextEditingController();
  String _goal = 'Maintenance';
  Map<String, int>? _macros;

  void _calculateMacros() {
    final double? calories = double.tryParse(_caloriesController.text);

    if (calories != null) {
      double proteinRatio, fatRatio, carbRatio;

      switch (_goal) {
        case 'Weight Loss':
          proteinRatio = 0.40;
          fatRatio = 0.30;
          carbRatio = 0.30;
          break;
        case 'Muscle Gain':
          proteinRatio = 0.30;
          fatRatio = 0.25;
          carbRatio = 0.45;
          break;
        case 'Maintenance':
        default:
          proteinRatio = 0.30;
          fatRatio = 0.30;
          carbRatio = 0.40;
          break;
      }

      setState(() {
        _macros = {
          'Protein': ((calories * proteinRatio) / 4).round(),
          'Fats': ((calories * fatRatio) / 9).round(),
          'Carbs': ((calories * carbRatio) / 4).round(),
        };
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
        title: 'Macro Calculator',
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
                    Text(
                      'Daily Calories',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. 2500',
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
                    const SizedBox(height: 24),
                    Text(
                      'Goal',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _goal,
                          isExpanded: true,
                          dropdownColor: cardColor,
                          style: TextStyle(color: textColor),
                          items: ['Weight Loss', 'Maintenance', 'Muscle Gain']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _goal = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _calculateMacros,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Calculate Macros',
                          style:
                              TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (_macros != null) ...[
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          _buildMacroCard(
                              'Protein', '${_macros!['Protein']}g', Colors.blue),
                          const SizedBox(width: 16),
                          _buildMacroCard(
                              'Carbs', '${_macros!['Carbs']}g', Colors.green),
                          const SizedBox(width: 16),
                          _buildMacroCard(
                              'Fats', '${_macros!['Fats']}g', Colors.orange),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildDisclaimerFooter(textColor),
                  ],
                ),
              ),
            ),
            CalculatorSeoContent(
              calculatorName: "Macro Calculator",
              isDarkMode: widget.isDarkMode,
              whatIsDescription: "A Macro Calculator takes your daily calorie needs a step further by breaking them down into the three essential macronutrients: protein, carbohydrates, and fats. Each of these \"macros\" plays a distinct and vital role in your body—protein for muscle repair, carbohydrates for energy, and fats for hormonal health and nutrient absorption.\n\nAt GymGuide, we know that total calories determine your weight, but macros determine your body composition. By fine-tuning your macro ratios, you can optimize your performance in the gym, accelerate recovery, and achieve that lean, athletic look you've been working for.",
              howItWorksSteps: [
                {'title': 'Calorie Baseline', 'description': 'We start with your TDEE based on your stats and activity.'},
                {'title': 'Goal Definition', 'description': 'Whether you\'re cutting, bulking, or maintaining, we adjust the ratios.'},
                {'title': 'Nutrient Breakdown', 'description': 'We assign grams for protein, fats, and carbs based on your needs.'},
                {'title': 'Flexible Tracking', 'description': 'You get a clear daily target for each macronutrient.'},
              ],
              whyMattersDescription: "\"You are what you eat\" is especially true when it comes to body composition. High-protein diets are scientifically proven to help preserve lean muscle tissue during weight loss and support muscle protein synthesis during growth. Similarly, getting the right amount of healthy fats and complex carbs ensures you have the energy to crush your workouts without feeling sluggish. Mastering your macros is the key to moving beyond \"weight loss\" and toward true \"fat loss.\"",
              healthyTips: [
                {'icon': 'consistency', 'text': 'Focus on Consistency'},
                {'icon': 'fitness', 'text': 'Combine Workouts with Nutrition'},
                {'icon': 'water', 'text': 'Stay Hydrated'},
                {'icon': 'track', 'text': 'Track Progress Weekly'},
              ],
              faqs: [
                {'q': 'What are the best macro ratios for fat loss?', 'a': 'A common starting point is 40% protein, 35% carbs, and 25% fats, but this can vary based on individual preference.'},
                {'q': 'Do I need to track every single gram?', 'a': 'For the best results, yes; however, staying within 5-10g of your targets is usually sufficient for most goals.'},
                {'q': 'Why is protein so important?', 'a': 'Protein has the highest thermic effect of food (TEF) and is the building block of all muscle tissue in the body.'},
                {'q': 'Can I eat \"dirty\" as long as I hit my macros?', 'a': 'While possible (IIFYM), focusing on whole, nutrient-dense foods will significantly improve your overall health and energy levels.'},
                {'q': 'How do I adjust macros for a bulk?', 'a': 'Typically, we increase carbohydrates while keeping protein high to fuel growth and recover from intense training.'},
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
                  'This app provides general fitness and health estimates for informational purposes only.\nIt is not medical advice.\n\nBased on AMDR (Acceptable Macronutrient Distribution Ranges) classification standards.',
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

  Widget _buildMacroCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
