import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OneRmCalculatorPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const OneRmCalculatorPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<OneRmCalculatorPage> createState() => _OneRmCalculatorPageState();
}

class _OneRmCalculatorPageState extends State<OneRmCalculatorPage> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  double? _oneRm;
  Map<int, int>? _percentages;

  void _calculateOneRm() {
    final double? weight = double.tryParse(_weightController.text);
    final int? reps = int.tryParse(_repsController.text);

    if (weight != null && reps != null && reps > 0) {
      // Epley Formula
      final oneRm = weight * (1 + (reps / 30));

      setState(() {
        _oneRm = oneRm;
        _percentages = {
          95: (oneRm * 0.95).round(),
          90: (oneRm * 0.90).round(),
          85: (oneRm * 0.85).round(),
          80: (oneRm * 0.80).round(),
          75: (oneRm * 0.75).round(),
          70: (oneRm * 0.70).round(),
          65: (oneRm * 0.65).round(),
          60: (oneRm * 0.60).round(),
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
        title: '1RM Calculator',
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
                _buildInput('Weight Lifted (kg/lbs)', _weightController,
                    'e.g. 100', textColor),
                const SizedBox(height: 16),
                _buildInput(
                    'Reps Performed', _repsController, 'e.g. 5', textColor),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _calculateOneRm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Calculate 1RM',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_oneRm != null) ...[
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
                          'Estimated 1 Rep Max',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_oneRm!.round()}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Training Percentages',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _percentages!.entries.map((entry) {
                      return Container(
                        width: 100,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              widget.isDarkMode ? Colors.black12 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${entry.key}%',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.value}',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
                  'This app provides general fitness and health estimates for informational purposes only.\nIt is not medical advice.\n\nBased on Brzycki & Epley 1RM classification standards.',
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
}
