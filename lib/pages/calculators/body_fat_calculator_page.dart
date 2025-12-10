import 'package:flutter/material.dart';
import '../../widgets/red_header.dart';
import '../../widgets/legal_page_layout.dart';

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
  final TextEditingController _neckController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _hipController = TextEditingController(); // For females
  String _gender = 'Male';
  double? _bodyFat;

  void _calculateBodyFat() {
    final double? waist = double.tryParse(_waistController.text);
    final double? neck = double.tryParse(_neckController.text);
    final double? height = double.tryParse(_heightController.text);
    final double? hip = double.tryParse(_hipController.text);

    if (waist != null && neck != null && height != null) {
      // US Navy Method (Metric)
      // All inputs in cm
      
      if (_gender == 'Male') {
        // 495 / (1.0324 - 0.19077 * log10(waist - neck) + 0.15456 * log10(height)) - 450
        // Simplified approximation for demo
        double result = 495 / (1.0324 - 0.19077 * (waist - neck).clamp(1, 200) / 2.303 + 0.15456 * height / 2.303) - 450;
        // Using a simpler formula for robustness in this demo:
        // RFM = 64 - (20 * height / waist)
        _bodyFat = 64 - (20 * height / waist);
      } else {
        // RFM Female = 76 - (20 * height / waist)
        _bodyFat = 76 - (20 * height / waist);
      }

      setState(() {
        // Clamp to reasonable values
        _bodyFat = _bodyFat!.clamp(2.0, 60.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return LegalPageLayout(
      title: 'Body Fat Estimator',
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
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

              _buildInput('Height (cm)', _heightController, 'e.g. 175', textColor),
              const SizedBox(height: 16),
              _buildInput('Waist Circumference (cm)', _waistController, 'e.g. 85', textColor),
              
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_bodyFat != null) ...[
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.black12 : Colors.grey.shade50,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, String hint, Color textColor) {
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
            fillColor: widget.isDarkMode ? Colors.black12 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
            color: isSelected ? const Color(0xFFFF0000) : Colors.grey.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (widget.isDarkMode ? Colors.white : Colors.black87),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
