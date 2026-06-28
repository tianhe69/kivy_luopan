import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/compass_state.dart';

class CompactControlPanel extends StatelessWidget {
  final CompassState state;
  final VoidCallback onPickImage;
  final VoidCallback onSaveImage;

  const CompactControlPanel({
    super.key,
    required this.state,
    required this.onPickImage,
    required this.onSaveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      color: Colors.grey[200],
      height: 130, // 增加高度以容纳更多控件
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：罗盘显示 + 触摸模式 + 图层控制 + 辅助线
            Row(
              children: [
                _smallButton(state.showCompass ? '隐藏' : '罗盘', 
                    state.toggleCompass, size: 52),
                const SizedBox(width: 3),
                // 触摸模式切换按钮
                _smallButton(
                    state.touchMode == TouchMode.addPoint ? '✏️加点' : '加点', 
                    state.toggleTouchMode, 
                    size: 56,
                    color: state.touchMode == TouchMode.addPoint 
                        ? const Color(0xFFE8F5E9)  // 浅绿背景（激活）
                        : Colors.grey[300]),
                const SizedBox(width: 2),
                _smallButton(
                    state.touchMode == TouchMode.deletePoint ? '🗑️删点' : '删点', 
                    state.toggleTouchMode, 
                    size: 56,
                    color: state.touchMode == TouchMode.deletePoint 
                        ? const Color(0xFFFFEBEE)  // 浅红背景（激活）
                        : Colors.grey[300]),
                const SizedBox(width: 3),
                // 图层控制（缩小版）
                _miniChipToggle('24山', CompassType.compass24, state),
                _miniChipToggle('12支', CompassType.compass12, state),
                _miniChipToggle('28宿', CompassType.luopan28, state),
                _miniChipToggle('玄空', CompassType.xuankongda, state),
                _miniChipToggle('周天', CompassType.zhoutian, state),
                const Spacer(),
                _smallButton('放射', state.toggleRadialLines, size: 44),
                const SizedBox(width: 2),
                _smallButton('天心', state.toggleCrossLines, size: 44),
              ],
            ),
            const SizedBox(height: 3),
            
            // 第二行：色调分离滑条 + 编辑工具
            Row(
              children: [
                const Text('色调:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildThresholdSlider(
                    '低', state.thresholdLower.toDouble(), 0, 255,
                    (v) => state.setThresholdLowerNoRecompute(v.toInt()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildThresholdSlider(
                    '高', state.thresholdUpper.toDouble(), 0, 255,
                    (v) => state.setThresholdUpperNoRecompute(v.toInt()),
                  ),
                ),
                const SizedBox(width: 4),
                // 编辑工具按钮组
                _smallButton('识别', 
                    () => state.recomputeAndRecognize(), size: 48),
                const SizedBox(width: 2),
                _smallButton('吸合', 
                    () => state.toggleSnapToCentroid(), size: 48),
                const SizedBox(width: 2),
                _smallButton('精点', 
                    () => state.simplifyToKeyPoints(), size: 48),
                const SizedBox(width: 2),
                _smallButton('清空', 
                    () => state.clearPolygonPoints(), size: 48),
              ],
            ),
            const SizedBox(height: 3),
            
            // 第三行：罗盘参数滑条 + 罗盘按钮
            Row(
              children: [
                const Text('罗盘:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                // 罗盘半径滑条
                Expanded(
                  child: _buildCompactSlider(
                    'R', state.compassRadius, 50, 400,
                    (v) => state.setCompassRadiusNoRecompute(v),
                  ),
                ),
                const SizedBox(width: 4),
                // 旋转角度输入框（支持小数、负值、Del/Backspace）
                _numberInput('转°', state.rotation, -180, 180, 52, context,
                    state.setRotation),
                const SizedBox(width: 4),
                // 透明度滑条
                Expanded(
                  child: _buildCompactSlider(
                    '透', state.opacity * 100, 10, 100,
                    (v) => state.setOpacityNoRecompute(v / 100),
                  ),
                ),
                const SizedBox(width: 4),
                // 罗盘显示/隐藏按钮
                _smallButton(state.showCompass ? '盘隐' : '盘显', 
                    state.toggleCompass, size: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback onPressed, 
      {IconData? icon, double size = 64, Color? color}) {
    return SizedBox(
      width: size,
      height: 28,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          backgroundColor: color ?? Colors.grey[300],
          foregroundColor: const Color(0xFF8B008B), // 紫红色
        ),
        child: icon != null
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 12),
                const SizedBox(width: 2),
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ])
            : Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _numberInput(String label, double value, double min, double max, double width, BuildContext context,
      ValueChanged<double> onChanged) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 8)),
          SizedBox(
            height: 24,
            child: _EditableNumberField(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // 迷你版图层切换按钮（更小更紧凑）
  Widget _miniChipToggle(String label, CompassType type, CompassState state) {
    final enabled = state.isRingEnabled(type);
    return Padding(
      padding: const EdgeInsets.only(right: 1.5),
      child: SizedBox(
        height: 24,
        child: FilterChip(
          label: Text(label, style: const TextStyle(fontSize: 8)),
          selected: enabled,
          onSelected: (_) => state.toggleRing(type),
          selectedColor: Colors.brown[200],
          backgroundColor: Colors.grey[300],
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
          labelPadding: const EdgeInsets.symmetric(horizontal: 1),
        ),
      ),
    );
  }
}

// 独立的数字输入框组件，管理自己的状态
class _EditableNumberField extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _EditableNumberField({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_EditableNumberField> createState() => _EditableNumberFieldState();
}

class _EditableNumberFieldState extends State<_EditableNumberField> {
  late TextEditingController _controller;
  bool _isEditing = false; // 标记是否正在编辑

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(_EditableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当值真正改变且不在编辑状态时才更新显示
    if (widget.value != oldWidget.value && !_isEditing) {
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    // 保留小数点后一位，支持负值
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,1}$')), // 限制最多1位小数
      ],
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      textAlign: TextAlign.center,
      onTap: () {
        // 点击时进入编辑模式
        _isEditing = true;
        // 全选文本，方便直接输入新值
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      },
      onEditingComplete: () {
        // 编辑完成（按Enter或失去焦点）
        _isEditing = false;
        final v = double.tryParse(_controller.text);
        if (v != null) {
          final clamped = v.clamp(widget.min, widget.max);
          _controller.text = _formatValue(clamped);
          widget.onChanged(clamped);
        } else if (_controller.text.isNotEmpty) {
          // 无效输入，恢复原值
          _controller.text = _formatValue(widget.value);
        }
      },
      onSubmitted: (text) {
        _isEditing = false;
        final v = double.tryParse(text);
        if (v != null) {
          final clamped = v.clamp(widget.min, widget.max);
          _controller.text = _formatValue(clamped);
          widget.onChanged(clamped);
        } else if (text.isNotEmpty) {
          // 无效输入，恢复原值
          _controller.text = _formatValue(widget.value);
        }
      },
    );
  }
}

// 色调分离滑条组件（精细版）
Widget _buildThresholdSlider(String label, double value, double min, double max,
    ValueChanged<double> onChanged) {
  return Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 8)),
            Text(value.toStringAsFixed(0), 
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(
          height: 24,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 255,
              label: value.toStringAsFixed(0),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}

// 紧凑滑条组件（用于罗盘参数，精细手柄）
Widget _buildCompactSlider(String label, double value, double min, double max,
    ValueChanged<double> onChanged) {
  return Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 8)),
            Text(value.toStringAsFixed(0), 
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(
          height: 20,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 1.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              label: value.toStringAsFixed(0),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}
