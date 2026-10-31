import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 毛玻璃效果全局开关（bool，默认 true=开启）
///
/// - true  = 透明背景 + BackdropFilter 高斯模糊（毛玻璃效果）
/// - false = 纯色背景（不透明），不使用 BackdropFilter（GPU 零开销）
///
/// 用户可在「系统设置 → 通用功能 → 毛玻璃效果」中开关。
final blurEffectProvider = StateProvider<bool>((ref) {
  return SpUtil.getBool(spBlurEffect, defValue: true);
});

/// 设置毛玻璃开关并持久化
Future<void> setBlurEffect(WidgetRef ref, bool enabled) async {
  await SpUtil.putBool(spBlurEffect, enabled);
  ref.read(blurEffectProvider.notifier).state = enabled;
}

/// 毛玻璃默认模糊半径（开启状态下使用）
const double kDefaultBlurSigma = 20.0;

/// 可复用的毛玻璃容器组件
///
/// 根据 [blurEffectProvider] 自动决定渲染方式：
/// - 开启：ClipRRect + BackdropFilter(sigma=20) + 半透明背景
/// - 关闭：纯色背景（不透明 1.0），GPU 零模糊开销
///
/// [backgroundColor] 为毛玻璃开启时的半透明背景色；
/// [solidBackgroundColor] 为毛玻璃关闭时的纯色背景（可选，默认取 backgroundColor 的不透明版本）。
class GlassContainer extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final Color? solidBackgroundColor;
  final double maxBlurSigma;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.backgroundColor,
    this.solidBackgroundColor,
    this.maxBlurSigma = kDefaultBlurSigma,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(blurEffectProvider);

    if (!enabled) {
      // 关闭：纯色模式（不透明度 1.0），GPU 零模糊开销
      return Container(
        decoration: BoxDecoration(
          color: solidBackgroundColor ?? _toSolid(backgroundColor),
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
          boxShadow: boxShadow,
        ),
        child: child,
      );
    }

    // 开启：毛玻璃模式 ClipRRect + BackdropFilter
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: kDefaultBlurSigma,
          sigmaY: kDefaultBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border,
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }

  /// 将半透明颜色转为不透明版本（alpha=1.0）
  Color _toSolid(Color color) {
    return color.withValues(alpha: 1.0);
  }
}

/// 可选的 BackdropFilter 包装器
///
/// 根据 [blurEffectProvider] 决定是否对 child 应用 BackdropFilter 模糊。
/// 关闭时直接返回 child（纯色），开启时包裹 BackdropFilter。
class OptionalBlur extends ConsumerWidget {
  final Widget child;
  final double sigma;

  const OptionalBlur({super.key, required this.child, required this.sigma});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(blurEffectProvider);
    if (!enabled) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
