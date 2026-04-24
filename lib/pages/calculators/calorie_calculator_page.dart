import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CalorieCalculatorPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const CalorieCalculatorPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<CalorieCalculatorPage> createState() => _CalorieCalculatorPageState();
}

class _CalorieCalculatorPageState extends State<CalorieCalculatorPage> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _gender = 'Male';
  String _activityLevel = 'Sedentary';
  double? _calories;
  String _unit = 'Metric'; // Metric or Imperial

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

  final Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly Active': 1.375,
    'Moderately Active': 1.55,
    'Very Active': 1.725,
    'Extra Active': 1.9,
  };

  void _calculateCalories() {
    final int? age = int.tryParse(_ageController.text);
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);

    if (age != null && height != null && weight != null) {
      double convWeight = weight;
      double convHeight = height;

      if (_unit == 'Imperial') {
        // Convert lbs to kg
        convWeight = weight * 0.453592;
        // Convert inches to cm
        convHeight = height * 2.54;
      }

      // Mifflin-St Jeor Equation
      double bmr;
      if (_gender == 'Male') {
        bmr = (10 * convWeight) + (6.25 * convHeight) - (5 * age) + 5;
      } else {
        bmr = (10 * convWeight) + (6.25 * convHeight) - (5 * age) - 161;
      }

      setState(() {
        _calories = bmr * (_activityMultipliers[_activityLevel] ?? 1.2);
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
        title: 'Calorie Calculator',
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
                // Gender Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToggleBtn('Male', _gender == 'Male'),
                    const SizedBox(width: 16),
                    _buildToggleBtn('Female', _gender == 'Female'),
                  ],
                ),
                const SizedBox(height: 32),

                // Inputs
                _buildInput('Age', _ageController, 'e.g. 25', textColor),
                const SizedBox(height: 16),
                _buildInput(
                    _unit == 'Metric' ? 'Height (cm)' : 'Height (inches)',
                    _heightController,
                    _unit == 'Metric' ? 'e.g. 175' : 'e.g. 69',
                    textColor),
                const SizedBox(height: 16),
                _buildInput(
                    _unit == 'Metric' ? 'Weight (kg)' : 'Weight (lbs)',
                    _weightController,
                    _unit == 'Metric' ? 'e.g. 70' : 'e.g. 154',
                    textColor),
                const SizedBox(height: 24),

                Text(
                  'Activity Level',
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
                      value: _activityLevel,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor),
                      items: _activityMultipliers.keys.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _activityLevel = newValue!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Calculate Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _calculateCalories,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Calculate Calories',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Result
                if (_calories != null) ...[
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
                          'Daily Calorie Needs',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_calories!.round()} kcal',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'to maintain current weight',
                          style: TextStyle(
                            color: textColor.withOpacity(0.5),
                            fontSize: 14,
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
                  'This app provides general fitness and health estimates for informational purposes only.\nIt is not medical advice.\n\nBased on Mifflin-St Jeor classification standards.',
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
