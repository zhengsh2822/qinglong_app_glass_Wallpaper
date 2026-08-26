import 'package:flutter/cupertino.dart';
import 'package:qinglong_app/base/ui/page_snapshot.dart';
import 'package:qinglong_app/base/ui/wallpaper_background.dart';

/// 自带壁纸背景的路由。
///
/// 解决：全局壁纸放在 Navigator 之下，push 二级页面时透明 Scaffold 让
/// 下层路由内容透出，导致显示错位；BackdropFilter 模糊的也是下层路由
/// 内容而非壁纸。
///
/// 原理：在 [buildPage] 时外层包 `Stack([WallpaperBackground, page])`，
/// 让每个路由都有独立的壁纸背景。push 动画时背景随页面一起滑入，
/// 遮盖下层路由，彻底消除透明层级问题。
///
/// 可选 [blurSigma] / [blurTintColor]：传入后路由级壁纸自带模糊和底色，
/// 完全遮盖下层路由，避免下层透出。
/// 实际模糊值由 WallpaperBackground 从 SP[spBgBlurSigma] 实时读取，
/// 用户可在"模糊调节"设置页调节，实时生效。
///
/// 性能：
/// 1. 二级页面统一 cacheBlur（非实时模糊）——背景模糊层用 RepaintBoundary
///    隔离缓存，push/pop 动画期间复用缓存图层，不再每帧重算全屏高斯模糊
/// 2. 整页快照（[PageSnapshot]）——动画期间把整页截成静态位图显示，
///    子组件 setState 不再触发 BackdropFilter 计算/整页 paint 链路
/// 3. 卡片"图层级缓存"——OptimizedFrostedGlass 外层 RepaintBoundary
///    隔离模糊层，动画期间复用缓存模糊层（详见 optimized_frosted_glass.dart）
///
/// PageSnapshot 监听路由自己的 animation 决定截屏时机，**不会触发下层
/// 路由误截图**（避免"下层页面突然变模糊再恢复"的视觉问题）。
///
/// 用法：全局替换 `CupertinoPageRoute` / `MaterialPageRoute` 为本类，
/// 参数完全兼容。
class WallpaperPageRoute<T> extends CupertinoPageRoute<T> {
  final double? blurSigma;
  final Color? blurTintColor;

  WallpaperPageRoute({
    required super.builder,
    super.title,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    this.blurSigma,
    this.blurTintColor,
  });

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = super.buildPage(context, animation, secondaryAnimation);
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(
          child: WallpaperBackground(
            overrideBlurSigma: blurSigma,
            overrideBlurTint: blurTintColor,
            // 二级页面统一非实时模糊：模糊层 RepaintBoundary 缓存，
            // 解决 push 动画期间每帧重算全屏模糊导致的掉帧（视觉不变）
            cacheBlur: true,
          ),
        ),
        // 整页一次性快照：PageSnapshot 监听自己的 animation.status
        // 决定截屏时机，仅对当前路由负责，不会触发下层路由误截图
        Positioned.fill(child: PageSnapshot(animation: animation, child: page)),
      ],
    );
  }
}
