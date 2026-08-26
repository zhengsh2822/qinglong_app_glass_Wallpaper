import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 顶部 Tab —— 液态玻璃风格（对齐 demos/liquid_glass_demo 顶部 tab 视觉）
///
/// 保持对外 API（tabs + tabController + editMode）不变，内部渲染改为：
///  - 大胶囊背景（壁纸版毛玻璃：透明底色 + BackdropFilter 高斯模糊）
///  - 液态滑块（渐变 + 边框 + 高光/内发光），滑块视觉由动画驱动
///  - 点击 animateTo(300ms)：全部 tab 统一两段式冲撞回弹（幅度随位移距离反馈）
///  - 按下即跳转：手指按下立刻平滑切页，快速点击松手补一段二段回弹
///  - 拖拽/长按抓取交互（与底部导航一致）
/// 交互/动画逻辑同步主题版（F:\mimo\qinglong_app_glass），视觉保留壁纸版透明毛玻璃。
class GlassSegmentedTab extends ConsumerStatefulWidget {
  final List<String> tabs;
  final TabController tabController;
  final bool editMode;

  const GlassSegmentedTab({
    super.key,
    required this.tabs,
    required this.tabController,
    this.editMode = false,
  });

  @override
  ConsumerState<GlassSegmentedTab> createState() => _GlassSegmentedTabState();
}

