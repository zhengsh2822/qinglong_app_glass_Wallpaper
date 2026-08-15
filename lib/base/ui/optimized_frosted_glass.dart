import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 高性能毛玻璃组件（对 BackdropFilter 的封装优化）
///
/// 相对原始 [BackdropFilter] 的性能优化：
/// 1. [ClipRect] + `Clip.hardEdge`：限制模糊计算区域，防止扩散到整屏
/// 2. [RepaintBoundary]：隔离重绘范围，模糊层变化不触发整页重绘
/// 3. sigma 默认 10（超出 12 人眼几乎无法区分，但 GPU 开销成倍增长）
/// 4. [tintColor] 半透明色补偿：降低 sigma 后模糊感不足时用它补偿而非增大 sigma
/// 5. 滚动缓存（[enableScrollCache]）：列表滚动时截取模糊结果缓存为静态图，
///    滚动过程中用缓存图替代实时模糊，滚动停止恢复实时模糊，截图用 0.5 pixelRatio 降采样
///
/// 注意：项目硬约束——卡片背景色默认必须全透明（[tintColor] 传
/// [Colors.transparent]），仅保留 BackdropFilter 高斯模糊，让全局壁纸透出。
/// [tintColor] 的 15% 白色默认仅作为"视觉补偿手段"存在，由调用方按需传入。
class OptimizedFrostedGlass extends StatefulWidget {
  final Widget child;
  final double sigma;
  final Color tintColor;
  final BorderRadius? borderRadius;

  /// 是否启用滚动缓存（列表/可滚动区域中的毛玻璃建议开启）。
  /// 开启后组件会查找最近的 [Scrollable]，滚动期间用缓存图替代实时模糊。
  final bool enableScrollCache;

  const OptimizedFrostedGlass({
    super.key,
    required this.child,
    this.sigma = 10,
    this.tintColor = const Color(0x26FFFFFF),
    this.borderRadius,
    this.enableScrollCache = false,
  });

  @override
  State<OptimizedFrostedGlass> createState() => _OptimizedFrostedGlassState();
}

class _OptimizedFrostedGlassState extends State<OptimizedFrostedGlass> {
  // GlobalKey 仅用于滚动缓存截图（enableScrollCache 时）。
  // 注意：不能无条件创建 GlobalKey——ReorderableListView 长按拖动时会把
  // 被拖卡片的子树复制到 Overlay，含 GlobalKey 的子树无法复制会冲突，
  // 导致拖动异常/卡片跳动/无法选中（账号排序页曾因此出问题）。
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
    // sigma 控制在 10 以内（超出 12 人眼几乎无差异，GPU 开销却成倍增长）
    final sigma = widget.sigma.clamp(0.0, 10.0);

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

    // 外层 RepaintBoundary 隔离重绘；ClipRect(hardEdge) 限制模糊计算区域
    // key 仅在启用滚动缓存时创建（避免 ReorderableListView 拖动复制子树冲突）
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
