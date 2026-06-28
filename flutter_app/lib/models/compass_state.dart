import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/image_utils.dart' as utils;
import '../utils/contour_detector.dart' as contour;

enum CompassType {
  compass24,
  compass12,
  luopan28,
  xuankongda,
  zhoutian,
}

enum BrushMode {
  none,
  white,
  black,
  polygon,
}

// 触摸交互模式
enum TouchMode {
  addPoint,    // 加点模式：点击生成新点
  deletePoint, // 删点模式：点击删除现有点
}

class CompassState extends ChangeNotifier {
  bool _showCompass = false;
  double _compassRadius = 168; // 根据图片默认值
  double _rotation = 10;       // 根据图片默认值
  double _centerX = 0;
  double _centerY = 0;
  double _opacity = 0.5;       // 根据图片默认值 50%
  bool _snapToCentroid = false;
  Color _ringColor = Colors.red;
  double _ringWidth = 2;
  Color _textColor = Colors.black;
  double _textSize = 14;
  bool _showCenterDot = true;
  ImageProvider? _backgroundImage;
  final Set<CompassType> _enabledRings = {
    CompassType.compass24,
    // CompassType.compass12,   // 默认关闭
    CompassType.luopan28,
    // CompassType.xuankongda,  // 默认关闭
    CompassType.zhoutian,
  };

  utils.ImageData? _originalImage;
  utils.ImageData? _maskImage;
  ui.Image? _maskOverlayImage;
  ui.Offset? _centroid;
  bool _showMask = true;
  int _thresholdLower = 65;    // 根据图片默认值
  int _thresholdUpper = 210;   // 根据图片默认值
  int _minAreaRatio = 50;      // 噪点过滤保持50
  BrushMode _brushMode = BrushMode.none;
  double _brushSize = 20;
  
  // 放射线和天心线
  bool _showRadialLines = false;
  bool _showCrossLines = false;

  // 触摸交互模式（移动端友好）
  TouchMode _touchMode = TouchMode.addPoint; // 默认加点模式
  
  final List<ui.Offset> _polygonPoints = [];
  int _draggingPointIndex = -1;
  bool _usePolygonMode = false;
  ui.Image? _polygonOverlayImage;
  bool _isContourFromRecognition = false;

  // 圈选相关
  bool _isSelecting = false;
  ui.Offset? _selectionStart;
  ui.Offset? _selectionEnd;
  final Set<int> _selectedPointIndices = {};

  bool get showCompass => _showCompass;
  double get compassRadius => _compassRadius;
  double get rotation => _rotation;
  double get centerX => _centerX;
  double get centerY => _centerY;
  double get opacity => _opacity;
  bool get snapToCentroid => _snapToCentroid;
  Color get ringColor => _ringColor;
  double get ringWidth => _ringWidth;
  Color get textColor => _textColor;
  double get textSize => _textSize;
  bool get showCenterDot => _showCenterDot;
  ImageProvider? get backgroundImage => _backgroundImage;
  Set<CompassType> get enabledRings => _enabledRings;

  utils.ImageData? get originalImage => _originalImage;
  utils.ImageData? get maskImage => _maskImage;
  ui.Image? get maskOverlayImage => _maskOverlayImage;
  ui.Offset? get centroid => _centroid;
  bool get showMask => _showMask;
  int get thresholdLower => _thresholdLower;
  int get thresholdUpper => _thresholdUpper;
  int get minAreaRatio => _minAreaRatio;
  BrushMode get brushMode => _brushMode;
  double get brushSize => _brushSize;
  bool get showRadialLines => _showRadialLines;
  bool get showCrossLines => _showCrossLines;
  TouchMode get touchMode => _touchMode; // 触摸模式
  List<ui.Offset> get polygonPoints => List.unmodifiable(_polygonPoints);
  bool get usePolygonMode => _usePolygonMode;
  ui.Image? get polygonOverlayImage => _polygonOverlayImage;
  bool get isContourFromRecognition => _isContourFromRecognition;
  bool get isSelecting => _isSelecting;
  ui.Offset? get selectionStart => _selectionStart;
  ui.Offset? get selectionEnd => _selectionEnd;
  Set<int> get selectedPointIndices => Set.unmodifiable(_selectedPointIndices);

  void toggleCompass() {
    _showCompass = !_showCompass;
    notifyListeners();
  }

  void toggleSnapToCentroid() {
    _snapToCentroid = !_snapToCentroid;
    notifyListeners();
  }

  // 罗盘参数延迟设置（不立即应用，等待点击"应用"按钮）
  void setCompassRadiusNoRecompute(double value) {
    _compassRadius = value;
    notifyListeners();
  }

