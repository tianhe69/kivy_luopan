import 'dart:ui';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'dart:collection';

class ImageData {
  final int width;
  final int height;
  final Uint8List pixels;
  ImageData(this.width, this.height, this.pixels);
}

class ImageUtils {
  static bool isBlackBackground(ImageData image) {
    final totalPixels = image.width * image.height;
    int blackPixels = 0;
    int totalBrightness = 0;
    final data = image.pixels;

    for (int i = 0; i < data.length; i += 4) {
      final r = data[i];
      final g = data[i + 1];
      final b = data[i + 2];
      final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
      totalBrightness += gray;
      if (gray < 50) blackPixels++;
    }

    final meanBrightness = totalBrightness / totalPixels;
    final blackRatio = blackPixels / totalPixels;
    return meanBrightness < 80 && blackRatio > 0.6;
  }

  // 改进的面域提取算法：
  // 1. 灰度阈值 → 二值图
  // 2. 形态学闭运算：先膨胀后腐蚀，填充内部空洞
  // 3. 连通分量标记 + 面积滤波：去除小噪点
  // 4. 保留最大连通区域（主面域）
  // 5. 完全填充主区域内的所有空洞
  static ImageData applyThresholdSeparation(
      ImageData image, int lower, int upper, {int minAreaRatio = 10}) {
    final w = image.width;
    final h = image.height;
    final src = image.pixels;
    final isBlackBg = isBlackBackground(image);

    // Step 1: 灰度阈值 → 二值图
    final binMask = Uint8List(w * h);
    for (int i = 0, idx = 0; i < src.length; i += 4, idx++) {
      final r = src[i];
      final g = src[i + 1];
      final b = src[i + 2];
      final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
      bool inRange = isBlackBg
          ? (gray >= lower && gray <= 255)
          : (gray >= lower && gray <= upper);
      binMask[idx] = inRange ? 1 : 0;
    }
    // 纯白/纯黑像素特殊处理
    for (int i = 0, idx = 0; i < src.length; i += 4, idx++) {
      final r = src[i];
      final g = src[i + 1];
      final b = src[i + 2];
      final isPureWhite = r > 200 && g > 200 && b > 200;
      final isPureBlack = r < 50 && g < 50 && b < 50;
      if (isBlackBg && isPureWhite) binMask[idx] = 1;
      if (!isBlackBg && isPureBlack) binMask[idx] = 1;
    }

    // Step 2: 形态学闭运算（先膨胀后腐蚀）填充小空洞
    // 根据图像大小自适应调整核大小
    final kernelSize = (w + h) ~/ 400; // 自适应核大小
    final dilateIter = kernelSize.clamp(3, 8);
    
    var closed = _dilateBin(binMask, w, h, dilateIter);
    closed = _erodeBin(closed, w, h, dilateIter);

    // Step 3: 连通分量标记
    final labels = _connectedComponentLabeling(closed, w, h);
    
    if (labels.isEmpty) {
      // 没有找到任何区域，返回原始二值图（避免全黑）
      final result = Uint8List(w * h * 4);
      for (int i = 0, j = 0; i < binMask.length; i++, j += 4) {
        if (binMask[i] == 1) {
          result[j] = 255;
          result[j + 1] = 255;
          result[j + 2] = 255;
          result[j + 3] = 255;
        }
      }
      return ImageData(w, h, result);
    }
    
    final componentAreas = <int, int>{};
    
    // 统计每个连通分量的面积
    for (final label in labels.values) {
      componentAreas[label] = (componentAreas[label] ?? 0) + 1;
    }

    // Step 4: 找到最大的连通分量（主面域）
    int maxLabel = 0;
    int maxArea = 0;
    componentAreas.forEach((label, area) {
      if (area > maxArea) {
        maxArea = area;
        maxLabel = label;
      }
    });

    // 如果最大区域面积为0，说明没有有效区域
    if (maxArea == 0) {
      final result = Uint8List(w * h * 4);
      for (int i = 0, j = 0; i < binMask.length; i++, j += 4) {
        if (binMask[i] == 1) {
          result[j] = 255;
          result[j + 1] = 255;
          result[j + 2] = 255;
          result[j + 3] = 255;
        }
      }
      return ImageData(w, h, result);
    }

    // Step 5: 只保留主面域，过滤掉小噪点
    final minArea = (w * h / minAreaRatio).round(); // 最小面积阈值
    final filteredMask = Uint8List(w * h);
    for (int i = 0; i < w * h; i++) {
      final label = labels[i] ?? 0;
      if (label == maxLabel || (componentAreas[label] ?? 0) >= minArea) {
        filteredMask[i] = 1;
      }
    }

    // Step 6: 完全填充主面域内的所有空洞
    // 使用 flood fill 从图像四周边缘标记外部背景（使用 Queue 优化性能）
    final backgroundVisited = Uint8List(w * h);
    final queue = Queue<int>();
    
    // 从四边所有像素点开始 flood fill
    for (int x = 0; x < w; x++) {
      // 上边
      if (filteredMask[x] == 0 && backgroundVisited[x] == 0) {
        queue.add(x);
        backgroundVisited[x] = 1;
      }
      // 下边
      final bottomIdx = (h - 1) * w + x;
      if (filteredMask[bottomIdx] == 0 && backgroundVisited[bottomIdx] == 0) {
        queue.add(bottomIdx);
        backgroundVisited[bottomIdx] = 1;
      }
    }
    for (int y = 0; y < h; y++) {
      // 左边
      final leftIdx = y * w;
      if (filteredMask[leftIdx] == 0 && backgroundVisited[leftIdx] == 0) {
        queue.add(leftIdx);
        backgroundVisited[leftIdx] = 1;
      }
      // 右边
      final rightIdx = y * w + w - 1;
      if (filteredMask[rightIdx] == 0 && backgroundVisited[rightIdx] == 0) {
        queue.add(rightIdx);
        backgroundVisited[rightIdx] = 1;
      }
    }
    
    // BFS flood fill（使用 Queue.removeFirst() O(1)）
    while (queue.isNotEmpty) {
      final idx = queue.removeFirst();
      final x = idx % w;
      final y = idx ~/ w;
      
      // 检查4邻域
      if (x > 0) {
        final n = idx - 1;
        if (backgroundVisited[n] == 0 && filteredMask[n] == 0) {
          backgroundVisited[n] = 1;
          queue.add(n);
        }
      }
      if (x < w - 1) {
        final n = idx + 1;
        if (backgroundVisited[n] == 0 && filteredMask[n] == 0) {
          backgroundVisited[n] = 1;
          queue.add(n);
        }
      }
      if (y > 0) {
        final n = idx - w;
        if (backgroundVisited[n] == 0 && filteredMask[n] == 0) {
          backgroundVisited[n] = 1;
          queue.add(n);
        }
      }
      if (y < h - 1) {
        final n = idx + w;
        if (backgroundVisited[n] == 0 && filteredMask[n] == 0) {
          backgroundVisited[n] = 1;
          queue.add(n);
        }
      }
    }
    
    // 未被背景访问到的前景 = 完整填充的面域
    final filledMask = Uint8List(w * h);
    var hasValidMask = false;
    for (int i = 0; i < w * h; i++) {
      if (filteredMask[i] == 1 && backgroundVisited[i] == 0) {
        filledMask[i] = 1;
        hasValidMask = true;
      }
    }
    
    // 如果没有有效面域，保持原样（避免全黑）
    if (!hasValidMask) {
      //  fallback: 返回原始二值图
      for (int i = 0; i < w * h; i++) {
        if (binMask[i] == 1) {
          filledMask[i] = 1;
        }
      }
    }

    // Step 7: 转成 RGBA
    final result = Uint8List(w * h * 4);
    for (int i = 0, j = 0; i < filledMask.length; i++, j += 4) {
      if (filledMask[i] == 1) {
        result[j] = 255;
        result[j + 1] = 255;
        result[j + 2] = 255;
        result[j + 3] = 255;
      }
    }
    return ImageData(w, h, result);
  }

