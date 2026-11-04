import 'package:flutter/material.dart';

import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/container_reveal.dart';
import 'package:qinglong_app/base/ui/page_tap_origin.dart';
import 'package:qinglong_app/base/ui/wallpaper_background.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 自带壁纸背景 + 统一容器转场的路由。
///
/// 页面转场动画二选一（SP [spClassicPageTransition]，构造时读一次本次路由
/// 生命周期内不变）：
/// - false（默认）：容器展开——以「最后一次点击命中的视觉卡片矩形」为来源
///   展开页面，返回时沿同一来源收回；取不到时回退到点击点 64x64 圆角源。
/// - true：经典右侧滑入（Cupertino 同款节奏），并向下层页面注入
///   「左移 30% + 压暗 0.28」视差变换（delegatedTransition）。
///
/// 注意：继承 [PageRoute] 而不是 CupertinoPageRoute——后者构造函数
/// `assert(opaque)`，而本路由 opaque=false（容器展开需要透出下层页面），
/// debug 模式必崩；转场与右滑均已由 ContainerReveal 自定义，无 Cupertino 依赖。
///
/// 收回可打断（与展开打断对称）：
/// - 收回阶段整页 IgnorePointer 之外，[ContainerCollapseTracker] 记录收回中的
///   本类路由；同来源卡片在收回完成前被重新点击时，新路由从旧收回进度
///   无缝续播（install 时同帧移除旧路由，避免双窗口叠影）。
class WallpaperPageRoute<T> extends PageRoute<T> {
  final double? blurSigma;
  final Color? blurTintColor;

  /// 显式指定的来源（预留：自动识别不准时可传精确矩形）。
  final Rect? sourceRect;
  final Widget? sourceChild;
  final double sourceRadius;
  final double sourceBlurSigma;
  final double sourceHighlightOpacity;
  final Color sourceBorderColor;

  @override
  final String? title;

  final WidgetBuilder builder;

  /// 是否走经典右侧滑入（构造时读一次 SP，本次路由生命周期内不变）。
  final bool _classic;

  /// 构造时捕获的点击来源（由根部 PageTapScope 记录）。
  final TapOriginData? _tapOrigin;

  /// 最近一次进入收回中的本类路由（由 [ContainerCollapseTracker] 维护），
  /// 供「收回中重开同来源」无缝续播。
  static WallpaperPageRoute<dynamic>? _collapsing;

  /// 收回被打断重开时的起始进度（0~1，构造时从旧路由捕获）：
  /// createAnimationController 设为初值，didPush 的 forward() 从此续播。
  double _initialRevealProgress = 0;

  /// 被本路由接管的收回中旧路由（install 时同帧移除，避免双窗口叠影）。
  WallpaperPageRoute<dynamic>? _interrupted;

  /// 来源标识：同卡片重开判定用（Rect/Offset 均为值相等）。
  Object? get _originKey => sourceRect ?? _tapOrigin?.rect ?? _tapOrigin?.point;

