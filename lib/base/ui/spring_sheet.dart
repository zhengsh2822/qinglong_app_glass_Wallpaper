import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 底部弹层弹簧数值（全局唯一）
///
/// 所有底部弹层（操作弹层 / 选择器 / 备份 / 字号 / 登录等）共用这一组，
/// 禁止在页面里单独调数值，否则不同页面手感会割裂。
///
/// 参数与 demos/sheet_spring_demo 验收结果一致（质量归一为 1）：
/// - 弹出 ζ≈0.74，到位后过冲约 3%
/// - 关闭更快收走
/// - 拖拽松手弹回更欠阻尼，小位移也看得见回弹
class SpringSheetSpec {
  const SpringSheetSpec._();

  /// 弹出
  static const SpringDescription open = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 21,
  );

  /// 关闭
  static const SpringDescription close = SpringDescription(
    mass: 1,
    stiffness: 290,
    damping: 25,
  );

  /// 拖拽松手弹回打开（更欠阻尼 → 回弹明显）
  static const SpringDescription reopen = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 15.1,
  );

  /// 错层：取消胶囊等次级卡片略滞后
  static const SpringDescription trailing = SpringDescription(
    mass: 1,
    stiffness: 176,
    damping: 19.3,
  );

  /// 下拉超过弹层高度的该比例 → 关闭
  static const double closeRatio = 0.28;

  /// 松手速度阈值（像素/秒）
  static const double closeVelocity = 800;

  /// 遮罩最大浓度
  static const double barrierOpacity = 0.45;
}

/// 打开底部弹层（弹簧回弹版）
///
/// 与 `showModalBottomSheet` 用法一致，但：
/// - 弹出 / 关闭 / 拖拽松手全部走弹簧（数值见 [SpringSheetSpec]）
/// - 支持动画中途打断：再次点击触发项会从当前位置反向
/// - 动画进行中遮罩不拦截点击，完全展开后才由遮罩接管
Future<T?> showSpringSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool enableDrag = true,
  bool isDismissible = true,
  bool useRootNavigator = false,
}) {
  // 动画进行中再次触发 → 反向打断，不新开一层
  if (SpringSheetRegistry.toggleIfTransitioning()) {
    return Future<T?>.value(null);
  }
  final _SpringSheetRoute<T> route = _SpringSheetRoute<T>(
    builder: builder,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
  );
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(route);
}

/// 当前正在显示的弹簧弹层（用于点击打断）
class SpringSheetRegistry {
  const SpringSheetRegistry._();

  static _SpringSheetRoute<dynamic>? _active;

  /// 若当前弹层仍在动画（未静止展开），反向它并返回 true
  static bool toggleIfTransitioning() {
    final _SpringSheetRoute<dynamic>? route = _active;
    if (route == null || route._settled) return false;
    route._toggleFromOutside();
    return true;
  }
}

/// 次级卡片槽位（如独立取消胶囊）：比主卡片略滞后，形成轻微错层
///
/// 只有放在 [showSpringSheet] 的 builder 内才生效，其它场景原样返回。
class SpringSheetTrailing extends StatelessWidget {
  const SpringSheetTrailing({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final _SpringSheetScope? scope =
        context.dependOnInheritedWidgetOfExactType<_SpringSheetScope>();
    if (scope == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: scope.trailingDelta,
      child: child,
      builder: (BuildContext ctx, double delta, Widget? c) {
        if (delta.abs() < 0.05) return c!;
        return Transform.translate(offset: Offset(0, delta), child: c!);
      },
    );
  }
}

class _SpringSheetScope extends InheritedWidget {
  const _SpringSheetScope({
    required this.trailingDelta,
    required super.child,
  });

  final ValueListenable<double> trailingDelta;

  @override
  bool updateShouldNotify(_SpringSheetScope oldWidget) =>
      trailingDelta != oldWidget.trailingDelta;
}

class _SpringSheetRoute<T> extends PopupRoute<T> {
  _SpringSheetRoute({
    required this.builder,
    required this.enableDrag,
    required this.isDismissible,
  });

  final WidgetBuilder builder;
  final bool enableDrag;
  final bool isDismissible;

  final GlobalKey _sheetKey = GlobalKey();

  /// 归一化位移：0 = 完全展开，1 = 完全移出屏幕
  final ValueNotifier<double> _offset = ValueNotifier<double>(1);

  /// 取消胶囊相对主卡片的额外位移（像素）
  final ValueNotifier<double> _trailingDelta = ValueNotifier<double>(0);