  void setRotationNoRecompute(double value) {
    _rotation = value;
    notifyListeners();
  }

  void setOpacityNoRecompute(double value) {
    _opacity = value;
    notifyListeners();
  }

  // 应用所有罗盘设置（点击"应用"按钮时调用）
  void applyCompassSettings() {
    // 触发通知，使所有变更生效
    notifyListeners();
  }

  void setCompassRadius(double value) {
    _compassRadius = value;
    notifyListeners();
  }

  void setRotation(double value) {
    _rotation = value;
    notifyListeners();
  }

  void setCenter(double x, double y) {
    _centerX = x;
    _centerY = y;
    notifyListeners();
  }

  void setOpacity(double value) {
    _opacity = value;
    notifyListeners();
  }

  void setRingColor(Color color) {
    _ringColor = color;
    notifyListeners();
  }

  void setRingWidth(double value) {
    _ringWidth = value;
    notifyListeners();
  }

  void setTextColor(Color color) {
    _textColor = color;
    notifyListeners();
  }

  void setTextSize(double value) {
    _textSize = value;
    notifyListeners();
  }

  void setShowCenterDot(bool value) {
    _showCenterDot = value;
    notifyListeners();
  }

  void toggleRing(CompassType type) {
    if (_enabledRings.contains(type)) {
      _enabledRings.remove(type);
    } else {
      _enabledRings.add(type);
    }
    notifyListeners();
  }

  bool isRingEnabled(CompassType type) => _enabledRings.contains(type);

  void toggleRadialLines() {
    _showRadialLines = !_showRadialLines;
    notifyListeners();
  }

  void toggleCrossLines() {
    _showCrossLines = !_showCrossLines;
    notifyListeners();
  }

  // 切换触摸模式（加点 <-> 删点）
  void toggleTouchMode() {
    _touchMode = _touchMode == TouchMode.addPoint 
        ? TouchMode.deletePoint 
        : TouchMode.addPoint;
    notifyListeners();
  }

  // 设置触摸模式
  void setTouchMode(TouchMode mode) {
    _touchMode = mode;
    notifyListeners();
  }

  void toggleMask() {
    _showMask = !_showMask;
    notifyListeners();
  }

  // 设置阈值（不自动重新计算，等待用户点击"识别"按钮）
  void setThresholdLowerNoRecompute(int value) {
    _thresholdLower = value;
    notifyListeners();
  }

  void setThresholdUpperNoRecompute(int value) {
    _thresholdUpper = value;
    notifyListeners();
  }

  // 重新计算mask和质心，并识别轮廓（点击"识别"按钮时调用）
  Future<void> recomputeAndRecognize() async {
    await _recomputeMaskAndCentroid();
    if (_originalImage != null) {
      await recognizeContour();
    }
  }

  Future<void> setThresholdLower(int value) async {
    _thresholdLower = value;
    await _recomputeMaskAndCentroid();
    // 如果之前已经识别过，自动重新提取轮廓点
    if (_isContourFromRecognition && _maskImage != null) {
      await recognizeContour();
    }
  }

  Future<void> setThresholdUpper(int value) async {
    _thresholdUpper = value;
    await _recomputeMaskAndCentroid();
    // 如果之前已经识别过，自动重新提取轮廓点
    if (_isContourFromRecognition && _maskImage != null) {
      await recognizeContour();
    }
  }

  Future<void> setMinAreaRatio(int value) async {
    _minAreaRatio = value;
    await _recomputeMaskAndCentroid();
    // 如果之前已经识别过，自动重新提取轮廓点
    if (_isContourFromRecognition && _maskImage != null) {
      await recognizeContour();
    }
  }

  void setBrushMode(BrushMode mode) {
    _brushMode = mode;
    notifyListeners();
  }

  void setBrushSize(double value) {
    _brushSize = value;
    notifyListeners();
  }

  // 重置所有状态（加载新图片时调用）
  void resetForNewImage() {
    // 清除多边形点和选区
    _polygonPoints.clear();
    _selectedPointIndices.clear();
    _isSelecting = false;
    _selectionStart = null;
    _selectionEnd = null;
    _draggingPointIndex = -1;
    
    // 清除质心
    _centroid = null;
    
    // 清除多边形覆盖图
    _polygonOverlayImage = null;
    
    // 重置罗盘位置到默认值
    _centerX = 0;
    _centerY = 0;
    
    // 重置识别状态
    _isContourFromRecognition = false;
    
    // 注意：不清除 _maskImage、_maskOverlayImage 和 _originalImage
    // 它们会在 loadOriginalImage 后重新计算
    
    notifyListeners();
  }

