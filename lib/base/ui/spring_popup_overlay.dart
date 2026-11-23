import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:qinglong_app/base/ui/spring_sheet.dart';

/// 弹簧弹窗浮层（自包含）：全屏遮罩 + 锚定底部的弹窗内容，
/// 弹簧入场（popupOpen：过冲回弹）/ 弹簧退场（close 规格），挂载/卸载内聚。
///
/// 主页面只负责：GlobalKey 调 show()/close() 与弹窗内容(child)。
/// IgnorePointer 仅在收起动画期间生效——不能按进度 t<1 判断：
/// 弹簧收敛带容差，t 永远差一点到 1，会把浮层永久变成忽略指针
/// （home_page 已踩坑：点外部永远关不掉）。
class SpringPopupOverlay extends StatefulWidget {
  const SpringPopupOverlay({
    super.key,
    required this.child,
    this.showMask = true,
    this.maskOpacity = 0.6,
    this.popDistance = 28,
    this.scaleFrom = 0.86,
  });

  /// 弹窗内容（调用方布局：边距/对齐/指向箭头都在 child 内）
  final Widget child;
  final bool showMask;
  final double maskOpacity;

  /// 入场时自下浮起的距离
  final double popDistance;
  final double scaleFrom;

  @override
  State<SpringPopupOverlay> createState() => SpringPopupOverlayState();
}

class SpringPopupOverlayState extends State<SpringPopupOverlay>
    with SingleTickerProviderStateMixin {
  // unbounded：无 0~1 边界钳制——AnimationController._tick 会把模拟值
  // clampDouble 到边界，弹簧过冲段（t>1）会被吃掉（demo 有回弹、App 没有的真因）
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );
  bool _visible = false;
  bool _closing = false;

  /// 弹簧入场（popupOpen：过冲回弹）
  void show() {
    if (_visible && !_closing) return;
    setState(() => _visible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller
        ..stop()
        ..value = 0
        ..animateWith(SpringSimulation(SpringSheetSpec.popupOpen, 0, 1, 0));
    });
  }

  /// 弹簧退场（close 规格，完成后自动卸载）
  void close() {
    if (!_visible || _closing) return;
    _closing = true;
    _controller
      ..stop()
      ..animateWith(
        SpringSimulation(SpringSheetSpec.close, _controller.value, 0, 0),
      );
  }

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _closing) {
        setState(() {
          _visible = false;
          _closing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 隐藏态整体不挂载内容（与原 Visibility 直切一致）
    if (!_visible) return const SizedBox.shrink();
    final double inset = MediaQuery.viewPaddingOf(context).bottom;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 过冲段不钳制（t>1 是回弹观感的来源）；仅透明度钳制在 0..1
        final double t = _controller.value;
        final double tc = t.clamp(0.0, 1.0);
        return Stack(
          children: [
            if (widget.showMask)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: close,
                  child: Opacity(
                    opacity: (widget.maskOpacity * tc).clamp(0.0, 1.0),
                    child: const ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: inset,
              child: IgnorePointer(
                ignoring: _closing,
                child: Opacity(
                  opacity: tc,
                  child: Transform.translate(
                    offset: Offset(0, widget.popDistance * (1 - t)),
                    child: Transform.scale(
                      scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
                      alignment: Alignment.bottomRight,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
