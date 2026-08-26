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
/// - 主页壁纸（[cacheBlur] 默认 false）不包 RepaintBoundary：背景在
///   Stack 底层不在 ListView 里，滚动不会触发 rebuild；若包 RepaintBoundary
///   会隔离成独立图层，导致上层 GlassCard 的 BackdropFilter 在滚动时无法
///   实时采样背景 → 滑动透明
/// - 路由级壁纸（[cacheBlur] true，见 WallpaperPageRoute）：模糊层用
///   RepaintBoundary 隔离缓存为独立图层，模糊结果只在首次渲染/壁纸变化时
///   计算一次；push 动画、页面重绘期间直接复用缓存，避免每帧重算全屏
///   高斯模糊 → 解决二级页面进入时掉帧（非实时模糊，视觉完全不变）
/// - 模糊层用 [ImageFilter.blur] + ImageFiltered，对子 widget 自身渲染
///   结果做模糊，不采样 layer——避免跨路由模糊到下层路由的 page 内容
/// - 网络图片先 Image.network 预览，后台下载到本地后切 Image.file
class WallpaperBackground extends StatelessWidget {
  /// 路由级覆盖模糊值，传入后忽略全局配置的 blurSigma。
  final double? overrideBlurSigma;

  /// 路由级覆盖底色，传入后在模糊层之上叠加此颜色。
  final Color? overrideBlurTint;

  /// 是否缓存模糊结果为独立图层（非实时模糊）。
  ///
  /// - true：模糊层被 RepaintBoundary 隔离缓存，只在首次渲染/壁纸变化时
  ///   计算一次高斯模糊；路由动画/页面重绘期间直接复用缓存图层，
  ///   避免每帧重新计算全屏模糊（GPU 开销显著下降）。适合二级静态页面。
  /// - false：每次 repaint 都重新计算模糊（实时），适合需要滚动实时采样
  ///   的场景（主页壁纸）。
  /// - null（默认）：自动判断——路由级壁纸（[overrideBlurSigma] != null）
  ///   默认 true，否则 false。
  final bool? cacheBlur;

  const WallpaperBackground({
    super.key,
    this.overrideBlurSigma,
    this.overrideBlurTint,
    this.cacheBlur,
  });

  @override
  Widget build(BuildContext context) {
    // 全屏壁纸解码按设备宽度限制，避免大图全分辨率解码占用内存
    // 用 displayWidth * 2 作为 cacheWidth（兼顾高分辨率屏幕清晰度）
    final screenWidth = MediaQuery.of(context).size.width.toInt();
    final decodeWidth = (screenWidth * 2).clamp(720, 2160);
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: WallpaperService.instance,
        builder: (_, __) => _buildLayered(decodeWidth),
      ),
    );
  }

  Widget _buildLayered(int decodeWidth) {
    final svc = WallpaperService.instance;
    final cfg = svc.config;
    // 背景模糊只作用于路由级（纯文字页面传了 overrideBlurSigma）
    // 全局主页背景（overrideBlurSigma 为 null）用 cfg.blurSigma 不受 SP 调节
    // 路由级实际模糊值从 SP[spBgBlurSigma] 实时读取，用户可在设置页调节
    final spBlur = SpUtil.getDouble(spBgBlurSigma, defValue: -1);
    final effectiveBlur = overrideBlurSigma != null
        ? (spBlur >= 0 ? spBlur : overrideBlurSigma!)
        : cfg.blurSigma;
    final base = _buildBase(cfg, decodeWidth);
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
    // 非实时模糊：路由级壁纸默认用 RepaintBoundary 隔离缓存模糊层。
    // 模糊结果只算一次，动画/重绘期间复用缓存，避免每帧重算全屏模糊；
    // 壁纸内容静态（路由内不变），缓存结果恒正确，不影响上层毛玻璃采样。
    final useCache = cacheBlur ?? (overrideBlurSigma != null);
    final bgLayer = useCache
        ? RepaintBoundary(child: blurredBase)
        : blurredBase;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层背景（已按需模糊）
        Positioned.fill(child: bgLayer),
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

  Widget _buildBase(WallpaperConfig cfg, int decodeWidth) {
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
          cacheWidth: decodeWidth,
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
            cacheWidth: decodeWidth,
          );
        }
        // 下载中：用 Image.network 实时预览，loading/error 时回退默认渐变
        return Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: decodeWidth,
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