  Future<void> loadOriginalImage(utils.ImageData image) async {
    _originalImage = image;
    await _recomputeMaskAndCentroid();
  }

  Future<void> _recomputeMaskAndCentroid() async {
    if (_originalImage == null) return;

    _maskImage = utils.ImageUtils.applyThresholdSeparation(
        _originalImage!, _thresholdLower, _thresholdUpper, minAreaRatio: 50);
    await _updateCentroidAndOverlay();
  }

  Future<void> _updateCentroidAndOverlay() async {
    if (_maskImage == null) return;

    final c = utils.ImageUtils.calculateCentroid(_maskImage!);
    if (c != null) {
      _centroid = c;
      _centerX = c.dx;
      _centerY = c.dy;
    } else {
      // 质心计算失败，保持原有中心不变
      // 如果还没有设置过中心，使用屏幕中心（由 CompassWidget 处理）
    }

    final overlay = utils.ImageUtils.maskToOverlay(
        _maskImage!,
        const Color(0xFF00E5FF),
        const Color(0x80FF6600),
        edgeWidth: 3);
    _maskOverlayImage =
        await utils.ImageUtils.imageDataToUiImage(overlay);

    notifyListeners();
  }

  Future<void> paintOnMask(int x, int y) async {
    if (_maskImage == null || _brushMode == BrushMode.none) return;
    final isWhite = _brushMode == BrushMode.white;
    utils.ImageUtils.drawBrushOnMask(
        _maskImage!, x, y, _brushSize.toInt(), isWhite);
    await _updateCentroidAndOverlay();
  }

  Future<void> paintLineOnMask(int x1, int y1, int x2, int y2) async {
    if (_maskImage == null || _brushMode == BrushMode.none) return;
    final isWhite = _brushMode == BrushMode.white;
    utils.ImageUtils.drawLineOnMask(
        _maskImage!, x1, y1, x2, y2, _brushSize.toInt(), isWhite);
    await _updateCentroidAndOverlay();
  }

  Future<void> resetMask() async {
    await _recomputeMaskAndCentroid();
  }

  // === 多边形打点模式 ===
  void setPolygonMode(bool enable) {
    _usePolygonMode = enable;
    _brushMode = enable ? BrushMode.polygon : BrushMode.none;
    if (!enable) {
      _polygonPoints.clear();
      _polygonOverlayImage = null;
    }
    notifyListeners();
  }

  // 识别面域：从原始图像中提取包围主体的封闭轮廓
  Future<void> recognizeContour() async {
    if (_originalImage == null) return;

    // 使用新的轮廓检测器，生成包围主体的封闭多段线
    final contourPoints = contour.ContourDetector.detectClosedContour(
      _originalImage!,
      _thresholdLower,
      _thresholdUpper,
    );

    if (contourPoints.isEmpty) return;

    // 设置为打点模式的点
    _polygonPoints.clear();
    _polygonPoints.addAll(contourPoints);
    _isContourFromRecognition = true;
    _usePolygonMode = true;
    _brushMode = BrushMode.polygon;

    // 计算质心
    _recomputePolygonCentroid();
    notifyListeners();
  }

  void addPolygonPoint(ui.Offset point) {
    if (!_usePolygonMode) return;

    // 前4个点按点击顺序直接追加，先形成初始区域
    if (_polygonPoints.length < 4) {
      _polygonPoints.add(point);
      _recomputePolygonCentroid();
      notifyListeners();
      return;
    }

    // 第5个点及以后：找到最近的边，把点插入到这条边上
    int bestIndex = 0;
    double bestDist = double.infinity;
    final n = _polygonPoints.length;

    for (int i = 0; i < n; i++) {
      final p1 = _polygonPoints[i];
      final p2 = _polygonPoints[(i + 1) % n];
      final dist = _pointToSegmentDistance(point, p1, p2);
      if (dist < bestDist) {
        bestDist = dist;
        bestIndex = (i + 1) % n;
      }
    }

    _polygonPoints.insert(bestIndex, point);
    _recomputePolygonCentroid();
    notifyListeners();
  }

  // 点到线段的距离
  double _pointToSegmentDistance(ui.Offset p, ui.Offset a, ui.Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0) return (p - a).distance;

    double t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    t = t.clamp(0.0, 1.0);

