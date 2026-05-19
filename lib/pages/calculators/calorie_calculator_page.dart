import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import '../../widgets/calculator_seo_content.dart';
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

  final Map<String, double> _activityOptions = {
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
        convWeight = weight * 0.453592;
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
        _calories = bmr * (_activityOptions[_activityLevel] ?? 1.2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return LegalPageLayout(
        title: 'Calorie Calculator',
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
                        _buildToggleBtn('Metric', _unit == 'Metric', (val) => setState(() => _unit = val)),
                        const SizedBox(width: 16),
                        _buildToggleBtn('Imperial', _unit == 'Imperial', (val) => setState(() => _unit = val)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    Text('Gender', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildChoiceBtn('Male', _gender == 'Male'),
                        const SizedBox(width: 12),
                        _buildChoiceBtn('Female', _gender == 'Female'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildInput('Age', _ageController, 'e.g. 25', textColor),
                    const SizedBox(height: 16),
                    _buildInput(_unit == 'Metric' ? 'Height (cm)' : 'Height (inches)', _heightController, _unit == 'Metric' ? 'e.g. 175' : 'e.g. 69', textColor),
                    const SizedBox(height: 16),
                    _buildInput(_unit == 'Metric' ? 'Weight (kg)' : 'Weight (lbs)', _weightController, _unit == 'Metric' ? 'e.g. 70' : 'e.g. 154', textColor),
                    const SizedBox(height: 24),

                    Text('Activity Level', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.isDarkMode ? Colors.white24 : Colors.black12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _activityLevel,
                          isExpanded: true,
                          dropdownColor: cardColor,
                          style: TextStyle(color: textColor),
                          items: _activityOptions.keys.map((String key) {
                            return DropdownMenuItem<String>(value: key, child: Text(key));
                          }).toList(),
                          onChanged: (val) => setState(() => _activityLevel = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _calculateCalories,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Calculate Calories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (_calories != null) ...[
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? Colors.black12 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('Daily Calorie Needs', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14)),
                            const SizedBox(height: 8),
                            Text('${_calories!.round()} kcal', style: TextStyle(color: textColor, fontSize: 48, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('to maintain current weight', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14)),
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
              calculatorName: "Calorie Calculator",
              isDarkMode: widget.isDarkMode,
              whatIsDescription: "A Calorie Calculator is a precise tool designed to estimate the number of calories your body needs daily to maintain, lose, or gain weight. It uses scientifically backed formulas like the Mifflin-St Jeor equation to determine your Basal Metabolic Rate (BMR) and then applies an activity factor to calculate your Total Daily Energy Expenditure (TDEE).\n\nAt GymGuide, we believe that understanding your energy balance is the cornerstone of any successful transformation. Whether you're a high-performance athlete or just starting your fitness journey, knowing your daily caloric needs empowers you to make informed decisions about your nutrition and stay on track toward your goals.",
              howItWorksSteps: [
                {'title': 'Baseline Metabolism', 'description': 'We calculate your BMR, the energy your body uses at rest.'},
                {'title': 'Activity Level', 'description': 'Your daily movement—from desk work to intense gym sessions—is added.'},
                {'title': 'Goal Selection', 'description': 'We adjust the total based on whether you want to lose, gain, or maintain.'},
                {'title': 'Daily Targets', 'description': 'You receive a personalized calorie goal to hit every day.'},
              ],
              whyMattersDescription: "Weight management is fundamentally a game of energy balance. If you consume more than you burn, you gain weight; if you consume less, you lose it. Without a baseline estimate, you're essentially guessing, which can lead to frustration and plateaus. By using our Calorie Calculator, you gain a reliable \"north star\" for your diet, ensuring that your hard work in the gym is supported by the right amount of fuel.",
              healthyTips: [
                {'icon': 'track', 'text': 'Track Progress Weekly'},
                {'icon': 'fitness', 'text': 'Combine Workouts with Nutrition'},
                {'icon': 'consistency', 'text': 'Focus on Consistency'},
                {'icon': 'water', 'text': 'Stay Hydrated'},
              ],
              faqs: [
                {'q': 'How many calories should I eat to lose weight?', 'a': 'Generally, a 300-500 calorie deficit from your TDEE is considered sustainable and safe.'},
                {'q': 'What is TDEE?', 'a': 'It stands for Total Daily Energy Expenditure, which is the total number of calories you burn in 24 hours.'},
                {'q': 'Is the calculator 100% accurate?', 'a': 'It provides a highly reliable estimate, but individual metabolism can vary based on genetics and health conditions.'},
                {'q': 'Should I eat back exercise calories?', 'a': 'Most people find better results by using a fixed activity factor rather than tracking every individual workout.'},
                {'q': 'How often should I recalculate?', 'a': 'We recommend recalculating every 5-10 lbs of weight change as your energy needs will shift.'},
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildInput(String label, TextEditingController controller, String hint, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            filled: true,
            fillColor: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF0000) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFFFF0000) : Colors.grey.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : (widget.isDarkMode ? Colors.white : Colors.black87), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildChoiceBtn(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _gender = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF0000).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFFFF0000) : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFFFF0000) : (widget.isDarkMode ? Colors.white70 : Colors.black54), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDisclaimerFooter(Color textColor) {
    final disclaimerTextColor = widget.isDarkMode ? Colors.white70 : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/svg/logo/disclaimeremoji.svg', width: 16, height: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('General fitness estimates for informational purposes only. Based on Mifflin-St Jeor equation.', style: TextStyle(fontSize: 12, color: disclaimerTextColor))),
          ],
        ),
        const SizedBox(height: 16),
        Text('Sources:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: disclaimerTextColor)),
        const Text('- WHO: https://www.who.int', style: TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
      ],
    );
  }
}
