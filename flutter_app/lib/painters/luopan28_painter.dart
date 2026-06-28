import 'package:flutter/material.dart';
import 'compass_painter.dart';

class Luopan28Painter {
  static const List<String> constellations28 = [
    '角', '亢', '氐', '房', '心', '尾', '箕',
    '斗', '牛', '女', '虚', '危', '室', '壁',
    '奎', '娄', '胃', '昴', '毕', '觜', '参',
    '井', '鬼', '柳', '星', '张', '翼', '轸',
  ];

  // 二十八宿传统度数（按《协纪辨方书》）
  static const List<double> degrees28 = [
    12, 9, 15, 5, 6, 18, 10,   // 东方青龙
    26, 8, 12, 10, 17, 16, 9,  // 北方玄武
    16, 12, 14, 11, 16, 2, 10, // 西方白虎
    33, 4, 15, 7, 18, 18, 17,  // 南方朱雀
  ]; // 总计 365.25 度

  static const List<Color> colors28 = [
    Color(0xFF006400), Color(0xFF006400), Color(0xFF006400),
    Color(0xFF006400), Color(0xFF006400), Color(0xFF006400),
    Color(0xFF006400),
    Color(0xFF4B0082), Color(0xFF4B0082), Color(0xFF4B0082),
    Color(0xFF4B0082), Color(0xFF4B0082), Color(0xFF4B0082),
    Color(0xFF4B0082),
    Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF),
    Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
    Color(0xFFFF0000), Color(0xFFFF0000), Color(0xFFFF0000),
    Color(0xFFFF0000), Color(0xFFFF0000), Color(0xFFFF0000),
    Color(0xFFFF0000),
  ];

  static void paint(Canvas canvas, double cx, double cy, double outerRadius,
      {double ringWidth = 2, double textSize = 13, double rotation = 0}) {
    // 将28宿环放在24山的内侧，避免文字重叠
    // 24山半径通常是 outerRadius
    // 28宿半径 = outerRadius - 35（留出足够空间让文字不冲突）
    final innerRadius = outerRadius - 35;
    final adjustedOuterRadius = outerRadius - 10;

    final ringPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    // 绘制内外圆环
    CompassPainterUtils.drawRing(canvas, cx, cy, adjustedOuterRadius, ringPaint);
    CompassPainterUtils.drawRing(canvas, cx, cy, innerRadius, ringPaint);

    // 计算每宿的起始角度（累计）
    final startAngles = <double>[];
    double currentAngle = 0;
    for (int i = 0; i < 28; i++) {
      startAngles.add(currentAngle);
      currentAngle += degrees28[i];
    }

    // 找到"虚"和"危"的交界位置
    // "虚"在索引10，"危"在索引11
    // 虚危交界 = startAngles[11]
    final xuWeiBoundary = startAngles[11]; // 虚危交界的累积角度

    // 偏移角度：让虚危交界对齐0度（正北）
    final offsetAngle = -xuWeiBoundary + rotation;

    // 动态调整字体大小：根据罗盘半径自适应缩放
    // 基准：半径200时字体9px，按比例缩放，范围7-12
    final adaptiveTextSize = (textSize * outerRadius / 200).clamp(7.0, 12.0);

    // 绘制每宿
    for (int i = 0; i < 28; i++) {
      final startAngle = startAngles[i] + offsetAngle;
      final endAngle = startAngle + degrees28[i];
      final midAngle = (startAngle + endAngle) / 2;

      // 绘制边界线（每宿的分界线）- 加粗显示以便清晰可见
      final linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = ringWidth + 0.5; // 稍微加粗分界线
      CompassPainterUtils.drawRadialLine(
          canvas, cx, cy, innerRadius, adjustedOuterRadius, startAngle, linePaint);

      // 绘制宿名文字 - 添加半透明背景色块提高可读性
      final textRadius = (innerRadius + adjustedOuterRadius) / 2;
      final bgColor = colors28[i];
      
      // 根据背景色决定文字颜色（确保对比度）
      final textColor = 
          bgColor == Colors.white || bgColor == const Color(0xFFFFFFFF)
              ? Colors.black  // 白色背景用纯黑文字，最大对比度
              : Colors.white; // 深色背景用纯白文字

      // 使用较小的字体以获得更好的清晰度
      final fontSize = adaptiveTextSize * 1.0; // 不再放大
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: constellations28[i],
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600, // 稍微加粗提高可读性
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      final position =
          CompassPainterUtils.angleToOffset(cx, cy, textRadius, midAngle);

      canvas.save();
      canvas.translate(position.dx, position.dy);
      double rotateAngle = midAngle * 3.141592653589793 / 180;
      if (midAngle > 90 && midAngle < 270) {
        rotateAngle += 3.141592653589793;
      }
      canvas.rotate(rotateAngle);

      // 添加半透明背景色块（适度透明度，确保文字清晰但不夸张）
      final bgPaint = Paint()..color = bgColor.withOpacity(0.85); // 85%透明度，平衡可读性和美观
      final bgRect = Rect.fromCenter(
        center: Offset.zero,
        width: textPainter.width + 5, // 适度padding
        height: textPainter.height + 4,
      );
      final bgPath = Path()
        ..addRRect(RRect.fromRectAndRadius(
            bgRect, const Radius.circular(2))); // 小圆角
      canvas.drawPath(bgPath, bgPaint);

      // 绘制文字
      textPainter.paint(
          canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // 最后再画一次0度位置的加粗线（虚危交界）
    final zeroLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = ringWidth + 1
      ..isAntiAlias = true;
    CompassPainterUtils.drawRadialLine(
        canvas, cx, cy, innerRadius, outerRadius, 0 + rotation, zeroLinePaint);
  }
}
