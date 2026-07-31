import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/services/wallpaper_service.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 可复用的壁纸背景组件。
///
/// 监听 [WallpaperService]，自动 rebuild。
/// 渲染层级（从下到上）：
/// 1. 底层背景（gradient / solid / local image / network image）
/// 2. 高斯模糊层（[ImageFiltered]，blurSigma > 0 时启用）
/// 3. 黑色蒙层（dimOpacity > 0 时启用，增强文字可读性）
///
/// 性能要点：
/// - 不用 RepaintBoundary：背景在 Stack 底层不在 ListView 里，滚动不会
///   触发 rebuild；若包 RepaintBoundary 会隔离成独立图层，导致上层
///   GlassCard 的 BackdropFilter 在滚动时无法实时采样背景 → 滑动透明
/// - 模糊层用 [ImageFilter.blur] + ImageFiltered，对子 widget 自身渲染
///   结果做模糊，不采样 layer——避免跨路由模糊到下层路由的 page 内容
/// - 网络图片先 Image.network 预览，后台下载到本地后切 Image.file
class WallpaperBackground extends StatelessWidget {
  /// 路由级覆盖模糊值，传入后忽略全局配置的 blurSigma。
  final double? overrideBlurSigma;

  /// 路由级覆盖底色，传入后在模糊层之上叠加此颜色。
  final Color? overrideBlurTint;

  const WallpaperBackground({
    super.key,
    this.overrideBlurSigma,
    this.overrideBlurTint,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: WallpaperService.instance,
        builder: (_, __) => _buildLayered(),
      ),
    );
  }

  Widget _buildLayered() {
    final svc = WallpaperService.instance;
    final cfg = svc.config;
    // 背景模糊只作用于路由级（纯文字页面传了 overrideBlurSigma）
    // 全局主页背景（overrideBlurSigma 为 null）用 cfg.blurSigma 不受 SP 调节
    // 路由级实际模糊值从 SP[spBgBlurSigma] 实时读取，用户可在设置页调节
    final spBlur = SpUtil.getDouble(spBgBlurSigma, defValue: -1);
    final effectiveBlur = overrideBlurSigma != null
        ? (spBlur >= 0 ? spBlur : overrideBlurSigma!)
        : cfg.blurSigma;
    final base = _buildBase(cfg);
    // 关键：用 ImageFiltered 包裹底层背景，对壁纸自身做模糊，
    // 不采样 layer——避免跨路由模糊到下层路由的 page 内容。
    final blurredBase = effectiveBlur > 0
        ? ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
            child: base,
          )
        : base;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层背景（已按需模糊）
        Positioned.fill(child: blurredBase),
        // 2. 路由级底色（可选）
        if (overrideBlurTint != null)
          Positioned.fill(child: ColoredBox(color: overrideBlurTint!)),
        // 3. 黑色蒙层
        if (cfg.dimOpacity > 0)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(cfg.dimOpacity),
            ),
          ),
      ],
    );
  }

  Widget _buildBase(WallpaperConfig cfg) {
    switch (cfg.type) {
      case WallpaperType.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: WallpaperService.instance.currentGradient,
          ),
        );
      case WallpaperType.solid:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorFromInt(cfg.solidColor),
          ),
        );
      case WallpaperType.local:
        final file = WallpaperService.instance.localImageFile;
        if (file == null) {
          // 文件丢失，回退到默认渐变
          return const DecoratedBox(
            decoration: BoxDecoration(gradient: PresetGradients.defaultGradient),
          );
        }
        return Image.file(
          file,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      case WallpaperType.network:
        final url = cfg.networkUrl;
        if (url == null || url.isEmpty || !isHttpUrl(url)) {
          return const DecoratedBox(
            decoration: BoxDecoration(gradient: PresetGradients.defaultGradient),
          );
        }
        // 优先用本地缓存文件（下载完成后切换为 Image.file，加载快且离线可用）
        final cached = WallpaperService.instance.networkCachedFile;
        if (cached != null) {
          return Image.file(
            cached,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        // 下载中：用 Image.network 实时预览，loading/error 时回退默认渐变
        return Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const DecoratedBox(
              decoration: BoxDecoration(gradient: PresetGradients.defaultGradient),
            );
          },
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(gradient: PresetGradients.defaultGradient),
          ),
        );
    }
  }
}
