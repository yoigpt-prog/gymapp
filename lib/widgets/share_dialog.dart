import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class ShareDialog extends StatelessWidget {
  final String shareUrl;
  final String exerciseName;
  final bool isDarkMode;

  const ShareDialog({
    Key? key,
    required this.shareUrl,
    required this.exerciseName,
    required this.isDarkMode,
  }) : super(key: key);

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _shareTo(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  /// WhatsApp: try native whatsapp:// deep-link first, fall back to share sheet.
  Future<void> _shareToWhatsApp(BuildContext context) async {
    final encodedText = Uri.encodeComponent(
        'Check out how to do $exerciseName on GymGuide!\n$shareUrl');
    final nativeUri = Uri.parse('whatsapp://send?text=$encodedText');
    final webUri =
        Uri.parse('https://api.whatsapp.com/send?text=$encodedText');

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        // WhatsApp not installed — open native share sheet instead
        await Share.shareUri(Uri.parse(shareUrl));
      }
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final encodedUrl = Uri.encodeComponent(shareUrl);
    final encodedText =
        Uri.encodeComponent('Check out how to do $exerciseName on GymGuide!');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: bgColor,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Exercise',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            _ShareButton(
              icon: Icons.copy,
              label: 'Copy Link',
              color: Colors.blueGrey,
              onTap: () => _copyLink(context),
              textColor: textColor,
            ),
            const SizedBox(height: 12),
            _ShareButton(
              assetPath: 'assets/whatsappicon.png',
              label: 'Share to WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () async {
                Navigator.of(context).pop();
                await _shareToWhatsApp(context);
              },
              textColor: textColor,
            ),
            const SizedBox(height: 12),
            _ShareButton(
              assetPath: 'assets/fbicon.png',
              label: 'Share to Facebook',
              color: const Color(0xFF1877F2),
              onTap: () {
                _shareTo(
                    'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl');
                Navigator.of(context).pop();
              },
              textColor: textColor,
            ),
            const SizedBox(height: 12),
            _ShareButton(
              assetPath: 'assets/xicon.png',
              label: 'Share to X',
              color: isDarkMode ? Colors.white70 : Colors.black87,
              onTap: () {
                _shareTo(
                    'https://twitter.com/intent/tweet?url=$encodedUrl&text=$encodedText');
                Navigator.of(context).pop();
              },
              textColor: textColor,
            ),
            if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) ...[
              const SizedBox(height: 12),
              _ShareButton(
                icon: Icons.ios_share_rounded,
                label: 'More options…',
                color: const Color(0xFFFF0000),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Share.shareUri(Uri.parse(shareUrl));
                },
                textColor: textColor,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF0000),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Color textColor;

  const _ShareButton({
    this.icon,
    this.assetPath,
    required this.label,
    required this.color,
    required this.onTap,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: textColor.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (assetPath != null)
              Image.asset(
                assetPath!,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              )
            else if (icon != null)
              Icon(icon!, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