  WallpaperPageRoute({
    required this.builder,
    this.title,
    super.settings,
    super.fullscreenDialog = false,
    this.blurSigma,
    this.blurTintColor,
    this.sourceRect,
    this.sourceChild,
    this.sourceRadius = 18,
    this.sourceBlurSigma = 0,
    this.sourceHighlightOpacity = 0,
    this.sourceBorderColor = Colors.transparent,
  }) : _classic = SpUtil.getBool(spClassicPageTransition, defValue: false),
       _tapOrigin = PageTapOrigin.lastFresh {
    // 收回打断：同来源的容器展开正在收回 → 新路由从旧进度无缝续播
    final WallpaperPageRoute<dynamic>? collapsing = _collapsing;
    final Animation<double>? anim = collapsing?.animation;
    if (collapsing != null &&
        !collapsing._classic &&
        anim != null &&
        anim.status == AnimationStatus.reverse &&
        anim.value > 0 &&
        collapsing._originKey == _originKey) {
      _initialRevealProgress = anim.value;
      _interrupted = collapsing;
    }
  }

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration =>
      _classic
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 480);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => false;

  @override
  void install() {
    super.install();
    if (_interrupted != null) {
      // push 与 removeRoute 同帧：新路由首帧即渲染旧收回位置的窗口，
      // 旧路由立刻消失，视觉零差异
      navigator?.removeRoute(_interrupted!);
      _interrupted = null;
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // 页面全程实时渲染，不做快照、不加透明度包裹。两个硬约束：
    // 1) PageSnapshot 位图无法携带 BackdropFilter 模糊——离屏截图的画布里
    //    毛玻璃采样不到背景，转场期间会看到「展开完模糊才出现」的跳变；
    // 2) 页面层的渐显 Opacity(<1) 会产生 saveLayer 隔离，卡片模糊同样只能
    //    采到隔离层内的空内容，透明度到 1.0（完全展开）才恢复。
    // 代价是转场期间毛玻璃实时渲染（成本与首页滚动同级，容器转场不缩放
    // 页面，可承受）；壁纸仍在 ContainerReveal 的壁纸层随窗口渐显。
    return builder(context);
  }

  /// 经典模式：向下层页面注入「左移 30% + 压暗 0.28」视差变换（用户选型，
  /// CupertinoPageTransition.delegatedTransition 同款机制）。delegated 由
  /// 上层路由提供下层变换，与下层页面自身路由类型无关；SDK 会自动抑制下层
  /// 原有 secondary 变换，不会双重叠加。容器展开模式返回 null，下层保持
  /// 原行为（容器转场不依赖下层变换）。
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _classic ? _classicDelegatedTransition : null;

  static Widget? _classicDelegatedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.30, 0),
      ).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.linearToEaseOut,
          reverseCurve: Curves.easeInToLinear,
        ),
      ),
      transformHitTests: false,
      child: AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (context, page) {
          final double t = Curves.easeOut.transform(secondaryAnimation.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              page!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.28 * t),
                  ),
                ),
              ),
            ],
          );
        },
        child: child,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 经典模式：右侧滑入/滑出（复刻 CupertinoPageRoute 节奏），返回时
    // 随动画反向自动滑回右侧，无需单独处理 pop
    if (_classic) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.linearToEaseOut),
        ),
        child: child,
      );
    }

    final Size screen = MediaQuery.sizeOf(context);
    // 容器霜化层：与账号页 ContainerTransformRoute 同配方，跟随用户的卡片
    // 模糊设置。展开前段窗口是一块「逐渐结霜的玻璃面板」（实时模糊旧页面），
    // 配合壁纸渐显，模糊全程连续过渡，不会清晰→模糊硬切。
    final double frostSigma =
        sourceBlurSigma > 0.01
            ? sourceBlurSigma
            : SpUtil.getDouble(spCardBlurSigma, defValue: 10);
    // 收回阶段整页 IgnorePointer：正在溶解的面板不应再吃输入，否则收回
    // 期间点下层页面无响应（表现=收回不支持打断）。展开与静止阶段保持
    // 可交互（展开中可打断返回）。
    return IgnorePointer(
      ignoring: animation.status == AnimationStatus.reverse,
      child: ContainerReveal(
        animation: animation,
        originRect: _resolveOrigin(screen),
        background: WallpaperBackground(
          overrideBlurSigma: blurSigma,
          overrideBlurTint: blurTintColor,
          cacheBlur: true,
        ),
        sourceChild: sourceChild,
        sourceRadius: sourceRadius,
        sourceBlurSigma: frostSigma,
        sourceHighlightOpacity: sourceHighlightOpacity,
        sourceBorderColor: sourceBorderColor,
        // pageFade 保持 null：页面层透明度会破坏卡片实时模糊（见 buildPage 注释），
        // 内容在展开窗口内以全透明度直接呈现。
        // reverseFade：收回方向内容随窗口收缩逐渐淡出，避免路由移除瞬间
        // 内容才消失产生闪烁（页面无自带入场动画，需容器代管收回淡出）。
        reverseFade: true,
        child: child,
      ),
    );
  }

  Rect _resolveOrigin(Size screen) {
    final Rect screenRect = Offset.zero & screen;

    final Rect? explicit = sourceRect;
    if (explicit != null) {
      final Rect clipped = explicit.intersect(screenRect);
      if (!clipped.isEmpty) return clipped;
    }

    final Rect? cardRect = _tapOrigin?.rect;
    if (cardRect != null) {
      final Rect clipped = cardRect.intersect(screenRect);
      if (!clipped.isEmpty) return clipped;
    }

    final Offset? point = _tapOrigin?.point;
    if (point != null) {
      final Rect rect = Rect.fromCenter(
        center: point,
        width: 64,
        height: 64,
      ).intersect(screenRect);
      if (!rect.isEmpty) return rect;
    }

    return Rect.fromCenter(
      center: screen.center(Offset.zero),
      width: 64,
      height: 64,
    );
  }
}

/// 注册到每账号 Navigator.navigatorObservers：记录收回中的本类路由，
/// 供「收回中重开同来源」无缝续播（收回打断，与展开打断对称）。
///
/// 展开支持打断是 Flutter 原生能力（推入中 pop，controller 从当前值反向）；
/// 收回原本不行——收回中的页面盖在下层上吃输入，重开也是双窗口叠影。
/// 配合 WallpaperPageRoute 构造器的同来源检测（initialRevealProgress +
/// install 时 removeRoute 旧路由）实现无缝续播。
class ContainerCollapseTracker extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is WallpaperPageRoute<dynamic> && !route._classic) {
      WallpaperPageRoute._collapsing = route;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(WallpaperPageRoute._collapsing, route)) {
      WallpaperPageRoute._collapsing = null;
    }
  }
}
