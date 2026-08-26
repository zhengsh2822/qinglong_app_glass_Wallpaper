import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 高性能毛玻璃组件（对 BackdropFilter 的封装优化）
///
/// 相对原始 [BackdropFilter] 的性能优化：
/// 1. [ClipRect] + `Clip.hardEdge`：限制模糊计算区域，防止扩散到整屏
/// 2. [RepaintBoundary]：隔离重绘范围 + 图层级缓存（非实时模糊）
/// 3. sigma 默认 10（超出 12 人眼几乎无法区分，但 GPU 开销成倍增长）
/// 4. [tintColor] 半透明色补偿：降低 sigma 后模糊感不足时用它补偿而非增大 sigma
/// 5. 滚动缓存（[enableScrollCache]）：列表滚动时截取模糊结果缓存为静态图，
///    滚动过程中用缓存图替代实时模糊，滚动停止恢复实时模糊，截图用 0.5 pixelRatio 降采样
///
/// ## 路由动画期间的整页快照
/// 路由 push/pop 动画期间不靠卡片自身快照（开销大），由
/// [PageSnapshot]（路由级）整页截一张图显示，详见
/// lib/base/ui/page_snapshot.dart。本组件无需再单独处理路由动画。
///
/// 注意：项目硬约束——卡片背景色默认必须全透明（[tintColor] 传
/// [Colors.transparent]），仅保留 BackdropFilter 高斯模糊，让全局壁纸透出。
/// [tintColor] 的 15% 白色默认仅作为"视觉补偿手段"存在，由调用方按需传入。
///
/// ## 纯色模式（sigma = 0）
/// 当 [sigma] 为 0（卡片模糊关闭）时退化为纯色卡片，完全移除
/// [BackdropFilter] —— 零离屏渲染，大幅降低 GPU 压力；纯色不透明度由
/// [spCardSolidOpacity] 单独调节（浅色主题白底 / 深色主题黑底），
/// 保证卡片内容可读性。
class OptimizedFrostedGlass extends ConsumerStatefulWidget {
  final Widget child;
  final double sigma;
  final Color tintColor;
  final BorderRadius? borderRadius;

  /// 是否启用滚动缓存（列表/可滚动区域中的毛玻璃建议开启）。
  /// 开启后组件会查找最近的 [Scrollable]，滚动期间用缓存图替代实时模糊。
  /// 注意：会创建 [GlobalKey] 用于截图，ReorderableListView 长按拖动会把
  /// 被拖卡片子树复制到 Overlay，含 GlobalKey 会冲突，因此可拖动列表里
  /// 必须保持关闭。
  final bool enableScrollCache;

  /// 强制 100% 不透明固定纯色（浅色白底/深色黑底），忽略 sigma 与卡片纯色调节。
  /// 供弹窗与顶部 tab 使用：不透明底色保证内容可读，且不随
  /// [spCardSolidColor]/[spCardSolidOpacity] 联动。
  final bool forceOpaqueSolid;

  const OptimizedFrostedGlass({
    super.key,
    required this.child,
    this.sigma = 4,
    this.tintColor = const Color(0x26FFFFFF),
    this.borderRadius,
    this.enableScrollCache = false,
    this.forceOpaqueSolid = false,
  });

  @override
  ConsumerState<OptimizedFrostedGlass> createState() =>
      _OptimizedFrostedGlassState();
}

