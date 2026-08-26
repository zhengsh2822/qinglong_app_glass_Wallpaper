import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 只读标签 chip 组件（Wallpaper 版毛玻璃风格）
///
/// 用于展示已选中的权限/分类等只读标签，与 Wallpaper 版 [GlassCard] 风格一致：
/// - 矩形圆角 5
/// - [BackdropFilter] 高斯模糊（sigma 由 [spCardBlurSigma] 控制，默认 8）
/// - 透明背景 + 主题色边框（宽 0.5）
/// - 主题色文字
/// - 无勾选图标（只读展示，不可点击）
///
/// 主题适配：
/// - cyber 模式：[CyberColors.borderGlow] 边框 + [CyberColors.titleWhite] 文字
/// - 非 cyber 模式：[AppleColors.accent] 半透明边框 + [AppleColors.textPrimary] 文字
///
/// 使用场景：
/// - 应用管理列表项的权限范围标签
/// - 应用详情页的权限标签
/// - 新增应用页的已选权限展示
class TagChip extends ConsumerWidget {
  final String label;

  const TagChip({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;

    final Color borderColor = isCyber
        ? CyberColors.borderGlow
        : AppleColors.accent.withValues(alpha: 0.4);
    final Color textColor =
        isCyber ? CyberColors.titleWhite : AppleColors.textPrimary;
    final double sigma = SpUtil.getDouble(spCardBlurSigma, defValue: 8);

    // 统一毛玻璃封装：sigma<=0 时自动退化为纯色（无 BackdropFilter）
    return OptimizedFrostedGlass(
      sigma: sigma,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
