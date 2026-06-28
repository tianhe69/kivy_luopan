import 'package:flutter/material.dart';
import 'compass_painter.dart';

class Compass24Painter {
  static const List<String> mountains24 = [
    '壬', '子', '癸',
    '丑', '艮', '寅',
    '甲', '卯', '乙',
    '辰', '巽', '巳',
    '丙', '午', '丁',
    '未', '坤', '申',
    '庚', '酉', '辛',
    '戌', '乾', '亥',
  ];

  static const List<Color> colors24 = [
    Color(0xFFFF0000), Color(0xFF000000), Color(0xFFFF0000),
    Color(0xFF000000), Color(0xFFFF0000), Color(0xFF000000),
    Color(0xFFFF0000), Color(0xFF000000), Color(0xFFFF0000),
    Color(0xFF000000), Color(0xFFFF0000), Color(0xFF000000),
    Color(0xFFFF0000), Color(0xFF000000), Color(0xFFFF0000),
    Color(0xFF000000), Color(0xFFFF0000), Color(0xFF000000),
    Color(0xFFFF0000), Color(0xFF000000), Color(0xFFFF0000),
    Color(0xFF000000), Color(0xFFFF0000), Color(0xFF000000),
  ];

  static void paint(Canvas canvas, double cx, double cy, double outerRadius,
      {double ringWidth = 2, double textSize = 14, double rotation = 0}) {
    final innerRadius = outerRadius - 30;

    final ringPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    CompassPainterUtils.drawRing(canvas, cx, cy, outerRadius, ringPaint);
    CompassPainterUtils.drawRing(canvas, cx, cy, innerRadius, ringPaint);

    const step = 360 / 24; // 每山15度
    
    // 偏移角度：让"子"(索引1)的中心对齐0度
    // 当前数组从"壬"(索引0)开始，"壬"占0°~15°，"子"占15°~30°
    // "子"的中心是 15° + 7.5° = 22.5°
    // 要让"子中"对齐0°，需要偏移 -22.5° + 7.5° = -15°
    // 但实际上，"子"应该在正北，即数组应该重新排列
    // 
    // 正确做法：让"子"的第1个边界线在 -7.5°，这样"子"的范围是[-7.5°, 7.5°]，中心0°
    // 由于"子"在索引1，所以索引0的"壬"应该从 -7.5° - 15° = -22.5° 开始
    // offsetAngle = -22.5°
    final offsetAngle = -22.5 + rotation;
    
    for (int i = 0; i < 24; i++) {
      final angle = i * step + offsetAngle;
      final linePaint = Paint()
        ..color = colors24[i]
        ..strokeWidth = ringWidth;
      CompassPainterUtils.drawRadialLine(
          canvas, cx, cy, innerRadius, outerRadius, angle, linePaint);

      final textAngle = angle + step / 2;
      final textRadius = (innerRadius + outerRadius) / 2;
      final textStyle = TextStyle(
        color: colors24[i],
        fontSize: textSize,
        fontWeight: FontWeight.bold,
      );
      CompassPainterUtils.drawRadialText(
          canvas, mountains24[i], cx, cy, textRadius, textAngle, textStyle);
    }
  }
}
