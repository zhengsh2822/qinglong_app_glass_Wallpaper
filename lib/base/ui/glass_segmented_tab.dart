import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 顶部 Tab —— 液态玻璃风格（v5：手势状态机移植自 top_tab_demo v6，同步主题版新优化）
///
/// 对外 API（tabs + tabController + editMode）保持不变。
///
/// 状态机（唯一真相 = _selectedIndex，由 TabController 与手势共同维护）：
///   IDLE → DOWN（命中 pressedIndex 后不再改变；启动长按计时 100ms + 速度追踪）
///    → 位移 ≤ slop(10px) 微抖不动；横向超 slop → DRAG（取消计时，滑块跟手）
///    → 计时到点 → LONGPRESS 锁定：目标 = pressedIndex 弹簧跳转并选中（轻震动）；
///      锁定后微动 ≤ slop 忽略（不偏移不改目标），再明显横拖超 slop → 转 DRAG 跟手
///    → UP：LONGPRESS 提交 pressedIndex（速度清零、严禁 fling）
///           DRAG 吸附最近菜单（|v| ≥ 1000px/s 沿速度方向再进一个菜单）
///           长按未到时且未超滑 = TAP 点击选中
///    → CANCEL（纵向抢占/系统取消）：回滚到 selectedIndex；每次结束全量清零，零残留
/// 视觉保真：欠阻尼弹簧 240Hz 子步进 + 加速度果冻挤压 + 按压缩小，全部由
///   selectedIndex 派生目标；动画只是可视化，被新目标打断时以新目标为准。
/// 仲裁实现：raw Listener 指针事件 + 自研相位判定（slop/计时/速度用具名常量控制），
///   不再依赖框架竞技场（旧实现 Tap×LongPress 竞技场是长按不张/跳格的根因）。
/// 外部联动：TabController 变更（内容页手势/其他入口）→ 滑块弹簧跟随目标，
///   手势进行中（phase != idle）由手势全权接管，避免双向打架。
/// 视觉保留壁纸版透明毛玻璃（OptimizedFrostedGlass 大胶囊 100% 不透明纯色 + 渐变滑块）。
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

    // ===== 壁纸版动态配色 =====
    // 大胶囊/小胶囊边框统一对齐底部导航大胶囊边框：
    //  cyber：半透明青微光 borderGlow（宽 0.5）；其他主题：无边框
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
    // 文字色：选中文案主题主色；未选中读自定义次字体色
    final Color activeColor = isCyber ? CyberColors.cyan : theme.primaryColor;
    final Color inactiveColor = theme.themeColor.title2Color();
    // 大胶囊背景默认透明（由 OptimizedFrostedGlass 提供毛玻璃）
    final Color bgColor = Colors.transparent;

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
                bgColor: bgColor,
                bgBorder: Border.all(color: borderColor, width: 0.5),
                thumbColor: thumbColor,
                thumbBorder: thumbBorder,
                thumbTopGlow: thumbTopGlow,
                thumbBottomGlow: thumbBottomGlow,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                isCyber: isCyber,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 手势状态机相位：IDLE → DOWN → (LONGPRESS | DRAG | TAP) → UP/CANCEL → IDLE
enum _Phase { idle, down, longPress, drag }

class _LiquidTabBarSlider extends StatefulWidget {
  final List<String> tabs;
  final TabController tabController;
  final Color bgColor;
  final Border? bgBorder;
  final Color thumbColor;
  final Border? thumbBorder;
  final Color? thumbTopGlow;
  final Color? thumbBottomGlow;
  final Color activeColor;
  final Color inactiveColor;
  final bool isCyber;

  const _LiquidTabBarSlider({
    required this.tabs,
    required this.tabController,
    required this.bgColor,
    required this.bgBorder,
    required this.thumbColor,
    required this.thumbBorder,
    required this.thumbTopGlow,
    required this.thumbBottomGlow,
    required this.activeColor,
    required this.inactiveColor,
    required this.isCyber,
  });

  @override
  State<_LiquidTabBarSlider> createState() => _LiquidTabBarSliderState();
}

