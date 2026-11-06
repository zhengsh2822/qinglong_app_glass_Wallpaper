import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/app_corner.dart';
import 'package:qinglong_app/base/ui/capsule_glow_card.dart';

/// "我的"页面通用卡片
///
/// 基于可复用组件 [CapsuleGlowCard]（高光内发光胶囊卡片）实现，未置顶样式：
/// - cyber 模式: CyberColors.cardBg + 青色发光边框 + 青色内发光
/// - 非 cyber 模式: 纯色 #F7F7F7 背景 + 纯白边框 + 浅灰顶部高光 + 纯白内发光
///
/// 圆角统一为 [AppleColors.radiusCard] (18)，水平 margin 统一为
/// [AppleColors.spaceMd] (16)。
class OtherPageCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// 圆角曲线类型；默认普通圆角，设置页可按需切换连续曲率。
  final AppCornerStyle cornerStyle;

  const OtherPageCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.cornerStyle = AppCornerStyle.circular,
  });

  /// 连续曲率圆角卡片：全项目统一使用，其他入口可按需回退普通圆角。
  const OtherPageCard.continuous({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
  }) : cornerStyle = AppCornerStyle.continuous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;

    return CapsuleGlowCard(
      isCyber: isCyber,
      isPinned: false,
      margin:
          margin ?? const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      padding: padding,
      borderRadius: const BorderRadius.all(
        Radius.circular(AppleColors.radiusCard),
      ),
      cornerStyle: cornerStyle,
      onTap: onTap,
      child: child,
    );
  }
}
