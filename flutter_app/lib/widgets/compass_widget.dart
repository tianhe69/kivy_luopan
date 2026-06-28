import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/compass_state.dart';
import '../painters/compass24_painter.dart';
import '../painters/compass12_painter.dart';
import '../painters/luopan28_painter.dart';
import '../painters/compass_xuankongda_painter.dart';
import '../painters/zhoutian_painter.dart';
import '../painters/compass_painter.dart';

class CompassWidget extends StatelessWidget {
  const CompassWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CompassState>(
      builder: (context, state, child) {
        if (!state.showCompass) return const SizedBox.shrink();

        return IgnorePointer(
          ignoring: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cx = state.centerX == 0
                  ? constraints.maxWidth / 2
                  : state.centerX;
              final cy = state.centerY == 0
                  ? constraints.maxHeight / 2
                  : state.centerY;

              return Opacity(
                opacity: state.opacity,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _FullCompassPainter(
                    cx: cx,
                    cy: cy,
                    radius: state.compassRadius,
                    rotation: state.rotation,
                    ringWidth: state.ringWidth,
                    textSize: state.textSize,
                    showCenterDot: state.showCenterDot,
                    enabledRings: state.enabledRings,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FullCompassPainter extends CustomPainter {
  final double cx;
  final double cy;
  final double radius;
  final double rotation;
  final double ringWidth;
  final double textSize;
  final bool showCenterDot;
  final Set<CompassType> enabledRings;

  _FullCompassPainter({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.rotation,
    required this.ringWidth,
    required this.textSize,
    required this.showCenterDot,
    required this.enabledRings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radiusOrder = <CompassType, double>{
      CompassType.zhoutian: radius,
      CompassType.compass24: radius - 25,
      CompassType.luopan28: radius - 60, // 28宿只比24山小一点，避免重叠
      CompassType.compass12: radius - 115, // 12地支再往下移
      CompassType.xuankongda: radius - 160,
    };

    for (final entry in radiusOrder.entries) {
      if (!enabledRings.contains(entry.key)) continue;
      final r = entry.value;
      if (r <= 20) continue;

      switch (entry.key) {
        case CompassType.compass24:
          Compass24Painter.paint(canvas, cx, cy, r,
              ringWidth: ringWidth, textSize: textSize, rotation: rotation);
          break;
        case CompassType.compass12:
          Compass12Painter.paint(canvas, cx, cy, r,
              ringWidth: ringWidth, textSize: textSize + 2, rotation: rotation);
          break;
        case CompassType.luopan28:
          Luopan28Painter.paint(canvas, cx, cy, r,
              ringWidth: ringWidth, textSize: textSize - 1, rotation: rotation);
          break;
        case CompassType.xuankongda:
          XuankongdaPainter.paint(canvas, cx, cy, r,
              ringWidth: ringWidth, textSize: textSize - 2, rotation: rotation);
          break;
        case CompassType.zhoutian:
          ZhoutianPainter.paint(canvas, cx, cy, r,
              ringWidth: ringWidth, textSize: textSize - 3, rotation: rotation);
          break;
      }
    }

    if (showCenterDot) {
      final dotPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullCompassPainter oldDelegate) {
    return oldDelegate.cx != cx ||
        oldDelegate.cy != cy ||
        oldDelegate.radius != radius ||
        oldDelegate.rotation != rotation ||
        oldDelegate.ringWidth != ringWidth ||
        oldDelegate.textSize != textSize ||
        oldDelegate.showCenterDot != showCenterDot ||
        oldDelegate.enabledRings.length != enabledRings.length;
  }
}
