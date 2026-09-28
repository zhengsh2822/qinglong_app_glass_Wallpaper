import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';

/// 「最新日志」文本入口（可复用组件）
///
/// 使用处（2 处及以上，故抽取为复用组件）：
/// 1. 仪表盘 - 今日成功/失败明细卡片
/// 2. 仪表盘 - 实时运行态「正在运行的任务」行
///
/// [enabled] 为 false 时置灰且不可点击（例如任务已被删除）。
class LogEntryButton extends ConsumerWidget {
  final VoidCallback onTap;
  final bool enabled;

  /// 文案，默认「最新日志」，紧凑场景可传「日志」
  final String label;

  /// 字号，默认 12，紧凑场景可传 11
  final double fontSize;

  const LogEntryButton({
    super.key,
    required this.onTap,
    this.enabled = true,
    this.label = '最新日志',
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color color =
        enabled
            ? ref.watch(themeProvider).primaryColor
            : ref.watch(themeProvider).themeColor.descColor();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.doc_text, size: fontSize + 2, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              decoration: enabled ? TextDecoration.underline : null,
              decorationColor: color,
            ),
          ),
        ],
      ),
    );
  }
}