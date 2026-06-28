import 'package:flutter/material.dart';
import 'compass_painter.dart';

class Compass12Painter {
  static const List<String> zodiacs12 = [
    '子', '丑', '寅', '卯', '辰', '巳',
    '午', '未', '申', '酉', '戌', '亥',
  ];

  static void paint(Canvas canvas, double cx, double cy, double outerRadius,
      {double ringWidth = 2, double textSize = 16, double rotation = 0}) {
    final innerRadius = outerRadius - 35;

    final ringPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    CompassPainterUtils.drawRing(canvas, cx, cy, outerRadius, ringPaint);
    CompassPainterUtils.drawRing(canvas, cx, cy, innerRadius, ringPaint);

    const step = 360 / 12; // 每支30度
    
    // 偏移角度：让"子"(索引0)的中心对齐0度
    // "子"从0°开始，占0°~30°，中心是15°
    // 要让"子中"对齐0°，需要"子"的范围是[-15°, 15°]
    // 所以起始角度应该是 -15°
    final offsetAngle = -15.0 + rotation;
    
    // 动态调整字体大小：根据罗盘半径自适应缩放
    // 基准：半径200时字体为textSize，按比例缩放，范围7-14
    final adaptiveTextSize = (textSize * outerRadius / 200).clamp(7.0, 14.0);
    
    for (int i = 0; i < 12; i++) {
      final angle = i * step + offsetAngle;
      final linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = ringWidth;
      CompassPainterUtils.drawRadialLine(
          canvas, cx, cy, innerRadius, outerRadius, angle, linePaint);

      final textAngle = angle + step / 2;
      final textRadius = (innerRadius + outerRadius) / 2;
      final textStyle = TextStyle(
        color: Colors.black,
        fontSize: adaptiveTextSize,
        fontWeight: FontWeight.bold,
      );
      CompassPainterUtils.drawRadialText(
          canvas, zodiacs12[i], cx, cy, textRadius, textAngle, textStyle);
    }
  }
}
