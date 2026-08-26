import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 毛玻璃卡片组件
///
/// 使用 BackdropFilter 实现高斯模糊效果，叠加半透明背景色，
/// 营造赛博朋克风格的毛玻璃质感。
///
/// 用法：
/// ```dart
/// CyberGlassCard(
///   child: ...,
///   borderRadius: 12,
/// )
/// ```
class CyberGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double blurSigma;
  final Color? backgroundColor;
  final Border? border;
  final VoidCallback? onTap;

  const CyberGlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 18,
    this.margin,
    this.padding,
    this.blurSigma = 10,
    this.backgroundColor,
    this.border,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: blurSigma);
    return Container(
      margin: margin,
      // 统一毛玻璃封装：sigma<=0 时自动退化为纯色（无 BackdropFilter）
      child: OptimizedFrostedGlass(
        sigma: effectiveSigma,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            // 半透明白色叠加，产生毛玻璃质感
            color: backgroundColor ?? const Color(0x20FFFFFF),
            borderRadius: BorderRadius.circular(borderRadius),
            border:
                border ??
                Border.all(color: CyberColors.borderGlow, width: 0.5),
          ),
          padding: padding,
          child:
              onTap != null
                  ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: child,
                    ),
                  )
                  : child,
        ),
      ),
    );
  }
}
