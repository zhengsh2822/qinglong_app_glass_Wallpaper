import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 弹性拖拽排序列表（自管槽位弹簧）
///
/// 参数与手感来自 demos/card_drag_reorder_demo 验收结果：
/// - 长按 320ms 抓取，抓取放大 1.03 倍 + 浮起阴影
/// - 其余卡片弹性让位：越过目标槽位后回弹
/// - 插入点上下两张邻卡都会被撑开再收回（拖动中 6px、落位瞬间 8px）
/// - 松手后卡片弹簧吸附到目标槽位（欠阻尼自然过冲）+ 轻微 squash
///
/// 说明：Flutter 自带 `SliverReorderableList` 的让位动画固定 250ms
/// `Curves.easeInOut`（无过冲）且不可配置，因此这里自管拖拽与槽位弹簧。
class ElasticReorderList<T> extends StatefulWidget {
  const ElasticReorderList({
    super.key,
    required this.items,
    required this.itemKey,
    required this.itemBuilder,
    required this.onReorder,
    this.enabled = true,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.autoScroll = true,
  });

  /// 当前顺序的数据列表（拖拽结束时通过 [onReorder] 通知外部修改它）
  final List<T> items;

  /// 每项稳定唯一 key（用于弹簧状态、尺寸测量与重排前的顺序缓存）
  final Key Function(T item) itemKey;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 与 `ReorderableListView.onReorder` 完全一致：
  /// 若 newIndex > oldIndex，调用方需自行 `newIndex -= 1` 再 removeAt/insert
  final ReorderCallback onReorder;

  /// 是否允许长按拖拽
  final bool enabled;

  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// 拖拽到列表上下边缘时是否自动滚动（内嵌在外部滚动视图时建议关闭）
  final bool autoScroll;

  @override
  State<ElasticReorderList<T>> createState() => _ElasticReorderListState<T>();
}

/// 长按触发时长（与 demo 一致，长按 320ms 抓取）
const Duration kElasticLongPressDelay = Duration(milliseconds: 320);

/// 抓取放大比例
const double kElasticLiftScale = 1.03;

/// 邻卡让位弹簧：在松手弹簧（k=420 / c=20）基础上提高刚度与阻尼
/// 效果：越过目标槽位约 8px 后收敛
const double kElasticSlotStiffness = 420 * 1.55;
const double kElasticSlotDamping = 20 * 1.30;

/// 插入点另一侧邻卡被撑开的位移（拖动中）
const double kElasticPulse = 6;

/// 落位瞬间上下两张邻卡被撑开的位移
const double kElasticDropPulse = 8;

/// 松手落位弹簧（欠阻尼，自然过冲）
const double kElasticDropStiffness = 420;
const double kElasticDropDamping = 20;

/// 单个标量弹簧状态（槽位偏移 / 落位位移 / 抬升）
class _ScalarSpring {
  _ScalarSpring({
    this.value = 0,
    this.target = 0,
    this.stiffness = kElasticSlotStiffness,
    this.damping = kElasticSlotDamping,
  });

  double value;
  double velocity = 0;
  double target;
  final double stiffness;
  final double damping;
  bool active = false;
}

class _DragSession {
  _DragSession({
    required this.key,
    required this.originalIndex,
    required this.size,
    required this.localLeft,
    required this.localTop,
    required this.localPointer,
    required this.proxyChild,
  });

  final Key key;
  final int originalIndex;
  final Size size;
  final double localLeft;
  final double localTop;
  final Offset localPointer;
  final Widget proxyChild;
}