class _OptimizedFrostedGlassState extends ConsumerState<OptimizedFrostedGlass> {
  // 滚动缓存截图用的 RepaintBoundary key，仅在 enableScrollCache 为 true 时
  // 创建，避免 ReorderableListView 拖动复制子树导致 GlobalKey 冲突。
  GlobalKey? _boundaryKey;
  ScrollableState? _scrollable;
  bool _isScrolling = false;
  bool _captureInProgress = false;
  ui.Image? _cachedImage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.enableScrollCache) {
      _setupScrollListener();
    }
  }

  void _setupScrollListener() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != _scrollable) {
      _scrollable?.position.isScrollingNotifier.removeListener(_onScrollingChanged);
      _scrollable = scrollable;
      _scrollable?.position.isScrollingNotifier.addListener(_onScrollingChanged);
    }
  }

  void _onScrollingChanged() {
    final scrolling = _scrollable?.position.isScrollingNotifier.value ?? false;
    if (scrolling && !_isScrolling) {
      // 滚动开始：截取当前模糊结果作为静态图片缓存
      _isScrolling = true;
      _capture();
    } else if (!scrolling && _isScrolling) {
      // 滚动停止：恢复实时模糊
      _isScrolling = false;
      if (mounted) {
        setState(() {
          _cachedImage?.dispose();
          _cachedImage = null;
        });
      }
    }
  }

  Future<void> _capture() async {
    if (_captureInProgress) return;
    _captureInProgress = true;
    try {
      // 等一帧，确保模糊层已渲染完成再截图
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_isScrolling) return;
      final boundary =
          _boundaryKey?.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      // 0.5 pixelRatio 降采样，大幅降低截图开销
      final image = await boundary.toImage(pixelRatio: 0.5);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _cachedImage?.dispose();
        _cachedImage = image;
      });
    } finally {
      _captureInProgress = false;
    }
  }

  @override
  void dispose() {
    _scrollable?.position.isScrollingNotifier.removeListener(_onScrollingChanged);
    _cachedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;
    // sigma 控制在 10 以内（超出 12 人眼几乎无差异，GPU 开销却成倍增长）
    final sigma = widget.sigma.clamp(0.0, 10.0);

    // 强制 100% 不透明固定纯色（弹窗/顶部 tab）：既不模糊，也不跟随卡片
    // 纯色调节，固定浅色白底/深色黑底，保证内容可读
    if (widget.forceOpaqueSolid) {
      return ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: ColoredBox(
          color: isDark ? Colors.black : Colors.white,
          child: widget.child,
        ),
      );
    }

    // 模糊关闭（sigma=0）：退化为纯色卡片，移除 BackdropFilter —— 零离屏
    // 渲染，大幅降低 GPU 压力；纯色不透明度由 spCardSolidOpacity 单独调节，
    // 颜色可自定义（spCardSolidColor，-1 时浅色主题白底/深色主题黑底）。
    if (sigma <= 0) {
      return ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: ColoredBox(
          color: cardSolidColor(isDark: isDark),
          child: widget.child,
        ),
      );
    }

    final Widget content;
    if (_isScrolling && _cachedImage != null) {
      // 滚动中：用静态缓存图替代实时模糊
      content = RawImage(
        image: _cachedImage,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
    } else {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: ColoredBox(color: widget.tintColor, child: widget.child),
      );
    }

    // 外层 RepaintBoundary：隔离重绘 + 图层级缓存（非实时模糊）。
    // 仅 enableScrollCache 时挂 key 用于截图（避免 ReorderableListView 拖动
    // 复制子树冲突——排序页卡片必须保持 enableScrollCache:false）。
    return RepaintBoundary(
      key: widget.enableScrollCache ? (_boundaryKey ??= GlobalKey()) : null,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          child: content,
        ),
      ),
    );
  }
}

/// 卡片纯色模式：卡片模糊关闭（sigma<=0）时返回 true。
///
/// 关闭模糊后所有卡片/弹窗遮罩/搜索框/顶部 tab/滑动卡片统一退化为纯色
/// （无 BackdropFilter），彻底消除 GPU 离屏渲染（saveLayer）开销。
bool isCardSolidMode() {
  return SpUtil.getDouble(spCardBlurSigma, defValue: 4) <= 0;
}

/// 卡片纯色背景：颜色可自定义（[spCardSolidColor]），未设置时浅色主题白底 /
/// 深色主题黑底；整体 × [spCardSolidOpacity] 不透明度。
Color cardSolidColor({required bool isDark}) {
  final opacity =
      SpUtil.getDouble(spCardSolidOpacity, defValue: 0.45).clamp(0.0, 1.0);
  // 用户自定义颜色（适配不同壁纸），-1 表示未设置 → 随主题自动白/黑
  final custom = SpUtil.getInt(spCardSolidColor, defValue: -1);
  final Color base =
      custom >= 0 ? Color(custom) : (isDark ? Colors.black : Colors.white);
  return base.withValues(alpha: opacity);
}
