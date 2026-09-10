import 'package:flutter/material.dart';

/// 排序三角状态（对齐网页版排序指示器）
/// - [none]：默认（按创建时间排序）→ 上下双三角描边空心
/// - [asc]：顺排 → 上三角纯色实心
/// - [desc]：逆排 → 下三角纯色实心
enum SortState { none, asc, desc }

/// 排序三态三角组件（上下双三角）
///
/// 用于顶部导航栏排序入口（env_page 等共用）：
/// - 未激活（默认）：上下双三角灰色描边空心
/// - 顺排：上三角 [activeColor] 纯色实心
/// - 逆排：下三角 [activeColor] 纯色实心
///
/// [activeColor] 通常传导航栏按钮文字色（iconTheme.color），
/// 保证三角与按钮文字同色；[inactiveColor] 为未激活描边灰。
class SortTriangle extends StatelessWidget {
  final SortState state;
  final Color activeColor;
  final Color inactiveColor;
  final double width;
  final double height;

  const SortTriangle({
    super.key,
    required this.state,
    required this.activeColor,
    required this.inactiveColor,
    this.width = 8,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SortTrianglePainter(
        state,
        activeColor,
        inactiveColor,
      ),
    );
  }
}

class _SortTrianglePainter extends CustomPainter {
  final SortState state;
  final Color activeColor;
  final Color inactiveColor;

  _SortTrianglePainter(this.state, this.activeColor, this.inactiveColor);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2;
    final asc = state == SortState.asc;
    final desc = state == SortState.desc;
    // 底边两端内收，让三角形瘦高（顶点在 w/2，底边 = 0.78w）
    const double inset = 0.11;

    // 上三角（▲）
    final upPath = Path()
      ..moveTo(w / 2, 1)
      ..lineTo(w * (1 - inset), mid - 1)
      ..lineTo(w * inset, mid - 1)
      ..close();
    _drawTri(canvas, upPath, asc ? activeColor : inactiveColor, asc);

    // 下三角（▼）
    final downPath = Path()
      ..moveTo(w / 2, h - 1)
      ..lineTo(w * (1 - inset), mid + 1)
      ..lineTo(w * inset, mid + 1)
      ..close();
    _drawTri(canvas, downPath, desc ? activeColor : inactiveColor, desc);
  }

  void _drawTri(Canvas canvas, Path path, Color color, bool filled) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SortTrianglePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
