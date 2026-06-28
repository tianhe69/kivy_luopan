import 'package:flutter/material.dart';
import 'compass_painter.dart';

class ZhoutianPainter {
  static void paint(Canvas canvas, double cx, double cy, double outerRadius,
      {double ringWidth = 2, double textSize = 10, double rotation = 0}) {
    final innerRadius = outerRadius - 18;

    final ringPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    CompassPainterUtils.drawRing(canvas, cx, cy, outerRadius, ringPaint);
    CompassPainterUtils.drawRing(canvas, cx, cy, innerRadius, ringPaint);

    for (int i = 0; i < 360; i++) {
      final angle = i + rotation;
      final linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = (i % 10 == 0) ? 1.5 : 0.8;
      final tickLength = (i % 10 == 0) ? 8.0 : 4.0;
      CompassPainterUtils.drawRadialLine(
        canvas,
        cx,
        cy,
        outerRadius - tickLength,
        outerRadius,
        angle.toDouble(),
        linePaint,
      );

      if (i % 10 == 0) {
        final textAngle = i + rotation;
        final textRadius = outerRadius - 13;
        final textStyle = TextStyle(
          color: Colors.black,
          fontSize: textSize,
          fontWeight: FontWeight.bold,
        );
        CompassPainterUtils.drawRadialText(
            canvas, '$i', cx, cy, textRadius, textAngle.toDouble(), textStyle);
      }
    }
  }
}
