import 'package:flutter/cupertino.dart';
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
          ),
        ),
        Positioned.fill(child: page),
      ],
    );
  }
}
