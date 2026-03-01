import 'dart:math';
import 'package:flutter/material.dart';

class PolygonBorder extends OutlinedBorder {
  final int sides;
  final double rotate;
  final double borderRadius;

  const PolygonBorder({
    BorderSide side = BorderSide.none,
    this.sides = 16,
    this.rotate = 0.0,
    this.borderRadius = 0.0,
  }) : super(side: side);

  @override
  ShapeBorder scale(double t) {
    return PolygonBorder(
      side: side.scale(t),
      sides: sides,
      rotate: rotate,
      borderRadius: borderRadius * t,
    );
  }

  @override
  OutlinedBorder copyWith({BorderSide? side, int? sides, double? rotate, double? borderRadius}) {
    return PolygonBorder(
      side: side ?? this.side,
      sides: sides ?? this.sides,
      rotate: rotate ?? this.rotate,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final center = rect.center;
    final radius = min(rect.width, rect.height) / 2;
    final anglePerSide = 2 * pi / sides;
    final startAngle = (rotate * pi / 180) - (pi / 2); // Start at top - 90 deg

    final points = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + (i * anglePerSide);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < sides; i++) {
        path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        final path = getOuterPath(rect, textDirection: textDirection);
        final paint = side.toPaint();
        canvas.drawPath(path, paint);
        break;
    }
  }
}
