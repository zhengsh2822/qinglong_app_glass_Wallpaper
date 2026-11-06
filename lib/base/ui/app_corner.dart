import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圆角曲线类型。
enum AppCornerStyle {
  /// 普通圆弧圆角：直边与圆弧交界处曲率跳变（G1）。
  circular,

  /// 连续曲率圆角：等价 SwiftUI `.continuous`，曲率从 0 平滑过渡（G2）。
  ///
  /// 由 Flutter 引擎原生 `RSuperellipse` 绘制，不自研路径、不做裁剪缓存。
  continuous,
}

/// 低于该半径时，连续曲率与普通圆角的视觉差异不可辨，统一走普通圆角。
const double _kContinuousMinRadius = 10.0;

/// 连续曲率的唯一策略入口：按半径与尺寸决定是否值得使用连续曲率。
///
/// - 半径 ≤ 10：视觉无收益，返回 [AppCornerStyle.circular]。
/// - 半径达到短边一半：已是胶囊，连续曲率会退化，返回
///   [AppCornerStyle.circular]。
/// - 其余情况返回 [AppCornerStyle.continuous]。
AppCornerStyle appCornerStyleFor(double radius, Size size) {
  if (radius <= _kContinuousMinRadius) {
    return AppCornerStyle.circular;
  }
  if (radius >= math.min(size.width, size.height) / 2) {
    return AppCornerStyle.circular;
  }
  return AppCornerStyle.continuous;
}

/// 统一圆角入口：按 [style] 返回引擎原生的连续曲率或普通圆角边框。
///
/// 选用 [RoundedSuperellipseBorder] 而不是自研折线路径：路径由引擎
/// `Path.addRSuperellipse` 构造，天然按设备像素栅格化，无需应用层
/// 缓存、分段数预算或 devicePixelRatio 补偿。
OutlinedBorder appCornerBorder({
  double radius = 0,
  BorderRadius? borderRadius,
  AppCornerStyle style = AppCornerStyle.continuous,
  BorderSide side = BorderSide.none,
}) {
  final BorderRadius br =
      borderRadius ?? BorderRadius.circular(radius < 0 ? 0 : radius);
  final bool isZero =
      borderRadius == null ? radius <= 0 : borderRadius == BorderRadius.zero;
  if (isZero) {
    return RoundedRectangleBorder(side: side);
  }
  if (style == AppCornerStyle.circular) {
    return RoundedRectangleBorder(borderRadius: br, side: side);
  }
  return RoundedSuperellipseBorder(borderRadius: br, side: side);
}
