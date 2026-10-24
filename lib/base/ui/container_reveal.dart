import 'dart:ui';

import 'package:flutter/material.dart';

/// 共享容器转场的「展开容器」：从 [originRect] 连续展开至全屏的裁剪窗口。
///
/// 由 [ContainerTransformRoute]（精确卡片来源）与 WallpaperPageRoute
/// （全局自动识别来源）共用，保证两种入口的视觉节奏完全一致。
///
/// 窗口内层级（从下到上）：
/// 1. 底色：fillT 5%~46% 渐入 [pageBackground]（单独绘制，color 与
///    gradient 同用时 color 会失效，必须分层）；
/// 2. 玻璃模糊：底色近不透明前保留，首帧复刻源卡片材质；
/// 3. 顶部高光 + 描边：随展开消失，起点与源卡片描边一致；
/// 4. 壁纸层 [background]：backgroundT 6%~42% 渐显，按最终全屏尺寸
///    布局、随展开窗口裁切显示（与页面同一屏幕坐标系，不随容器缩放）；
/// 5. 页面内容 [child]：按最终整页尺寸布局，文字不缩放发虚；
///    [pageFade] 非空时叠加淡入（页面无自带入场时使用）；
/// 6. 源卡片内容 [sourceChild]：固定原尺寸原位置，前 14% 淡出。
///
/// 节奏：
/// - 展开：整段 easeInOutCubic，中段最快结尾收住；
/// - 圆角：60% 进度前保持 [sourceRadius]，最后 40% 收至全屏直角；
///   收缩是同一区间反向播放，收回阶段才逐渐恢复圆角；
/// - 背景：容器外整体压暗（18%~75% 至 0.22），突出前景容器。
class ContainerReveal extends StatelessWidget {
  const ContainerReveal({
    super.key,
    required this.animation,
    required this.originRect,
    required this.child,
    this.background,
    this.sourceChild,
    this.sourceRadius = 18,
    this.sourceBlurSigma = 10,
    this.sourceHighlightOpacity = 0.06,
    this.sourceBorderColor = const Color(0xFF00F0FF),
    this.pageBackground = const Color(0xFF080A0D),
    this.pageFade,
    this.reverseFade = false,
  });

  final Animation<double> animation;

  /// 来源矩形（屏幕坐标系）：跳转前捕获的卡片/标题/点击点矩形。
  final Rect originRect;

  /// 目标页面壁纸背景（随窗口渐显；null 则无壁纸层）。
  final Widget? background;

  /// 源卡片内容（不含玻璃材质），展开初期淡出。
  final Widget? sourceChild;

  /// 目标页面内容；容器只负责裁切与淡入，不缩放。
  final Widget child;

  final double sourceRadius;

  /// 源卡片实际模糊值（跟随用户的卡片模糊设置），保证首帧材质一致。
  final double sourceBlurSigma;

  /// 源卡片顶部高光强度（GlassCard 为 0.06，普通卡片/标题为 0）。
  final double sourceHighlightOpacity;

  final Color sourceBorderColor;
  final Color pageBackground;

  /// 页面内容淡入区间；页面自带分段入场（ContainerTransformRoute）时
  /// 传 null 保持全程不透明。
  final Curve? pageFade;

