import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/app_corner.dart';

/// 可选择 chip 组件
///
/// 统一封装选中/未选中状态的 chip 样式，用于多选场景：
/// - 应用管理的权限选择
/// - 数据备份的内容选择
///
/// 样式：矩形圆角 10（按钮比标签大，圆角略大更协调），左侧勾选图标 + 文字，支持 cyber/非 cyber 双主题。
/// 遵循项目规范：不使用 BackdropFilter，避免高刷新率屏幕 GPU 过载。
class SelectableChip extends ConsumerWidget {
  final String label;
  final bool selected;

  /// 点击切换回调，null 时禁用
  final ValueChanged<bool>? onToggle;

  /// 是否禁用（处理中时置灰）
  final bool disabled;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    this.onToggle,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;

    final Color accentColor = isCyber ? CyberColors.cyan : AppleColors.accent;
    final Color descColor =
        isCyber ? CyberColors.descColor : AppleColors.textSecondary;
    // 选中态字体跟随"主字体颜色"，未选中跟随"次字体颜色"
    final Color selectedText = ref.watch(themeProvider).customPrimaryTextColor;
    final Color unselectedText =
        ref.watch(themeProvider).customSecondaryTextColor;
    final FontWeight fw = FontWeight(ref.watch(textWeightProvider));

    // 选中态颜色
    final Color selectedBg = accentColor.withValues(alpha: 0.15);
    final Color selectedBorder = accentColor.withValues(alpha: 0.6);
    // 未选中态颜色
    final Color unselectedBg =
        isCyber
            ? Colors.white.withValues(alpha: 0.05)
            : AppleColors.bgSecondary;
    final Color unselectedBorder = descColor.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: disabled || onToggle == null ? null : () => onToggle!(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          shape: appCornerBorder(
            radius: 10,
            side: BorderSide(
              color: selected ? selectedBorder : unselectedBorder,
            ),
          ),
          color: selected ? selectedBg : unselectedBg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 14,
              color:
                  selected
                      ? accentColor
                      : (disabled
                          ? descColor.withValues(alpha: 0.5)
                          : descColor),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: fw,
                color:
                    selected
                        ? selectedText
                        : (disabled
                            ? descColor.withValues(alpha: 0.5)
                            : unselectedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
