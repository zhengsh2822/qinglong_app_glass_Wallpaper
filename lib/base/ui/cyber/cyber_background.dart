import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';

/// 赛博终端全局背景
///
/// 结构层级（从底到顶）：
/// 1. 透明底色（让全局壁纸透过）
/// 2. 可选网格纹理（默认关闭）
/// 3. 页面内容 child
///
/// 说明：已移除底部光影渐变层（青色光从底部向上散射），
/// 避免渐变与全局壁纸叠加导致视觉杂乱。
class CyberBackground extends StatelessWidget {
  final Widget child;
  final bool showGrid;

  const CyberBackground({
    Key? key,
    required this.child,
    this.showGrid = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 第1层：透明底色（让全局壁纸透过）
        Container(color: Colors.transparent),

        // 第2层：可选网格纹理
        if (showGrid)
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

        // 第3层：页面内容
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
