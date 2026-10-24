import 'package:flutter/material.dart';
import 'package:qinglong_app/base/ui/container_reveal.dart';
import 'package:qinglong_app/base/ui/page_tap_origin.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/wallpaper_background.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 自带壁纸背景 + 统一容器转场的路由。
///
/// 旧行为：继承 CupertinoPageRoute，所有页面从右侧滑入。
/// 新行为：以「最后一次点击命中的视觉卡片矩形」为来源展开页面，
/// 返回时沿同一来源收回；取不到时回退到点击点 64x64 圆角源。
///
/// 注意：继承 [PageRoute] 而不是 CupertinoPageRoute——后者构造函数
/// `assert(opaque)`，而本路由 opaque=false（容器展开需要透出下层页面），
/// debug 模式必崩；转场与右滑均已由 ContainerReveal 自定义，无 Cupertino 依赖。
///
/// 结构与性能：
/// - 壁纸画在展开容器内部（与 ContainerReveal 的 demo 配方一致），
///   随容器从卡片位置一起展开，而不是一块空黑矩形在长；
/// - 页面内容仍包 [PageSnapshot] 整页快照，动画期间走静态位图；
/// - 转场节奏由共用组件 [ContainerReveal] 提供，与账号页精确来源
///   转场完全一致；页面内容在 30%~72% 区间淡入。
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
  }) : _tapOrigin = PageTapOrigin.lastFresh;

  @override
  bool get opaque => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 480);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 480);

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

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Size screen = MediaQuery.sizeOf(context);
    // 容器霜化层：与账号页 ContainerTransformRoute 同配方，跟随用户的卡片
    // 模糊设置。展开前段窗口是一块「逐渐结霜的玻璃面板」（实时模糊旧页面），
    // 配合壁纸渐显，模糊全程连续过渡，不会清晰→模糊硬切。
    final double frostSigma =
        sourceBlurSigma > 0.01
            ? sourceBlurSigma
            : SpUtil.getDouble(spCardBlurSigma, defValue: 10);
    return ContainerReveal(
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
