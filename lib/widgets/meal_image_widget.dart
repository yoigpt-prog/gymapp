import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/meal_image_service.dart';

/// A self-contained widget that renders a meal image with a floating camera
/// button. Custom images are stored locally on-device only (never synced).
///
/// Priority when loading:
///   1. User's custom local image (from SharedPreferences + filesystem)
///   2. Default network image supplied by [defaultImageUrl]
///   3. Placeholder icon
class MealImageWidget extends StatefulWidget {
  final String mealId;
  final String? defaultImageUrl;
  final bool isDarkMode;
  /// Optional: overlaid widgets (e.g. "Eaten" badge). Passed through as-is.
  final List<Widget> overlays;

  const MealImageWidget({
    super.key,
    required this.mealId,
    required this.isDarkMode,
    this.defaultImageUrl,
    this.overlays = const [],
  });

  @override
  State<MealImageWidget> createState() => _MealImageWidgetState();
}

class _MealImageWidgetState extends State<MealImageWidget> {
  String? _customImagePath;
  bool _loadingCustom = true;

  @override
  void initState() {
    super.initState();
    _loadCustomImage();
  }

  @override
  void didUpdateWidget(MealImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mealId != widget.mealId) {
      _loadCustomImage();
    }
  }

  Future<void> _loadCustomImage() async {
    if (kIsWeb) {
      if (mounted) setState(() => _loadingCustom = false);
      return;
    }
    final path = await MealImageService.getCustomImagePath(widget.mealId);
    if (mounted) {
      setState(() {
        _customImagePath = path;
        _loadingCustom = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile == null) return;

      final permanentPath = await MealImageService.saveCustomImage(
        widget.mealId,
        pickedFile.path,
      );

      if (mounted) setState(() => _customImagePath = permanentPath);
    } catch (e) {
      debugPrint('[MealImage] Error picking image: $e');
    }
  }

  void _showImageOptions() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    final Widget sheetContent = _ImageOptionsSheet(
      onCamera: () => _pickImage(ImageSource.camera),
      onGallery: () => _pickImage(ImageSource.gallery),
      onRemove: _customImagePath != null
          ? () async {
              await MealImageService.removeCustomImage(widget.mealId);
              if (mounted) setState(() => _customImagePath = null);
            }
          : null,
      isDarkMode: widget.isDarkMode,
      isDialog: isTablet,
    );

    if (isTablet) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: sheetContent,
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: false,
        builder: (_) => sheetContent,
      );
    }
  }

  Widget _buildImageContent() {
    // 1. Custom local image
    if (!_loadingCustom && _customImagePath != null) {
      final file = File(_customImagePath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    // 2. Default network image
    final url = widget.defaultImageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
        loadingBuilder: (context, child, chunk) {
          if (chunk == null) return child;
          return _buildPlaceholder(loading: true);
        },
      );
    }

    // 3. Placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder({bool loading = false}) {
    return Container(
      color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200],
      child: Center(
        child: loading
            ? const CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFFF4444))
            : Icon(Icons.restaurant,
                color: Colors.grey[400], size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Main image ──────────────────────────────────────────────────────
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImageContent(),
          ),
        ),

        // ── Pass-through overlays (e.g. Eaten badge) ─────────────────────
        ...widget.overlays,

        // ── Camera / edit button (mobile only) ───────────────────────────
        if (!kIsWeb)
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: _showImageOptions,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.60),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Bottom-sheet options ─────────────────────────────────────────────────────

class _ImageOptionsSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;
  final bool isDarkMode;
  final bool isDialog;

  const _ImageOptionsSheet({
    required this.onCamera,
    required this.onGallery,
    this.onRemove,
    required this.isDarkMode,
    this.isDialog = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.grey[600]!;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: isDialog 
            ? BorderRadius.circular(24) 
            : const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar (only on bottom sheet)
              if (!isDialog)
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              SizedBox(height: isDialog ? 12 : 20),
              Text(
                'Meal Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Photos are stored on your device only',
                style: TextStyle(fontSize: 13, color: subColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _OptionTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo',
                color: const Color(0xFFFF4444),
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.pop(context);
                  onCamera();
                },
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                color: const Color(0xFF4488FF),
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.pop(context);
                  onGallery();
                },
              ),
              if (onRemove != null) ...[
                const SizedBox(height: 10),
                _OptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Custom Photo',
                  color: Colors.grey,
                  isDarkMode: isDarkMode,
                  onTap: () {
                    Navigator.pop(context);
                    onRemove!();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
