import 'dart:math';
import 'package:flutter/material.dart';

class CompassPainterUtils {
  static Offset angleToOffset(
      double cx, double cy, double radius, double angleDeg) {
    final rad = (angleDeg - 90) * pi / 180;
    return Offset(cx + radius * cos(rad), cy + radius * sin(rad));
  }

  static void drawRing(Canvas canvas, double cx, double cy, double radius,
      Paint paint) {
    canvas.drawCircle(Offset(cx, cy), radius, paint);
  }

  static void drawRadialLine(Canvas canvas, double cx, double cy,
      double innerRadius, double outerRadius, double angleDeg, Paint paint) {
    final start = angleToOffset(cx, cy, innerRadius, angleDeg);
    final end = angleToOffset(cx, cy, outerRadius, angleDeg);
    canvas.drawLine(start, end, paint);
  }

  static void drawText(Canvas canvas, String text, Offset position,
      TextStyle style, TextAlign align) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    textPainter.layout();
    final dx = align == TextAlign.center
        ? -textPainter.width / 2
        : (align == TextAlign.right ? -textPainter.width : 0.0);
    textPainter.paint(canvas, position + Offset(dx, -textPainter.height / 2));
  }

  static void drawRadialText(Canvas canvas, String text, double cx, double cy,
      double radius, double angleDeg, TextStyle style,
      {bool rotate = true}) {
    final position = angleToOffset(cx, cy, radius, angleDeg);

    if (rotate) {
      canvas.save();
      canvas.translate(position.dx, position.dy);
      double rotateAngle = angleDeg * pi / 180;
      if (angleDeg > 90 && angleDeg < 270) {
        rotateAngle += pi;
      }
      canvas.rotate(rotateAngle);
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    } else {
      drawText(canvas, text, position, style, TextAlign.center);
    }
  }
}
