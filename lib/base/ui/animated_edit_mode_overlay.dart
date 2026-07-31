import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';

/// 可中断的底部弹出功能页 Overlay
///
/// 用于编辑模式下底部"运行/停止/启用/禁用/置顶/删除"等功能页的弹出展示。
///
/// 特性：
/// - **从底部向上弹出动画**：进场使用 `Curves.easeOutCubic`，300ms
/// - **退场动画**：向下滑出，`Curves.easeOutCubic`，300ms（与进场一致，末尾减速更可见）
/// - **进出均可打断**：进场过程中再次调用 [hide] 会从当前进度开始退场；
///   退场过程中再次调用 [show] 会从当前进度开始进场。底层依赖
///   `AnimationController.forward()` / `reverse()`，它们本身支持从当前值中断续动画。
/// - **主题感知**：背景色通过 [backgroundColorBuilder] 实时读取，主题切换时自动更新
///   （无需重启应用）。
///
/// 使用方式：
/// ```dart
/// final overlay = AnimatedEditModeOverlay(
///   context: context,
///   backgroundColorBuilder: (ref) =>
///     ref.read(themeProvider).currentTheme.bottomNavigationBarTheme.backgroundColor ??
///     Colors.black,
///   builder: (ctx) => Row(children: [EditModeButton(...)]),
/// );
/// overlay.show();   // 弹出
/// overlay.hide();   // 收起（动画完成后自动从 Overlay 移除）
/// overlay.dispose(); // 页面 dispose 时调用，强制清理
/// ```
class AnimatedEditModeOverlay {
  AnimatedEditModeOverlay({
    required this.context,
    required this.builder,
    required this.backgroundColorBuilder,
  });

  final BuildContext context;
  final WidgetBuilder builder;
  /// 背景色实时构建器。在 host 的 build 中通过 Consumer 调用，
  /// 因此主题切换时会自动重建并读取最新主题的背景色。
  final Color Function(WidgetRef ref) backgroundColorBuilder;

  OverlayEntry? _entry;
  _AnimatedOverlayHostState? _host;

  /// 是否当前正在显示中（含动画进行中）
  bool get isShowing => _host != null;

  /// 弹出底部功能页
  ///
  /// 若已存在（包括正在退场中），会从当前进度继续进场动画（打断退场）。
  void show() {
    if (_host != null) {
      // 已存在：可能正在进场或退场，调用 forward 从当前值继续到 1.0
      _host!._forward();
      return;
    }
    _entry = OverlayEntry(
      builder:
          (c) => _AnimatedOverlayHost(
            owner: this,
            contentBuilder: builder,
          ),
    );
    Overlay.of(context)?.insert(_entry!);
  }

  /// 收起底部功能页
  ///
  /// 若正在进场中，会从当前进度开始退场（打断进场）。动画完成后自动从 Overlay 移除。
  /// 若未显示，无操作。
  void hide() {
    _host?._reverse();
  }

  /// 强制清理（页面 dispose 时调用）
  ///
  /// 仅移除 OverlayEntry；底层 State 在被 unmount 时会自行 dispose AnimationController。
  /// 不在这里直接 dispose controller，避免与 State.dispose() 重复 dispose 导致断言失败。
  void dispose() {
    _entry?.remove();
    _entry = null;
    _host = null;
  }
}

class _AnimatedOverlayHost extends ConsumerStatefulWidget {
  const _AnimatedOverlayHost({
    required this.owner,
    required this.contentBuilder,
  });

  final AnimatedEditModeOverlay owner;
  final WidgetBuilder contentBuilder;

  @override
  ConsumerState<_AnimatedOverlayHost> createState() =>
      _AnimatedOverlayHostState();
}

class _AnimatedOverlayHostState extends ConsumerState<_AnimatedOverlayHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideOffset;
  late final Animation<double> _fadeOpacity;

  bool _removed = false;

  @override
  void initState() {
    super.initState();
    widget.owner._host = this;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      // 退场时长与进场一致，避免退场太快看不出来
      reverseDuration: const Duration(milliseconds: 300),
    );
    // 从屏幕底部滑入
    _slideOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        // 进场 easeOutCubic（末尾减速，自然的弹起感）
        // 退场也用 easeOutCubic（起始快→末尾慢），末尾减速让整个滑出过程清晰可见
        // （原先用 easeInCubic 末尾加速，最后阶段太快，看起来像直接消失）
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
    // 轻微淡入淡出，避免边界突变
    _fadeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOut,
      ),
    );
    // 监听动画状态：退场完成（dismissed）后自动移除 OverlayEntry
    _controller.addStatusListener(_onStatusChanged);
    // 首帧立即启动进场动画（延后一帧确保 widget 已挂载、ticker 已激活）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_removed) {
        _controller.forward();
      }
    });
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_removed) {
      _removeEntry();
    }
  }

  void _forward() {
    if (!mounted || _removed) return;
    _controller.forward();
  }

  void _reverse() {
    if (!mounted || _removed) return;
    // 若已经在 0（dismissed），直接移除
    if (_controller.value <= 0.0) {
      _removeEntry();
      return;
    }
    _controller.reverse();
  }

  void _removeEntry() {
    if (_removed) return;
    _removed = true;
    widget.owner._entry?.remove();
    widget.owner._entry = null;
    widget.owner._host = null;
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听主题变化，主题切换时自动重建以读取最新背景色
    // ignore: unused_result
    ref.watch(themeProvider);
    // 实时从 themeProvider 读取当前主题的底部导航栏背景色
    final backgroundColor = widget.owner.backgroundColorBuilder(ref);

    // 内容只构建一次，传给 AnimatedBuilder 的 child，避免每帧重建 Row/按钮
    final content = Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width,
        color: backgroundColor,
        child: SafeArea(
          top: false,
          child: widget.contentBuilder(context),
        ),
      ),
    );

    // FadeTransition / SlideTransition 自身就是 AnimatedWidget，会自动监听动画
    // AnimatedBuilder 仅用于在每帧更新 IgnorePointer（退场完成后屏蔽触摸）
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return IgnorePointer(
          // 退场完成后忽略触摸
          ignoring: _controller.status == AnimationStatus.dismissed,
          child: child,
        );
      },
      child: FadeTransition(
        opacity: _fadeOpacity,
        child: SlideTransition(
          position: _slideOffset,
          child: content,
        ),
      ),
    );
  }
}
