import 'package:flutter/material.dart';
import 'compass_painter.dart';

class XuankongdaPainter {
  static const List<String> hexagrams8 = [
    '坎', '艮', '震', '巽',
    '离', '坤', '兑', '乾',
  ];

  static const List<String> hexagrams24 = [
    '坎为水', '山水蒙', '水雷屯',
    '山泽损', '艮为山', '山火贲',
    '震为雷', '雷地豫', '雷水解',
    '巽为风', '风天小畜', '风火家人',
    '离为火', '火水未济', '火风鼎',
    '地水师', '坤为地', '地天泰',
    '兑为泽', '泽水困', '泽山咸',
    '天泽履', '乾为天', '天雷大壮',
  ];

  static void paint(Canvas canvas, double cx, double cy, double outerRadius,
      {double ringWidth = 2, double textSize = 11, double rotation = 0}) {
    final midRadius = outerRadius - 30;
    final innerRadius = outerRadius - 60;

    final ringPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    CompassPainterUtils.drawRing(canvas, cx, cy, outerRadius, ringPaint);
    CompassPainterUtils.drawRing(canvas, cx, cy, midRadius, ringPaint);
    CompassPainterUtils.drawRing(canvas, cx, cy, innerRadius, ringPaint);

    const step24 = 360 / 24;
    for (int i = 0; i < 24; i++) {
      final angle = i * step24 + rotation;
      final linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = ringWidth * 0.6;
      CompassPainterUtils.drawRadialLine(
          canvas, cx, cy, innerRadius, midRadius, angle, linePaint);
    }

    const step8 = 360 / 8;
    for (int i = 0; i < 8; i++) {
      final angle = i * step8 + rotation;
      final linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = ringWidth;
      CompassPainterUtils.drawRadialLine(
          canvas, cx, cy, innerRadius, outerRadius, angle, linePaint);

      final textAngle = angle + step8 / 2;
      final outerTextRadius = (midRadius + outerRadius) / 2;
      final outerStyle = TextStyle(
        color: Colors.black,
        fontSize: textSize + 1,
        fontWeight: FontWeight.bold,
      );
      CompassPainterUtils.drawRadialText(
          canvas, hexagrams8[i], cx, cy, outerTextRadius, textAngle, outerStyle);

      final innerTextRadius = (innerRadius + midRadius) / 2;
      final innerStyle = TextStyle(
        color: Colors.black,
        fontSize: textSize - 2,
      );
      final idx1 = i * 3;
      final innerText =
          '${hexagrams24[idx1]}\n${hexagrams24[idx1 + 1]}\n${hexagrams24[idx1 + 2]}';
      _drawMultiLineRadialText(
          canvas, innerText, cx, cy, innerTextRadius, textAngle, innerStyle);
    }
  }

  static void _drawMultiLineRadialText(Canvas canvas, String text, double cx,
      double cy, double radius, double angleDeg, TextStyle style) {
    final position = CompassPainterUtils.angleToOffset(cx, cy, radius, angleDeg);
    final lines = text.split('\n');

    canvas.save();
    canvas.translate(position.dx, position.dy);
    double rotateAngle = angleDeg * 3.141592653589793 / 180;
    if (angleDeg > 90 && angleDeg < 270) {
      rotateAngle += 3.141592653589793;
    }
    canvas.rotate(rotateAngle);

    double totalHeight = 0;
    final painters = <TextPainter>[];
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(text: line, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.layout();
      painters.add(tp);
      totalHeight += tp.height;
    }

    double currentY = -totalHeight / 2;
    for (final tp in painters) {
      tp.paint(canvas, Offset(-tp.width / 2, currentY));
      currentY += tp.height;
    }
    canvas.restore();
  }
}
