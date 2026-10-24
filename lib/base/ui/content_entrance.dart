import 'package:flutter/material.dart';

/// 内容首次出现的柔和入场：淡入（+ 可选轻微上移归位）。
///
/// 用于替换「加载完成 → 内容直接闪现」的生硬切换，接入点：
/// - BaseStateWidget 的 builder（应用管理/订阅管理/依赖管理：
///   LOADING→CONTENT 切换时挂载播放一次）；
/// - 页面自身 loading 完成后的内容首现（脚本管理/登录日志）。
///
/// 挂载即播放一次；同位置的后续 rebuild 不会重播（控制器已完成）。
/// 与 SharedPageEntrance 的区别：后者由路由 animation 驱动，本组件自带控制器。
class ContentEntrance extends StatefulWidget {
  const ContentEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    this.offsetY = 14,
  });

  final Widget child;
  final Duration duration;

  /// 入场时的垂直位移；传 0 为纯淡入。
  final double offsetY;

  @override
  State<ContentEntrance> createState() => _ContentEntranceState();
}

class _ContentEntranceState extends State<ContentEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final double t = _curve.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
