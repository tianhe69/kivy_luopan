import 'dart:io';
import 'dart:ui';
import 'dart:math' show cos, sin, min;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../models/compass_state.dart';
import '../widgets/compass_widget.dart';
import '../widgets/control_panel.dart';
import '../utils/image_utils.dart' as utils;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _showPanel = true;
  bool _isDrawing = false;
  int _lastX = 0;
  int _lastY = 0;
  Size _imageDisplaySize = Size.zero;
  Offset _imageDisplayOffset = Offset.zero;
  double _imageScale = 1.0;
  bool _isDraggingPoint = false;
  bool _isSelectingPoints = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;
    final byteData =
        await image.toByteData(format: ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final imageData = utils.ImageData(
      image.width,
      image.height,
      byteData.buffer.asUint8List(),
    );
    image.dispose();
    codec.dispose();

    if (!mounted) return;
    final state = Provider.of<CompassState>(context, listen: false);
    
    // 加载新图片前先重置所有状态
    state.resetForNewImage();
    state.setBackgroundImage(FileImage(File(pickedFile.path)));
    await state.loadOriginalImage(imageData);
  }

  Future<void> _saveImage() async {
    // 暂时保持截图方式，但提示用户当前保存的是全屏
    final imageBytes = await _screenshotController.capture();
    if (imageBytes == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'luopan_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(imageBytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已保存到相册\n⚠️ 当前为全屏截图（含黑边和控制面板）\n💡 建议：使用手机相册裁剪功能截取图像区域'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handlePanStart(DragStartDetails details, CompassState state) {
    if (state.brushMode == BrushMode.none) return;
    if (state.originalImage == null) return;

    _isDrawing = true;
    final pos = _screenToImage(details.localPosition);
    _lastX = pos.dx.toInt();
    _lastY = pos.dy.toInt();
    state.paintOnMask(_lastX, _lastY);
  }

  void _handlePanUpdate(DragUpdateDetails details, CompassState state) {
    if (!_isDrawing) return;
    if (state.brushMode == BrushMode.none) return;
    if (state.originalImage == null) return;

    final pos = _screenToImage(details.localPosition);
    final x = pos.dx.toInt();
    final y = pos.dy.toInt();
    state.paintLineOnMask(_lastX, _lastY, x, y);
    _lastX = x;
    _lastY = y;
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDrawing = false;
  }

  void _handlePointerDown(PointerDownEvent e, CompassState state) {
    if (state.originalImage == null) return;
    final imgPos = _screenToImage(e.localPosition);

    if (state.usePolygonMode) {
      // 右键：如果有选中点则删除选中，否则删单个点
      if (e.buttons == kSecondaryMouseButton) {
        if (state.selectedPointIndices.isNotEmpty) {
          state.deleteSelectedPoints();
        } else {
          state.removePolygonPointAt(imgPos);
        }
        return;
      }
      
      // 左键 + Ctrl：开始圈选（使用HardwareKeyboard检测Ctrl键）
      // 必须在检测加点/删点之前判断，确保优先级最高
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
      
      if (isCtrlPressed) {
        state.startSelection(imgPos);
        _isSelectingPoints = true;
        return;
      }
      
      // 左键：根据触摸模式决定行为（加点或删除）
      // 只有在没有按Ctrl键时才执行
      final hit = state.findPolygonPointAt(imgPos);
      
      if (state.touchMode == TouchMode.deletePoint) {
        // 删点模式：优先删除点击的点
        if (hit != null) {
          // 如果有点被选中，删除选中的点
          if (state.selectedPointIndices.contains(hit)) {
            state.deleteSelectedPoints();
          } else {
            // 否则删除单个点
            state.removePolygonPointAt(imgPos);
          }
        }
      } else {
        // 加点模式：拖拽现有点或添加新点
        if (hit != null) {
          state.startDraggingPoint(hit);
          _isDraggingPoint = true;
        } else {
          state.clearSelection();
          state.addPolygonPoint(imgPos);
        }
      }
      return;
    }

    if (state.brushMode == BrushMode.none) return;
    _isDrawing = true;
    _lastX = imgPos.dx.toInt();
    _lastY = imgPos.dy.toInt();
    state.paintOnMask(_lastX, _lastY);
  }

  void _handlePointerMove(PointerMoveEvent e, CompassState state) {
    if (state.originalImage == null) return;
    final imgPos = _screenToImage(e.localPosition);

    if (state.usePolygonMode && _isDraggingPoint) {
      state.updateDraggingPoint(imgPos);
      return;
    }

    // 圈选拖拽
    if (state.usePolygonMode && _isSelectingPoints) {
      state.updateSelection(imgPos);
      return;
    }

    if (!_isDrawing) return;
    if (state.brushMode == BrushMode.none || state.brushMode == BrushMode.polygon) return;
    final x = imgPos.dx.toInt();
    final y = imgPos.dy.toInt();
    state.paintLineOnMask(_lastX, _lastY, x, y);
    _lastX = x;
    _lastY = y;
  }

  void _handlePointerUp(PointerUpEvent e, CompassState state) {
    if (state.usePolygonMode && _isDraggingPoint) {
      state.endDraggingPoint();
      _isDraggingPoint = false;
      return;
    }
    if (state.usePolygonMode && _isSelectingPoints) {
      state.endSelection();
      _isSelectingPoints = false;
      return;
    }
    _isDrawing = false;
  }

  Offset _screenToImage(Offset screenPos) {
    final dx = (screenPos.dx - _imageDisplayOffset.dx) / _imageScale;
    final dy = (screenPos.dy - _imageDisplayOffset.dy) / _imageScale;
    return Offset(dx, dy);
  }

  Offset _imageToScreen(Offset imagePos) {
    final dx = imagePos.dx * _imageScale + _imageDisplayOffset.dx;
    final dy = imagePos.dy * _imageScale + _imageDisplayOffset.dy;
    return Offset(dx, dy);
  }

  void _updateSnapToCentroid(CompassState state) {
    if (state.snapToCentroid && state.centroid != null) {
      final screenPos = _imageToScreen(state.centroid!);
      state.setCenter(screenPos.dx, screenPos.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('天和鸿运质心罗盘'),
        backgroundColor: Colors.brown[300],
        actions: [
          // 顶部按钮加文字
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image, size: 18),
              label: const Text('打开', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: _saveImage,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('保存', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_showPanel ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showPanel = !_showPanel;
              });
            },
            tooltip: '控制面板',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Screenshot(
              controller: _screenshotController,
              child: Container(
                color: Colors.black,
                child: Consumer<CompassState>(
                  builder: (context, state, child) {
                    if (state.backgroundImage == null) {
                      return const Center(
                        child: Text(
                          '请先打开一张图片',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      );
                    }
                    
                    // 吸合质心：状态变化后更新罗盘位置
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _updateSnapToCentroid(state);
                      }
                    });
                    
                    return Column(
                      children: [
                        Expanded(
                          child: Listener(
                            onPointerDown: (e) => _handlePointerDown(e, state),
                            onPointerMove: (e) => _handlePointerMove(e, state),
                            onPointerUp: (e) => _handlePointerUp(e, state),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildImageLayer(state),
                                if (state.showMask &&
                                    state.maskOverlayImage != null &&
                                    !state.usePolygonMode)
                                  _buildMaskLayer(state),
                                if (state.usePolygonMode &&
                                    state.polygonPoints.length >= 4)
                                  _buildPolygonFillLayer(state),
                                if (state.usePolygonMode)
                                  _buildPolygonOverlay(state),
                                _buildRadialLines(state),
                                _buildCrossLines(state),
                                _buildCentroidMarker(state),
                                const CompassWidget(),
                              ],
                            ),
                          ),
                        ),
                        if (_showPanel)
                          CompactControlPanel(
                            state: state,
                            onPickImage: _pickImage,
                            onSaveImage: _saveImage,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageLayer(CompassState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Image(
          image: state.backgroundImage!,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame == null) return child;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _calculateImageLayout(constraints.biggest, state);
            });
            return child;
          },
        );
      },
    );
  }

  void _calculateImageLayout(Size containerSize, CompassState state) {
    if (state.originalImage == null) return;

    final imgW = state.originalImage!.width.toDouble();
    final imgH = state.originalImage!.height.toDouble();

    final scaleX = containerSize.width / imgW;
    final scaleY = containerSize.height / imgH;
    _imageScale = scaleX < scaleY ? scaleX : scaleY;

    final displayW = imgW * _imageScale;
    final displayH = imgH * _imageScale;

    _imageDisplayOffset = Offset(
      (containerSize.width - displayW) / 2,
      (containerSize.height - displayH) / 2,
    );
    _imageDisplaySize = Size(displayW, displayH);
    
    // 布局变化时，如果开启吸合，更新罗盘中心
    _updateSnapToCentroid(state);
  }

  Widget _buildMaskLayer(CompassState state) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RawImage(
            image: state.maskOverlayImage!,
            fit: BoxFit.contain,
          );
        },
      ),
    );
  }

  Widget _buildPolygonFillLayer(CompassState state) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PolygonFillPainter(
          points: state.polygonPoints,
          imageOffset: _imageDisplayOffset,
          imageScale: _imageScale,
        ),
      ),
    );
  }

  Widget _buildPolygonOverlay(CompassState state) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PolygonOverlayPainter(
          points: state.polygonPoints,
          imageOffset: _imageDisplayOffset,
          imageScale: _imageScale,
          selectedIndices: state.selectedPointIndices,
          selectionStart: state.selectionStart,
          selectionEnd: state.selectionEnd,
        ),
      ),
    );
  }

  Widget _buildCentroidMarker(CompassState state) {
    if (state.centroid == null || !state.showCompass) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CentroidPainter(
          centroid: state.centroid!,
          imageOffset: _imageDisplayOffset,
          imageScale: _imageScale,
        ),
      ),
    );
  }

  Widget _buildRadialLines(CompassState state) {
    if (!state.showRadialLines || state.centroid == null || state.originalImage == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RadialLinesPainter(
          centroid: state.centroid,
          imageOffset: _imageDisplayOffset,
          imageScale: _imageScale,
          imageSize: Size(
            state.originalImage!.width.toDouble(),
            state.originalImage!.height.toDouble(),
          ),
          rotation: state.rotation, // 传递旋转角度
        ),
      ),
    );
  }

  Widget _buildCrossLines(CompassState state) {
    if (!state.showCrossLines || state.centroid == null || state.originalImage == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CrossLinesPainter(
          centroid: state.centroid,
          imageOffset: _imageDisplayOffset,
          imageScale: _imageScale,
          imageSize: Size(
            state.originalImage!.width.toDouble(),
            state.originalImage!.height.toDouble(),
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Consumer<CompassState>(
      builder: (context, state, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Colors.grey[200],
          height: 200,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: state.toggleCompass,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            backgroundColor:
                                state.showCompass ? Colors.green : Colors.grey,
                          ),
                          child: Text(state.showCompass ? '隐藏罗盘' : '显示罗盘',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image, size: 16),
                          label: const Text('打开图片',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: _saveImage,
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('保存',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const _SectionTitle('面域阈值'),
                _buildCompactSlider(
                    '下限', state.thresholdLower.toDouble(), 0, 255,
                    (v) => state.setThresholdLower(v.toInt())),
                _buildCompactSlider(
                    '上限', state.thresholdUpper.toDouble(), 0, 255,
                    (v) => state.setThresholdUpper(v.toInt())),
                _buildCompactSlider(
                    '噪点', state.minAreaRatio.toDouble(), 10, 200,
                    (v) => state.setMinAreaRatio(v.toInt())),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _SectionTitle('画笔'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 26,
                        child: _buildBrushButton('白', BrushMode.white, state),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 26,
                        child: _buildBrushButton('黑', BrushMode.black, state),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 26,
                        child: _buildBrushButton('点', BrushMode.polygon, state),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 26,
                        child: _buildBrushButton('无', BrushMode.none, state),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: _buildCompactSlider(
                          '', state.brushSize, 2, 100, state.setBrushSize),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 50,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: state.originalImage != null
                            ? () => state.recognizeContour()
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('识别',
                            style: TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 50,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: state.centroid != null
                            ? () => state.toggleSnapToCentroid()
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: state.snapToCentroid 
                              ? Colors.orange 
                              : Colors.grey,
                        ),
                        child: Text(
                            state.snapToCentroid ? '吸合' : '吸合',
                            style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 60,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () {
                          if (state.usePolygonMode) {
                            state.clearPolygonPoints();
                          } else {
                            state.resetMask();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(state.usePolygonMode ? '清点' : '重置',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('图层'),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          _buildRingToggle('24山', CompassType.compass24, state),
                          _buildRingToggle('12支', CompassType.compass12, state),
                          _buildRingToggle('28宿', CompassType.luopan28, state),
                          _buildRingToggle(
                              '玄空', CompassType.xuankongda, state),
                          _buildRingToggle('周天', CompassType.zhoutian, state),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _SectionTitle('辅助线'),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: state.toggleRadialLines,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            backgroundColor:
                                state.showRadialLines ? Colors.blue : Colors.grey,
                          ),
                          child: Text(
                              state.showRadialLines ? '放射线' : '放射线',
                              style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: state.toggleCrossLines,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            backgroundColor:
                                state.showCrossLines ? Colors.pink : Colors.grey,
                          ),
                          child: Text(
                              state.showCrossLines ? '天心线' : '天心线',
                              style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const _SectionTitle('参数'),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildCompactSlider(
                          'R', state.compassRadius, 50, 400,
                          state.setCompassRadius),
                    ),
                    Expanded(
                      child: _buildCompactSlider(
                          '转', state.rotation, 0, 360, state.setRotation),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 42),
                    Expanded(
                      child: _buildCompactSlider(
                          '透', state.opacity, 0.1, 1.0, state.setOpacity),
                    ),
                    Expanded(
                      child: _buildCompactSlider(
                          '线', state.ringWidth, 0.5, 5, state.setRingWidth),
                    ),
                    Expanded(
                      child: _buildCompactSlider(
                          '字', state.textSize, 8, 30, state.setTextSize),
                    ),
                  ],
                ),
                if (state.centroid != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '质心: (${state.centroid!.dx.toStringAsFixed(1)}, ${state.centroid!.dy.toStringAsFixed(1)})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrushButton(String label, BrushMode mode, CompassState state) {
    final selected = state.brushMode == mode;
    return ElevatedButton(
      onPressed: () {
        if (mode == BrushMode.polygon) {
          state.setPolygonMode(true);
        } else {
          state.setPolygonMode(false);
          state.setBrushMode(mode);
        }
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor:
            selected ? (mode == BrushMode.white ? Colors.white : mode == BrushMode.black ? Colors.black : mode == BrushMode.polygon ? Colors.yellow : Colors.grey) : Colors.grey[300],
        foregroundColor: selected
            ? (mode == BrushMode.black ? Colors.white : Colors.black)
            : Colors.black,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildRingToggle(String label, CompassType type, CompassState state) {
    final enabled = state.isRingEnabled(type);
    return SizedBox(
      height: 28,
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: enabled,
        onSelected: (_) => state.toggleRing(type),
        selectedColor: Colors.brown[200],
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      ),
    );
  }

  Widget _buildCompactSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          SizedBox(width: 24, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        SizedBox(width: 32, child: Text(value.toStringAsFixed(0),
            style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 11, color: Colors.brown)),
    );
  }
}

class _CentroidPainter extends CustomPainter {
  final Offset centroid;
  final Offset imageOffset;
  final double imageScale;

  _CentroidPainter({
    required this.centroid,
    required this.imageOffset,
    required this.imageScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = imageOffset.dx + centroid.dx * imageScale;
    final y = imageOffset.dy + centroid.dy * imageScale;

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(x, y), 8, paint);

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CentroidPainter oldDelegate) {
    return oldDelegate.centroid != centroid ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageScale != imageScale;
  }
}

class _PolygonFillPainter extends CustomPainter {
  final List<Offset> points;
  final Offset imageOffset;
  final double imageScale;

  _PolygonFillPainter({
    required this.points,
    required this.imageOffset,
    required this.imageScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 3) return;

    final path = Path();
    final first = imageOffset + points.first * imageScale;
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < points.length; i++) {
      final p = imageOffset + points[i] * imageScale;
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    final paint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PolygonFillPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageScale != imageScale;
  }
}

class _PolygonOverlayPainter extends CustomPainter {
  final List<Offset> points;
  final Offset imageOffset;
  final double imageScale;
  final Set<int> selectedIndices;
  final Offset? selectionStart;
  final Offset? selectionEnd;

  _PolygonOverlayPainter({
    required this.points,
    required this.imageOffset,
    required this.imageScale,
    required this.selectedIndices,
    this.selectionStart,
    this.selectionEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && selectionStart == null) return;

    final edgePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pointFillPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    final pointStrokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final selectedPointFillPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // 连线
    if (points.length >= 2) {
      for (int i = 0; i < points.length; i++) {
        final p1 = imageOffset + points[i] * imageScale;
        final p2 = imageOffset +
            points[(i + 1) % points.length] * imageScale;
        canvas.drawLine(p1, p2, edgePaint);
      }
    }

    // 顶点
    for (int i = 0; i < points.length; i++) {
      final p = imageOffset + points[i] * imageScale;
      final isSelected = selectedIndices.contains(i);
      canvas.drawCircle(
        p, 
        6, 
        isSelected ? selectedPointFillPaint : pointFillPaint,
      );
      canvas.drawCircle(p, 6, pointStrokePaint);
    }

    // 圈选框
    if (selectionStart != null && selectionEnd != null) {
      final selStart = imageOffset + selectionStart! * imageScale;
      final selEnd = imageOffset + selectionEnd! * imageScale;
      
      final rect = Rect.fromPoints(selStart, selEnd);
      
      final selectionPaint = Paint()
        ..color = Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      final selectionBorderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawRect(rect, selectionPaint);
      canvas.drawRect(rect, selectionBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonOverlayPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageScale != imageScale ||
        oldDelegate.selectedIndices != selectedIndices ||
        oldDelegate.selectionStart != selectionStart ||
        oldDelegate.selectionEnd != selectionEnd;
  }
}

// 放射线Painter：从质心发出24条线，与24山的分割线完全重合，随罗盘旋转
class _RadialLinesPainter extends CustomPainter {
  final Offset? centroid;
  final Offset imageOffset;
  final double imageScale;
  final Size imageSize;
  final double rotation; // 旋转角度

  _RadialLinesPainter({
    required this.centroid,
    required this.imageOffset,
    required this.imageScale,
    required this.imageSize,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (centroid == null || imageSize.width == 0) return;

    final cx = imageOffset.dx + centroid!.dx * imageScale;
    final cy = imageOffset.dy + centroid!.dy * imageScale;

    final linePaint = Paint()
      ..color = const Color(0xFF00BFFF) // 亮蓝色 (DeepSkyBlue)
      ..strokeWidth = 1.5;

    // 24条放射线，与24山的分割线完全重合
    // 24山从"壬"开始，"壬"的左边界是 -22.5°（或337.5°）
    // 每隔15°一条分割线
    // 加上旋转角度
    for (int i = 0; i < 24; i++) {
      final angle = -22.5 + i * 15 + rotation; // 与24山分割线对齐 + 旋转
      final radian = angle * 3.141592653589793 / 180;

      // 计算射线与原图像边界的交点
      final endPoint = _findImageBoundaryPoint(cx, cy, radian);

      canvas.drawLine(Offset(cx, cy), endPoint, linePaint);
    }
  }

  // 找到从(cx,cy)出发，角度为radian的射线与原图像边界的交点
  Offset _findImageBoundaryPoint(double cx, double cy, double radian) {
    final dx = cos(radian);
    final dy = sin(radian);

    // 计算显示区域的边界（考虑缩放和偏移）
    final displayLeft = imageOffset.dx;
    final displayTop = imageOffset.dy;
    final displayRight = displayLeft + imageSize.width * imageScale;
    final displayBottom = displayTop + imageSize.height * imageScale;

    double minT = double.infinity;

    // 与左边 x=displayLeft 的交点
    if (dx < 0) {
      final t = (displayLeft - cx) / dx;
      if (t > 0) minT = min(minT, t);
    }

    // 与右边 x=displayRight 的交点
    if (dx > 0) {
      final t = (displayRight - cx) / dx;
      if (t > 0) minT = min(minT, t);
    }

    // 与上边 y=displayTop 的交点
    if (dy < 0) {
      final t = (displayTop - cy) / dy;
      if (t > 0) minT = min(minT, t);
    }

    // 与下边 y=displayBottom 的交点
    if (dy > 0) {
      final t = (displayBottom - cy) / dy;
      if (t > 0) minT = min(minT, t);
    }

    if (minT == double.infinity) {
      return Offset(cx, cy);
    }

    return Offset(cx + dx * minT, cy + dy * minT);
  }

  @override
  bool shouldRepaint(covariant _RadialLinesPainter oldDelegate) {
    return oldDelegate.centroid != centroid ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageScale != imageScale ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation;
  }
}

// 十字天心线Painter：正南北和正东西两条线，终点为原图像边缘
class _CrossLinesPainter extends CustomPainter {
  final Offset? centroid;
  final Offset imageOffset;
  final double imageScale;
  final Size imageSize;

  _CrossLinesPainter({
    required this.centroid,
    required this.imageOffset,
    required this.imageScale,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (centroid == null || imageSize.width == 0) return;

    final cx = imageOffset.dx + centroid!.dx * imageScale;
    final cy = imageOffset.dy + centroid!.dy * imageScale;

    // 计算显示区域的边界（考虑缩放和偏移）
    final displayLeft = imageOffset.dx;
    final displayTop = imageOffset.dy;
    final displayRight = displayLeft + imageSize.width * imageScale;
    final displayBottom = displayTop + imageSize.height * imageScale;

    final linePaint = Paint()
      ..color = const Color(0xFFFF00FF) // 亮洋红色
      ..strokeWidth = 2.5;

    // 正南北线（垂直线）：从显示区域顶部到底部
    canvas.drawLine(
      Offset(cx, displayTop),
      Offset(cx, displayBottom),
      linePaint,
    );

    // 正东西线（水平线）：从显示区域左侧到右侧
    canvas.drawLine(
      Offset(displayLeft, cy),
      Offset(displayRight, cy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossLinesPainter oldDelegate) {
    return oldDelegate.centroid != centroid ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageScale != imageScale ||
        oldDelegate.imageSize != imageSize;
  }
}
