import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    if (content.contains("final url = Uri.parse('https://apps.apple.com/us/app/gym-guide-app/id6760553535');")) {
      content = content.replaceAll(
          "final url = Uri.parse('https://apps.apple.com/us/app/gym-guide-app/id6760553535');",
          "final url = Uri.parse(AnalyticsService().appendVisitorId('https://apps.apple.com/us/app/gym-guide-app/id6760553535'));");
      changed = true;
    }

    if (content.contains("final url = Uri.parse('https://play.google.com/store/apps/details?id=com.gymguide.app');")) {
      content = content.replaceAll(
          "final url = Uri.parse('https://play.google.com/store/apps/details?id=com.gymguide.app');",
          "final url = Uri.parse(AnalyticsService().appendVisitorId('https://play.google.com/store/apps/details?id=com.gymguide.app'));");
      changed = true;
    }

    // download_page.dart
    if (file.path.endsWith('download_page.dart') && content.contains("final uri = Uri.parse(urlString);")) {
      content = content.replaceAll("final uri = Uri.parse(urlString);", "final uri = Uri.parse(AnalyticsService().appendVisitorId(urlString));");
      changed = true;
    }

    // red_header.dart
    if (file.path.endsWith('red_header.dart') && content.contains("final uri = Uri.parse(url);")) {
      content = content.replaceAll("final uri = Uri.parse(url);", "final uri = Uri.parse(AnalyticsService().appendVisitorId(url));");
      changed = true;
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