    final proj = a + ab * t;
    return (p - proj).distance;
  }

  void removePolygonPointAt(ui.Offset point, {double tolerance = 12}) {
    if (!_usePolygonMode) return;
    int? removeIdx;
    double minDist = tolerance;
    for (int i = 0; i < _polygonPoints.length; i++) {
      final d = (_polygonPoints[i] - point).distance;
      if (d < minDist) {
        minDist = d;
        removeIdx = i;
      }
    }
    if (removeIdx != null) {
      _polygonPoints.removeAt(removeIdx);
      _recomputePolygonCentroid();
      notifyListeners();
    }
  }

  int? findPolygonPointAt(ui.Offset point, {double tolerance = 12}) {
    int? found;
    double minDist = tolerance;
    for (int i = 0; i < _polygonPoints.length; i++) {
      final d = (_polygonPoints[i] - point).distance;
      if (d < minDist) {
        minDist = d;
        found = i;
      }
    }
    return found;
  }

  void startDraggingPoint(int index) {
    _draggingPointIndex = index;
  }

  void updateDraggingPoint(ui.Offset point) {
    if (_draggingPointIndex < 0) return;
    if (_draggingPointIndex >= _polygonPoints.length) return;
    _polygonPoints[_draggingPointIndex] = point;
    _recomputePolygonCentroid();
    notifyListeners();
  }

  void endDraggingPoint() {
    _draggingPointIndex = -1;
  }

  void clearPolygonPoints() {
    _polygonPoints.clear();
    _polygonOverlayImage = null;
    _centroid = null;
    _isContourFromRecognition = false;
    _selectedPointIndices.clear();
    _isSelecting = false;
    _selectionStart = null;
    _selectionEnd = null;
    notifyListeners();
  }

  // 智能精简：保留8个边界点 + 拐角点
  Future<void> simplifyToKeyPoints() async {
    if (_polygonPoints.length < 4) return;

    final simplified = utils.ImageUtils.simplifyPoints(_polygonPoints);
    
    if (simplified.length >= 4) {
      _polygonPoints.clear();
      _polygonPoints.addAll(simplified);
      _recomputePolygonCentroid();
      notifyListeners();
    }
  }

  // === 圈选相关 ===
  void startSelection(ui.Offset point) {
    _isSelecting = true;
    _selectionStart = point;
    _selectionEnd = point;
    _selectedPointIndices.clear();
    _updateSelection();
    notifyListeners();
  }

  void updateSelection(ui.Offset point) {
    if (!_isSelecting) return;
    _selectionEnd = point;
    _updateSelection();
    notifyListeners();
  }

  void endSelection() {
    // 保持选中状态，但停止拖拽选择框
    _isSelecting = false;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPointIndices.clear();
    _selectionStart = null;
    _selectionEnd = null;
    _isSelecting = false;
    notifyListeners();
  }

  void _updateSelection() {
    if (_selectionStart == null || _selectionEnd == null) return;
    _selectedPointIndices.clear();

    final left = _selectionStart!.dx < _selectionEnd!.dx 
        ? _selectionStart!.dx 
        : _selectionEnd!.dx;
    final right = _selectionStart!.dx > _selectionEnd!.dx 
        ? _selectionStart!.dx 
        : _selectionEnd!.dx;
    final top = _selectionStart!.dy < _selectionEnd!.dy 
        ? _selectionStart!.dy 
        : _selectionEnd!.dy;
    final bottom = _selectionStart!.dy > _selectionEnd!.dy 
        ? _selectionStart!.dy 
        : _selectionEnd!.dy;

    for (int i = 0; i < _polygonPoints.length; i++) {
      final p = _polygonPoints[i];
      if (p.dx >= left && p.dx <= right && p.dy >= top && p.dy <= bottom) {
        _selectedPointIndices.add(i);
      }
    }
  }

  // 删除选中的点
  void deleteSelectedPoints() {
    if (_selectedPointIndices.isEmpty) return;

    // 从后往前删，避免索引错位
    final sortedIndices = _selectedPointIndices.toList()..sort((a, b) => b - a);
    for (final idx in sortedIndices) {
      if (idx >= 0 && idx < _polygonPoints.length) {
        _polygonPoints.removeAt(idx);
      }
    }

    _selectedPointIndices.clear();
    _selectionStart = null;
    _selectionEnd = null;
    _isSelecting = false;
    _recomputePolygonCentroid();
    notifyListeners();
  }

  void _recomputePolygonCentroid() {
    if (_polygonPoints.length < 4) {
      _centroid = null;
      return;
    }
    _centroid = utils.ImageUtils.polygonCentroid(_polygonPoints);
    notifyListeners();
  }

  void setBackgroundImage(ImageProvider? image) {
    _backgroundImage = image;
    notifyListeners();
  }
}
