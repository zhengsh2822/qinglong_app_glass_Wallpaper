import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 可复用的 HSL 颜色选择器（3 条独立滑块）
///
/// 布局：
/// 色相   ▰▰▰▰▰▰▰▰▰▰  （彩虹 0→360°）
/// 饱和度 ▰▰▰▰▰▰▰▰▰▰  （白 → 当前色）
/// 明度   ▰▰▰▰▰▰▰▰▰▰  （黑 → 白）
///
/// 每条滑块：左侧 label + 圆角条形 slider（带渐变背景）+ 白色圆形 thumb
///
/// 用法：
/// ```dart
/// HslColorPicker(
///   color: Colors.red,
///   onChanged: (Color c) => ...,
///   onChangeEnd: (Color c) => ...,
/// )
/// ```
class HslColorPicker extends StatefulWidget {
  /// 当前颜色
  final Color color;

  /// 颜色变化回调（拖动中持续触发）
  final ValueChanged<Color>? onChanged;

  /// 拖动结束回调（释放时触发一次）
  final ValueChanged<Color>? onChangeEnd;

  /// slider 高度
  final double sliderHeight;

  /// label 宽度
  final double labelWidth;

  /// 圆角
  final double radius;

  const HslColorPicker({
    super.key,
    required this.color,
    this.onChanged,
    this.onChangeEnd,
    this.sliderHeight = 30,
    this.labelWidth = 56,
    this.radius = 999, // 胶囊形
  });

  @override
  State<HslColorPicker> createState() => _HslColorPickerState();
}

class _HslColorPickerState extends State<HslColorPicker> {
  late HSLColor _hsl;

  @override
  void initState() {
    super.initState();
    _hsl = HSLColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant HslColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color.value != oldWidget.color.value &&
        widget.color.value != _hsl.toColor().value) {
      _hsl = HSLColor.fromColor(widget.color);
    }
  }

  void _emit({bool end = false}) {
    final c = _hsl.toColor();
    widget.onChanged?.call(c);
    if (end) widget.onChangeEnd?.call(c);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHueRow(),
        const SizedBox(height: 14),
        _buildSaturationRow(),
        const SizedBox(height: 14),
        _buildLightnessRow(),
      ],
    );
  }

  // —— 色相：彩虹渐变 ——
  Widget _buildHueRow() {
    return _SliderRow(
      label: "色相",
      labelWidth: widget.labelWidth,
      sliderHeight: widget.sliderHeight,
      radius: widget.radius,
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFFF0000), // 0°   红
          Color(0xFFFFFF00), // 60°  黄
          Color(0xFF00FF00), // 120° 绿
          Color(0xFF00FFFF), // 180° 青
          Color(0xFF0000FF), // 240° 蓝
          Color(0xFFFF00FF), // 300° 紫
          Color(0xFFFF0000), // 360° 红
        ],
      ),
      value: _hsl.hue / 360.0,
      onChanged: (v) {
        setState(() {
          _hsl = _hsl.withHue(v * 360);
        });
        _emit();
      },
      onChangeEnd: () => _emit(end: true),
    );
  }

  // —— 饱和度：白 → 当前色（基于固定 lightness=0.5） ——
  Widget _buildSaturationRow() {
    final pure = HSLColor.fromAHSL(1.0, _hsl.hue, 1.0, 0.5).toColor();
    final gray = HSLColor.fromAHSL(1.0, _hsl.hue, 0.0, 0.5).toColor();
    return _SliderRow(
      label: "饱和度",
      labelWidth: widget.labelWidth,
      sliderHeight: widget.sliderHeight,
      radius: widget.radius,
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [gray, pure],
      ),
      value: _hsl.saturation,
      onChanged: (v) {
        setState(() {
          _hsl = _hsl.withSaturation(v);
        });
        _emit();
      },
      onChangeEnd: () => _emit(end: true),
    );
  }

  // —— 明度：黑 → 白（基于当前 hue 和 saturation） ——
  Widget _buildLightnessRow() {
    final base = HSLColor.fromAHSL(1.0, _hsl.hue, _hsl.saturation, 0.5);
    final black = base.withLightness(0.0).toColor();
    final mid = base.toColor();
    final white = base.withLightness(1.0).toColor();
    return _SliderRow(
      label: "明度",
      labelWidth: widget.labelWidth,
      sliderHeight: widget.sliderHeight,
      radius: widget.radius,
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [black, mid, white],
        stops: const [0.0, 0.5, 1.0],
      ),
      value: _hsl.lightness,
      onChanged: (v) {
        setState(() {
          _hsl = _hsl.withLightness(v);
        });
        _emit();
      },
      onChangeEnd: () => _emit(end: true),
    );
  }
}

/// 单行：label + 圆角条形渐变 slider
class _SliderRow extends StatelessWidget {
  final String label;
  final double labelWidth;
  final double sliderHeight;
  final double radius;
  final LinearGradient gradient;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  const _SliderRow({
    required this.label,
    required this.labelWidth,
    required this.sliderHeight,
    required this.radius,
    required this.gradient,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) => _handlePan(d.localPosition, w),
                onPanUpdate: (d) => _handlePan(d.localPosition, w),
                onPanEnd: (_) => onChangeEnd(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: SizedBox(
                    width: w,
                    height: sliderHeight,
                    child: CustomPaint(
                      painter: _SliderPainter(
                        thumbX: value * w,
                        radius: sliderHeight / 2,
                        gradient: gradient,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handlePan(Offset local, double width) {
    final v = (local.dx / width).clamp(0.0, 1.0);
    onChanged(v);
  }
}

/// 圆角条形渐变 slider 画笔（白底+白边圆形 thumb）
class _SliderPainter extends CustomPainter {
  final double thumbX;
  final double radius;
  final LinearGradient gradient;

  _SliderPainter({
    required this.thumbX,
    required this.radius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 渐变背景
    final bgPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // 圆形 thumb：白底+白边
    final thumbCenter = Offset(
      thumbX.clamp(radius, size.width - radius),
      size.height / 2,
    );
    // 阴影
    canvas.drawCircle(
      thumbCenter,
      radius + 1,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // 白色圆形 thumb
    canvas.drawCircle(thumbCenter, radius, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) =>
      thumbX != old.thumbX ||
      radius != old.radius ||
      gradient != old.gradient;
}