  /// 遮罩是否接管点击（完全展开后才接管；动画中途穿透给页面，支持触发项打断）
  final ValueNotifier<bool> _barrierActive = ValueNotifier<bool>(false);

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  double _y = 1;
  double _v = 0;
  double _target = 1;
  double _ty = 1;
  double _tv = 0;
  SpringDescription _spring = SpringSheetSpec.open;

  bool _settled = false;
  bool _popping = false;
  bool _dragging = false;
  bool _started = false;
  bool _disposed = false;

  /// 手指累计位移（归一化、未做橡皮筋）+ 起手基准，
  /// 橡皮筋只能对「原始累计位移」压缩一次；若对已压缩的 y 反复压缩，
  /// 上拉位移会收敛在 1% 附近（表现为按住横条上拉几乎不动）
  double _dragRaw = 0;
  double _dragBase = 0;

  /// 列表滚到边界后由越界量驱动弹层（与拖拽共用同一套收尾逻辑）
  bool _scrollDriving = false;
  int _lastScrollUs = 0;
  double _scrollVelNorm = 0;

  /// 顶部横条带用原始指针接管拖拽（不参与手势竞技场），
  /// 保证"按住横条拖拽"一定生效，不会被列表/按钮等识别器抢走
  static const double _handleBand = 56;
  int? _pointerId;
  double _pointerDownY = 0;
  double _pointerLastY = 0;
  bool _manualDrag = false;

