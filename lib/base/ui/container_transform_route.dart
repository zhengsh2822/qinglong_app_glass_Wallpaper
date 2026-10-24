import 'package:flutter/material.dart';

import 'container_reveal.dart';

/// 「共享容器」转场路由（账号卡片 → 切换账号页）。
///
/// 交互过程（进入与返回时长一致，返回动画完整可见）：
/// 1. 点击源卡片后，调用方先隐藏原卡片，并记录它的全局矩形 [sourceRect]；
/// 2. 路由首帧用同尺寸、同圆角、同青色描边的容器盖住原位置，
///    容器内绘制源卡片内容 [sourceChild]，因此没有跳变；
/// 3. 容器由卡片矩形连续展开至整屏，展开窗口内直接裁切「最终整页布局」，
///    文字不会缩放发虚，页面内容按各自区间渐显、上移归位；
/// 4. 返回时容器收回卡片矩形，源卡片内容最后 14% 淡回，路由移除后
///    调用方恢复原卡片，视觉上无缝衔接。
///
/// 容器内部层级与节奏由共用组件 [ContainerReveal] 实现；
/// 页面自带分段入场动画（pageBuilder 拿 animation 自己做），故 pageFade 为 null。
class ContainerTransformRoute extends PageRoute<void> {
  ContainerTransformRoute({
    required this.sourceRect,
    required this.pageBuilder,
    this.sourceChild,
    this.background,
    this.sourceRadius = 18,
    this.sourceBlurSigma = 10,
    this.sourceHighlightOpacity = 0.06,
    this.sourceBorderColor = const Color(0xFF00F0FF),
    this.pageBackground = const Color(0xFF080A0D),
    this.duration = const Duration(milliseconds: 480),
    super.settings,
  });

  /// 源卡片在屏幕坐标系中的矩形（跳转前捕获）。
  final Rect sourceRect;

  /// 源卡片内容（不含玻璃背景），用于展开初期的淡出。
  final Widget? sourceChild;

  /// 目标页面的壁纸背景（壁纸版必须传入，随容器展开渐显）。
  final Widget? background;

  /// 目标页面构建器；页面需要自行使用 animation 做分段入场。
  final Widget Function(BuildContext context, Animation<double> animation)
  pageBuilder;

  final double sourceRadius;

  /// 源卡片实际模糊值（跟随用户的卡片模糊设置），保证首帧材质一致。
  final double sourceBlurSigma;

  /// 源卡片顶部高光强度（GlassCard 为 0.06，普通账号卡片为 0）。
  final double sourceHighlightOpacity;

  /// 源卡片描边色（顶部标题条等无描边场景传 Colors.transparent）。
  final Color sourceBorderColor;

  final Color pageBackground;
  final Duration duration;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return pageBuilder(context, animation);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ContainerReveal(
      animation: animation,
      originRect: sourceRect,
      background: background,
      sourceChild: sourceChild,
      sourceRadius: sourceRadius,
      sourceBlurSigma: sourceBlurSigma,
      sourceHighlightOpacity: sourceHighlightOpacity,
      sourceBorderColor: sourceBorderColor,
      pageBackground: pageBackground,
      child: child,
    );
  }
}
