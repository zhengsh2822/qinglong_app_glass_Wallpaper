import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 通用透明毛玻璃卡片组件。
///
/// 设计要点：
/// - 使用 [BackdropFilter] 实现真正的高斯模糊，能透过卡片看到壁纸
/// - 卡片背景为半透明色（不透明度由主题决定），保证文字可读性
/// - 圆角默认 18（与 [AppleColors.radiusCard] 一致）
/// - 顶部 1px 高光边模拟玻璃边缘的光线反射
/// - 柔和阴影传达层级深度
///
/// 主题适配：
/// - 浅色主题（light/white）：白色 70% 不透明 + 浅灰边框
/// - 暗色主题（cyber/dark）：深色 50% 不透明 + 青色微光边框
///
/// 性能要点：
/// - 使用 [OptimizedFrostedGlass]：ClipRect(hardEdge) 限制模糊区域 +
///   RepaintBoundary 隔离重绘 + sigma ≤10 + 可选滚动缓存
/// - sigma 默认 10，列表场景建议 ≤10 以保证滚动流畅
class GlassCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double radius;
  final double sigma;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  /// 是否启用滚动缓存（用于列表中的卡片，滚动期间用静态缓存图替代实时模糊）
  final bool enableScrollCache;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.radius = AppleColors.radiusCard,
    this.sigma = 10,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.boxShadow,
    this.onTap,
    this.borderRadius,
    this.enableScrollCache = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;

    // 全透明，仅保留 BackdropFilter 高斯模糊
    final effectiveColor = color ?? Colors.transparent;

    // 默认边框色：浅色用浅灰，暗色用青色微光
    final effectiveBorder = borderColor ??
        (isDark ? CyberColors.borderGlow : AppleColors.cardBorder);

    final br = borderRadius ?? BorderRadius.circular(radius);

    // 卡片模糊：SP 有设置时覆盖默认 sigma（用户在设置页调节）
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: sigma);

    return Container(
      margin: margin,
      child: OptimizedFrostedGlass(
        sigma: effectiveSigma,
        tintColor: Colors.transparent,
        borderRadius: br,
        enableScrollCache: enableScrollCache,
        child: Container(
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: br,
            border: Border.all(
              color: effectiveBorder,
              width: borderWidth,
            ),
            // 顶部高光：模拟光线照射玻璃边缘
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(isDark ? 0.06 : 0.18),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.15],
            ),
          ),
          padding: padding,
          child: onTap != null
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: br,
                    child: child,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}

/// 列表项毛玻璃卡片。
///
/// 专门用于 task/env/config/subscribe/dependency 等列表页面，
/// 替代原本重复 5 次的「if (isCyber) Container(cardBg+border) else
/// Container(bgSecondary+boxShadow)」模式。
///
/// 特性：
/// - 圆角 18，水平 margin 15（与原项目一致）
/// - 默认 sigma 10（适合列表滚动）
/// - 启用滚动缓存（列表滚动期间用静态缓存图替代实时模糊，提升帧率）
/// - 支持 [onTap]（自动包 Material+InkWell）
class GlassListItemCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double radius;
  final double sigma;
  final VoidCallback? onTap;

  const GlassListItemCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.radius = AppleColors.radiusCard,
    this.sigma = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;

    // 全透明，仅保留 BackdropFilter 高斯模糊
    final effectiveColor = Colors.transparent;

    final effectiveBorder = isDark ? CyberColors.borderGlow : AppleColors.cardBorder;

    // 卡片模糊：SP 有设置时覆盖默认 sigma（用户在设置页调节）
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: sigma);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 15),
      child: OptimizedFrostedGlass(
        sigma: effectiveSigma,
        tintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        // 关闭滚动缓存：滚动/下拉刷新时保持实时毛玻璃，避免缓存图导致卡片样式变化
        enableScrollCache: false,
        child: Container(
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: effectiveBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(isDark ? 0.05 : 0.15),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.15],
            ),
          ),
          padding: padding,
          child: onTap != null
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(radius),
                    child: child,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}

/// 页面级高斯模糊背景层。
///
/// 用于定时任务/环境变量/配置文件/依赖管理等列表页面，
/// 在壁纸之上、内容之下加一层高斯模糊 + 半透明底色，
/// 让页面不会全透明（壁纸过于清晰影响内容可读性）。
///
/// 用法：包裹在 Scaffold body 外层
/// ```dart
/// body: GlassPageBackground(
///   child: NestedScrollView(...),
/// ),
/// ```
///
/// 性能要点：
/// - sigma 默认 8，列表场景够用且不影响滚动流畅度
/// - 用 Stack 分层：底层 BackdropFilter 模糊壁纸，上层放实际内容
///   内容不被模糊，只有背景壁纸被模糊
class GlassPageBackground extends StatelessWidget {
  final Widget child;
  final double sigma;
  final Color? color;

  const GlassPageBackground({
    super.key,
    required this.child,
    this.sigma = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 不使用 BackdropFilter：BackdropFilter 会跨路由采样下层页面内容，
    // 导致下层路由也被模糊。壁纸模糊已由 WallpaperPageRoute 中的
    // WallpaperBackground(overrideBlurSigma) 在路由级别完成，
    // 这里只需提供半透明底色即可。
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: color ?? Colors.transparent,
          ),
        ),
        child,
      ],
    );
  }
}

/// 顶部 AppBar 区域的毛玻璃容器。
///
/// 用于替代原项目 [QlAppBar] 中的纯色 appBarBg 渐变，
/// 实现"顶部色块也使用透明毛玻璃"的需求。
class GlassAppBarContainer extends ConsumerWidget {
  final Widget child;
  final double sigma;

  const GlassAppBarContainer({
    super.key,
    required this.child,
    this.sigma = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;

    // 全透明，仅保留 BackdropFilter 高斯模糊
    final effectiveColor = Colors.transparent;

    final effectiveBorder = isDark ? CyberColors.borderGlow : AppleColors.cardBorder;

    // 卡片模糊：SP 有设置时覆盖默认 sigma（用户在设置页调节）
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: sigma);

    return OptimizedFrostedGlass(
      sigma: effectiveSigma,
      tintColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: effectiveColor,
          border: Border(
            bottom: BorderSide(color: effectiveBorder, width: 0.5),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(isDark ? 0.06 : 0.18),
              Colors.white.withOpacity(0.0),
            ],
            stops: const [0.0, 0.5],
          ),
        ),
        child: child,
      ),
    );
  }
}
