import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/main.dart';

/// 渐变流光圆环进度加载器（方案②：渐变描边 + 光晕 + 头部圆点 + 中心百分比）。
///
/// - [progress] 非 null：确定性模式，圆环按进度填充，中心显示百分比；
/// - [progress] 为 null：不确定模式，圆弧持续旋转扫动，中心不显示数字。
///
/// 通用组件：WebDAV 备份/还原与服务端版本检查等所有需要加载态的场景统一使用，
/// 配合 [QlProgressOverlay] 全屏浮层展示。
class ProgressRingLoader extends ConsumerStatefulWidget {
  /// 0.0 ~ 1.0；null 表示不确定态
  final double? progress;

  final double size;

  final double strokeWidth;

  /// 环与头部圆点颜色：主色调（跟随主题 primaryColor）
  final Color accent;

  const ProgressRingLoader({
    super.key,
    this.progress,
    this.size = 76,
    this.strokeWidth = 6,
    required this.accent,
  });

  @override
  ConsumerState<ProgressRingLoader> createState() => _ProgressRingLoaderState();
}

class _ProgressRingLoaderState extends ConsumerState<ProgressRingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant ProgressRingLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == null) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      if (_spin.isAnimating) _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _spin,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    progress: widget.progress,
                    strokeWidth: widget.strokeWidth,
                    spin: _spin.value,
                    accent: widget.accent,
                  ),
                );
              },
            ),
            if (widget.progress != null)
              Text(
                "${(widget.progress!.clamp(0.0, 1.0) * 100).round()}%",
                style: TextStyle(
                  color: ref.watch(themeProvider).themeColor.titleColor(),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double? progress;
  final double strokeWidth;
  final double spin;
  final Color accent;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.spin,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = strokeWidth;
    final double radius = (size.shortestSide - stroke) / 2;
    final Offset center = size.center(Offset.zero);
    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    // 轨道：弱化浅色
    final Paint track =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0x1FFFFFFF);
    canvas.drawCircle(center, radius, track);

    final Paint paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = accent;

    double sweep;
    double startAngle;
    if (progress == null) {
      // 不确定态：弧长与角度同时摆动旋转
      final double t = spin;
      sweep =
          (60 + 55 * (0.5 + 0.5 * math.sin(2 * math.pi * t))) * math.pi / 180;
      startAngle = -math.pi / 2 + 2 * math.pi * t;
    } else {
      sweep = 2 * math.pi * progress!.clamp(0.0, 1.0);
      startAngle = -math.pi / 2;
    }

    if (sweep > 0.01) {
      // 光晕层：同弧线加模糊重绘一遍
      final Paint glow =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = accent
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawArc(arcRect, startAngle, sweep, false, glow);
      canvas.drawArc(arcRect, startAngle, sweep, false, paint);

      // 头部圆点（光晕 + 实心）
      final double tipAngle = startAngle + sweep;
      final Offset tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      final Paint dotGlow =
          Paint()
            ..color = accent.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(tip, stroke * 0.9, dotGlow);
      canvas.drawCircle(tip, stroke * 0.5, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.spin != spin ||
      old.strokeWidth != strokeWidth;
}

/// 统一加载进度浮层：暗色遮罩 + 毛玻璃面板 + 渐变流光环 + 状态文字。
///
/// 用法：
/// ```dart
/// QlProgressOverlay.show(context, status: "备份中");
/// try {
///   await work(onProgress: (stage, progress) {
///     QlProgressOverlay.update(status: stage, progress: progress);
///   });
/// } finally {
///   QlProgressOverlay.dismiss();
/// }
/// ```
/// [QlProgressOverlay.update] 的 progress 传 null 显示不确定态；
/// 重复 show 只更新状态。
class QlProgressOverlay {
  static OverlayEntry? _entry;

  static final ValueNotifier<({String status, double? progress})> _state =
      ValueNotifier(const (status: "加载中", progress: null));

  static void show(BuildContext context, {required String status}) {
    _state.value = (status: status, progress: null);
    if (_entry != null) return;
    final OverlayState? overlay =
        navigatorState.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(builder: (_) => const _ProgressOverlayPanel());
    overlay.insert(_entry!);
  }

  static void update({String? status, double? progress}) {
    final current = _state.value;
    _state.value = (
      status: status ?? current.status,
      progress: progress ?? current.progress,
    );
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _ProgressOverlayPanel extends ConsumerWidget {
  const _ProgressOverlayPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: ValueListenableBuilder<({String status, double? progress})>(
        valueListenable: QlProgressOverlay._state,
        builder: (context, state, _) {
          // 注意：本面板经 OverlayEntry 插入后外层包有 Material（_InkFeatures
          // RenderObject），Positioned 需要 Stack 直系语义会被 ParentData 校验
          // 拒绝并每帧抛 Incorrect use of ParentDataWidget（异常风暴卡死主线程，
          // 见 ql_debug.log 433 条记录）。改用 SizedBox.expand 撑满。
          return SizedBox.expand(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color:
                        ref
                            .watch(themeProvider)
                            .themeColor
                            .settingBordorColor(),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProgressRingLoader(
                        progress: state.progress,
                        accent: ref.watch(themeProvider).primaryColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.status,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              ref.watch(themeProvider).themeColor.titleColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
