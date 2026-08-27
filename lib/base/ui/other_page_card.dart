import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/glow_card.dart';

/// "我的"页面通用卡片（壁纸版）
///
/// 基于可复用组件 [CapsuleGlowCard]（高光内发光胶囊卡片）实现：
/// - 深色模式（cyber/dark）：青色发光边框 + 青色内发光 + 青色外发光，
///   底层毛玻璃保持全局壁纸透出
/// - 浅色模式（兜底）：白色边框 + 浅灰顶部高光 + 白色内发光
///
/// 圆角统一为 [AppleColors.radiusCard] (18)，水平 margin 统一为
/// [AppleColors.spaceMd] (16)。
class OtherPageCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const OtherPageCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CapsuleGlowCard(
      glowIntensity: 0.5,
      margin:
          margin ??
          const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      padding: padding,
      borderRadius: const BorderRadius.all(
        Radius.circular(AppleColors.radiusCard),
      ),
      onTap: onTap,
      child: child,
    );
  }
}