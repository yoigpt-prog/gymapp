import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class DataExportPage extends StatelessWidget {
  const DataExportPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        
        if (isDesktop) {
          return LegalPageLayout(
            title: 'Download Your Data',
            isDarkMode: isDarkMode,
            child: _buildContent(context, isDarkMode),
          );
        }
        
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('Download Your Data'),
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            foregroundColor: isDarkMode ? Colors.white : Colors.black,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildContent(context, isDarkMode),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isDarkMode) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildText(
              'You may request a full export of your data stored by GymGuide.',
              isDarkMode,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Includes:',
              '• Profile\n'
              '• Quiz answers\n'
              '• Workout plans\n'
              '• Meal plans\n'
              '• Progress logs',
              isDarkMode,
            ),
            const SizedBox(height: 24),
            _buildInfoBox(
              'Request export: support@gymguide.co',
              isDarkMode,
            ),
            const SizedBox(height: 16),
            _buildText(
              'Data will be delivered within 30 days.',
              isDarkMode,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showRequestDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Request Data Export',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
  }


  Widget _buildSection(String title, String content, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        _buildText(content, isDarkMode),
      ],
    );
  }

  Widget _buildInfoBox(String text, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.email, color: Color(0xFF0D47A1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF0D47A1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(String text, bool isDarkMode) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }

  void _showRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Data Export'),
        content: const Text(
          'Please email support@gymguide.co to request your data export.\n\n'
          'You will receive your data within 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
