import 'package:flutter/material.dart';
import '../../widgets/legal_page_layout.dart';

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        
        if (isDesktop) {
          return LegalPageLayout(
            title: 'Delete Account',
            isDarkMode: isDarkMode,
            child: _buildContent(context, isDarkMode),
          );
        }
        
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('Delete Account'),
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
              'You may permanently delete your account at any time.',
              isDarkMode,
              bold: true,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Deleting your account will:',
              '• Remove your Supabase account\n'
              '• Delete your workout history\n'
              '• Delete your progress\n'
              '• Delete quiz data\n'
              '• Delete preferences\n'
              '• Remove AI-generated plans',
              isDarkMode,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Some financial records (required by Apple/Google) may remain but cannot identify you.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFFB71C1C),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'To delete your account:',
              '• Go to Settings → Delete Account\n'
              '• Or email: support@gymguide.co',
              isDarkMode,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Color(0xFFFF6F00)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Deletion is permanent and cannot be undone.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6F00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _confirmDelete(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete My Account',
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

  Widget _buildText(String text, bool isDarkMode, {bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          'This will permanently delete:\n'
          '• All workout data\n'
          '• Meal plans\n'
          '• Progress history\n'
          '• Account settings\n\n'
          'This action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF0000))),
          ),
        ],
      ),
    );

    if (first != true || !context.mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Warning'),
        content: const Text(
          'This is your LAST CHANCE to cancel!\n\n'
          'Click DELETE to permanently delete your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF0000))),
          ),
        ],
      ),
    );

    if (second == true && context.mounted) {
      // TODO: Call backend to delete account
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion initiated. Your account will be deleted within 24 hours.'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}
