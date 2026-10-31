import 'package:flutter/material.dart';

/// 「我的」页功能入口网格：每行固定 [perRow] 个、spaceEvenly 排布。
///
/// 替代硬编码的多行 Row——入口超出 [perRow] 时自动换行，
/// 末行不足 [perRow] 个时同样 spaceEvenly 铺满，物理上杜绝溢出。
class FeatureGrid extends StatelessWidget {
  final List<Widget> children;
  final int perRow;
  final double rowSpacing;

  const FeatureGrid({
    super.key,
    required this.children,
    this.perRow = 4,
    this.rowSpacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    final List<List<Widget>> rows = <List<Widget>>[];
    for (int i = 0; i < children.length; i += perRow) {
      final int end =
          (i + perRow > children.length) ? children.length : i + perRow;
      rows.add(children.sublist(i, end));
    }
    return Column(
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: rowSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows[r],
          ),
        ],
      ],
    );
  }
}
