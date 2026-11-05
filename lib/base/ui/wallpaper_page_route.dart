import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show TickerFuture;

import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/container_reveal.dart';
import 'package:qinglong_app/base/ui/page_tap_origin.dart';
import 'package:qinglong_app/base/ui/wallpaper_background.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/ql_debug_log.dart';

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

  // 经典模式边缘侧滑返回状态
  bool _classicBackDragging = false;
  double? _classicBackDragVelocity;

  /// 构造时捕获的点击来源（由根部 PageTapScope 记录）。
  final TapOriginData? _tapOrigin;

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
       _tapOrigin = PageTapOrigin.lastFresh;

  @override
  TickerFuture didPush() {
    QlDebugLog.write('[RTE] didPush classic=$_classic');
    return super.didPush();
  }

  @override
  bool didPop(dynamic result) {
    QlDebugLog.write('[RTE] didPop classic=$_classic');
    return super.didPop(result);
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    QlDebugLog.write('[RTE] didPopNext classic=$_classic');
    super.didPopNext(nextRoute);
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
    // 经典模式没有 ContainerReveal 壳——页面自身透明，必须垫壁纸背景层
    // （跟随路由的 blurSigma/blurTint 参数），否则页面全黑无背景。
    if (_classic) {
      return Stack(
        fit: StackFit.expand,
        children: [
          WallpaperBackground(
            overrideBlurSigma: blurSigma,
            overrideBlurTint: blurTintColor,
            cacheBlur: true,
          ),
          builder(context),
        ],
      );
    }
    return builder(context);
  }

  /// 经典模式：向下层页面注入「左移 30% + 压暗 0.28」视差变换（用户选型，
  /// CupertinoPageTransition.delegatedTransition 同款机制）。delegated 由
  /// 上层路由提供下层变换，与下层页面自身路由类型无关；SDK 会自动抑制下层
  /// 原有 secondary 变换，不会双重叠加。容器展开模式返回 null，下层保持
  /// 原行为（容器转场不依赖下层变换）。
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _classic
          ? (
            context,
            animation,
            secondaryAnimation,
            allowSnapshotting,
            child,
          ) => _classicDelegatedTransition(
            context,
            animation,
            secondaryAnimation,
            allowSnapshotting,
            child,
          )
          : null;

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
      // 经典模式补边缘侧滑返回手势（CupertinoPageRoute 同款体验）：
      // 自定义 SlideTransition 不含 Cupertino 的 BackGestureDetector，
      // 不补的话二级页无法侧滑返回（返回键仍可用）
      final Size screen = MediaQuery.sizeOf(context);
      final double dragW = 20.0;
      return Stack(
        fit: StackFit.expand,
        children: [
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.linearToEaseOut),
            ),
            child: child,
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: dragW,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _classicBackDragStart,
              onHorizontalDragUpdate: (d) => _classicBackDragUpdate(d, screen),
              onHorizontalDragEnd: _classicBackDragEnd,
            ),
          ),
        ],
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
    // pageBackground：收回完成帧（animation=0）的容器底色。路由移除后该帧
    // 因合成层清理延迟还会显示 ~0.3s——垫上 scaffoldBackgroundColor 后完成帧
    // 与首页卡片视觉一致，残留不可见（主题版同款参数，壁纸版此前漏传导致
    // 二级页内容透在壁纸上显形 = "卡片闪烁/残留"）。
    final Color pageBackground = Theme.of(context).scaffoldBackgroundColor;
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
        pageBackground: pageBackground,
        // pageFade 保持 null：页面层透明度会破坏卡片实时模糊（见 buildPage 注释），
        // 内容在展开窗口内以全透明度直接呈现。
        // reverseFade：收回方向内容随窗口收缩逐渐淡出，避免路由移除瞬间
        // 内容才消失产生闪烁（页面无自带入场动画，需容器代管收回淡出）。
        reverseFade: true,
        child: child,
      ),
    );
  }

  // ── 经典模式边缘侧滑返回 ────────────────────────────────
  void _classicBackDragStart(DragStartDetails details) {
    if (!((_classicBackDragVelocity ?? 0) != 0)) {
      _classicBackDragVelocity = 0;
    }
    _classicBackDragging = true;
    navigator?.didStartUserGesture();
  }

  void _classicBackDragUpdate(DragUpdateDetails details, Size screen) {
    if (!_classicBackDragging) return;
    final double delta = details.delta.dx / screen.width;
    controller?.value = ((controller?.value ?? 1) - delta).clamp(0.0, 1.0);
    _classicBackDragVelocity = details.delta.dx;
  }

  void _classicBackDragEnd(DragEndDetails details) {
    if (!_classicBackDragging) return;
    _classicBackDragging = false;
    final double v = controller?.value ?? 1;
    final bool shouldPop = v < 0.5 || details.velocity.pixelsPerSecond.dx > 500;
    if (shouldPop) {
      navigator?.pop();
    } else {
      // 回弹：未过半则滑回原位
      controller?.animateTo(
        1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
    navigator?.didStopUserGesture();
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