class _GlassSegmentedTabState extends ConsumerState<GlassSegmentedTab> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final theme = ref.watch(themeProvider);

    // ===== 顶部tab小胶囊（滑块） =====
    // 大胶囊/小胶囊边框统一对齐底部导航大胶囊边框（又细又不是很亮）：
    //  cyber：半透明青微光 borderGlow（宽 0.5）；其他主题：无边框（对齐底部导航 barBorder 为 null）
    final Color borderColor = isCyber
        ? CyberColors.borderGlow
        : Colors.transparent;
    // 滑块底色：cyber 全透明 + 底部内发光；其他主题 #E5E5E5 渐变底
    final Color thumbColor = isCyber
        ? Colors.transparent
        : const Color(0xFFE5E5E5);
    // 小胶囊边框：柔和色 + 细边框（0.5）
    final Border thumbBorder = Border.all(color: borderColor, width: 0.5);
    final Color? thumbTopGlow =
        isCyber ? null : Colors.white.withValues(alpha: 0.9);
    final Color? thumbBottomGlow = isCyber
        ? const Color(0x22CCCCCC)
        : null;

    // 文字色（壁纸版动态配色）：
    //  - 选中文案颜色：主题主色（cyber 青 / 其他主题 primaryColor）
    //  - 未选中文案：读 SP 自定义次字体，回退壁纸反色
    final Color activeColor = isCyber ? CyberColors.cyan : theme.primaryColor;
    final Color inactiveColor = theme.themeColor.title2Color();

    return SizedBox(
      height: 55,
      child: IgnorePointer(
        ignoring: widget.editMode,
        child: ColoredBox(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              bottom: 6,
              top: 6,
            ),
            child: AnimatedOpacity(
              opacity: _isReady ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _LiquidTabBarSlider(
                tabs: widget.tabs,
                tabController: widget.tabController,
                thumbColor: thumbColor,
                thumbBorder: thumbBorder,
                thumbTopGlow: thumbTopGlow,
                thumbBottomGlow: thumbBottomGlow,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                borderColor: borderColor,
                isCyber: isCyber,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidTabBarSlider extends StatefulWidget {
  final List<String> tabs;
  final TabController tabController;
  final Color thumbColor;
  final Border thumbBorder;
  final Color? thumbTopGlow;
  final Color? thumbBottomGlow;
  final Color activeColor;
  final Color inactiveColor;
  final Color borderColor;
  final bool isCyber;

  const _LiquidTabBarSlider({
    required this.tabs,
    required this.tabController,
    required this.thumbColor,
    required this.thumbBorder,
    required this.thumbTopGlow,
    required this.thumbBottomGlow,
    required this.activeColor,
    required this.inactiveColor,
    required this.borderColor,
    required this.isCyber,
  });

  @override
  State<_LiquidTabBarSlider> createState() => _LiquidTabBarSliderState();
}

class _LiquidTabBarSliderState extends State<_LiquidTabBarSlider>
    with TickerProviderStateMixin {
  // 回弹动画（本地控制器，不影响 TabController —— 页面内容走 TabBarView +
  // tabController.animation 保持平滑切换；回弹/挤压只作用于滑块视觉层）。
  late final AnimationController _rebound;
  // 抓取缩放（长按缩小，与底部导航交互一致）
  late final AnimationController _grab;

  double _lastAmp = 1.0; // 最近一次切换的回弹幅度（随位移距离反馈，0.35~1.0）
  double _boundaryDir = 1.0; // +1 向右过墙 / -1 向左过墙
  double _pressValue = 0; // 按下时页面位置（index 单位，回弹距离/方向依据）

  // 手势/拖拽状态
  bool _isInteracting = false;
  bool _isDragging = false;
  bool _longTapFired = false;
  double? _dragP; // 拖拽时滑块位置（index 单位）；提交后保留到页面到位
  int _dragHover = 0;
  Offset _downLocal = Offset.zero;
  Timer? _longTapTimer;
  double _lastTotalW = 0; // build 时记录的大胶囊宽度
  bool _downSwitched = false; // 按下是否已立即切页（松手 tap 时避免重复提交）

  // 边界过墙量（tab 宽度比例，与底部导航 11% 一致）
  static const double _boundaryOvershoot = 0.11;
  // 进入拖拽的最小水平位移（水平需主导竖向，避免与页面竖向滚动冲突）
  static const double _dragThreshold = 5.0;
  // 长按判定时长（与底部导航一致）
  static const Duration _longTapDuration = Duration(milliseconds: 500);

  /// 抓取缩放：0=正常 1.0，1=长按抓取 0.85
  double get _grabScale =>
      lerpDouble(1.0, 0.85, _grab.value) ?? 1.0;

  @override
  void initState() {
    super.initState();
    _rebound = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _grab = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    // 页面动画到位后清除拖拽覆盖（避免滑块残留卡在拖拽位）
    widget.tabController.animation!.addStatusListener(_onTabStatus);
  }

  void _onTabStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_isDragging) {
      setState(() => _dragP = null);
    }
  }

  @override
  void dispose() {
    _longTapTimer?.cancel();
    widget.tabController.animation!.removeStatusListener(_onTabStatus);
    _rebound.dispose();
    _grab.dispose();
    super.dispose();
  }

  /// 点击/提交：页面切换 + 回弹。
  /// 全部 tab 统一"两段式 easeOutCubic 干脆回弹"（去掉中间 tab 慢启动 SpringCurve）：
  ///  滑块本地两段式挤压回弹（幅度随位移距离反馈），页面用 easeOutCubic 平滑到位。
  void _onTap(int i) {
    final current = widget.tabController.animation!.value.round();
    final maxDist = widget.tabs.length - 1;
    final dist = (i - current).abs();
    _lastAmp = 0.35 + 0.65 * (maxDist > 0 ? dist / maxDist : 1.0);
    _boundaryDir = i >= current ? 1.0 : -1.0;
    _rebound.forward(from: 0);
    widget.tabController.animateTo(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 仅切页不回弹（长按/按下起手的"平滑滑动"），回弹留在快速点击松手再触发
  void _onTapPlain(int i) {
    final current = widget.tabController.animation!.value.round();
    final maxDist = widget.tabs.length - 1;
    final dist = (i - current).abs();
    _lastAmp = 0.35 + 0.65 * (maxDist > 0 ? dist / maxDist : 1.0);
    _boundaryDir = i >= current ? 1.0 : -1.0;
    widget.tabController.animateTo(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 仅补一段二段回弹（快速点击：按下已平滑切页，松手再弹一下，幅度随按下原点距离）
  void _bounceOnly(int i) {
    final dist = (i - _pressValue).abs();
    final maxDist = widget.tabs.length - 1;
    _lastAmp = 0.35 + 0.65 * (maxDist > 0 ? dist / maxDist : 1.0);
    _boundaryDir = i >= _pressValue ? 1.0 : -1.0;
    _rebound.forward(from: 0);
  }

  /// 提交（点击/拖拽松手/长按拖拽）：拖拽/抓取场景保留滑块在目标位，
  /// 等页面动画到位后再跟随，避免"拖到 2 又跳回 0"的跳变。
  /// bounce=false 时仅平滑滑动（长按/按下起手），快速点击松手再补回弹。
  void _commit(int i, {bool bounce = true}) {
    _dragP = (_isDragging || _longTapFired) ? i.toDouble() : null;
    if (bounce) {
      _onTap(i);
    } else {
      _onTapPlain(i);
    }
  }

  // ---------- 手势（同步底部导航：按压缩小 → 长按抓取 → 可拖拽） ----------

  double _pFromFinger(double localDx) {
    final w = _lastTotalW;
    if (w <= 0) return 0;
    final p = (localDx / w).clamp(0.0, 1.0);
    return p * (widget.tabs.length - 1);
  }

  int _indexAt(double localDx) {
    final w = _lastTotalW;
    if (w <= 0) return 0;
    final p = (localDx / w).clamp(0.0, 0.9999);
    return (p * widget.tabs.length).floor().clamp(0, widget.tabs.length - 1);
  }

  void _onPointerDown(PointerDownEvent e) {
    _isInteracting = true;
    _isDragging = false;
    _longTapFired = false;
    _downLocal = e.localPosition;
    _dragP = null;
    // 按下立即切页（最快的"立即跳转"，与底部导航一致）：落到不同 tab 直接提交，
    // 不等松手/长按。同 tab 按下仅保留抓取预备反馈。
    final int downTarget = _indexAt(e.localPosition.dx);
    _pressValue = widget.tabController.animation!.value;
    _downSwitched = downTarget != widget.tabController.animation!.value.round();
    if (_downSwitched) {
      _dragHover = downTarget;
      // 按下立即切页：起手仅"平滑滑动"，二段回弹留到松手再决定（长按无回弹）
      _commit(downTarget, bounce: false);
    }
    // 按压即轻微缩小（抓取预备）
    _grab.animateTo(0.5, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    _longTapTimer?.cancel();
    _longTapTimer = Timer(_longTapDuration, () {
      if (!mounted || !_isInteracting || _isDragging) return;
      _longTapFired = true;
      _longTapTimer?.cancel();
      // 长按：小胶囊缩小（抓取）；按下已立即切页，这里仅在同 tab 时才提交，
      // 避免对已切换的目标重复提交造成二次回弹
      final int target = _indexAt(_downLocal.dx);
      _dragHover = target;
      _grab.animateTo(
        1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
      if (target != widget.tabController.animation!.value.round()) {
        _commit(target);
      }
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_isInteracting) return;
    final delta = e.localPosition - _downLocal;
    if (!_isDragging) {
      // 水平主导才进入拖拽，避免与页面竖向滚动冲突
      if (delta.dx.abs() < _dragThreshold || delta.dx.abs() < delta.dy.abs()) {
        return;
      }
      _isDragging = true;
      _longTapTimer?.cancel();
    }
    _dragP = _pFromFinger(e.localPosition.dx);
    _dragHover = _indexAt(e.localPosition.dx);
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_isInteracting) return;
    _longTapTimer?.cancel();
    if (_longTapFired) {
      // 已长按（抓取）：拖拽过就提交，否则只恢复
      if (_isDragging) {
        _commit(_dragHover);
      }
    } else if (!_isDragging) {
      // 点击：若按下已平滑切页（_downSwitched），快速点击松手补一段二段回弹；
      // 长按时 _longTapFired 走上面分支不补 → 长按无回弹
      final int target = _indexAt(e.localPosition.dx);
      if (_downSwitched) {
        _bounceOnly(target);
      } else {
        _commit(target);
      }
    } else {
      // 拖拽松手
      _commit(_dragHover);
    }
    _grab.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
    _isInteracting = false;
    _isDragging = false;
    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _longTapTimer?.cancel();
    if (_isInteracting && _isDragging) {
      _commit(_dragHover);
    }
    _grab.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
    _isInteracting = false;
    _isDragging = false;
    setState(() {});
  }

  /// 滑块过冲偏移（tab 宽度单位）：两段式回弹的"过墙"段，幅度随位移反馈
  double _offsetP() {
    final double t = _rebound.value;
    final double p = t < 0.48 ? (t / 0.48) : (1 - (t - 0.48) / 0.52);
    return _boundaryDir * _boundaryOvershoot * _lastAmp * p;
  }

  double _scaleX() {
    final double t = _rebound.value;
    final double target = 1.0 - 0.22 * _lastAmp; // 挤压深度随幅度
    return t < 0.48
        ? lerpDouble(1.0, target, t / 0.48)!
        : lerpDouble(target, 1.0, (t - 0.48) / 0.52)!;
  }

  double _scaleY() {
    final double t = _rebound.value;
    final double target = 1.0 + 0.05 * _lastAmp; // 拉伸深度随幅度
    return t < 0.48
        ? lerpDouble(1.0, target, t / 0.48)!
        : lerpDouble(target, 1.0, (t - 0.48) / 0.52)!;
  }

  @override
  Widget build(BuildContext context) {
    // GPU 优化：LayoutBuilder 必须放在 AnimatedBuilder 外层（只在大胶囊尺寸
    // 变化时重算几何，动画期间不重新布局）。
    // 同时必须放在大胶囊 Container 内部：Container 带边框（赛博 1px）时
    // child 区域会被边框内缩（两侧各 1px），若在外层取 constraints.maxWidth
    // 会拿到含边框的整宽，而文字 Row 实际用的是内缩后的窄宽度，导致滑块
    // 随索引逐渐偏右（运行中/未使用/已禁用 越靠右越明显）。
    final int count = widget.tabs.length;
    // 大胶囊毛玻璃 sigma（壁纸版全局统一调节）
    final double sigma = SpUtil.getDouble(spCardBlurSigma, defValue: 4);

    // 统一底层 Listener 处理 点击/长按抓取/拖拽（与底部导航一致）
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: Container(
          height: 43,
          decoration: BoxDecoration(
            // 壁纸版：大胶囊透明毛玻璃透出全局壁纸，加主题主色细边框（0.5）
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: widget.borderColor, width: 0.5),
          ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double tabWidth = totalWidth / count;
            const double horizontalPadding = 3.0;
            final double thumbWidth = tabWidth - horizontalPadding * 2;
            _lastTotalW = totalWidth;

            // 顶部 tab：100% 不透明固定纯色（白/黑），不模糊、不跟随卡片纯色调节
            return OptimizedFrostedGlass(
              sigma: sigma,
              borderRadius: BorderRadius.circular(22),
              forceOpaqueSolid: true,
              child: AnimatedBuilder(
                  animation: Listenable.merge([
                    widget.tabController.animation!,
                    _rebound,
                    _grab,
                  ]),
                  builder: (context, child) {
                    final double base = widget.tabController.animation!.value;
                    // 拖拽/提交中：保留滑块在拖拽位，直到页面动画到位
                    final bool holdDrag =
                        _dragP != null &&
                        (_isDragging || (base - _dragP!).abs() > 0.02);
                    final double displayP = holdDrag ? _dragP! : base + _offsetP();
                    final double gs = _grabScale;
                    final double sx = holdDrag ? gs : _scaleX() * gs;
                    final double sy = holdDrag ? gs : _scaleY() * gs;
                    final double thumbLeft =
                        horizontalPadding + displayP * tabWidth;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // ---------- 液态滑块 ----------
                        Positioned(
                          left: thumbLeft,
                          top: 4,
                          bottom: 4,
                          width: thumbWidth,
                          child: IgnorePointer(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..scale(sx, sy),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      widget.thumbColor,
                                      widget.thumbColor.withValues(alpha: 0.35),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(17.5),
                                  border: widget.thumbBorder,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0x2E000000),
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                    if (widget.thumbTopGlow != null)
                                      BoxShadow(
                                        color: widget.thumbTopGlow!,
                                        blurRadius: 4,
                                        offset: const Offset(0, -1),
                                      ),
                                    if (widget.thumbBottomGlow != null)
                                      BoxShadow(
                                        color: widget.thumbBottomGlow!,
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ---------- 文字 ----------
                        Row(
                          children: List.generate(count, (i) {
                            // 文字跟随滑块位置变色（拖拽时随手指滑动）
                            final double distance = (displayP - i).abs();
                            final double t = distance.clamp(0.0, 1.0);
                            final Color textColor = Color.lerp(
                              widget.activeColor,
                              widget.inactiveColor,
                              t,
                            )!;

                            return Expanded(
                              child: Center(
                                child: Text(
                                  widget.tabs[i],
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
            );
          },
        ),
      ),
    );
  }
}

class GlassSegmentedTabDelegate extends SliverPersistentHeaderDelegate {
  final List<String> tabs;
  final TabController tabController;
  final bool editMode;

  const GlassSegmentedTabDelegate({
    required this.tabs,
    required this.tabController,
    this.editMode = false,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return GlassSegmentedTab(
      tabs: tabs,
      tabController: tabController,
      editMode: editMode,
    );
  }

  @override
  bool shouldRebuild(covariant GlassSegmentedTabDelegate oldDelegate) {
    return editMode != oldDelegate.editMode ||
        tabs.length != oldDelegate.tabs.length;
  }

  @override
  double get maxExtent => 55;

  @override
  double get minExtent => 55;
}