void main() {
  String imagePath = 'https://pub-724fd4b4dccd4c3280afaf3b240ff6ef.r2.dev/00251205-Barbell-Bench-Press_Chest-FIX2_GREEN.mp4';
  final uri = Uri.tryParse(imagePath);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    String filename = uri.pathSegments.last.replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '.jpg');
    filename = filename.replaceAllMapped(RegExp(r'^(\d{6})05'), (match) => match.group(1)!);
    filename = filename.replaceAll(RegExp(r'_GREEN', caseSensitive: false), '');
    print('Result: https://www.gymguide.co/exercise/$filename');
  }
}
