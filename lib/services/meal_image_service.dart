import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages device-local custom meal images.
///
/// Images are copied to the app's persistent documents directory and their
/// paths are stored in SharedPreferences keyed by mealId.
/// Nothing is ever uploaded to a server — all data is device-specific.
class MealImageService {
  static const String _keyPrefix = 'meal_custom_image_';

  static String _key(String mealId) => '$_keyPrefix$mealId';

  /// Returns the local file path for a custom image, or null if none exists.
  static Future<String?> getCustomImagePath(String mealId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(mealId));
    if (path == null) return null;
    // Verify the file still exists (e.g. not deleted after OS cache clear)
    if (!File(path).existsSync()) {
      await prefs.remove(_key(mealId));
      return null;
    }
    return path;
  }

  /// Copies the picked image file to the app's permanent documents directory
  /// and saves the resulting path to SharedPreferences.
  /// Returns the permanent file path.
  static Future<String> saveCustomImage(String mealId, String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'meal_img_${mealId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = '${dir.path}/$fileName';

    // Copy source file to permanent location
    await File(sourcePath).copy(destPath);

    // Persist path in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    // Remove any old file for this meal before storing the new path
    final oldPath = prefs.getString(_key(mealId));
    if (oldPath != null && oldPath != destPath) {
      try {
        final oldFile = File(oldPath);
        if (oldFile.existsSync()) await oldFile.delete();
      } catch (_) {}
    }
    await prefs.setString(_key(mealId), destPath);

    return destPath;
  }

  /// Removes the custom image for a meal (both the file and the preference key).
  static Future<void> removeCustomImage(String mealId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(mealId));
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } catch (_) {}
      await prefs.remove(_key(mealId));
    }
  }
}
