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
  /// 最近一次进入收回中的本类路由（由 ContainerCollapseTracker 维护），
  /// 供「收回中重开同来源」无缝续播（与展开打断对称）。
  static ContainerTransformRoute? _collapsing;

  /// ContainerCollapseTracker 维护入口（_collapsing 为库私有，跨库经此访问）
  static void trackCollapsing(ContainerTransformRoute? route) {
    _collapsing = route;
  }

  /// 路由移除时清理追踪（仅当仍指向该路由）
  static void untrackCollapsing(ContainerTransformRoute? route) {
    if (identical(_collapsing, route)) _collapsing = null;
  }

  /// 收回被打断重开时的起始进度（0~1，构造时从旧路由捕获）：
  /// createAnimationController 设为初值，didPush 的 forward() 从此续播。
  double _initialRevealProgress = 0;

  /// 被本路由接管的收回中旧路由（install 时同帧移除，避免双窗口叠影）。
  ContainerTransformRoute? _interrupted;

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
  }) {
    // 收回打断：同来源（源矩形相等）的本类路由正在收回 → 新路由从旧进度
    // 无缝续播展开。页面自带分段入场动画直接吃路由动画，从中间值续播即
    // 内容入场同步续播，天然无缝。
    final ContainerTransformRoute? collapsing = _collapsing;
    final Animation<double>? anim = collapsing?.animation;
    if (collapsing != null &&
        anim != null &&
        anim.status == AnimationStatus.reverse &&
        anim.value > 0 &&
        collapsing.sourceRect == sourceRect) {
      _initialRevealProgress = anim.value;
      _interrupted = collapsing;
    }
  }

  @override
  AnimationController createAnimationController() {
    final AnimationController controller = super.createAnimationController();
    // createAnimationController 在 install() 阶段执行，早于 didPush() 的
    // forward()——先设初值，展开即从旧收回位置续播
    if (_initialRevealProgress > 0) {
      controller.value = _initialRevealProgress.clamp(0.0, 1.0);
    }
    return controller;
  }

  @override
  void install() {
    super.install();
    if (_interrupted != null) {
      // push 与 removeRoute 同帧：新路由首帧即渲染旧收回位置的窗口，
      // 旧路由立刻消失，视觉零差异。
      navigator?.removeRoute(_interrupted!);
      _interrupted = null;
    }
  }

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
    // 收回阶段整页 IgnorePointer：正在收回的面板不应再吃输入，让点击穿透
    // 到下层源卡片，从卡片重新打开即可打断收回；展开与静止阶段保持可交互
    //（展开中可打断返回）。
    return IgnorePointer(
      ignoring: animation.status == AnimationStatus.reverse,
      child: ContainerReveal(
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
      ),
    );
  }
}

/// 注册到 MaterialApp.navigatorObservers：记录收回中的 ContainerTransformRoute，
/// 供「收回中重开同来源」无缝续播（回收打断，与展开打断对称）。
///
/// 展开支持打断是 Flutter 原生能力（推入中 pop，controller 从当前值反向）；
/// 收回原本不行——收回中的页面盖在下层上吃输入，重开也是双窗口叠影。
/// 配合路由构造器的同来源检测（initialRevealProgress + install 时
/// removeRoute 旧路由）实现无缝续播。
class ContainerCollapseTracker extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ContainerTransformRoute) {
      ContainerTransformRoute.trackCollapsing(route);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ContainerTransformRoute.untrackCollapsing(
      route is ContainerTransformRoute ? route : null,
    );
  }
}
