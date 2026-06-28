import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'image_utils.dart';

/// 轮廓检测器：使用中心射线法从色调分离后的图像中提取包围主体的封闭轮廓
class ContourDetector {
  /// 提取包围主体的封闭轮廓（中心射线法）
  /// 
  /// 算法流程：
  /// 1. 应用色调分离阈值，得到二值图
  /// 2. 计算图像中心点
  /// 3. 从0度开始，顺时针每隔一定角度（共60条射线）向图像边缘发射射线
  /// 4. 每条射线从图像边缘向中心回溯，找到第一个符合条件的像素点就打点
  /// 5. 打点后该射线停用，顺时针转到下一个角度继续
  /// 6. 所有射线完成后，将打到的点就近连接形成封闭多边形
  /// 
  /// [image] 原始图像
  /// [thresholdLower] 灰度阈值下限
  /// [thresholdUpper] 灰度阈值上限
  /// 返回按角度排序的轮廓点列表（首尾相连形成封闭多段线）
  static List<ui.Offset> detectClosedContour(
    ImageData image,
    int thresholdLower,
    int thresholdUpper,
  ) {
    final w = image.width;
    final h = image.height;
    
    // Step 1: 应用阈值分离，得到二值图
    final binary = _applyThreshold(image, thresholdLower, thresholdUpper);
    
    // Step 2: 计算图像中心
    final centerX = w / 2.0;
    final centerY = h / 2.0;
    
    // Step 3: 从各个角度发射射线（60条射线，每隔6度一条）
    final numRays = 60;
    final angleStep = 360.0 / numRays;
    final contourPoints = <ui.Offset>[];
    
    for (int i = 0; i < numRays; i++) {
      final angle = i * angleStep;
      final point = _castRay(binary, w, h, centerX, centerY, angle, thresholdLower, thresholdUpper);
      
      if (point != null) {
        contourPoints.add(point);
      }
    }
    
    if (contourPoints.isEmpty) return [];
    
    // Step 4: 按角度排序（相对于中心点），形成连续的封闭轮廓
    contourPoints.sort((a, b) {
      final angleA = math.atan2(a.dy - centerY, a.dx - centerX);
      final angleB = math.atan2(b.dy - centerY, b.dx - centerX);
      return angleA.compareTo(angleB);
    });
    
    // Step 5: 简化轮廓（去除冗余点，保留关键拐点）
    return _simplifyContour(contourPoints, tolerance: 2.0);
  }
  
  /// 应用阈值分离，得到二值图
  static Uint8List _applyThreshold(
    ImageData image,
    int lower,
    int upper,
  ) {
    final w = image.width;
    final h = image.height;
    final src = image.pixels;
    final isBlackBg = ImageUtils.isBlackBackground(image);
    
    final binary = Uint8List(w * h);
    for (int i = 0, idx = 0; i < src.length; i += 4, idx++) {
      final r = src[i];
      final g = src[i + 1];
      final b = src[i + 2];
      final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
      
      bool inRange = isBlackBg
          ? (gray >= lower && gray <= 255)
          : (gray >= lower && gray <= upper);
      
      binary[idx] = inRange ? 1 : 0;
    }
    
    return binary;
  }
  
  /// 从指定角度发射射线，从图像边缘向中心回溯，找到第一个符合条件的像素点
  /// 
  /// [binary] 二值图
  /// [w] 图像宽度
  /// [h] 图像高度
  /// [centerX] 中心X坐标
  /// [centerY] 中心Y坐标
  /// [angleDegrees] 射线角度（度数）
  /// 返回找到的第一个有效像素点，如果没有则返回null
  static ui.Offset? _castRay(
    Uint8List binary,
    int w,
    int h,
    double centerX,
    double centerY,
    double angleDegrees,
    int thresholdLower,
    int thresholdUpper,
  ) {
    // 将角度转换为弧度
    final angleRad = angleDegrees * math.pi / 180.0;
    
    // 计算射线方向向量
    final dx = math.cos(angleRad);
    final dy = math.sin(angleRad);
    
    // 计算射线与图像边界的交点（从中心向外延伸到边界）
    final edgePoint = _findEdgeIntersection(centerX, centerY, dx, dy, w, h);
    
    if (edgePoint == null) return null;
    
    // 从边缘点向中心回溯，找到第一个符合条件的像素
    // 步长设为1像素，确保精度
    const stepSize = 1.0;
    final maxSteps = ((edgePoint - ui.Offset(centerX, centerY)).distance / stepSize).ceil();
    
    for (int step = 0; step < maxSteps; step++) {
      final t = step * stepSize;
      final x = edgePoint.dx - dx * t;
      final y = edgePoint.dy - dy * t;
      
      // 检查是否在图像范围内
      if (x < 0 || x >= w || y < 0 || y >= h) continue;
      
      final ix = x.toInt();
      final iy = y.toInt();
      final idx = iy * w + ix;
      
      // 检查是否是有效像素（在阈值范围内）
      if (binary[idx] == 1) {
        // 找到第一个有效像素，返回该点
        return ui.Offset(x, y);
      }
    }
    
    return null;
  }
  