  // 连通分量标记算法（Two-Pass + Union-Find）
  static Map<int, int> _connectedComponentLabeling(
      Uint8List bin, int w, int h) {
    final labels = <int, int?>{}; // index -> label
    final parent = <int, int>{}; // union-find 父节点
    int nextLabel = 1;

    int find(int x) {
      if (!parent.containsKey(x)) parent[x] = x;
      if (parent[x] != x) parent[x] = find(parent[x]!);
      return parent[x]!;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    // First pass: 分配临时标签
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = y * w + x;
        if (bin[idx] == 0) continue;

        // 检查左邻居和上邻居
        final leftLabel = x > 0 ? labels[idx - 1] : null;
        final topLabel = y > 0 ? labels[idx - w] : null;

        if (leftLabel == null && topLabel == null) {
          // 新区域
          labels[idx] = nextLabel;
          parent[nextLabel] = nextLabel;
          nextLabel++;
        } else if (leftLabel != null && topLabel == null) {
          labels[idx] = leftLabel;
        } else if (leftLabel == null && topLabel != null) {
          labels[idx] = topLabel;
        } else {
          // 都有标签，取较小的并合并
          labels[idx] = leftLabel! < topLabel! ? leftLabel : topLabel;
          if (leftLabel != topLabel) {
            union(leftLabel!, topLabel!);
          }
        }
      }
    }