class _ElasticReorderListState<T> extends State<ElasticReorderList<T>>
    with TickerProviderStateMixin {
  final GlobalKey _stackKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  final Map<Key, GlobalKey> _itemKeys = <Key, GlobalKey>{};
  final Map<Key, ValueNotifier<double>> _slotOffsets =
      <Key, ValueNotifier<double>>{};
  final Map<Key, _ScalarSpring> _slotSprings = <Key, _ScalarSpring>{};

  final ValueNotifier<double> _proxyTop = ValueNotifier<double>(0);
  final ValueNotifier<double> _proxyLift = ValueNotifier<double>(0);

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  List<Key>? _dragOrder;
  _DragSession? _drag;
  Offset _pointerGlobal = Offset.zero;
  bool _dropping = false;
  _ScalarSpring? _dropSpring;

  @override
  void dispose() {
    _ticker?.dispose();
    _scroll.dispose();
    _proxyTop.dispose();
    _proxyLift.dispose();
    for (final ValueNotifier<double> n in _slotOffsets.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    _lastElapsed = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    dt = math.min(dt, 0.032);

    bool active = false;

    // 槽位弹簧：邻卡让位 / 撑开脉冲
    for (final MapEntry<Key, _ScalarSpring> entry in _slotSprings.entries) {
      final _ScalarSpring s = entry.value;
      if (!s.active) continue;
      final double a =
          -s.stiffness * (s.value - s.target) - s.damping * s.velocity;
      s.velocity += a * dt;
      s.value += s.velocity * dt;
      if ((s.value - s.target).abs() < 0.35 && s.velocity.abs() < 8) {
        s.value = s.target;
        s.velocity = 0;
        s.active = false;
        _slotOffsets[entry.key]?.value = s.value;
      } else {
        _slotOffsets[entry.key]?.value = s.value;
        active = true;
      }
    }

    final _DragSession? drag = _drag;
    if (drag != null) {
      // 抓取抬升 / 落位还原
      final double targetLift = _dropping ? 0 : 1;
      final double diff = targetLift - _proxyLift.value;
      if (diff.abs() > 0.001) {
        _proxyLift.value += diff * math.min(1.0, dt * 18);
        active = true;
      } else if (_proxyLift.value != targetLift) {
        _proxyLift.value = targetLift;
      }

      // 落位位移弹簧
      final _ScalarSpring? drop = _dropSpring;
      if (drop != null && drop.active) {
        final double a =
            -drop.stiffness * (drop.value - drop.target) -
            drop.damping * drop.velocity;
        drop.velocity += a * dt;
        drop.value += drop.velocity * dt;
        _proxyTop.value = drop.value;
        if ((drop.value - drop.target).abs() < 0.4 &&
            drop.velocity.abs() < 20) {
          _proxyTop.value = drop.target;
          drop.active = false;
          _finishDrop();
        } else {
          active = true;
        }
      }

      // 拖到上下边缘自动滚动
      if (!_dropping && widget.autoScroll) {
        if (_autoScrollTick(dt)) active = true;
      }
    }

    if (!active && _ticker != null && _drag == null) {
      _ticker!.stop();
      _ticker = null;
    }
  }

  bool _autoScrollTick(double dt) {
    if (!_scroll.hasClients) return false;
    final RenderBox? box =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final double height = box.size.height;
    final double dy = _pointerGlobal.dy - box.localToGlobal(Offset.zero).dy;
    const double edge = 90;
    const double maxSpeed = 900;
    double v = 0;
    if (dy < edge) {
      v = -math.min(1.0, (edge - dy) / edge) * maxSpeed;
    } else if (dy > height - edge) {
      v = math.min(1.0, (dy - (height - edge)) / edge) * maxSpeed;
    } else {
      return false;
    }
    final ScrollPosition pos = _scroll.position;
    final double next =
        (pos.pixels + v * dt).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (next == pos.pixels) return false;
    pos.jumpTo(next);
    _updateDrag(_pointerGlobal);
    return true;
  }

  double? _localTopOf(Key key) {
    final RenderObject? ro =
        _itemKeys[key]?.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return null;
    final Offset local = stackBox.globalToLocal(ro.localToGlobal(Offset.zero));
    final double offset = _slotOffsets[key]?.value ?? 0;
    return local.dy - offset;
  }

  double? _heightOf(Key key) {
    final RenderObject? ro =
        _itemKeys[key]?.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.size.height;
  }

  Drag? _handleDragStart(Key key, Offset globalPosition) {
    if (!widget.enabled || _drag != null) return null;
    _startDrag(key, globalPosition);
    if (_drag == null) return null;
    return _ElasticDrag(onUpdate: _updateDrag, onEnd: _endDrag);
  }

  void _startDrag(Key key, Offset globalPosition) {
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? box =
        _itemKeys[key]?.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || box == null || !box.hasSize) return;

    final Map<Key, T> byKey = _itemsByKey();
    final T? item = byKey[key];
    if (item == null) return;
    final int index = widget.items.indexOf(item);
    if (index < 0) return;

    final Offset topLeftLocal =
        stackBox.globalToLocal(box.localToGlobal(Offset.zero));
    final Size size = box.size;

    setState(() {
      _dragOrder = widget.items.map(widget.itemKey).toList();
      _drag = _DragSession(
        key: key,
        originalIndex: index,
        size: size,
        localLeft: topLeftLocal.dx,
        localTop: topLeftLocal.dy,
        localPointer: stackBox.globalToLocal(globalPosition),
        proxyChild: widget.itemBuilder(context, item, index),
      );
      _proxyTop.value = topLeftLocal.dy;
      _proxyLift.value = 0;
    });
    _pointerGlobal = globalPosition;
    _ensureTicker();
  }

  void _updateDrag(Offset globalPosition) {
    final _DragSession? d = _drag;
    if (d == null || _dropping) return;
    _pointerGlobal = globalPosition;
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    final Offset local = stackBox.globalToLocal(globalPosition);
    _proxyTop.value = d.localTop + (local.dy - d.localPointer.dy);
    final int? insert = _computeInsertIndex(_proxyTop.value + d.size.height / 2);
    if (insert != null) _moveDragTo(insert);
  }

  /// 计算插入位置（在「移除拖拽项后的顺序」中的下标）
  ///
  /// 未构建的项只能在视口之外：位于首个已构建项之前的都算在拖拽点上方，
  /// 之后的都算下方，因此用「已构建项的中心」即可完成判定，
  /// 同时天然支持贴住列表底部时继续插入末位。
  int? _computeInsertIndex(double center) {
    final List<Key> order = _dragOrder ?? <Key>[];
    final _DragSession? d = _drag;
    if (d == null || order.isEmpty) return null;

    int firstBuilt = order.length;
    final List<MapEntry<int, double>> centers = <MapEntry<int, double>>[];
    for (int i = 0; i < order.length; i++) {
      final Key key = order[i];
      final double? top = _localTopOf(key);
      if (top == null) continue;
      if (i < firstBuilt) firstBuilt = i;
      if (key == d.key) continue;
      final double h = _heightOf(key) ?? 0;
      centers.add(MapEntry<int, double>(i, top + h / 2));
    }
    if (centers.isEmpty && firstBuilt >= order.length) return null;

    int insert = 0;
    for (int i = 0; i < firstBuilt; i++) {
      if (order[i] != d.key) insert++;
    }
    for (final MapEntry<int, double> c in centers) {
      if (c.value < center) insert++;
    }
    return insert;
  }

  void _moveDragTo(int insert) {
    final _DragSession? d = _drag;
    final List<Key>? order = _dragOrder;
    if (d == null || order == null) return;
    final int current = order.indexOf(d.key);
    if (current < 0 || insert == current) return;

    order.removeAt(current);
    order.insert(insert, d.key);

    final double extent = d.size.height;
    setState(() {
      if (insert > current) {
        // 拖拽项下移：中间项整体上移一格 → 先补正偏移保持原位，再弹簧归零
        for (int i = current; i < insert; i++) {
          _shiftSlot(order[i], extent);
        }
        if (insert + 1 < order.length) {
          _pulseSlot(order[insert + 1], kElasticPulse);
        }
      } else {
        // 拖拽项上移：中间项整体下移一格
        for (int i = insert + 1; i <= current; i++) {
          _shiftSlot(order[i], -extent);
        }
        if (insert - 1 >= 0) {
          _pulseSlot(order[insert - 1], -kElasticPulse);
        }
      }
    });
  }

  void _shiftSlot(Key key, double delta) {
    final _ScalarSpring s = _slotSprings.putIfAbsent(
      key,
      () => _ScalarSpring(),
    );
    s.value += delta;
    s.target = 0;
    s.active = true;
    _slotOffsets.putIfAbsent(key, () => ValueNotifier<double>(0)).value =
        s.value;
    _ensureTicker();
  }

  void _pulseSlot(Key key, double delta) {
    final _ScalarSpring s = _slotSprings.putIfAbsent(
      key,
      () => _ScalarSpring(),
    );
    if (s.value.abs() > 1.5) return;
    s.value += delta;
    s.velocity = 0;
    s.target = 0;
    s.active = true;
    _slotOffsets.putIfAbsent(key, () => ValueNotifier<double>(0)).value =
        s.value;
    _ensureTicker();
  }

  void _endDrag() {
    final _DragSession? d = _drag;
    final List<Key>? order = _dragOrder;
    if (d == null || order == null) return;

    final int finalPos = order.indexOf(d.key);
    final bool moved = finalPos >= 0 && finalPos != d.originalIndex;
    final double targetTop = _localTopOf(d.key) ?? _proxyTop.value;

    _dropping = true;

    if (moved) {
      final int newIndex = finalPos > d.originalIndex
          ? finalPos + 1
          : finalPos;
      widget.onReorder(d.originalIndex, newIndex);
      // 落位瞬间：目标槽位上下两张邻卡都被撑开
      if (finalPos > 0) _pulseSlot(order[finalPos - 1], -kElasticDropPulse);
      if (finalPos < order.length - 1) {
        _pulseSlot(order[finalPos + 1], kElasticDropPulse);
      }
    }

    setState(() {
      _dragOrder = null;
    });

    _dropSpring = _ScalarSpring(
      value: _proxyTop.value,
      target: targetTop,
      stiffness: kElasticDropStiffness,
      damping: kElasticDropDamping,
    )..active = true;
    _ensureTicker();

    // 重建后校准一次目标：外部可能拒绝本次重排（如搜索态），
    // 此时占位卡会回到原位置，代理需要跟着回到正确落点。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _drag != d) return;
      final double? t = _localTopOf(d.key);
      final _ScalarSpring? drop = _dropSpring;
      if (t != null && drop != null && (t - drop.target).abs() > 0.4) {
        drop.target = t;
        drop.active = true;
        _ensureTicker();
      }
    });
  }

  void _finishDrop() {
    _dropSpring = null;
    _dropping = false;
    if (mounted) {
      setState(() {
        _drag = null;
      });
    }
  }

  Map<Key, T> _itemsByKey() {
    final Map<Key, T> map = <Key, T>{};
    for (final T item in widget.items) {
      map[widget.itemKey(item)] = item;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final Map<Key, T> byKey = _itemsByKey();
    final List<Key> keys = <Key>[];
    final List<Key> source =
        _dragOrder ?? widget.items.map(widget.itemKey).toList();
    for (final Key key in source) {
      if (byKey.containsKey(key)) keys.add(key);
    }

    final Widget list = ListView.builder(
      controller: _scroll,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      itemCount: keys.length,
      itemBuilder: (BuildContext ctx, int index) {
        final Key key = keys[index];
        return _buildItem(ctx, key, byKey[key] as T, index);
      },
    );

    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: <Widget>[list, if (_drag != null) _buildProxyLayer(context)],
    );
  }

  Widget _buildItem(BuildContext context, Key key, T item, int index) {
    final GlobalKey gk = _itemKeys.putIfAbsent(key, () => GlobalKey());
    final ValueNotifier<double> offset = _slotOffsets.putIfAbsent(
      key,
      () => ValueNotifier<double>(0),
    );
    final bool hidden = _drag != null && _drag!.key == key;

    // 注意：拖拽句柄必须始终存在（不能因为开始拖拽就移除），
    // 否则包裹它的 RawGestureDetector 被卸载会销毁正在跟踪指针的识别器，
    // 导致后续 move/up 全部丢失。
    Widget content = Opacity(
      opacity: hidden ? 0 : 1,
      child: IgnorePointer(
        ignoring: hidden,
        child: widget.itemBuilder(context, item, index),
      ),
    );
    if (widget.enabled) {
      content = _ElasticDragHandle(
        onStart: (Offset position) => _handleDragStart(key, position),
        child: content,
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: offset,
      child: KeyedSubtree(key: gk, child: content),
      builder: (BuildContext ctx, double value, Widget? child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
    );
  }

  Widget _buildProxyLayer(BuildContext context) {
    final _DragSession d = _drag!;
    return Positioned.fill(
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: _proxyTop,
          builder: (BuildContext ctx, double top, Widget? child) {
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: d.localLeft,
                  top: top,
                  width: d.size.width,
                  height: d.size.height,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _proxyLift,
                    child: Material(
                      type: MaterialType.transparency,
                      child: d.proxyChild,
                    ),
                    builder: (BuildContext ctx, double lift, Widget? child) {
                      return _ElasticLiftDecor(
                        lift: lift,
                        dropping: _dropping,
                        isDark:
                            Theme.of(ctx).brightness == Brightness.dark,
                        child: child!,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 卡片拖拽代理：抓取放大 + 阴影渐显 + 落位 squash
class _ElasticLiftDecor extends StatelessWidget {
  const _ElasticLiftDecor({
    required this.lift,
    required this.dropping,
    required this.isDark,
    required this.child,
  });

  final double lift;
  final bool dropping;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    double squash = 0;
    if (dropping) {
      final double p = (1 - lift).clamp(0.0, 1.0);
      squash = -0.04 * math.sin(math.pi * math.pow(p, 2.2).toDouble());
    }
    final double scale =
        (1.0 + (kElasticLiftScale - 1.0) * lift + squash).clamp(0.9, 1.2);

    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: lift <= 0.001
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: (isDark ? 0.35 : 0.10) * lift,
                    ),
                    blurRadius: (isDark ? 24 : 20) * lift,
                    spreadRadius: (isDark ? 1 : 0) * lift,
                    offset: Offset(0, (isDark ? 8 : 6) * lift),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

/// 长按 320ms 抓取（与 ReorderableDelayedDragStartListener 同机制，时长可配）
class _ElasticDragHandle extends StatefulWidget {
  const _ElasticDragHandle({required this.onStart, required this.child});

  final Drag? Function(Offset position) onStart;
  final Widget child;

  @override
  State<_ElasticDragHandle> createState() => _ElasticDragHandleState();
}

class _ElasticDragHandleState extends State<_ElasticDragHandle> {
  late final DelayedMultiDragGestureRecognizer _recognizer =
      DelayedMultiDragGestureRecognizer(
        delay: kElasticLongPressDelay,
        debugOwner: this,
      );

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        DelayedMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              DelayedMultiDragGestureRecognizer
            >(() => _recognizer, (DelayedMultiDragGestureRecognizer instance) {
              instance.onStart = widget.onStart;
            }),
      },
      child: widget.child,
    );
  }
}

class _ElasticDrag extends Drag {
  _ElasticDrag({required this.onUpdate, required this.onEnd});

  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.globalPosition);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}
