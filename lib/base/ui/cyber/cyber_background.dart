import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';

/// 赛博终端全局背景
///
/// 结构层级（从底到顶）：
/// 1. 纯黑底色 (#050505) — 极致纯净的深空黑
/// 2. 底部光影渐变 — 屏幕底部35%区域，青色光从底部向上散射
/// 3. 可选网格纹理（默认关闭）
/// 4. 页面内容 child
///
/// 光影效果参考Gemini的深邃纯净感，模拟环境光从屏幕底部向上散射的科技氛围。
class CyberBackground extends StatelessWidget {
  final Widget child;
  final bool showGrid;
  final bool showGradient;

  const CyberBackground({
    Key? key,
    required this.child,
    this.showGrid = false,
    this.showGradient = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 第1层：透明底色（让全局壁纸透过）
        Container(color: Colors.transparent),

        // 第2层：底部光影渐变 — 青色光从底部向上散射
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.of(context).size.height * 0.38,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0x1A00F0FF), // 底部：青色带10%透明度
                    Color(0x0800F0FF), // 中部：青色带3%透明度
                    Colors.transparent, // 顶部：完全透明
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 第3层：可选网格纹理
        if (showGrid)
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

        // 第4层：页面内容
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = CyberColors.gridLine
          ..strokeWidth = 0.5;

    const step = 30.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final dotPaint =
        Paint()
          ..color = CyberColors.cyan.withValues(alpha: 0.06)
          ..style = PaintingStyle.fill;
    final rng = Random(42);
    for (int i = 0; i < 8; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 80 + rng.nextDouble() * 60, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
