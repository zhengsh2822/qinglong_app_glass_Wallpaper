import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 胶囊高光内发光卡片容器（壁纸版可复用组件）
///
/// 移植自主题版 CapsuleGlowCard 的高光设计，同时保留壁纸版核心机制：
/// - [frost] 为 true 时（默认）：底层内置 [OptimizedFrostedGlass]，
///   卡片模糊/纯色跟随全局设置，全局壁纸始终透出（不做不透明纯色底）
/// - [frost] 为 false 时：仅提供高光外发光装饰盒（不裁剪、不包玻璃），
///   供"带左右滑动按钮的列表卡片"（定时任务等）使用——滑动按钮在卡片
///   外部不可被 Clip 裁剪，玻璃/边框由卡片主体自行提供
/// - 高光效果与主题版对齐：
///   - 顶部亮线高光（boxShadow offset(0,-1)）
///   - 底部内侧发光（boxShadow offset(0,2)）
///   - 外发光（cyber 青色 / 其他浅色系）
/// - [isPinned] 置顶卡片：内发光增强（boost 1.25）+ 更亮青色发光边框（frost 模式）
/// - 深色模式（cyber/dark）：青色发光边框 + 青色内发光
/// - 浅色模式（兜底）：白色边框 + 浅灰顶部高光 + 白色内发光
///
/// 用法：设置页分组卡片、我的页面卡片、定时任务卡片（frost: false）等。
class CapsuleGlowCard extends ConsumerWidget {
  final Widget child;

  /// 发光强度 0~1（默认 0.5，与主题版一致）
  final double glowIntensity;

  /// 是否内置毛玻璃层（默认 true）。带左右滑动按钮（Slidable/CyberSlidable）
  /// 的列表卡片传 false，仅提供高光装饰，玻璃与边框委托给卡片主体。
  final bool frost;

  /// 置顶卡片：增强内发光 + 更亮边框（frost 模式生效）
  final bool isPinned;

  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const CapsuleGlowCard({
    super.key,
    required this.child,
    this.glowIntensity = 0.5,
    this.frost = true,
    this.isPinned = false,
    this.margin,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;
    final double g = glowIntensity.clamp(0.0, 1.0);
    final br = borderRadius ?? const BorderRadius.all(Radius.circular(18));
    final double boost = isPinned ? 1.25 : 1.0;

    // 卡片模糊跟随全局设置（默认 4），关闭模糊时自动退化为纯色卡片
    final effectiveSigma = SpUtil.getDouble(
      spCardBlurSigma,
      defValue: 4,
    );

    final List<BoxShadow> glow;
    final Color borderColor;
    if (isDark) {
      borderColor = isPinned
          ? CyberColors.cyan.withValues(alpha: 0.6)
          : CyberColors.cyan.withValues(alpha: 0.25);
      glow = [
        // 顶部青色高光（内发光）
        BoxShadow(
          color: CyberColors.cyan.withValues(alpha: 0.28 * g),
          blurRadius: 2.5,
          spreadRadius: 0.2,
          offset: const Offset(0, -1),
        ),
        // 底部青色内发光
        BoxShadow(
          color: CyberColors.cyan.withValues(alpha: 0.12 * g),
          blurRadius: (6 * g + 2) * boost,
          spreadRadius: 0.4 * g,
          offset: const Offset(0, 2),
        ),
        // 青色外发光
        BoxShadow(
          color: CyberColors.cyan.withValues(alpha: (isPinned ? 0.12 : 0.06) * g),
          blurRadius: 14,
          spreadRadius: 0.5,
        ),
      ];
    } else {
      borderColor = Colors.white;
      glow = [
        // 顶部浅灰高光（内发光）
        BoxShadow(
          color: const Color(0xFFF2F2F4).withValues(alpha: 0.8 * g),
          blurRadius: 2.5,
          spreadRadius: 0.2,
          offset: const Offset(0, -1),
        ),
        // 底部纯白内发光
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.16 * g),
          blurRadius: (6 * g + 2) * boost,
          spreadRadius: 0.4 * g,
          offset: const Offset(0, 2),
        ),
        // 外阴影
        const BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
    }

    // frost: false —— 仅高光装饰盒（不裁剪，滑动按钮可正常滑出卡片外）
    if (!frost) {
      if (onTap == null) {
        return Container(
          margin: margin,
          decoration: BoxDecoration(borderRadius: br, boxShadow: glow),
          child: child,
        );
      }
      return Container(
        margin: margin,
        decoration: BoxDecoration(borderRadius: br, boxShadow: glow),
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: br, onTap: onTap, child: child),
        ),
      );
    }

    // frost: true —— 内置毛玻璃层 + 边框 + 高光
    final Widget content = ClipRRect(
      borderRadius: br,
      child: OptimizedFrostedGlass(
        sigma: effectiveSigma,
        borderRadius: br,
        child: Container(
          decoration: BoxDecoration(
            // 全透明：仅保留毛玻璃模糊，让全局壁纸透出
            color: Colors.transparent,
            borderRadius: br,
            border: Border.all(
              color: borderColor,
              width: isPinned && isDark ? 1.5 : 1,
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(borderRadius: br, boxShadow: glow),
        child: content,
      );
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(borderRadius: br, boxShadow: glow),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}