  T? _pendingResult;
  double _sheetHeight = 0;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  /// 不使用路由自带的 ModalBarrier：它会吞掉所有点击，
  /// 导致动画途中触发项无法被再次点到（打断）。
  /// 遮罩改由本路由自己绘制，按状态决定是否拦截点击。
  @override
  Widget buildModalBarrier() => const SizedBox.shrink();

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    if (!_started) {
      _started = true;
      SpringSheetRegistry._active = this;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _measure();
        _animateTo(0, 0, SpringSheetSpec.open);
      });
    }

    // 弹层内列表统一用 Clamping 物理：列表滚到边界后继续拖动时不要内部回弹，
    // 越界量交给弹层做橡皮筋（上拉弹层上移 / 下拉跟手关闭），与 demo 手感一致
    final Widget content = ScrollConfiguration(
      behavior: const _SheetScrollBehavior(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: _SpringSheetScope(
          trailingDelta: _trailingDelta,
          child: builder(context),
        ),
      ),
    );

    Widget sheet = KeyedSubtree(key: _sheetKey, child: content);
    if (enableDrag) {
      // 原始指针监听：顶部横条带（卡片最上方 _handleBand）绕过手势竞技场，
      // 保证"按住横条拖拽"在任何弹层里都生效
      sheet = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onVerticalDragCancel: _onDragCancel,
          child: sheet,
        ),
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: _barrierActive,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isDismissible ? _dismiss : null,
              // 遮罩区域也参与拖拽：用户按住卡片顶部横条（手指常落在卡片上沿外）
              // 时同样能带动弹层，避免"按住横条没有上拉效果"
              onVerticalDragStart: enableDrag ? _onDragStart : null,
              onVerticalDragUpdate: enableDrag ? _onDragUpdate : null,
              onVerticalDragEnd: enableDrag ? _onDragEnd : null,
              onVerticalDragCancel: enableDrag ? _onDragCancel : null,
              child: ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (BuildContext ctx, double v, Widget? _) {
                  final double p = (1 - v).clamp(0.0, 1.0);
                  return ColoredBox(
                    color: Colors.black.withValues(
                      alpha: SpringSheetSpec.barrierOpacity * p,
                    ),
                  );
                },
              ),
            ),
            builder: (BuildContext ctx, bool active, Widget? child) {
              return IgnorePointer(ignoring: !active, child: child!);
            },
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<double>(
              valueListenable: _offset,
              child: sheet,
              builder: (BuildContext ctx, double v, Widget? child) {
                return FractionalTranslation(
                  translation: Offset(0, v),
                  child: SizedBox(width: double.infinity, child: child!),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 完全展开且未拖拽时，遮罩才接管点击；动画中途点击穿透到页面（支持触发项打断）
  void _syncBarrier() {
    if (_disposed) return;
    final bool next = _settled && !_dragging;
    if (_barrierActive.value != next) _barrierActive.value = next;
  }

  void _measure() {
    final RenderBox? box =
        _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.height > 0) {
      if ((_sheetHeight - box.size.height).abs() > 0.5) {
        _sheetHeight = box.size.height;
        _notify();
      }
    }
  }

  void _ensureTicker() {
    if (_ticker != null || _disposed) return;
    _lastElapsed = Duration.zero;
    _ticker = navigator!.createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    dt = math.min(dt, 0.032);

    final int steps = math.max(1, (dt / 0.004).ceil());
    final double h = dt / steps;
    for (int i = 0; i < steps; i++) {
      _step(_spring, h);
      _stepTrailing(h);
    }
    _notify();

    final bool mainDone = _isSettledOn(_y, _v, _target);
    final bool trailingDone = _isSettledOn(_ty, _tv, _target);
    if (mainDone && trailingDone) {
      if (_target == 0) {
        _settled = true;
      } else {
        _settled = false;
        _stopTicker();
        _finishClose();
        return;
      }
    }
    if (_settled && !_dragging) {
      _stopTicker();
    }
    _syncBarrier();
  }

  bool _isSettledOn(double y, double v, double target) {
    return (y - target).abs() < 0.002 && v.abs() < 0.02;
  }

  void _step(SpringDescription s, double h) {
    final double a =
        (-s.stiffness * (_y - _target) - s.damping * _v) / s.mass;
    _v += a * h;
    _y += _v * h;
  }

  void _stepTrailing(double h) {
    final double a =
        (-SpringSheetSpec.trailing.stiffness * (_ty - _target) -
            SpringSheetSpec.trailing.damping * _tv) /
        SpringSheetSpec.trailing.mass;
    _tv += a * h;
    _ty += _tv * h;
  }

  void _notify() {
    if (_disposed) return;
    _offset.value = _y;
    _trailingDelta.value = (_ty - _y) * _sheetHeight;
  }

  /// 打断时必须清零速度：否则会带着上一段动画的惯性继续冲，看起来像没打断
  void _animateTo(double target, double velocity, SpringDescription spring) {
    _spring = spring;
    _target = target;
    _v = velocity;
    _tv = velocity;
    _settled = false;
    _ensureTicker();
    _syncBarrier();
  }

  void _toggleFromOutside() {
    if (_target == 0) {
      _dragging = false;
      _animateTo(1, 0, SpringSheetSpec.close);
    } else {
      _dragging = false;
      _animateTo(0, 0, SpringSheetSpec.open);
    }
  }

  void _dismiss() {
    if (!isDismissible) return;
    _animateTo(1, 0, SpringSheetSpec.close);
  }

  // ---------------- 拖拽 ----------------
  void _beginDrag() {
    _scrollDriving = false;
    _dragRaw = 0;
    _dragBase = _y;
    _dragging = true;
    _settled = false;
    _stopTicker();
    _v = 0;
    _tv = 0;
    _target = _y > 0.5 ? 1 : 0;
    _syncBarrier();
    _notify();
  }

  void _onDragStart(DragStartDetails details) {
    if (!enableDrag || _manualDrag) return;
    _beginDrag();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_manualDrag || !_dragging) return;
    final double h = _sheetHeight > 0 ? _sheetHeight : 1;
    _applyDragDelta(details.delta.dy / h);
  }

  // ---------------- 顶部横条：原始指针接管 ----------------
  void _onPointerDown(PointerDownEvent e) {
    if (!enableDrag || _pointerId != null || _manualDrag) return;
    final RenderBox? box =
        _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final Offset local = box.globalToLocal(e.position);
    if (!_settled) return; // 动画进行中不接管，交给点击打断逻辑
    if (local.dy < 0 || local.dy > _handleBand) return;
    _pointerId = e.pointer;
    _pointerDownY = e.position.dy;
    _pointerLastY = e.position.dy;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointerId) return;
    if (!_manualDrag) {
      final double moved = e.position.dy - _pointerDownY;
      if (moved.abs() < 8) return;
      if (_dragging) {
        // 已由 GestureDetector 接管，避免重复驱动
        _pointerId = null;
        return;
      }
      _manualDrag = true;
      _beginDrag();
      _pointerLastY = e.position.dy;
      return;
    }
    final double step = e.position.dy - _pointerLastY;
    _pointerLastY = e.position.dy;
    final double h = _sheetHeight > 0 ? _sheetHeight : 1;
    _applyDragDelta(step / h);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _pointerId) return;
    _finishManualDrag();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _pointerId) return;
    _finishManualDrag();
  }

  void _finishManualDrag() {
    _pointerId = null;
    if (!_manualDrag) return;
    _manualDrag = false;
    _endDragNorm(0);
  }

  /// 上拉橡皮筋：越拉越沉（与 demo `rubber(x)` 同一公式）
  double _rubberUp(double over) {
    const double d = 0.8;
    return (over * d * 0.55) / (d + 0.55 * over);
  }

  /// 下拉越界阻尼更重（避免拖出屏幕）
  double _rubberDown(double over) => _rubberUp(over) * 0.4;

  void _applyDragDelta(double deltaNorm) {
    _dragRaw += deltaNorm;
    double next = _dragBase + _dragRaw;
    if (next < 0) {
      next = -_rubberUp(-next);
    } else if (next > 1) {
      next = 1 + _rubberDown(next - 1);
    }
    _y = next;
    _ty = next;
    _notify();
  }

  /// 列表滚到边界后的越界量转交弹层：
  /// 顶部继续下拉 → 弹层跟手下移（可顺势关闭）；底部继续上拉 → 弹层橡皮筋上移
  bool _handleScrollNotification(ScrollNotification n) {
    if (_disposed) return false;
    if (n is ScrollEndNotification) {
      if (!_scrollDriving) return false;
      _scrollDriving = false;
      final int now = DateTime.now().microsecondsSinceEpoch;
      final bool fresh = _lastScrollUs != 0 && (now - _lastScrollUs) < 90000;
      _endDragNorm(fresh ? _scrollVelNorm : 0);
      return false;
    }
    if (n is! OverscrollNotification || n.dragDetails == null) return false;

    if (!_scrollDriving) {
      _scrollDriving = true;
      _dragRaw = 0;
      _dragBase = _y;
      _dragging = true;
      _settled = false;
      _stopTicker();
      _v = 0;
      _tv = 0;
      _target = _y > 0.5 ? 1 : 0;
      _lastScrollUs = 0;
      _syncBarrier();
    }

    final double h = _sheetHeight > 0 ? _sheetHeight : 1;
    final double before = _y;
    _applyDragDelta(-n.overscroll / h);

    // 用弹层位移估算速度，供松手时判定关闭/弹回
    final int now = DateTime.now().microsecondsSinceEpoch;
    if (_lastScrollUs != 0) {
      final double dt = (now - _lastScrollUs) / 1000000.0;
      if (dt > 0.0005 && dt < 0.12) {
        final double inst = (_y - before) / dt;
        _scrollVelNorm = _scrollVelNorm * 0.6 + inst * 0.4;
      } else {
        _scrollVelNorm = 0;
      }
    } else {
      _scrollVelNorm = 0;
    }
    _lastScrollUs = now;
    return false;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_manualDrag || !_dragging) return;
    final double h = _sheetHeight > 0 ? _sheetHeight : 1;
    _endDragNorm((details.primaryVelocity ?? 0) / h);
  }

  /// [vNorm]：归一化位移速度（向下为正，单位：弹层高度/秒）
  void _endDragNorm(double vNorm) {
    if (!_dragging) return;
    _dragging = false;
    final double h = _sheetHeight > 0 ? _sheetHeight : 1;
    final double threshold = SpringSheetSpec.closeVelocity / h;
    final bool shouldClose =
        _y > SpringSheetSpec.closeRatio ||
        (vNorm > threshold && _y > 0.02);
    if (shouldClose) {
      _animateTo(1, math.max(0, vNorm), SpringSheetSpec.close);
    } else {
      _animateTo(0, math.min(0, vNorm), SpringSheetSpec.reopen);
    }
  }

  void _onDragCancel() {
    if (_manualDrag || !_dragging) return;
    _dragging = false;
    _animateTo(_y > 0.5 ? 1 : 0, 0, SpringSheetSpec.open);
  }

  void _finishClose() {
    if (_popping || _disposed) return;
    _popping = true;
    final T? result = _pendingResult;
    final NavigatorState? nav = navigator;
    if (nav != null && nav.mounted) {
      if (isCurrent) {
        nav.pop<T>(result);
      } else {
        // 理论上不会发生（弹层拦截了其它交互），兜底避免误弹其它路由
        nav.removeRoute(this);
      }
    }
  }

  @override
  bool didPop(T? result) {
    if (_popping) return super.didPop(result);
    _pendingResult = result;
    _dragging = false;
    _animateTo(1, 0, SpringSheetSpec.close);
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    if (identical(SpringSheetRegistry._active, this)) {
      SpringSheetRegistry._active = null;
    }
    _stopTicker();
    _offset.dispose();
    _trailingDelta.dispose();
    super.dispose();
  }
}

/// 弹层内统一滚动物理：边界不回弹（否则列表自己吃掉越界量），
/// 越界量由 `_handleScrollNotification` 交给弹层做橡皮筋。
/// 父级滚动行为是全局 BouncingScrollPhysics（见 main.dart），此处必须覆盖。
class _SheetScrollBehavior extends ScrollBehavior {
  const _SheetScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