  /// 计算从中心点出发，方向为(dx, dy)的射线与图像边界的交点
  static ui.Offset? _findEdgeIntersection(
    double cx,
    double cy,
    double dx,
    double dy,
    int w,
    int h,
  ) {
    double minT = double.infinity;
    bool found = false;
    
    // 与左边 x=0 的交点
    if (dx < 0) {
      final t = -cx / dx;
      if (t > 0 && t < minT) {
        final y = cy + dy * t;
        if (y >= 0 && y < h) {
          minT = t;
          found = true;
        }
      }
    }
    
    // 与右边 x=w-1 的交点
    if (dx > 0) {
      final t = (w - 1 - cx) / dx;
      if (t > 0 && t < minT) {
        final y = cy + dy * t;
        if (y >= 0 && y < h) {
          minT = t;
          found = true;
        }
      }
    }
    
    // 与上边 y=0 的交点
    if (dy < 0) {
      final t = -cy / dy;
      if (t > 0 && t < minT) {
        final x = cx + dx * t;
        if (x >= 0 && x < w) {
          minT = t;
          found = true;
        }
      }
    }
    
    // 与下边 y=h-1 的交点
    if (dy > 0) {
      final t = (h - 1 - cy) / dy;
      if (t > 0 && t < minT) {
        final x = cx + dx * t;
        if (x >= 0 && x < w) {
          minT = t;
          found = true;
        }
      }
    }
    
    if (!found || minT == double.infinity) return null;
    
    return ui.Offset(cx + dx * minT, cy + dy * minT);
  }
  
  /// 简化轮廓（Douglas-Peucker算法的简化版）
  /// 保留关键拐点和直角转折点
  static List<ui.Offset> _simplifyContour(
    List<ui.Offset> contour, {
    double tolerance = 2.0,
  }) {
    if (contour.length < 3) return contour;
    
    final simplified = <ui.Offset>[contour.first];
    
    for (int i = 1; i < contour.length - 1; i++) {
      final prev = simplified.last;
      final curr = contour[i];
      final next = contour[(i + 1) % contour.length];
      
      // 计算点到直线的距离
      final dist = _pointToLineDistance(curr, prev, next);
      
      // 检查是否是直角转折点（角度变化超过60度）
      final isCorner = _isCornerPoint(prev, curr, next);
      
      if (dist > tolerance || isCorner) {
        simplified.add(curr);
      }
    }
    
    // 确保最后一个点被添加
    if (!simplified.contains(contour.last)) {
      simplified.add(contour.last);
    }
    
    return simplified;
  }
  
  /// 判断是否是直角转折点
  static bool _isCornerPoint(ui.Offset prev, ui.Offset curr, ui.Offset next) {
    // 计算两个向量的夹角
    final v1 = prev - curr;
    final v2 = next - curr;
    
    final dotProduct = v1.dx * v2.dx + v1.dy * v2.dy;
    final len1 = v1.distance;
    final len2 = v2.distance;
    
    if (len1 == 0 || len2 == 0) return false;
    
    final cosAngle = dotProduct / (len1 * len2);
    final clampedCos = cosAngle.clamp(-1.0, 1.0);
    final angle = math.acos(clampedCos) * 180.0 / math.pi;
    
    // 如果角度小于120度（即转折超过60度），认为是拐点
    return angle < 120.0;
  }
  
  /// 计算点到直线的距离
  static double _pointToLineDistance(
    ui.Offset point,
    ui.Offset lineStart,
    ui.Offset lineEnd,
  ) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    
    final lengthSq = dx * dx + dy * dy;
    if (lengthSq == 0) return (point - lineStart).distance;
    
    final t = ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) / lengthSq;
    final clampedT = t.clamp(0.0, 1.0);
    
    final projX = lineStart.dx + clampedT * dx;
    final projY = lineStart.dy + clampedT * dy;
    
    return math.sqrt(
      (point.dx - projX) * (point.dx - projX) +
      (point.dy - projY) * (point.dy - projY),
    );
  }
}
