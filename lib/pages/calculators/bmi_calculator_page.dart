import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BmiCalculatorPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const BmiCalculatorPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<BmiCalculatorPage> createState() => _BmiCalculatorPageState();
}

class _BmiCalculatorPageState extends State<BmiCalculatorPage> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _unit = 'Metric'; // Metric or Imperial
  double? _bmi;
  String _bmiCategory = '';

  @override
  void initState() {
    super.initState();
    _loadUnitPreference();
  }

  Future<void> _loadUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final weightUnit = prefs.getString('weight_unit');
    if (weightUnit == 'lbs') {
      setState(() {
        _unit = 'Imperial';
      });
    } else {
      setState(() {
        _unit = 'Metric';
      });
    }
  }

  void _calculateBmi() {
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);

    if (height != null && weight != null && height > 0 && weight > 0) {
      setState(() {
        if (_unit == 'Metric') {
          // Height in cm, Weight in kg
          _bmi = weight / ((height / 100) * (height / 100));
        } else {
          // Height in inches, Weight in lbs
          _bmi = (weight / (height * height)) * 703;
        }
        _bmiCategory = _getBmiCategory(_bmi!);
      });
    }
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 24.9) return 'Normal weight';
    if (bmi < 29.9) return 'Overweight';
    return 'Obesity';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return LegalPageLayout(
        title: 'BMI Calculator',
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.toggleTheme,
        embedded: true,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unit Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToggleBtn('Metric', _unit == 'Metric'),
                    const SizedBox(width: 16),
                    _buildToggleBtn('Imperial', _unit == 'Imperial'),
                  ],
                ),
                const SizedBox(height: 32),

                // Inputs
                Text(
                  _unit == 'Metric' ? 'Height (cm)' : 'Height (inches)',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: _unit == 'Metric' ? 'e.g. 175' : 'e.g. 69',
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
                  _unit == 'Metric' ? 'Weight (kg)' : 'Weight (lbs)',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: _unit == 'Metric' ? 'e.g. 70' : 'e.g. 154',
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
                const SizedBox(height: 32),

                // Calculate Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _calculateBmi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Calculate BMI',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Result
                if (_bmi != null) ...[
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
                          'Your BMI',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _bmi!.toStringAsFixed(1),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _bmiCategory,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                  'This app provides general fitness and health estimates for informational purposes only.\nIt is not medical advice.\n\nBased on WHO BMI classification standards.',
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

  Widget _buildToggleBtn(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _unit = label),
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