    // Second pass: 应用等价关系
    final result = <int, int>{};
    for (final entry in labels.entries) {
      result[entry.key] = find(entry.value!);
    }

    return result;
  }

  // 2x2核的dilate
  static Uint8List _dilateBin(Uint8List bin, int w, int h, int iterations) {
    var cur = List<int>.from(bin);
    for (int iter = 0; iter < iterations; iter++) {
      final next = List<int>.from(cur);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (cur[y * w + x] == 1) {
            for (int dy = -1; dy <= 1; dy++) {
              for (int dx = -1; dx <= 1; dx++) {
                final nx = x + dx;
                final ny = y + dy;
                if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                  next[ny * w + nx] = 1;
                }
              }
            }
          }
        }
      }
      cur = next;
    }
    return Uint8List.fromList(cur);
  }

  // 2x2核的erode
  static Uint8List _erodeBin(Uint8List bin, int w, int h, int iterations) {
    var cur = List<int>.from(bin);
    for (int iter = 0; iter < iterations; iter++) {
      final next = List<int>.filled(w * h, 0);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          bool all = true;
          for (int dy = -1; dy <= 1 && all; dy++) {
            for (int dx = -1; dx <= 1 && all; dx++) {
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                if (cur[ny * w + nx] == 0) all = false;
              } else {
                all = false;
              }
            }
          }
          next[y * w + x] = all ? 1 : 0;
        }
      }
      cur = next;
    }
    return Uint8List.fromList(cur);
  }

  static Offset? calculateCentroid(ImageData mask) {
    double m00 = 0;
    double m10 = 0;
    double m01 = 0;
    final w = mask.width;
    final h = mask.height;
    final data = mask.pixels;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        if (data[idx] > 128) {
          m00 += 1;
          m10 += x;
          m01 += y;
        }
      }
    }

    if (m00 == 0) return null;
    return Offset(m10 / m00, m01 / m00);
  }

  // 多边形扫描线填充，返回二值mask
  static ImageData polygonToMask(List<Offset> points, int w, int h) {
    if (points.length < 3) {
      return ImageData(w, h, Uint8List(w * h * 4));
    }

    final mask = Uint8List(w * h);
    final n = points.length;

    // 扫描线算法：对每条水平线，求与多边形边的交点，排序后区间填充
    for (int y = 0; y < h; y++) {
      final intersections = <double>[];

      for (int i = 0; i < n; i++) {
        final p1 = points[i];
        final p2 = points[(i + 1) % n];

        final y1 = p1.dy;
        final y2 = p2.dy;
        final x1 = p1.dx;
        final x2 = p2.dx;

        // 边在扫描线同一侧，跳过
        if ((y1 < y && y2 < y) || (y1 >= y && y2 >= y)) continue;
        if ((y1 == y && y2 == y)) continue;

        // 求交点 x
        final t = (y - y1) / (y2 - y1);
        final xIntersect = x1 + t * (x2 - x1);
        intersections.add(xIntersect);
      }

      // 排序
      intersections.sort();

      // 两两配对填充
      for (int i = 0; i + 1 < intersections.length; i += 2) {
        final xStart = intersections[i].ceil().clamp(0, w - 1);
        final xEnd = intersections[i + 1].floor().clamp(0, w - 1);
        for (int x = xStart; x <= xEnd; x++) {
          mask[y * w + x] = 1;
        }
      }
    }

    // 转 RGBA
    final result = Uint8List(w * h * 4);
    for (int i = 0, j = 0; i < mask.length; i++, j += 4) {
      if (mask[i] == 1) {
        result[j] = 255;
        result[j + 1] = 255;
        result[j + 2] = 255;
        result[j + 3] = 255;
      }
    }
    return ImageData(w, h, result);
  }

  // 多边形质心（几何公式，不需要像素级遍历）
  static Offset? polygonCentroid(List<Offset> points) {
    if (points.length < 3) return null;
    double area = 0;
    double cx = 0;
    double cy = 0;
    final n = points.length;

    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      final cross = p1.dx * p2.dy - p2.dx * p1.dy;
      area += cross;
      cx += (p1.dx + p2.dx) * cross;
      cy += (p1.dy + p2.dy) * cross;
    }

    area *= 0.5;
    if (area.abs() < 1e-6) return null;
    cx /= (6 * area);
    cy /= (6 * area);
    return Offset(cx, cy);
  }

  static void drawBrushOnMask(
      ImageData mask, int x, int y, int radius, bool isWhite) {
    final w = mask.width;
    final h = mask.height;
    final data = mask.pixels;

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy <= radius * radius) {
          final nx = x + dx;
          final ny = y + dy;
          if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
            final idx = (ny * w + nx) * 4;
            if (isWhite) {
              data[idx] = 255;
              data[idx + 1] = 255;
              data[idx + 2] = 255;
              data[idx + 3] = 255;
            } else {
              data[idx] = 0;
              data[idx + 1] = 0;
              data[idx + 2] = 0;
              data[idx + 3] = 0;
            }
          }
        }
      }
    }
  }

  static void drawLineOnMask(ImageData mask, int x1, int y1, int x2, int y2,
      int radius, bool isWhite) {
    final dx = (x2 - x1).abs();
    final dy = (y2 - y1).abs();
    final sx = x1 < x2 ? 1 : -1;
    final sy = y1 < y2 ? 1 : -1;
    var err = dx - dy;

    var x = x1;
    var y = y1;

    while (true) {
      drawBrushOnMask(mask, x, y, radius, isWhite);
      if (x == x2 && y == y2) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }

  // 填充区域 + 加粗边缘
  static ImageData maskToOverlay(ImageData mask, Color edgeColor, Color fillColor, {int edgeWidth = 2}) {
    final w = mask.width;
    final h = mask.height;
    final edgeMap = List<bool>.filled(w * h, false);
    final src = mask.pixels;

    // 先找出所有边缘像素
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        if (src[idx] <= 128) continue;

        bool isEdge = false;
        final neighbors = [
          [x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1],
        ];
        for (final n in neighbors) {
          final nx = n[0];
          final ny = n[1];
          if (nx < 0 || nx >= w || ny < 0 || ny >= h) {
            isEdge = true;
            break;
          }
          final nidx = (ny * w + nx) * 4;
          if (src[nidx] <= 128) {
            isEdge = true;
            break;
          }
        }
        if (isEdge) edgeMap[y * w + x] = true;
      }
    }

    // 对边缘做膨胀（加粗）
    if (edgeWidth > 1) {
      final dilated = List<bool>.from(edgeMap);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (!edgeMap[y * w + x]) continue;
          for (int dy = -edgeWidth; dy <= edgeWidth; dy++) {
            for (int dx = -edgeWidth; dx <= edgeWidth; dx++) {
              if (dx * dx + dy * dy <= edgeWidth * edgeWidth) {
                final nx = x + dx;
                final ny = y + dy;
                if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                  dilated[ny * w + nx] = true;
                }
              }
            }
          }
        }
      }
      edgeMap.setRange(0, edgeMap.length, dilated);
    }

    // 生成结果
    final result = Uint8List(w * h * 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        if (src[idx] <= 128) continue;

        if (edgeMap[y * w + x]) {
          result[idx] = edgeColor.red;
          result[idx + 1] = edgeColor.green;
          result[idx + 2] = edgeColor.blue;
          result[idx + 3] = edgeColor.alpha;
        } else {
          result[idx] = fillColor.red;
          result[idx + 1] = fillColor.green;
          result[idx + 2] = fillColor.blue;
          result[idx + 3] = fillColor.alpha;
        }
      }
    }
    return ImageData(w, h, result);
  }

  static Future<Image> imageDataToUiImage(ImageData data) async {
    final completer = Completer<Image>();
    decodeImageFromPixels(
      data.pixels,
      data.width,
      data.height,
      PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );
    return completer.future;
  }

  // 提取面域轮廓点
  // 射线扫描法：从面域质心按角度发射射线，从外向内找最外层边界点
  /// 使用平行光线法提取轮廓点
  /// 
  /// [image] 原始图像
  /// [thresholdLower] 灰度阈值下限
  /// [thresholdUpper] 灰度阈值上限
  /// [numRays] 每个方向的光线数量（默认20）
  static List<Offset> extractContourPoints(
    ImageData image, {
    required int thresholdLower,
    required int thresholdUpper,
    int numRays = 20,
  }) {
    final w = image.width;
    final h = image.height;
    final data = image.pixels;
    
    // 判断背景色
    final isBlackBg = isBlackBackground(image);

    // Step 1: 从上边向下发射垂直光线（numRays条）
    final boundaryPoints = <Offset>[];
    for (int i = 0; i < numRays; i++) {
      final x = ((i + 0.5) / numRays * w).toInt();
      if (x < 0 || x >= w) continue;
      
      // 从上往下找第一个符合阈值的像素
      for (int y = 0; y < h; y++) {
        final idx = (y * w + x) * 4;
        final r = data[idx];
        final g = data[idx + 1];
        final b = data[idx + 2];
        final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
        
        // 根据背景色判断是否在阈值范围内
        bool inRange = isBlackBg
            ? (gray >= thresholdLower && gray <= 255)
            : (gray >= thresholdLower && gray <= thresholdUpper);
        
        if (inRange) {
          boundaryPoints.add(Offset(x.toDouble(), y.toDouble()));
          break; // 找到就停止
        }
      }
    }

    // Step 2: 从下边向上发射垂直光线（numRays条）
    for (int i = 0; i < numRays; i++) {
      final x = ((i + 0.5) / numRays * w).toInt();
      if (x < 0 || x >= w) continue;
      
      // 从下往上找第一个符合阈值的像素
      for (int y = h - 1; y >= 0; y--) {
        final idx = (y * w + x) * 4;
        final r = data[idx];
        final g = data[idx + 1];
        final b = data[idx + 2];
        final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
        
        bool inRange = isBlackBg
            ? (gray >= thresholdLower && gray <= 255)
            : (gray >= thresholdLower && gray <= thresholdUpper);
        
        if (inRange) {
          boundaryPoints.add(Offset(x.toDouble(), y.toDouble()));
          break; // 找到就停止
        }
      }
    }

    // Step 3: 从左边向右发射水平光线（numRays条）
    for (int i = 0; i < numRays; i++) {
      final y = ((i + 0.5) / numRays * h).toInt();
      if (y < 0 || y >= h) continue;
      
      // 从左往右找第一个符合阈值的像素
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        final r = data[idx];
        final g = data[idx + 1];
        final b = data[idx + 2];
        final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
        
        bool inRange = isBlackBg
            ? (gray >= thresholdLower && gray <= 255)
            : (gray >= thresholdLower && gray <= thresholdUpper);
        
        if (inRange) {
          boundaryPoints.add(Offset(x.toDouble(), y.toDouble()));
          break; // 找到就停止
        }
      }
    }

    // Step 4: 从右边向左发射水平光线（numRays条）
    for (int i = 0; i < numRays; i++) {
      final y = ((i + 0.5) / numRays * h).toInt();
      if (y < 0 || y >= h) continue;
      
      // 从右往左找第一个符合阈值的像素
      for (int x = w - 1; x >= 0; x--) {
        final idx = (y * w + x) * 4;
        final r = data[idx];
        final g = data[idx + 1];
        final b = data[idx + 2];
        final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
        
        bool inRange = isBlackBg
            ? (gray >= thresholdLower && gray <= 255)
            : (gray >= thresholdLower && gray <= thresholdUpper);
        
        if (inRange) {
          boundaryPoints.add(Offset(x.toDouble(), y.toDouble()));
          break; // 找到就停止
        }
      }
    }

    if (boundaryPoints.length < 3) return [];

    // Step 5: 按角度排序（以质心为参考点）
    double cx = 0, cy = 0;
    int count = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        final r = data[idx];
        final g = data[idx + 1];
        final b = data[idx + 2];
        final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
        
        bool inRange = isBlackBg
            ? (gray >= thresholdLower && gray <= 255)
            : (gray >= thresholdLower && gray <= thresholdUpper);
        
        if (inRange) {
          cx += x;
          cy += y;
          count++;
        }
      }
    }
    if (count == 0) return [];
    cx /= count;
    cy /= count;

    // 按角度排序
    boundaryPoints.sort((a, b) {
      final angleA = math.atan2(a.dy - cy, a.dx - cx);
      final angleB = math.atan2(b.dy - cy, b.dx - cx);
      return angleA.compareTo(angleB);
    });

    // 简单去重
    final filtered = <Offset>[boundaryPoints.first];
    for (int i = 1; i < boundaryPoints.length; i++) {
      final last = filtered.last;
      if ((boundaryPoints[i] - last).distance > 1.0) {
        filtered.add(boundaryPoints[i]);
      }
    }

    return filtered.length >= 3 ? filtered : boundaryPoints;
  }

  /// 智能精简点集：保留8个方向的边界点 + 拐角点
  /// 
  /// 算法流程：
  /// 1. 计算质心
  /// 2. 检测拐角点（基于角度变化）
  /// 3. 将剩余点按角度分成8个扇区
  /// 4. 每个扇区保留最远的点
  /// 5. 合并拐角点和边界点，按顺时针排序
  /// 智能精简：保留周天15度扇区边界点 + 大转角点
  static List<Offset> simplifyPoints(List<Offset> points, {int numSectors = 24}) {
    if (points.length < 4) return points;

    // Step 1: 计算质心
    double cx = 0, cy = 0;
    for (final p in points) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= points.length;
    cy /= points.length;
    final centroid = Offset(cx, cy);

    // Step 2: 检测拐角点（基于角度变化，阈值放宽到45-135度）
    final cornerPoints = _detectCornerPoints(points, centroid);

    // Step 3: 将所有点转换为极坐标
    final polarPoints = <_PolarPoint>[];
    for (final p in points) {
      final dx = p.dx - cx;
      final dy = p.dy - cy;
      final angle = math.atan2(dy, dx); // -π ~ π
      final radius = math.sqrt(dx * dx + dy * dy);
      polarPoints.add(_PolarPoint(p, angle, radius));
    }

    // Step 4: 将所有点按角度分成24个扇区（周天每15度一个扇区）
    final sectorAngle = 2 * math.pi / numSectors;
    final boundaryPoints = <Offset>[];
    
    for (int i = 0; i < numSectors; i++) {
      final sectorStart = i * sectorAngle - math.pi;
      final sectorEnd = sectorStart + sectorAngle;

      // 找出该扇区内的所有点
      final sectorCandidates = polarPoints.where((pp) {
        var angle = pp.angle;
        if (angle < sectorStart) angle += 2 * math.pi;
        return angle >= sectorStart && angle < sectorEnd;
      }).toList();

      if (sectorCandidates.isNotEmpty) {
        // 保留距离最远的点（边界点）
        sectorCandidates.sort((a, b) => b.radius.compareTo(a.radius));
        boundaryPoints.add(sectorCandidates.first.point);
      }
    }

    // Step 5: 合并拐角点和边界点
    final allKeypoints = <Offset>[...cornerPoints, ...boundaryPoints];
    
    // 去重：距离太近的点只保留一个
    final deduped = <Offset>[];
    for (final p in allKeypoints) {
      var isDuplicate = false;
      for (final existing in deduped) {
        if ((p - existing).distance < 8) { // 8像素阈值
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        deduped.add(p);
      }
    }

    // Step 6: 按顺时针排序
    deduped.sort((a, b) {
      final angleA = math.atan2(a.dy - cy, a.dx - cx);
      final angleB = math.atan2(b.dy - cy, b.dx - cx);
      return angleA.compareTo(angleB);
    });

    return deduped.length >= 4 ? deduped : points;
  }

  /// 检测拐角点：基于相邻线段的角度变化
  static List<Offset> _detectCornerPoints(List<Offset> points, Offset centroid) {
    final corners = <Offset>[];
    final n = points.length;
    if (n < 3) return corners;

    for (int i = 0; i < n; i++) {
      final prev = points[(i - 1 + n) % n];
      final curr = points[i];
      final next = points[(i + 1) % n];

      // 计算向量
      final v1X = curr.dx - prev.dx;
      final v1Y = curr.dy - prev.dy;
      final v2X = next.dx - curr.dx;
      final v2Y = next.dy - curr.dy;

      // 归一化
      final len1 = math.sqrt(v1X * v1X + v1Y * v1Y);
      final len2 = math.sqrt(v2X * v2X + v2Y * v2Y);
      if (len1 < 1 || len2 < 1) continue;

      final nv1X = v1X / len1;
      final nv1Y = v1Y / len1;
      final nv2X = v2X / len2;
      final nv2Y = v2Y / len2;

      // 计算夹角（点积）
      final dotProduct = nv1X * nv2X + nv1Y * nv2Y;
      final cosAngle = dotProduct.clamp(-1.0, 1.0);
      final angle = math.acos(cosAngle); // 弧度

      // 如果夹角在 45°~135° 之间，认为是大转角（之前是60-120度，现在放宽）
      const minCornerAngle = 45 * math.pi / 180; // 45度
      const maxCornerAngle = 135 * math.pi / 180; // 135度
      
      if (angle >= minCornerAngle && angle <= maxCornerAngle) {
        corners.add(curr);
      }
    }

    return corners;
  }
}

/// 极坐标点辅助类
class _PolarPoint {
  final Offset point;
  final double angle;
  final double radius;

  _PolarPoint(this.point, this.angle, this.radius);
}