  /// 收回方向内容随窗口收缩逐渐淡出（页面无自带入场动画时必须开启，
  /// 否则内容全程不透明、路由移除瞬间才消失，产生闪烁）。
  /// 展开方向不受影响（保持全不透明，保住卡片实时毛玻璃）。
  final bool reverseFade;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, page) {
        final double t = animation.value;

        final double expandT = Curves.easeInOutCubic.transform(t);
        final Rect rect = Rect.lerp(originRect, Offset.zero & screen, expandT)!;

        final double radiusT = const Interval(
          0.60,
          1.0,
          curve: Curves.easeInOutCubic,
        ).transform(t);
        final double radius = lerpDouble(sourceRadius, 0, radiusT)!;

        // 收回「同步溶解」（reverseFade）：溶解层次在【整个容器】上——
        // 窗口内部（底色/壁纸/页面）在收回期间保持实心，容器作为一个
        // 实心玻璃面板随收缩整体溶解。若只淡出页面层，页面内卡片会因
        // Opacity saveLayer 采样不到容器内壁纸而瞬间失去毛玻璃（实测）。
        // 溶出时机与曲线：前 50% 收缩保持完全不透明；后 50% 窗口已贴近
        // 卡片、移动放缓，用线性匀速溶解——easeOut 类曲线在递减方向会把
        // 大部分变化压进最后几帧（观感=瞬间消失），务必用 linear。
        final bool reversing = animation.status == AnimationStatus.reverse;
        final bool dissolving = reverseFade && reversing;
        final double containerT =
            dissolving
                ? const Interval(0.0, 0.50, curve: Curves.linear).transform(t)
                : 1.0;

        final double fillT =
            dissolving
                ? 1.0
                : const Interval(
                  0.05,
                  0.46,
                  curve: Curves.easeOutCubic,
                ).transform(t);
        final Color baseColor =
            Color.lerp(Colors.transparent, pageBackground, fillT)!;

        final double backgroundT =
            dissolving
                ? 1.0
                : const Interval(
                  0.06,
                  0.42,
                  curve: Curves.easeOutCubic,
                ).transform(t);

        final double borderAlpha =
            0.5 *
            (1 - const Interval(0.0, 0.5, curve: Curves.easeOut).transform(t));

        final double sourceOpacity =
            1 - const Interval(0.0, 0.14, curve: Curves.easeOut).transform(t);

        // 底色变为不透明前保留背景模糊，复刻玻璃卡片的材质。
        final bool withBlur = sourceBlurSigma > 0.01 && fillT < 0.97;

        final double dim =
            0.22 *
            const Interval(0.18, 0.75, curve: Curves.easeOut).transform(t);

        // 页面透明度：
        // - pageFade 非空：页面自带分段入场，随其区间变化；
        // - reverseFade（收回同步溶解）下页面层不再单独淡出——溶解由容器
        //   整体承担，页面保持全不透明，卡片实时毛玻璃采样不受影响。
        final double pageT = pageFade?.transform(t) ?? 1.0;

        // 收回同步溶解：整个面板（含实心底色/壁纸/内容）统一淡出，
        // 卡片毛玻璃在 saveLayer 内采样容器内壁纸，全程保持。
        // 注意 Opacity 必须包在 Positioned【内部】——Positioned 只能作为
        // Stack 的直接子级，外包一层会使定位失效（收回布局错乱）。
        Widget panel = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
              if (withBlur)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: sourceBlurSigma,
                      sigmaY: sourceBlurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(
                            alpha: sourceHighlightOpacity * (1 - fillT),
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.16],
                      ),
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: sourceBorderColor.withValues(
                          alpha: borderAlpha.clamp(0.0, 1.0),
                        ),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // 壁纸层：按最终全屏尺寸布局，随展开窗口渐显。
              if (background != null)
                Positioned(
                  left: -rect.left,
                  top: -rect.top,
                  width: screen.width,
                  height: screen.height,
                  child: IgnorePointer(
                    child: Opacity(opacity: backgroundT, child: background!),
                  ),
                ),
              // 页面按最终整页尺寸布局，通过展开窗口裁切显示。
              // 仅在 pageT < 1 时包 Opacity（收回淡出）——透明度 <1
              // 会产生 saveLayer，展开方向必须保持无包裹以保住
              // 卡片实时毛玻璃。
              Positioned(
                left: -rect.left,
                top: -rect.top,
                width: screen.width,
                height: screen.height,
                child:
                    pageT >= 1.0
                        ? page!
                        : Opacity(opacity: pageT, child: page!),
              ),
              // 源卡片内容固定在原尺寸位置，只做透明度淡出。
              if (sourceChild != null && sourceOpacity > 0.001)
                Positioned(
                  left: 0,
                  top: 0,
                  width: originRect.width,
                  height: originRect.height,
                  child: IgnorePointer(
                    child: Opacity(opacity: sourceOpacity, child: sourceChild!),
                  ),
                ),
            ],
          ),
        );
        if (containerT < 1.0) {
          panel = Opacity(opacity: containerT, child: panel);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            // 背景轻微压暗，突出前景容器；收回溶解时随之淡出露出旧页面。
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: dim)),
            ),
            Positioned.fromRect(rect: rect, child: panel),
          ],
        );
      },
    );
  }
}