class _LiquidTabBarSliderState extends State<_LiquidTabBarSlider>
    with SingleTickerProviderStateMixin {
  // ── 单一数据源：选中索引（滑块位置/文字高亮/页面切换全部由它派生）────
  int _selectedIndex = 0;

  // ── 手势状态机 ───────────────────────────────────────────────
  _Phase _phase = _Phase.idle;
  int _pressedIndex = 0; // DOWN 命中索引：按下瞬间确定，此后不再改变
  double _downDx = 0; // 按下坐标（局部）
  double _downDy = 0;
  Timer? _longPressTimer; // 长按计时器
  final List<(double, double)> _velSamples = []; // (dx px, time s) 速度追踪窗口

  // ── 位置弹簧（index 单位 0..n-1）──────────────────────────────
  double _travelPos = 0; // 滑块当前位置（frac）
  double _travelVel = 0;
  double _travelTarget = 0;
  bool _travelActive = false;

  // ── 拖动 ─────────────────────────────────────────────────────
  bool _dragging = false;
  double _dragTarget = 0; // 手指目标 frac
  double _dragFollow = 0; // 滑块跟手 frac（平滑追手指）
  double _grabOffsetFrac = 0; // 抓取点相对滑块的偏移（首帧不跳变的关键）

  // ── 按压反馈（按住不动 → 滑块轻微缩小）──────────────────────
  bool _pressDown = false; // 手指是否按着
  double _pressStrength = 0; // 0=正常 1=完全按压缩小

  // ── 加速度→变形模型（像素域）─────────────────────────────────
  final List<(Offset, double)> _history = []; // (位置px, 时间s)
  double _deviation = 0; // 当前变形偏差（scaleX=1+d, scaleY=1-d）
  double _travelSign = 0; // 旅程方向键：-1 左 / 1 右 / 0 手指驱动
  double _travelSignEased = 0;
  bool _motionTracking = false;

  // ── 布局缓存 ─────────────────────────────────────────────────
  double _lastTotalW = 0;

  static const double _pad = 3.0; // 胶囊内左右边距
  // ── 手势规格常量（集中定义、可调）────────────────────────────
  static const Duration _longPressDuration = Duration(milliseconds: 100); // 长按判定时长
  static const double _touchSlop = 10.0; // 触摸 slop：累计位移超过才算拖动
  static const double _flingVelocity = 1000.0; // fling 速度阈值（px/s）
  static const double _velocityWindow = 0.12; // 松手速度采样窗口（秒）
  // 弹簧参数（liquid_glass_demo 调好的 travel spring）
  static const double _travelStiffness = 280;
  static const double _travelDamping = 31.4;
  // 加速度模型参数（liquid_glass_demo nav pill 调好的参数）
  static const double _sampleWindow = 0.3;
  static const double _sensitivity = 0.00007;
  static const double _maxDeformation = 0.12;
  static const double _responseTime = 0.18;

  int get _count => widget.tabs.length;

  Ticker? _ticker;
  Duration? _tickerLast;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.tabController.index.clamp(0, _count - 1);
    _travelPos = _selectedIndex.toDouble();
    _travelTarget = _travelPos;
    widget.tabController.addListener(_onControllerChanged);
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant _LiquidTabBarSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabController != widget.tabController) {
      oldWidget.tabController.removeListener(_onControllerChanged);
      widget.tabController.addListener(_onControllerChanged);
      _selectedIndex = widget.tabController.index.clamp(0, _count - 1);
      _travelPos = _selectedIndex.toDouble();
      _travelTarget = _travelPos;
      _travelVel = 0;
      _travelActive = false;
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onControllerChanged);
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _ticker?.dispose();
    super.dispose();
  }

  void _startTicker() {
    if (_ticker?.isActive != true) {
      _tickerLast = null;
      _ticker?.start();
    }
  }

  /// 外部切换 TabController（内容页手势/其他入口）→ 滑块弹簧跟随；
  /// 手势进行中（phase != idle）由手势全权接管，避免双向打架。
  void _onControllerChanged() {
    if (!mounted) return;
    if (_phase != _Phase.idle) return;
    final int idx = widget.tabController.index.clamp(0, _count - 1);
    if (idx == _selectedIndex) return;
    _log('CONTROLLER → index=$idx (external switch, spring follow)');
    _selectedIndex = idx;
    _startSpringFollow(idx.toDouble());
  }

  // ── 手势状态机（raw Listener 指针事件 + 自研仲裁，不依赖框架竞技场）────
  /// DOWN：命中测试锁定 pressedIndex → 启动长按计时 + 速度追踪
  void _onPointerDown(PointerDownEvent e) {
    _resetGestureState(); // 两次手势间零残留
    _phase = _Phase.down;
    _downDx = e.localPosition.dx;
    _downDy = e.localPosition.dy;
    final cellW = _lastTotalW / _count;
    _pressedIndex = cellW <= 0
        ? _selectedIndex
        : (e.localPosition.dx / cellW).floor().clamp(0, _count - 1);
    _pressDown = true;
    _velSamples
      ..clear()
      ..add((e.localPosition.dx, e.timeStamp.inMicroseconds / 1e6));
    _longPressTimer?.cancel();
    _longPressTimer = Timer(_longPressDuration, _onLongPressFired);
    _startTicker();
    _setStateSafe();
    _log('DOWN → pressedIndex=$_pressedIndex dx=${e.localPosition.dx.toStringAsFixed(1)}');
  }

  /// MOVE：按相位仲裁（微抖 ≤ slop 不得取消长按；纵向超 slop → CANCEL）
  ///  - down：横向超 slop → DRAG；纵向超 slop → CANCEL；≤ slop 忽略
  ///  - longPress：锁定，微动 ≤ slop 忽略（不偏移不改目标）；再明显横拖超 slop → DRAG
  ///  - drag：跟手
  void _onPointerMove(PointerMoveEvent e) {
    final double dxMove = e.localPosition.dx - _downDx;
    final double dyMove = e.localPosition.dy - _downDy;
    _velSamples.add((e.localPosition.dx, e.timeStamp.inMicroseconds / 1e6));
    final cutoff = _velSamples.last.$2 - _velocityWindow;
    _velSamples.removeWhere((s) => s.$2 < cutoff);
    switch (_phase) {
      case _Phase.down:
        if (dxMove.abs() > _touchSlop || dyMove.abs() > _touchSlop) {
          if (dyMove.abs() > dxMove.abs()) {
            _log('MOVE → CANCEL (vertical takeover)');
            _cancel();
          } else {
            _enterDrag();
            _log('MOVE → DRAG (slop=$_touchSlop px exceeded)');
            _applyDragFinger(dx: e.localPosition.dx);
          }
        }
        break;
      case _Phase.longPress:
        // 锁定后微动 ≤ slop 忽略（不改目标不偏移，修"长按已选中跳格"）；
        // 再明显横拖超 slop → 从锁定态转入跟手滑动
        if (dxMove.abs() > _touchSlop) {
          _enterDrag(fromDx: e.localPosition.dx);
          _log('MOVE@LONGPRESS → 转入 DRAG (再拖超 slop)');
          _applyDragFinger(dx: e.localPosition.dx);
        }
        break;
      case _Phase.drag:
        _applyDragFinger(dx: e.localPosition.dx);
        break;
      case _Phase.idle:
        break;
    }
  }

  /// UP：按相位收尾（LONGPRESS 提交 pressedIndex 且禁 fling /
  /// DRAG 吸附最近 + 快甩前进一步 / 未到时未超滑 = TAP 点击选中）
  void _onPointerUp(PointerUpEvent e) {
    final double vx = _releaseVelocity();
    switch (_phase) {
      case _Phase.longPress:
        if (_selectedIndex != _pressedIndex) _select(_pressedIndex);
        _log('UP@LONGPRESS → commit pressedIndex=$_pressedIndex, vx=${vx.toStringAsFixed(0)} ignored');
        break;
      case _Phase.drag:
        final double from = _dragFollow;
        var next = from.round().clamp(0, _count - 1);
        if (vx.abs() >= _flingVelocity) {
          next = (next + vx.sign.toInt()).clamp(0, _count - 1);
          _log('UP@DRAG → fling adopted vx=${vx.toStringAsFixed(0)} → next=$next');
        } else {
          _log('UP@DRAG → snap nearest vx=${vx.toStringAsFixed(0)} → next=$next');
        }
        _select(next, from: from);
        break;
      case _Phase.down:
        _select(_pressedIndex);
        _log('UP@DOWN → TAP select pressedIndex=$_pressedIndex');
        break;
      case _Phase.idle:
        break;
    }
    _resetGestureState();
  }

  /// 系统取消（来电/多指接管等）→ 安全回滚并清理状态
  void _onPointerCancel(PointerCancelEvent e) {
    _cancel();
  }

  /// 长按计时到点：锁定 LONGPRESS，目标 = pressedIndex，弹簧跳转 + 缩小反馈（轻震动）
  /// 长按任意菜单（无论是否已选中）都必须跳转并选中它
  void _onLongPressFired() {
    if (_phase != _Phase.down) return; // 已被 DRAG/CANCEL 抢占
    _phase = _Phase.longPress;
    HapticFeedback.lightImpact();
    _select(_pressedIndex);
    _log('LONGPRESS fired → locked, target=pressedIndex=$_pressedIndex');
    _setStateSafe();
  }

  /// 进入拖动：取消长按计时，记录抓取偏移，滑块从当前视觉位置平滑跟手。
  /// [fromDx] 抓取偏移基准手指位置（down 转 drag 用按下点；长按锁定转 drag 用当时手指点）
  void _enterDrag({double? fromDx}) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _phase = _Phase.drag;
    _dragging = true;
    _travelActive = false;
    _travelVel = 0;
    _travelSign = 0;
    _travelSignEased = 0;
    _dragFollow = _travelPos;
    _grabOffsetFrac = _dragFollow - _fracFromLocal(fromDx ?? _downDx);
    _dragTarget = _dragFollow;
    _startTicker();
    _setStateSafe();
  }

  /// 拖动跟手：目标 = 手指位置 + 抓取偏移（按住哪里拖哪里，首帧不跳变）
  void _applyDragFinger({required double dx}) {
    _dragTarget = (_fracFromLocal(dx) + _grabOffsetFrac)
        .clamp(0.0, (_count - 1).toDouble());
    _setStateSafe();
  }

  /// CANCEL：安全回滚到选中菜单 + 全量清理
  void _cancel() {
    _log('CANCEL → rollback to selectedIndex=$_selectedIndex');
    final double from = _dragging ? _dragFollow : _travelPos;
    _resetGestureState();
    _startSpring(_selectedIndex.toDouble(), from: from);
  }

  /// 每次手势开始/结束：清零全部手势状态（计时器、速度、锁定标志、按下态），零残留
  void _resetGestureState() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _phase = _Phase.idle;
    _dragging = false;
    _pressDown = false;
    _velSamples.clear();
  }

  /// 唯一选择入口（单一数据源）：selectedIndex 变更 → 弹簧目标 + TabController 页面联动。
  /// [from] 指定弹簧起点（拖动松手用跟手位置，其余默认当前视觉位置）；
  /// 动画被打断时直接以新目标为准（覆盖 _travelTarget 即可）。
  void _select(int next, {double? from}) {
    final bool changed = _selectedIndex != next;
    _selectedIndex = next;
    _startSpring(next.toDouble(),
        from: from ?? (_dragging ? _dragFollow : _travelPos));
    if (widget.tabController.index != next) {
      widget.tabController.animateTo(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (!changed) {
      _log('SELECT → same index $next (spring refresh only)');
    }
  }

  /// 弹簧奔向目标（纯可视化；保留欠阻尼过冲 + 果冻变形采样）
  void _startSpring(double targetFrac, {required double from}) {
    _dragging = false;
    _travelActive = true;
    _travelPos = from;
    _travelVel = 0;
    _travelTarget = targetFrac;
    final span = _travelTarget - _travelPos;
    _travelSign = span.abs() < 1e-6 ? 0 : span.sign;
    _startTicker();
    _setStateSafe();
  }

  /// 外部同步专用：只改弹簧目标、不清速度（页面拖动下滑块平滑追目标，无二次弹跳）
  void _startSpringFollow(double targetFrac) {
    _dragging = false;
    _travelActive = true;
    _travelTarget = targetFrac;
    final span = _travelTarget - _travelPos;
    if (span.abs() >= 1e-6) _travelSign = span.sign;
    _startTicker();
    _setStateSafe();
  }

  /// 松手速度（px/s）：速度窗内首尾斜率
  double _releaseVelocity() {
    final s = _velSamples;
    if (s.length < 2) return 0;
    final dt = s.last.$2 - s.first.$2;
    if (dt <= 0) return 0;
    return (s.last.$1 - s.first.$1) / dt;
  }

  /// 手指本地坐标 → frac（index 单位）
  double _fracFromLocal(double dx) {
    if (_lastTotalW <= 0) return 0;
    final double cellW = _lastTotalW / _count;
    return (dx - _pad) / cellW;
  }

  void _setStateSafe() {
    if (mounted) setState(() {});
  }

  void _log(String msg) {
    debugPrint('[TopTab] $msg');
  }

  // ── 物理 ticker ───────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    final last = _tickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;
    if (dt <= 0) return;

    // 1) 位置弹簧（240Hz 子步进，欠阻尼自然过冲收敛）
    if (_travelActive) {
      final r = _springStep(
        x: _travelPos,
        vel: _travelVel,
        target: _travelTarget,
        dt: dt,
      );
      _travelPos = r.$1;
      _travelVel = r.$2;
      final settled =
          (_travelPos - _travelTarget).abs() < 0.003 && _travelVel.abs() < 0.05;
      if (settled) {
        _travelPos = _travelTarget;
        _travelVel = 0;
        _travelActive = false;
      }
    }

    // 2) 按压反馈：按下 → 缩小到位；松开 → 平滑恢复
    final double pressTarget = _pressDown ? 1.0 : 0.0;
    const double pressTau = 0.045;
    _pressStrength +=
        (pressTarget - _pressStrength) * (1 - math.exp(-dt / pressTau));

    // 3) 拖动跟手：滑块平滑追手指（按住不动时目标=当前位置，不会漂移）
    if (_dragging) {
      const double followTau = 0.02;
      _dragFollow +=
          (_dragTarget - _dragFollow) * (1 - math.exp(-dt / followTau));
    }

    // 4) 采样滑块当前像素位置 → 加速度变形
    final double frac = _dragging ? _dragFollow : _travelPos;
    final double sampleX =
        _lastTotalW > 0 ? _pad + frac * (_lastTotalW / _count) : 0;
    _trackMotion(
        Offset(sampleX, 0), seconds: elapsed.inMicroseconds / 1e6, dt: dt);

    // 旅程方向键：向左拉宽、向右挤窄，整个行程一致
    if (_motionTracking) {
      if (_travelSignEased == 0) {
        _travelSignEased = _travelSign;
      } else if (_travelSignEased != _travelSign) {
        const double signTau = 0.25;
        _travelSignEased +=
            (_travelSign - _travelSignEased) * (1 - math.exp(-dt / signTau));
        if ((_travelSign - _travelSignEased).abs() < 0.01) {
          _travelSignEased = _travelSign;
        }
      }
      final double key = _travelSignEased;
      if (key != 0) {
        _deviation = _deviation * (1 - key.abs()) - key * _deviation.abs();
      }
    }

    // 5) 全部停下才停 ticker：按压/变形采样窗口要排空
    final bool pressSettled = _pressStrength < 0.001 && !_pressDown;
    final bool motionSettled = !_motionTracking || _deviation.abs() < 0.0005;
    if (!_travelActive && !_dragging && pressSettled && motionSettled) {
      _pressStrength = 0;
      _motionStop();
      _travelSign = 0;
      _travelSignEased = 0;
      _ticker?.stop();
    }

    if (mounted) setState(() {});
  }

  /// 欠阻尼弹簧积分一步（同 liquidGlassSpringStep，240Hz 子步进）
  (double, double) _springStep({
    required double x,
    required double vel,
    required double target,
    required double dt,
  }) {
    var t = dt;
    var px = x;
    var pv = vel;
    while (t > 0) {
      final step = t > 1 / 240.0 ? 1 / 240.0 : t;
      final accel = -_travelStiffness * (px - target) - _travelDamping * pv;
      pv += accel * step;
      px += pv * step;
      t -= step;
    }
    return (px, pv);
  }

  /// 每帧采样位置，窗口内平均加速度 → 变形偏差（scaleX=1+d, scaleY=1-d）
  void _trackMotion(Offset position,
      {required double seconds, required double dt}) {
    if (!_motionTracking) {
      _history.clear();
      _deviation = 0;
      _motionTracking = true;
    }
    _history.add((position, seconds));
    final cutoff = seconds - _sampleWindow;
    _history.removeWhere((s) => s.$2 < cutoff);
    final raw = (_averageAcceleration() * _sensitivity)
        .clamp(-_maxDeformation, _maxDeformation);
    final ease =
        _responseTime <= 0 ? 1.0 : (dt / _responseTime).clamp(0.0, 1.0);
    _deviation += (raw - _deviation) * ease;
  }

  double _averageAcceleration() {
    final h = _history;
    if (h.length < 3) return 0;
    final velocities = <(Offset, double)>[]; // (velocity px/s, mid time)
    for (var i = 1; i < h.length; i++) {
      final d = h[i].$2 - h[i - 1].$2;
      if (d <= 0) continue;
      velocities.add(
        ((h[i].$1 - h[i - 1].$1) / d, (h[i].$2 + h[i - 1].$2) / 2),
      );
    }
    if (velocities.length < 2) return 0;
    var total = 0.0;
    var count = 0;
    for (var i = 1; i < velocities.length; i++) {
      final d = velocities[i].$2 - velocities[i - 1].$2;
      if (d <= 0) continue;
      total += (velocities[i].$1.dx - velocities[i - 1].$1.dx) / d;
      count++;
    }
    if (count == 0) return 0;
    return total / count;
  }

  void _motionStop() {
    _motionTracking = false;
    _history.clear();
    _deviation = 0;
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final int count = _count;
    // 壁纸版大胶囊毛玻璃 sigma（全局统一调节）
    final double sigma = SpUtil.getDouble(spCardBlurSigma, defValue: 4);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double tabWidth = totalWidth / count;
        final double thumbWidth = tabWidth - _pad * 2;
        _lastTotalW = totalWidth;

        // 滑块当前位置（弹簧 / 跟手）+ 按压缩小 + 加速度果冻变形
        final double frac = _dragging ? _dragFollow : _travelPos;
        final double pressScale = 1.0 - 0.12 * _pressStrength;
        final double dew = _deviation; // 已 flip 偏差（旅行方向键统一）
        final double sx = (1 + dew).clamp(0.7, 1.3) * pressScale;
        final double sy = (1 - dew).clamp(0.7, 1.3) * pressScale;

        // 顶部 tab 大胶囊：100% 不透明固定纯色（白/黑），不模糊、不跟随卡片纯色调节
        final Widget capsule = OptimizedFrostedGlass(
          sigma: sigma,
          borderRadius: BorderRadius.circular(22),
          forceOpaqueSolid: true,
          child: Container(
            height: 43,
            decoration: BoxDecoration(
              color: widget.bgColor,
              borderRadius: BorderRadius.circular(22),
              border: widget.bgBorder,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ---------- 液态滑块（弹簧位置 + 按压缩小 + 加速度果冻变形；每帧 setState 驱动） ----------
                  Positioned(
                    left: _pad + frac * tabWidth,
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
                              const BoxShadow(
                                color: Color(0x2E000000),
                                blurRadius: 5,
                                offset: Offset(0, 3),
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
                  // ---------- 文字（颜色随滑块位置渐变） ----------
                  Row(
                    children: List.generate(count, (i) {
                      final double distance =
                          (frac - i).abs().clamp(0.0, 1.0);
                      final Color textColor = Color.lerp(
                        widget.activeColor,
                        widget.inactiveColor,
                        distance,
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
              ),
            ),
          ),
        );

        // 手势输入：raw Listener 读原始指针事件走显式状态机（slop/计时/速度自裁决）。
        // 内层空 GestureDetector 仅用于在竞技场占位横向拖拽，防止父级 TabBarView/滚动
        // 同时响应造成双动；Listener 不参与竞技场，事件流不受影响。
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {},
            onHorizontalDragUpdate: (_) {},
            onHorizontalDragEnd: (_) {},
            child: capsule,
          ),
        );
      },
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
  double get maxExtent => 55;

  @override
  double get minExtent => 55;

  @override
  bool shouldRebuild(covariant GlassSegmentedTabDelegate oldDelegate) {
    return tabs != oldDelegate.tabs ||
        tabController != oldDelegate.tabController ||
        editMode != oldDelegate.editMode;
  }
}