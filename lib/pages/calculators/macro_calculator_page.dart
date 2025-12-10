import 'package:flutter/material.dart';
import '../../widgets/red_header.dart';
import '../../widgets/legal_page_layout.dart';

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
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return LegalPageLayout(
      title: 'Macro Calculator',
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
                  fillColor: widget.isDarkMode ? Colors.black12 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                  color: widget.isDarkMode ? Colors.black12 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_macros != null) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    _buildMacroCard('Protein', '${_macros!['Protein']}g', Colors.blue),
                    const SizedBox(width: 16),
                    _buildMacroCard('Carbs', '${_macros!['Carbs']}g', Colors.green),
                    const SizedBox(width: 16),
                    _buildMacroCard('Fats', '${_macros!['Fats']}g', Colors.orange),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
