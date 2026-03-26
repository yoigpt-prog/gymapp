import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/legal_page_layout.dart';
import '../../services/supabase_service.dart';

class ContactSupportPage extends StatefulWidget {
  final VoidCallback? toggleTheme;
  const ContactSupportPage({Key? key, this.toggleTheme}) : super(key: key);

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _submitted = false;
  bool _success = false;
  bool _error = false;
  bool _sending = false;

  static const _supportEmail = 'contact@gymguide.co';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName';
    }
    if (fieldName == 'message' && value.trim().length < 10) {
      return 'Message must be at least 10 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<void> _sendMessage() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _success = false;
      _error = false;
    });

    try {
      await SupabaseService().sendContactMessage(
        name: _nameController.text,
        email: _emailController.text,
        subject: _subjectController.text,
        message: _messageController.text,
      );

      setState(() {
        _success = true;
        _error = false;
        _submitted = false;
      });
      _nameController.clear();
      _emailController.clear();
      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      print('ERROR: Form sending failed: $e');
      setState(() => _error = true);
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _openDirectEmail() async {
    final uri = Uri.parse('mailto:$_supportEmail');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://gymguide.co');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LegalPageLayout(
      onToggleTheme: widget.toggleTheme,
      title: 'Contact Support',
      isDarkMode: isDark,
      child: _ContactBody(
        isDark: isDark,
        formKey: _formKey,
        nameController: _nameController,
        emailController: _emailController,
        subjectController: _subjectController,
        messageController: _messageController,
        submitted: _submitted,
        success: _success,
        error: _error,
        sending: _sending,
        validateRequired: _validateRequired,
        validateEmail: _validateEmail,
        onSend: _sendMessage,
        onDirectEmail: _openDirectEmail,
        onWebsite: _openWebsite,
      ),
    );
  }
}

// ─── Body Widget ─────────────────────────────────────────────────────────────

class _ContactBody extends StatelessWidget {
  final bool isDark;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final bool submitted;
  final bool success;
  final bool error;
  final bool sending;
  final String? Function(String?, String) validateRequired;
  final String? Function(String?) validateEmail;
  final VoidCallback onSend;
  final VoidCallback onDirectEmail;
  final VoidCallback onWebsite;

  static const _red = Color(0xFFFF2222);
  static const _supportEmail = 'contact@gymguide.co';

  const _ContactBody({
    required this.isDark,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.subjectController,
    required this.messageController,
    required this.submitted,
    required this.success,
    required this.error,
    required this.sending,
    required this.validateRequired,
    required this.validateEmail,
    required this.onSend,
    required this.onDirectEmail,
    required this.onWebsite,
  });

  @override
  Widget build(BuildContext context) {
    final subText = isDark ? Colors.white60 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF252525) : const Color(0xFFF9F9F9);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final inputFill = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final inputBorder = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Subtitle
        Text(
          'We\'re here to help. Send us a message and we\'ll respond as soon as possible.',
          style: TextStyle(fontSize: 14, height: 1.65, color: subText),
        ),
        const SizedBox(height: 28),

        // ── Quick Contact Card
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _QuickRow(
                icon: Icons.email_outlined,
                label: 'Email Support',
                value: _supportEmail,
                isDark: isDark,
                onTap: onDirectEmail,
                showDivider: true,
              ),
              _QuickRow(
                icon: Icons.language_outlined,
                label: 'Website',
                value: 'gymguide.co',
                isDark: isDark,
                onTap: onWebsite,
                showDivider: true,
              ),
              _QuickRow(
                icon: Icons.schedule_outlined,
                label: 'Response Time',
                value: 'Usually within 24 hours',
                isDark: isDark,
                onTap: null,
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── Form Title
        Text(
          'Send a Message',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),

        // ── Form
        Form(
          key: formKey,
          autovalidateMode: submitted
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            children: [
              _FormField(
                controller: nameController,
                label: 'Name',
                icon: Icons.person_outline,
                isDark: isDark,
                fillColor: inputFill,
                borderColor: inputBorder,
                validator: (v) => validateRequired(v, 'name'),
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                isDark: isDark,
                fillColor: inputFill,
                borderColor: inputBorder,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: subjectController,
                label: 'Subject',
                icon: Icons.subject_outlined,
                isDark: isDark,
                fillColor: inputFill,
                borderColor: inputBorder,
                validator: (v) => validateRequired(v, 'subject'),
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: messageController,
                label: 'Message',
                icon: Icons.message_outlined,
                isDark: isDark,
                fillColor: inputFill,
                borderColor: inputBorder,
                maxLines: 5,
                validator: (v) => validateRequired(v, 'message'),
              ),
              const SizedBox(height: 24),

              // ── Success Banner
              if (success) ...[
                _StatusBanner(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF22CC66),
                  message:
                      'Your message has been sent successfully. We\'ll get back to you soon.',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
              ],

              // ── Error Banner
              if (error) ...[
                _StatusBanner(
                  icon: Icons.error_outline,
                  color: _red,
                  message:
                      'Something went wrong. Please try again or contact us directly via email.',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
              ],

              // ── Send Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: sending ? null : onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _red.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: sending
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Sending...',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Send Message',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Direct Email Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onDirectEmail,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(
                    'Email Support Directly',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Compliance note
              Center(
                child: Text(
                  'No login required to contact support',
                  style: TextStyle(fontSize: 12, color: subText),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Quick Contact Row ────────────────────────────────────────────────────────

class _QuickRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final VoidCallback? onTap;
  final bool showDivider;

  static const _red = Color(0xFFFF2222);

  const _QuickRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final subText = isDark ? Colors.white60 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black87;
    final divColor = isDark ? Colors.white10 : Colors.black12;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _red, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: subText)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.arrow_forward_ios, size: 14, color: subText),
        ],
      ),
    );

    if (onTap != null) {
      row = InkWell(
        onTap: onTap,
        borderRadius: showDivider
            ? BorderRadius.zero
            : const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: row,
      );
    }

    return Column(
      children: [
        row,
        if (showDivider)
          Divider(height: 1, thickness: 1, color: divColor),
      ],
    );
  }
}

// ─── Form Field ───────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;
  final Color fillColor;
  final Color borderColor;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  static const _red = Color(0xFFFF2222);

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    required this.fillColor,
    required this.borderColor,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? Colors.white54 : Colors.black45;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontSize: 14),
        prefixIcon: Icon(icon, color: _red, size: 20),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _red, fontSize: 12),
      ),
    );
  }
}

// ─── Status Banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final bool isDark;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
