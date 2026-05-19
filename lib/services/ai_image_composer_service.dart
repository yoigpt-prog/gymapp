import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class AiImageComposerService {
  /// Generates the OpenGraph thumbnail (1200x630)
  static Future<Uint8List> createOgThumbnail(
      Uint8List beforeBytes, Uint8List afterBytes, String goal) async {
    return _composite(beforeBytes, afterBytes, goal, 1200, 630, isHorizontal: true);
  }

  /// Generates the 9:16 Story image (1080x1920)
  static Future<Uint8List> createStoryImage(
      Uint8List beforeBytes, Uint8List afterBytes, String goal) async {
    return _composite(beforeBytes, afterBytes, goal, 1080, 1920, isHorizontal: false);
  }

  static Future<Uint8List> _composite(
    Uint8List beforeBytes,
    Uint8List afterBytes,
    String goal,
    int width,
    int height, {
    required bool isHorizontal,
  }) async {
    final ui.Image beforeImage = await decodeImageFromList(beforeBytes);
    final ui.Image afterImage = await decodeImageFromList(afterBytes);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
        recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // Draw background
    final bgPaint = ui.Paint()..color = const ui.Color(0xFF0F0F0F);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    Rect beforeRect;
    Rect afterRect;
    if (isHorizontal) {
      beforeRect = Rect.fromLTWH(0, 0, width / 2, height.toDouble());
      afterRect = Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble());
    } else {
      beforeRect = Rect.fromLTWH(0, 0, width.toDouble(), height / 2);
      afterRect = Rect.fromLTWH(0, height / 2, width.toDouble(), height / 2);
    }

    _drawImageCover(canvas, beforeImage, beforeRect);
    _drawImageCover(canvas, afterImage, afterRect);

    // Draw separator line
    final linePaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..strokeWidth = 4.0;
    if (isHorizontal) {
      canvas.drawLine(Offset(width / 2, 0), Offset(width / 2, height.toDouble()), linePaint);
    } else {
      canvas.drawLine(Offset(0, height / 2), Offset(width.toDouble(), height / 2), linePaint);
    }

    // Draw Goal Badge
    final badgePaint = ui.Paint()
      ..color = const ui.Color(0xFFFF0000)
      ..style = ui.PaintingStyle.fill;
    
    // Draw Branding Text (GymGuide)
    const logoStyle = TextStyle(
      color: ui.Color(0xFFFFFFFF),
      fontSize: 48,
      fontWeight: FontWeight.w900,
      fontFamily: 'Roboto', // Fallback
    );
    final logoSpan = TextSpan(text: 'GymGuide AI', style: logoStyle);
    final logoPainter = TextPainter(
      text: logoSpan,
      textDirection: TextDirection.ltr,
    );
    logoPainter.layout();

    // Draw Goal text
    final goalStyle = TextStyle(
      color: const ui.Color(0xFFFFFFFF),
      fontSize: 24,
      fontWeight: FontWeight.w700,
      fontFamily: 'Roboto',
    );
    final goalSpan = TextSpan(text: 'Goal: $goal', style: goalStyle);
    final goalPainter = TextPainter(
      text: goalSpan,
      textDirection: TextDirection.ltr,
    );
    goalPainter.layout();

    // Position branding and goal at the bottom left (with some padding)
    final double padding = isHorizontal ? 40.0 : 60.0;
    final double bottomY = height - padding - logoPainter.height;
    
    // Draw gradient overlay at bottom so text is readable
    final gradientRect = Rect.fromLTWH(0, height * 0.6, width.toDouble(), height * 0.4);
    final gradientPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, height * 0.6),
        Offset(0, height.toDouble()),
        [const ui.Color(0x00000000), const ui.Color(0xCC000000)],
      );
    canvas.drawRect(gradientRect, gradientPaint);

    logoPainter.paint(canvas, Offset(padding, bottomY));
    
    final badgeRect = RRect.fromLTRBR(
      padding,
      bottomY - goalPainter.height - 20,
      padding + goalPainter.width + 32,
      bottomY - 4,
      const Radius.circular(20),
    );
    canvas.drawRRect(badgeRect, badgePaint);
    goalPainter.paint(canvas, Offset(padding + 16, bottomY - goalPainter.height - 12));

    // Draw Disclaimer
    const discStyle = TextStyle(
      color: ui.Color(0x99FFFFFF), // white60
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );
    final discSpan = TextSpan(text: 'AI preview. Results vary.', style: discStyle);
    final discPainter = TextPainter(
      text: discSpan,
      textDirection: TextDirection.ltr,
    );
    discPainter.layout();
    discPainter.paint(canvas, Offset(width - padding - discPainter.width, height - padding - discPainter.height));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawImageCover(ui.Canvas canvas, ui.Image image, Rect dstRect) {
    final double imgAspect = image.width / image.height;
    final double dstAspect = dstRect.width / dstRect.height;

    Rect srcRect;
    if (imgAspect > dstAspect) {
      // Image is wider than dst -> crop horizontally
      final cropWidth = image.height * dstAspect;
      final cropX = (image.width - cropWidth) / 2;
      srcRect = Rect.fromLTWH(cropX, 0, cropWidth, image.height.toDouble());
    } else {
      // Image is taller than dst -> crop vertically
      final cropHeight = image.width / dstAspect;
      final cropY = (image.height - cropHeight) / 2;
      srcRect = Rect.fromLTWH(0, cropY, image.width.toDouble(), cropHeight);
    }

    canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());
  }
}
