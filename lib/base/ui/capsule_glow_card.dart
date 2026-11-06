import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/app_corner.dart';

/// 胶囊高光内发光卡片容器（可复用组件）
///
/// 参考 demos/task_card_glow_demo 的小胶囊高光内发光设计：
/// - 顶部高光（inset BoxShadow offset(0,-1)）+ 底部内侧发光（inset offset(0,2)）
/// - 苹果风格（默认）：纯色背景（未置顶 #F7F7F7 / 置顶 #EDEDF2）+ 纯白边框 1px
///   + 浅灰顶部高光 + 纯白内发光
/// - 赛博风格（默认）：深色 cardBg + 青色发光边框（置顶 1.5px alpha 0.6 / 未置顶 1px alpha 0.2）
///   + 青色顶部高光 + 青色底部内发光
///
/// 置顶卡片：更灰背景 + 粗边框 + 增强内发光（boost 1.25）
///
/// [newPinnedStyle]（定时任务页面专属新样式，其他页面保持默认）：
/// - 苹果：置顶/未置顶颜色互换（置顶 #F7F7F7 / 未置顶 #EDEDF2）
/// - 赛博：置顶边框细化为 1.25px
///
/// 用法：定时任务列表卡片（Slidable 外层）、我的页面卡片等列表项容器。
class CapsuleGlowCard extends StatelessWidget {
  final Widget child;
  final bool isCyber;
  final bool isPinned;

  /// 定时任务页面专属置顶新样式（仅定时任务传 true）：
  /// 苹果置顶/未置顶颜色互换 + 赛博置顶边框 1.25px；其他页面保持默认样式
  final bool newPinnedStyle;

  /// 发光强度 0~1（默认 0.5，对应 demo 滑杆 50）
  final double glowIntensity;

  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// 圆角曲线类型；默认普通圆角，保持既有卡片渲染路径。
  ///
  /// 传 [AppCornerStyle.continuous] 时改用引擎原生连续曲率轮廓，
  /// 此时要求 [borderRadius] 四角半径一致（取左上角半径）。
  final AppCornerStyle cornerStyle;
  final VoidCallback? onTap;

  const CapsuleGlowCard({
    super.key,
    required this.child,
    required this.isCyber,
    this.isPinned = false,
    this.newPinnedStyle = false,
    this.glowIntensity = 0.5,
    this.margin,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.cornerStyle = AppCornerStyle.circular,
    this.onTap,
  });

  /// 连续曲率卡片：全项目列表卡片统一入口。
  ///
  /// 半径 ≤10 或 ≥100（胶囊）时自动回退普通圆角，避免小圆角无收益、
  /// 胶囊轮廓退化。
  const CapsuleGlowCard.continuous({
    super.key,
    required this.child,
    required this.isCyber,
    this.isPinned = false,
    this.newPinnedStyle = false,
    this.glowIntensity = 0.5,
    this.margin,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.onTap,
  }) : cornerStyle = AppCornerStyle.continuous;

  @override
  Widget build(BuildContext context) {
    final double g = glowIntensity.clamp(0.0, 1.0);
    final double boost = isPinned ? 1.25 : 1.0;
    final List<BoxShadow> glow;

    if (isCyber) {
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
        // 外发光
        BoxShadow(
          color: CyberColors.cyan.withValues(
            alpha: (isPinned ? 0.12 : 0.06) * g,
          ),
          blurRadius: 14,
          spreadRadius: 0.5,
        ),
      ];
    } else {
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

    final Color borderColor =
        isCyber
            ? CyberColors.cyan.withValues(alpha: isPinned ? 0.6 : 0.2)
            : Colors.white;
    // 赛博置顶边框：newPinnedStyle 1.25px，默认 1.5px（未置顶均 1px）
    final double borderWidth =
        isCyber ? (isPinned ? (newPinnedStyle ? 1.25 : 1.5) : 1) : 1;

    final Color backgroundColor =
        isCyber
            ? CyberColors.cardBg
            // 苹果：newPinnedStyle 互换（置顶浅 #F7F7F7 / 未置顶灰 #EDEDF2），
            // 默认原样式（未置顶 #F7F7F7 / 置顶 #EDEDF2）
            : (newPinnedStyle
                ? (isPinned ? const Color(0xFFF7F7F7) : const Color(0xFFEDEDF2))
                : (isPinned
                    ? const Color(0xFFEDEDF2)
                    : const Color(0xFFF7F7F7)));

    final double cornerRadius = borderRadius?.topLeft.x ?? 18;
    final bool useContinuous =
        cornerStyle == AppCornerStyle.continuous &&
        cornerRadius > 10 &&
        cornerRadius < 100;
    final ShapeBorder? shape =
        useContinuous
            ? appCornerBorder(
              radius: cornerRadius,
              side: BorderSide(color: borderColor, width: borderWidth),
            )
            : null;

    final Widget content = Container(
      margin: margin,
      padding: padding,
      decoration:
          shape == null
              ? BoxDecoration(
                color: backgroundColor,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: glow,
              )
              : ShapeDecoration(
                shape: shape,
                color: backgroundColor,
                shadows: glow,
              ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: shape,
        borderRadius: shape == null ? borderRadius : null,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
