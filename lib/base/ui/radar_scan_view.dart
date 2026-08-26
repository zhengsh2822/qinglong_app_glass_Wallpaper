import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 雷达扫描 + 外圈进度条 复合动画
///
/// - 外圈：基于 progress 的圆环进度条（虚线 + 主色实线）
/// - 内圈：旋转的扇形雷达扫描效果（主色渐变）
/// - 中心：进度百分比数字 + 状态文字
class RadarScanPainter extends CustomPainter {
  /// 扫描进度 [0.0, 1.0]
  final double progress;

  /// 雷达扫描旋转角度 [0.0, 2π]
  final double rotation;

  /// 主题主色
  final Color primaryColor;

  /// 描述文字颜色
  final Color descColor;

  /// 中心进度数字（可选，外部 TextStack 渲染更清晰）
  final bool showProgressText;

  RadarScanPainter({
    required this.progress,
    required this.rotation,
    required this.primaryColor,
    required this.descColor,
    this.showProgressText = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    _paintRadarSweep(canvas, center, radius);
    _paintConcentricRings(canvas, center, radius);
    _paintCrossLines(canvas, center, radius);
    _paintOuterProgressRing(canvas, center, radius);
    _paintCenterGlow(canvas, center, radius);
  }

  /// 雷达扫描扇形（旋转渐变）
  void _paintRadarSweep(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final sweepWidth = radius * 0.18;
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius * 0.78);

    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: math.pi * 1.5,
      colors: [
        primaryColor.withOpacity(0.0),
        primaryColor.withOpacity(0.05),
        primaryColor.withOpacity(0.18),
        primaryColor.withOpacity(0.45),
        primaryColor.withOpacity(0.0),
      ],
      stops: const [0.0, 0.55, 0.82, 0.95, 1.0],
      transform: const GradientRotation(0),
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..arcTo(rect, -math.pi / 2 - sweepWidth, sweepWidth * 2, false)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// 同心圆网格
  void _paintConcentricRings(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..color = primaryColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final ratios = [0.25, 0.5, 0.78];
    for (final r in ratios) {
      canvas.drawCircle(center, radius * r, ringPaint);
    }
  }

  /// 十字扫描线
  void _paintCrossLines(Canvas canvas, Offset center, double radius) {
    final linePaint = Paint()
      ..color = primaryColor.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final r = radius * 0.78;
    canvas.drawLine(
      Offset(center.dx - r, center.dy),
      Offset(center.dx + r, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - r),
      Offset(center.dx, center.dy + r),
      linePaint,
    );
  }

  /// 外圈进度环（虚线背景 + 实线前景）
  void _paintOuterProgressRing(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final outerRadius = radius * 0.95;
    final strokeWidth = math.max(3.0, radius * 0.025);

    // 底层虚线轨道
    final trackPaint = Paint()
      ..color = primaryColor.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final dashCount = 48;
    final dashAngle = (2 * math.pi) / dashCount;
    final visibleLength = dashAngle * 0.55;
    for (int i = 0; i < dashCount; i++) {
      final start = -math.pi / 2 + i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        start,
        visibleLength,
        false,
        trackPaint,
      );
    }

    // 前景进度实线
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi,
          colors: [
            primaryColor.withOpacity(0.45),
            primaryColor,
            primaryColor.withOpacity(0.85),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: outerRadius),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 1
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );

      // 进度头部亮点
      final headAngle = -math.pi / 2 + 2 * math.pi * progress.clamp(0.0, 1.0);
      final headOffset = Offset(
        center.dx + outerRadius * math.cos(headAngle),
        center.dy + outerRadius * math.sin(headAngle),
      );
      final headPaint = Paint()..color = primaryColor;
      canvas.drawCircle(headOffset, strokeWidth * 0.9, headPaint);
      canvas.drawCircle(
        headOffset,
        strokeWidth * 1.8,
        Paint()..color = primaryColor.withOpacity(0.25),
      );
    }
  }

  /// 中心光晕
  void _paintCenterGlow(Canvas canvas, Offset center, double radius) {
    final glowRadius = radius * 0.08;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.55),
          primaryColor.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: glowRadius * 1.6),
      );
    canvas.drawCircle(center, glowRadius * 1.6, glowPaint);

    final corePaint = Paint()..color = primaryColor;
    canvas.drawCircle(center, glowRadius * 0.5, corePaint);
  }

  @override
  bool shouldRepaint(covariant RadarScanPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.descColor != descColor;
  }
}

/// 雷达扫描视图（自带旋转动画 + 中心文字）
class RadarScanView extends StatefulWidget {
  final double size;
  final double progress;
  final Color primaryColor;
  final Color descColor;
  final String? percentText;
  final String? bottomText;

  const RadarScanView({
    super.key,
    required this.size,
    required this.progress,
    required this.primaryColor,
    required this.descColor,
    this.percentText,
    this.bottomText,
  });

  @override
  State<RadarScanView> createState() => _RadarScanViewState();
}

class _RadarScanViewState extends State<RadarScanView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: RadarScanPainter(
                    progress: widget.progress,
                    rotation: _controller.value * 2 * math.pi,
                    primaryColor: widget.primaryColor,
                    descColor: widget.descColor,
                  ),
                );
              },
            ),
            // 百分比大字：放在扫描完成/状态文字上方，避免和雷达中心圆点重合
            if (widget.percentText != null)
              Positioned(
                bottom: widget.size * 0.30,
                child: Text(
                  widget.percentText!,
                  style: TextStyle(
                    fontSize: widget.size * 0.11,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            // 状态文字：底部（"3 / 10" / "扫描完成" / "准备就绪"）
            if (widget.bottomText != null)
              Positioned(
                bottom: widget.size * 0.12,
                child: Text(
                  widget.bottomText!,
                  style: TextStyle(
                    fontSize: widget.size * 0.05,
                    color: widget.descColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
