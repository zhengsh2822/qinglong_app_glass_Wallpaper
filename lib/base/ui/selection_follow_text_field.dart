import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 选区滚动跟随多行文本框 —— 嵌套滚动 + 边缘自动滚动（A 方案，同步主题版）
///
/// 解决的问题：
/// 1. IME「开始选择 → 方向键延伸」跨屏时视口不跟随 active 端点滚动；
/// 2. 手柄拖到框外后内容不再滚动（旧版只能靠手指位移带动），松手后最后一行
///    被框底裁掉、所见非所选；
/// 3. 全选后抓顶端手柄往下拖时，框架把视图一路滚到 selection.extent（文本末尾）
///    —— 表现为"一拖就跳到底部"，没法有序逐行取消选中；
/// 4. 已有选区时手指按在文字上滑动，选区被框架当成"移动光标"而清掉。
///
/// 机制：
/// A. 从源头接管框架的滚动（两条路径都堵）：
///    - [_VetoScrollController] 否决框架的 `_scrollController.animateTo/jumpTo`：
///      EditableText 每次 userUpdateTextEditingValue 都会 _scheduleShowCaretOnScreen
///      把光标强制滚进可视区，与我们自己的修正互相拉锯（方向切换时表现为抖动）；
///    - [_NoImplicitScrollPhysics] 关掉 allowImplicitScrolling，堵住
///      `renderEditable.showOnScreen → RenderViewport.showOnScreen → offset.moveTo`
///      这条绕开 ScrollController 的路径（它就是"一拖就跳到底"的元凶）。
///      注意不能用 NeverScrollableScrollPhysics：其 shouldAcceptUserOffset 为 false，
///      Scrollable 会连拖动识别器都不注册 → 框内滑动直接失效。
/// B. 边缘自动滚动（手柄拖出框外）：16ms ticker，越界越多滚得越快（14~240 px/s）、
///    单帧最多一行，滚到哪选到哪 —— 每 tick 把正在拖的那一端钳到可视边缘那一行
///    （所见即所选）；被拖端顶到文本头/尾（_activeStuck）即停表。松手时再钳一次。
/// C. 「滑动查看」：已有选区时手指按在框内拖动 = 只滚内容、选区原样保留；没拖动
///    （只是点一下）则按框架原意把光标落到点击处。
/// D. IME 方向键延伸：非指针期间保留逐层修正 + maxStepPerEvent/scrollIntervalMs
///    限频（框架滚动由 A 的否决窗口让位，窗口时长与旧版抑制机制一致 300ms）。
/// E. 判定"被拖的是哪一端"按 offsets 变化判断（不能按方向猜：从顶部往下拖起点
///    手柄与从底部往上拖终点手柄同样是"反向"，猜错就会把另一端改掉）。
///
/// 视觉：壁纸版胶囊形毛玻璃（OptimizedFrostedGlass + 卡片模糊 sigma + 0.5 描边），
/// 与 GlassTextField 风格一致。
///
/// 诊断：debugPrint("[SelFollow] ...") 输出挂载、滚动层链、selection 变化、
/// 边缘拖拽/滑动查看接管、ticker 每步位移；kDebugMode 下默认显示屏幕角标。
class SelectionFollowTextField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int maxLines;
  final int minLines;
  final InputDecoration? decoration;
  final bool autofocus;
  final bool enabled;

  /// 诊断标签：标记当前挂在哪个页面哪个字段。
  final String debugLabel;

  /// 功能总开关（诊断时可关闭跟随，仅观察日志）。
  final bool enableFollow;

  /// 滚动后 caret 距视口上/下边缘的安全距离（px），越大越早触发滚动。
  final double edgePadding;

  /// 单次滚动最大位移（以行高为单位）：滚动步长跟随"光标实际越出视口的距离"
  /// —— 短按/小越界滚 1 行（精确可控），持续按住光标越界加深时滚到上限
  /// （快速选多行），真正"跟随越界距离"。默认 8 行（激进档）。
  final double maxStepPerEvent;

  /// 滚动限频（毫秒）：IME 长按连发频率固定且很高，若每事件都滚会飞滚
  /// 无法控制。限频后每 [scrollIntervalMs] 最多实际滚动一次（步长见
  /// [maxStepPerEvent]），按住时长决定滚动距离、松手即停。默认 80ms（激进档）。
  final int scrollIntervalMs;

  /// 屏幕角标：显示实时修正量。默认 kDebugMode 下开启。
  final bool showDebugBadge;

  const SelectionFollowTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.maxLines = 1,
    this.minLines = 1,
    this.decoration,
    this.autofocus = false,
    this.enabled = true,
    this.debugLabel = '',
    this.enableFollow = true,
    this.edgePadding = 24,
    this.maxStepPerEvent = 8.0,
    this.scrollIntervalMs = 80,
    this.showDebugBadge = kDebugMode,
  });

  @override
  ConsumerState<SelectionFollowTextField> createState() =>
      _SelectionFollowTextFieldState();
}

/// 只做一件事：接管滚动期间否决框架自己的"光标可见性滚动"。
///
/// EditableText 每次 userUpdateTextEditingValue（手柄拖拽时每帧都会调）都会
/// `_scheduleShowCaretOnScreen → _scrollController.animateTo(...)`，把光标滚进
/// 可视区。手指在框外时它会一路把内容顶到底，还会和我们的边缘滚动互相抢 →
/// 表现成"视图/选区上下反复跳动"。接管期间这里直接否决掉。
class _VetoScrollController extends ScrollController {
  _VetoScrollController(this.shouldVeto);

  final bool Function() shouldVeto;

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) {
    if (shouldVeto()) return Future<void>.value();
    return super.animateTo(offset, duration: duration, curve: curve);
  }

  @override
  void jumpTo(double value) {
    if (shouldVeto()) return;
    super.jumpTo(value);
  }
}

/// 只关掉"隐式滚动"，保留手指拖动与程序化滚动。
///
/// 框架的"让光标可见"除了 `_scrollController.animateTo`，还会走
/// `renderEditable.showOnScreen(rect:)` → `RenderViewport.showOnScreen`
/// → `offset.moveTo()`，直接操作 ScrollPosition、绕开 ScrollController。
/// 它只在 `physics.allowImplicitScrolling` 为 true 时执行，而默认 physics 就是
/// true → 全选后拖顶端手柄时视图会一路滑到 selection.extent（文本末尾）。
///
/// 注意不能用 NeverScrollableScrollPhysics：它的 shouldAcceptUserOffset 为
/// false，Scrollable 会连拖动识别器一起不注册 → 框内滑动直接失效。
class _NoImplicitScrollPhysics extends ScrollPhysics {
  const _NoImplicitScrollPhysics({super.parent});

  @override
  _NoImplicitScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _NoImplicitScrollPhysics(parent: buildParent(ancestor));

  @override
  bool get allowImplicitScrolling => false;
}

class _SelectionFollowTextFieldState
    extends ConsumerState<SelectionFollowTextField> {
  final GlobalKey _fieldKey = GlobalKey();
  TextSelection? _lastSelection;
  double _lastDeltaPx = 0;

  /// 交给 EditableText 使用的滚动控制器：接管期间否决框架自己的滚动（见类说明）
  late final _VetoScrollController _scrollController = _VetoScrollController(
    () => _takeoverScrollNow(),
  );

  /// 本组件自己改写选区时的重入保护
  bool _rewriting = false;

  /// IME（非指针）期间的接管窗口：selection 变化后的一小段时间内否决框架滚动
  /// （框架用被 maxLines 裁剪的 caret 矩形算目标位置，会与我们的逐层修正拉锯）
  bool _imeVeto = false;
  Timer? _imeVetoTimer;
  int _lastScrollAtMs = 0;

  // ── 指针状态（边缘拖拽 + 滑动查看）────────────────────────────
  bool _pointerDown = false;
  Offset _pointer = Offset.zero;
  Timer? _ticker;
  int _lastTickMs = 0;

  /// 本次触摸是否按在值框窗口内
  bool _pdInBox = false;

  /// 本次触摸是否主动扩展过选区（手柄拖拽/长按拖选）
  bool _pdSelectionDrag = false;

  /// 本次触摸是否判定为「滑动查看」
  bool _pdScrollView = false;

  /// 框架把手柄外的拖动当成"移动光标"（会毁掉选区）
  bool _pdFrameworkCaret = false;
  double _pdLastY = 0;

  /// 本次触摸的按下位置（区分"点一下"和"拖动"）
  Offset? _pdDown;

  /// 按下时的选区，滑动查看期间原样保留
  TextSelection? _pdSnapshot;

  /// 框架想把光标落到的位置（点一下才用它）
  TextSelection? _pdCaretSel;

  /// 正在拖的是选区起点 base（false = 终点 extent）
  bool _pdSideBase = false;

  /// 本次触摸是否真的拖动过（位移超过 [_kDragSlop]）。
  ///
  /// 点工具栏按钮时（全选/复制/粘贴…）指针落在值框外侧、又恰好带着
  /// "有选区 + 有焦点"的状态，如果不看位移就当成边缘拖拽，松手那一刻会把
  /// 选区钳到可视边缘 → 框架据此重建整个工具栏 → 按钮的 tap 落空，
  /// 表现成"工具栏按钮点了没反应"。点一下不算拖，必须真的移动过才算。
  bool _pdMoved = false;

  /// 区分"点一下"与"拖动"的位移阈值（logical px）
  static const double _kDragSlop = 12;

  /// 元素树遍历结果缓存（指针事件 120Hz，不能每次都 DFS）
  EditableTextState? _editableCache;
  List<ScrollableState>? _layersCache;

  // ── 屏幕角标 ─────────────────────────────────────────────────
  OverlayEntry? _badgeEntry;
  final ValueNotifier<String> _badgeText = ValueNotifier<String>('');

  // 路由引用缓存：initState 中不可调用 ModalRoute.of（依赖 inherited widget 会触发
  // 框架断言"dependOnInheritedWidgetOfExactType called before initState completed"红屏），
  // 改在 didChangeDependencies 中获取并缓存，供手势错峰/离场短路复用
  ModalRoute<dynamic>? _modal;

  @override
  void initState() {
    super.initState();
    _log(
      'initState: mounted on <${widget.debugLabel}>, '
      'controllerHash=0x${widget.controller.hashCode.toRadixString(16)}, '
      'enableFollow=${widget.enableFollow}, edgePadding=${widget.edgePadding}, '
      'maxStep=${widget.maxStepPerEvent}',
    );
    widget.controller.addListener(_onSelectionChanged);
    // 手柄拖拽的事件走 Overlay 手势，普通 Listener 收不到 →
    // 必须挂全局 pointerRouter（框架内部也是这么跟踪的）
    if (widget.enableFollow) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    }
    _mountBadge();
    // 首帧后打印滚动层链（诊断 3）
    WidgetsBinding.instance.addPostFrameCallback((_) => _dumpScrollableChain());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // initState 期间禁止依赖 inherited widget，路由引用只能在依赖就绪后获取。
    final modal = ModalRoute.of(context);
    if (!identical(modal, _modal)) {
      final old = _modal;
      if (old != null && old.animation != null) {
        old.animation!.removeStatusListener(_onRouteAnimationStatus);
      }
      _modal = modal;
      if (modal != null && modal.animation != null) {
        // 手势返回错峰：监听路由动画，进入 reverse（手势左滑/反向动画播放）时
        // 立即收起键盘，让键盘收起动画与路由反向动画错开，避免双重动画叠加掉帧
        modal.animation!.addStatusListener(_onRouteAnimationStatus);
      }
    }
  }

  /// 路由动画状态变化：reverse（手势返回/反向动画播放）时主动收起键盘，
  /// 把键盘隐藏动画从路由动画中错峰出去（键盘动画 200-300ms + 路由动画 400ms
  /// 重叠会让帧预算被打满，是手势返回掉帧的主因之一）
  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      final focus = FocusManager.instance.primaryFocus;
      if (focus != null && focus.hasFocus) {
        focus.unfocus();
      }
    }
  }

  @override
  void didUpdateWidget(covariant SelectionFollowTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_onSelectionChanged);
      _log(
        'controller swapped: old=0x${oldWidget.controller.hashCode.toRadixString(16)} '
        'new=0x${widget.controller.hashCode.toRadixString(16)}',
      );
    }
    if (oldWidget.enableFollow != widget.enableFollow) {
      if (widget.enableFollow) {
        GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
      } else {
        GestureBinding.instance.pointerRouter.removeGlobalRoute(
          _onGlobalPointer,
        );
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    final modal = _modal;
    if (modal != null && modal.animation != null) {
      modal.animation!.removeStatusListener(_onRouteAnimationStatus);
    }
    if (widget.enableFollow) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    }
    _imeVetoTimer?.cancel();
    _ticker?.cancel();
    _cachePainter?.dispose();
    _badgeEntry?.remove();
    _badgeText.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 此刻的滚动是否由本组件接管（接管期间必须否决框架自己的滚动）
  ///
  /// 手柄拖拽期间也要接管：框架的 _scheduleShowCaretOnScreen 永远把视图滚到
  /// **selection.extent**。全选后抓顶端手柄往下拖时 extent 在文本末尾（离视窗
  /// 可能十几行远），于是手指刚动一下，视图就"嗖"地跳到底部，根本没法有序地
  /// 逐行从顶部取消选中。
  bool _takeoverScrollNow() =>
      _imeVeto || _edgeDragActive() || _pdScrollView || _pdSelectionDrag;

  /// IME（非指针）期间续期接管窗口；停手后窗口自然结束、框架恢复自理
  void _armImeVeto() {
    _imeVeto = true;
    _imeVetoTimer?.cancel();
    _imeVetoTimer = Timer(const Duration(milliseconds: 300), () {
      _imeVeto = false;
    });
  }

  // ── 诊断日志 ─────────────────────────────────────────────────
  void _log(String msg) {
    // 仅 debug 输出，release 不刷屏
    if (kDebugMode) debugPrint('[SelFollow] $msg');
  }

  /// 诊断 3：自内向外打印全部祖先 ScrollableState
  void _dumpScrollableChain() {
    final editable = _findEditableTextState(_fieldKey.currentContext);
    if (editable == null) {
      _log('dumpScrollableChain: EditableTextState not found');
      return;
    }
    final list = _ancestorScrollables(editable.context);
    _log('dumpScrollableChain: ${list.length} ancestor scrollable(s):');
    for (final s in list) {
      final type = s.runtimeType.toString().split('.').last;
      _log(
        '  [$type] max=${s.position.maxScrollExtent.toStringAsFixed(0)} '
        'pixels=${s.position.pixels.toStringAsFixed(0)} '
        'canScroll=${s.position.maxScrollExtent > 0}',
      );
    }
  }

  // ── UI（壁纸版胶囊形毛玻璃视觉，与 GlassTextField 一致）──────
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;
    // 与卡片同色系描边，宽度 0.5（与 GlassTextField 一致）
    final borderColor =
        isDark ? CyberColors.borderGlow : AppleColors.cardBorder;
    const radius = 24.0;
    // 卡片模糊：SP 有设置时覆盖默认 sigma
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 4);

    return OptimizedFrostedGlass(
      sigma: effectiveSigma,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: TextField(
          key: _fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          // 框架的"让光标可见"有两条滚动路径，都必须从源头堵住（见类说明）：
          // ① _scrollController.animateTo（被 _VetoScrollController 否决）
          // ② renderEditable.showOnScreen → position.moveTo（由 physics 关掉）
          scrollController: _scrollController,
          scrollPhysics: const _NoImplicitScrollPhysics(),
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          decoration: InputDecoration(
            hintText: widget.decoration?.hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          autofocus: widget.autofocus,
          enabled: widget.enabled,
        ),
      ),
    );
  }

  // ── 指针追踪（手柄拖拽 + 滑动查看 + 边缘自动滚动）────────────
  void _onGlobalPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _pointerDown = true;
      _pointer = event.position;
      _beginPointerSession(event.position);
      return;
    }
    if (event is PointerMoveEvent) {
      _pointerDown = true;
      _pointer = event.position;
      final Offset? down = _pdDown;
      if (!_pdMoved &&
          down != null &&
          (event.position - down).distance > _kDragSlop) {
        _pdMoved = true; // 真的拖起来了：此后才允许接管滚动/钳制端点
      }
      if (_pdFrameworkCaret) {
        // 滑动查看：框架抢走了这次拖动（当成移动光标），内容由我们 1:1 跟手滚
        _dragScrollBy(_pointer.dy - _pdLastY);
        _pdLastY = _pointer.dy;
      } else if (_ticker == null && _edgeDragActive()) {
        // 手指还在动就说明拖拽没结束：ticker 若已停（滚到顶/底后手指又往回拖）
        // 需要重启，否则会表现为"不再跟随"
        _startTicker();
      }
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      final bool wasEdge = _pointerDown && _edgeDragActive();
      _pointerDown = false;
      _pointer = event.position;
      _stopTicker('松手');
      if (wasEdge) _finalizeOnRelease();
      _endPointerSession();
    }
  }

  // ── 「滑动查看」会话 ──────────────────────────────────────────
  void _beginPointerSession(Offset down) {
    _pdSelectionDrag = false;
    _pdScrollView = false;
    _pdFrameworkCaret = false;
    _pdSnapshot = null;
    _pdCaretSel = null;
    _pdSideBase = false;
    _pdMoved = false;
    _pdDown = down;
    _pdLastY = down.dy;
    if (!widget.enableFollow) {
      _pdInBox = false;
      return;
    }
    final _Probe? probe = _probe();
    if (probe == null) {
      _pdInBox = false;
      return;
    }
    final Rect vp = _viewportOf(probe.re);
    _pdInBox =
        down.dy >= vp.top &&
        down.dy <= vp.bottom &&
        down.dx >= vp.left - 12 &&
        down.dx <= vp.right + 12;
    final TextSelection sel = widget.controller.selection;
    // 只有"已有选区"时才走滑动查看：没有选区时拖动光标是正常需求
    _pdSnapshot = sel.isValid && !sel.isCollapsed ? sel : null;
  }

  void _endPointerSession() {
    if (_pdScrollView) {
      // 位移用整个会话累计的 _pdMoved（拖出去又拖回原点也算拖过；
      // 只看"松手点与按下点的距离"会把这种情况误判成点一下）
      if (!_pdMoved && _pdCaretSel != null) {
        // 只是点了一下（没拖动）：按框架的原意把光标落到点击处、收起选区
        _lastSelection = _pdCaretSel;
        _rewriting = true;
        widget.controller.selection = _pdCaretSel!;
        _rewriting = false;
      } else {
        // 框架在拖动收尾时会弹复制工具条/手柄，滑动查看不需要
        _probe()?.editable.hideToolbar();
      }
    }
    _pdInBox = false;
    _pdSelectionDrag = false;
    _pdScrollView = false;
    _pdFrameworkCaret = false;
    _pdSnapshot = null;
    _pdCaretSel = null;
    _pdSideBase = false;
    _pdDown = null;
  }

  /// 记下本次拖拽正在被拖的是哪一端（选区起点 base / 终点 extent）。
  ///
  /// 必须按"哪一端在动"判断，不能按方向猜：从顶部往下拖起点手柄（= 从顶部
  /// 逐行取消选中）和从底部往上拖终点手柄同样是"反向"操作，猜错就会把另一端
  /// 改掉 —— 表现成选区突然被砍到另一边。
  void _noteDraggedSide(TextSelection sel, TextSelection? prev) {
    if (prev == null) return;
    final bool baseMoved = sel.baseOffset != prev.baseOffset;
    final bool extMoved = sel.extentOffset != prev.extentOffset;
    if (baseMoved && !extMoved) {
      _pdSideBase = true;
    } else if (extMoved && !baseMoved) {
      _pdSideBase = false;
    }
  }

  /// 让内容 1:1 跟随手指（手指上移 = 内容上滚）
  void _dragScrollBy(double dy) {
    if (dy.abs() < 0.01) return;
    final _Probe? probe = _probe();
    if (probe == null) return;
    _scrollLayers(probe.layers, -dy);
  }

  // ── selection 变化 → 跟随 ────────────────────────────────────
  void _onSelectionChanged() {
    if (_rewriting) return; // 自己改写的选区不再回环
    // 路由离场短路：停止跟随，杜绝动画帧内再触发全量 TextPainter layout
    // （IME 键盘失焦/光标变化在返回时每帧触发 selection 变化，是退出页面掉帧的根因）
    // 1) 点击左上角退出：pop 后本路由 isCurrent 立即变 false（上层路由接管）
    // 2) 系统手势左滑返回：拖动期间 isCurrent 仍是 true（手势未结束不算真正 pop），
    //    但 route.animation 已进入 reverse 状态（交互式手势驱动反向动画播放），
    //    需同时判断动画状态——仅靠 isCurrent 拦不住手势返回，仍会掉帧
    // 路由引用由 didChangeDependencies 缓存（_modal），此处避免重复依赖查找
    final modal = _modal;
    if (modal != null) {
      final status = modal.animation?.status;
      if (!modal.isCurrent || status == AnimationStatus.reverse) return;
    }
    final TextSelection sel = widget.controller.selection;
    if (!sel.isValid) return;
    final TextSelection? prev = _lastSelection;
    if (prev != null &&
        sel.baseOffset == prev.baseOffset &&
        sel.extentOffset == prev.extentOffset) {
      return;
    }
    _lastSelection = sel;
    // 活动端点 = 实际移动的那一端（IME 行为各异：实测本输入法按 ↑ 延伸时移动 base）
    _pendingActive = _resolveActiveOffset(sel, prev);

    // ── 滑动查看：有选区时手指按在文字上拖动 ─────────────────────
    // 框架会把这次拖动解释成"移动光标"，一滑就把选区弄没了。这里先复原
    // 按下时的选区，改由我们让内容跟手滚动（点一下不拖的情况在松手时还原）。
    if (_pointerDown && widget.enableFollow) {
      if (!sel.isCollapsed) {
        // 手柄拖拽 / 长按拖选：按原逻辑处理，并记下正在被拖的是哪一端
        _pdSelectionDrag = true; // 同时也是"滚动交给我们接管"的标志
        _noteDraggedSide(sel, prev);
      } else if (_pdInBox && _pdSnapshot != null && !_pdFrameworkCaret) {
        _pdFrameworkCaret = true;
        _pdScrollView = true;
        _pdCaretSel = sel;
        _pdLastY = _pointer.dy;
        _lastSelection = _pdSnapshot;
        _rewriting = true;
        widget.controller.selection = _pdSnapshot!;
        _rewriting = false;
        _log(
          '滑动查看：保留选区 ${_pdSnapshot!.baseOffset}..${_pdSnapshot!.extentOffset}',
        );
        return;
      }
    }

    // 非指针期间（IME 方向键延伸/输入）：否决框架自己的"让光标可见"滚动，
    // 由本组件逐层修正（等价于旧版把框架滚动按回原位的抑制机制，但不拉锯）
    if (!_pointerDown && widget.enableFollow) _armImeVeto();

    if (_edgeDragActive()) {
      _startTicker();
      // 手指在框外：必须在**同一个事件里**就把端点钳到可视边缘。
      // 拖到帧末再改，框架值和本组件值会交替渲染 → 选区/手柄上下跳
      if (_rewriteEndpointToEdge()) return;
    }

    _pendingSel = sel;
    if (!_followScheduled) {
      _followScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _followScheduled = false;
        if (!mounted) return;
        final TextSelection? s = _pendingSel;
        if (s != null) _scrollExtentIntoView(s, _pendingActive);
      });
    }
  }

  /// 解析活动端点：比较前后两次 selection，哪端 offset 变化就跟哪端；
  /// 两端同时变化（点击/全选/首次）回退跟随 extent。
  int _resolveActiveOffset(TextSelection sel, TextSelection? prev) {
    if (prev != null) {
      final bool baseMoved = sel.baseOffset != prev.baseOffset;
      final bool extMoved = sel.extentOffset != prev.extentOffset;
      if (baseMoved && !extMoved) return sel.baseOffset;
      if (extMoved && !baseMoved) return sel.extentOffset;
    }
    return sel.extentOffset;
  }

  void _scrollExtentIntoView(TextSelection sel, int activeOffset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 路由离场二次短路：selection 事件可能在手势方向反转前就入队，
      // 执行帧时才播放反向动画，这里再拦一次（与 _onSelectionChanged 同条件）
      final modal = ModalRoute.of(context);
      if (modal != null) {
        final status = modal.animation?.status;
        if (!modal.isCurrent || status == AnimationStatus.reverse) return;
      }
      final _Probe? probe = _probe();
      if (probe == null) {
        _log('scroll: editable/scrollable not ready, skip');
        return;
      }
      final EditableTextState editable = probe.editable;
      final RenderEditable re = probe.re;
      final List<ScrollableState> scrollables = probe.layers;

      // 手指按在框内（滑动查看 / 手柄拖拽）时不自动跟随光标：会和滚动互抢
      if (_pdInBox && widget.enableFollow) return;
      if (_edgeDragActive()) {
        // 手指在框外：滚动交给边缘 ticker（越界越多滚得越快）
        _startTicker();
        return;
      }

      final ScrollPosition innerPos = scrollables.first.position;
      // ── 快速路径（根治退出页面掉帧）────────────────────────────
      // pop 动画期间 IME 键盘失焦只改 selection 不改文本，若文本未变且上次已
      // 确认"全文本高度 ≤ 视口"（无需滚动），则本帧直接跳过：不再做
      // getOffsetForCaret/localToGlobal/逐层坐标换算，避免动画每帧全链路重活。
      // 文本一旦变化（真正输入/粘贴）缓存失效，重新走完整链路测量。
      final String? plain = re.text?.toPlainText();
      final double vpH = innerPos.viewportDimension;
      if (plain != null &&
          plain == _cachePlainText &&
          _cacheFitsViewport &&
          vpH == _cacheViewportH) {
        return;
      }
      if (plain != _cachePlainText) {
        _cachePlainText = plain;
        _cacheFitsViewport = false; // 文本变化，需重新测量
      }

      // caret offset（先 clamp 到文本长度）
      final int len = re.text?.toPlainText().length ?? 0;
      final int offset = activeOffset.clamp(0, math.max(0, len));

      // —— 关键：getLocalRectForCaret 受 TextField(maxLines) 裁剪，仅布局可视行，
      //    对超出可视行的 offset 返回错乱坐标。改用独立 TextPainter(maxLines:null)
      //    布局完整文本，算出 caret 在文本中的真实行位置（文本坐标，未滚动）。
      double oldDy;
      try {
        oldDy =
            re
                .getLocalRectForCaret(
                  TextPosition(offset: offset, affinity: sel.affinity),
                )
                .top;
      } catch (e) {
        oldDy = double.nan;
      }
      final TextPainter? tp = _fullTextPainter(re, editable);
      if (tp == null) {
        _log('scroll: fullTextPainter failed, skip');
        return;
      }
      // 缓存测量结果：全文本高度 ≤ 内层视口高度 → 无需任何滚动，后续同文本
      // selection 变化直接短路（配合上面的快速路径，pop 动画帧不再全链路重活）
      _cacheViewportH = innerPos.viewportDimension;
      _cacheFitsViewport = tp.height <= innerPos.viewportDimension;
      final Offset textOffset = tp.getOffsetForCaret(
        TextPosition(offset: offset, affinity: sel.affinity),
        Rect.zero,
      );
      final double lineHeight = re.preferredLineHeight;

      // 文本坐标 → renderEditable 全局坐标（localToGlobal 已含内层滚动 transform）
      final Offset global = re.localToGlobal(textOffset);
      double caretTop = global.dy;
      double caretBottom = global.dy + lineHeight;
      final double maxStep = lineHeight * widget.maxStepPerEvent;

      double totalDelta = 0;
      final StringBuffer sb = StringBuffer(
        'active=$activeOffset(base=${sel.baseOffset} ext=${sel.extentOffset}) '
        'textY=${textOffset.dy.toStringAsFixed(0)} oldDy=${oldDy.toStringAsFixed(0)} '
        'caret=${caretTop.toStringAsFixed(0)}~${caretBottom.toStringAsFixed(0)} '
        'lineH=${lineHeight.toStringAsFixed(0)} maxStep=${maxStep.toStringAsFixed(0)} '
        'layers=${scrollables.length}',
      );

      // 自内向外逐层合成修正（同一事件一次遍历，不叠加）。
      // 注意：不引入 Ticker/lerp —— 之前 lerp 会让 cur 滞后 target，方向切换时
      // target 基于滞后的 cur 重算导致"超前堆积 + 猛冲乱跳"。改为每事件直接
      // jumpTo 单步（≤1 行），连续事件自然跟手，方向切换立即响应，松手即停。
      for (var li = 0; li < scrollables.length; li++) {
        if (!widget.enableFollow) break;
        final ScrollableState layer = scrollables[li];
        final ScrollPosition pos = layer.position;
        final double max = pos.maxScrollExtent;
        final double cur = pos.pixels;
        // viewport 顶/高：
        //  - 内层（li==0，含 renderEditable）：RenderEditable 本身就是内层
        //    viewport（size 即可视窗口，滚动量只作用在文字绘制上 _paintOffset），
        //    localToGlobal 拿到的是**固定不动**的窗口矩形 —— 千万别再加 pixels，
        //    加了判定边界会随滚动向下漂移（越界判定失效、ticker 中途停摆）。
        //  - 外层：用其自身 RenderBox（页面级 viewport，尺寸可靠）。
        final Rect vp = li == 0 ? _viewportOf(re) : _boxOf(layer);
        if (vp.isEmpty) continue;
        final double edge = widget.edgePadding;
        final double localTop = caretTop - vp.top;
        final double localBottom = caretBottom - vp.top;

        double delta = 0;
        if (localTop < edge) {
          delta = (localTop - edge).clamp(-cur, 0.0); // 负：向上滚，不低于 0
        } else if (localBottom > vp.height - edge) {
          // 注意：localBottom 是相对 vp.top 的局部坐标，必须与视口高度比较，
          // 不能与全局绝对坐标比，否则要等光标越出视口很远才触发。
          delta = (localBottom - (vp.height - edge)).clamp(0.0, max - cur);
        }
        // 单步上限：剩余可滚量
        final double remaining = maxStep - totalDelta.abs();
        if (remaining <= 0) break;
        if (delta.abs() > remaining) {
          delta = delta.sign * remaining;
        }
        if (delta == 0) continue;

        final double nextCur = (cur + delta).clamp(0.0, max);
        // 限频：IME 长按连发频率固定且很高，若每事件都滚会飞滚无法控制。
        // 每 scrollIntervalMs 最多实际滚动一次，按住时长决定滚动距离、松手即停。
        final int now = DateTime.now().millisecondsSinceEpoch;
        final bool didScroll =
            _lastScrollAtMs == 0 ||
            now - _lastScrollAtMs >= widget.scrollIntervalMs;
        if (didScroll) {
          pos.jumpTo(nextCur);
          _lastScrollAtMs = now;
        }
        caretTop += delta;
        caretBottom += delta;
        totalDelta += delta;
        sb.write(
          '\n  [${layer.runtimeType.toString().split('.').last}] '
          'vp=${vp.top.toStringAsFixed(0)}~${vp.bottom.toStringAsFixed(0)} '
          'cur=${cur.toStringAsFixed(0)} next=${nextCur.toStringAsFixed(0)} '
          'delta=${delta.toStringAsFixed(0)} max=${max.toStringAsFixed(0)} '
          '${didScroll ? "scrolled" : "throttled"}',
        );
      }

      if (totalDelta != 0) {
        _lastDeltaPx = totalDelta;
        _log(sb.toString());
        if (widget.showDebugBadge) {
          _badgeText.value = '+${_lastDeltaPx.toStringAsFixed(0)}px';
        }
      } else {
        _log('scroll: already in view ($sb)');
        if (widget.showDebugBadge) _badgeText.value = 'idle';
      }
    });
  }

  // ── 边界判定 / 端点钳制 ──────────────────────────────────────
  /// 指针按下 + **真的拖动过** + 有选区 + 有焦点 + 已越过可视边缘 + 横向还在框内
  bool _edgeDragActive() {
    if (!widget.enableFollow) return false;
    if (!_pointerDown) return false;
    // 没移动过 = 只是点了一下（工具栏按钮、点一下文字）：绝不能当成边缘拖拽，
    // 否则松手时的收尾钳制会改写选区、把刚点的工具栏按钮"点没了"
    if (!_pdMoved) return false;
    // 手指按在文字上、且全程没有主动扩展过选区 → 这是「滑动查看」，不接管
    if (_pdInBox && !_pdSelectionDrag) return false;
    final TextSelection sel = widget.controller.selection;
    if (!sel.isValid || sel.isCollapsed) return false;
    final _Probe? probe = _probe();
    if (probe == null) return false;
    if (!probe.editable.widget.focusNode.hasFocus) return false;
    final Rect vp = _viewportOf(probe.re);
    final ({double top, double bottom}) e = _dragEdges(probe.re);
    if (_pointer.dy <= e.bottom && _pointer.dy >= e.top) return false;
    return _pointer.dx >= vp.left - 12 && _pointer.dx <= vp.right + 12;
  }

  /// 把正在拖拽的那一端改写为"可视边缘那一行"的文本位置。
  /// 返回 true 表示改写过（本次跟随到此为止）。
  bool _rewriteEndpointToEdge() {
    final _Probe? probe = _probe();
    if (probe == null) return false;
    final RenderEditable re = probe.re;
    final TextSelection sel = widget.controller.selection;
    if (!sel.isValid || sel.isCollapsed) return false;

    final Rect vp = _viewportOf(re);
    final ({double top, double bottom}) e = _dragEdges(re);
    final bool below = _pointer.dy > e.bottom;
    final bool above = _pointer.dy < e.top;
    if (!below && !above) return false;

    final ScrollPosition innerPos = probe.layers.first.position;
    final int len = re.text?.toPlainText().length ?? 0;
    final int edgeOff;
    if (below && innerPos.pixels >= innerPos.maxScrollExtent - 0.5) {
      edgeOff = len; // 已经滚到底：端点直接落到文本末尾
    } else if (above && innerPos.pixels <= 0.5) {
      edgeOff = 0; // 已经滚到顶：端点直接落到文本开头
    } else {
      final double anchorY =
          below ? e.bottom - widget.edgePadding : e.top + widget.edgePadding;
      final double x = _pointer.dx.clamp(vp.left + 1, vp.right - 1);
      // getPositionForPoint 收全局坐标（内部 globalToLocal - _paintOffset）
      edgeOff = re
          .getPositionForPoint(Offset(x, anchorY))
          .offset
          .clamp(0, math.max(0, len));
    }

    // 改的是"被拖的那一端"，并钳在"不越过另一端"的区间里
    // （选区可能反向 base>extent，所以区间要按方向给）
    final bool normalized = sel.baseOffset <= sel.extentOffset;
    final int off =
        _pdSideBase
            ? (normalized
                ? edgeOff.clamp(0, sel.extentOffset)
                : edgeOff.clamp(sel.extentOffset, len))
            : (normalized
                ? edgeOff.clamp(sel.baseOffset, len)
                : edgeOff.clamp(0, sel.baseOffset));

    final TextSelection next =
        _pdSideBase
            ? TextSelection(baseOffset: off, extentOffset: sel.extentOffset)
            : TextSelection(baseOffset: sel.baseOffset, extentOffset: off);
    if (next.baseOffset == sel.baseOffset &&
        next.extentOffset == sel.extentOffset) {
      return false;
    }
    _lastSelection = next;
    _rewriting = true;
    widget.controller.selection = next;
    _rewriting = false;
    return true;
  }

  /// 正在拖的那一端是否已经顶到边界（再滚也变不了选区了）
  bool _activeStuck(int dir) {
    final TextSelection s = widget.controller.selection;
    if (!s.isValid) return true;
    final int len = widget.controller.text.length;
    final bool normalized = s.baseOffset <= s.extentOffset;
    final int active = _pdSideBase ? s.baseOffset : s.extentOffset;
    final int other = _pdSideBase ? s.extentOffset : s.baseOffset;
    if (dir > 0) {
      // 向下：端点朝文本末尾走，撞上另一端（或文本末尾）就停
      final bool blockedByOther = _pdSideBase ? normalized : !normalized;
      return blockedByOther ? active >= other : active >= len;
    }
    // 向上：端点朝文本开头走
    final bool blockedByOther = _pdSideBase ? !normalized : normalized;
    return blockedByOther ? active <= other : active <= 0;
  }

  /// 松手收尾：把端点钳到可视边缘（所见即所选），且不额外滚动，
  /// 尊重用户停下的位置。
  void _finalizeOnRelease() {
    _rewriteEndpointToEdge();
  }

  // ── 边缘自动滚动（A 方案核心）────────────────────────────────
  void _startTicker() {
    _lastTickMs = 0;
    _ticker ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tick(),
    );
  }

  void _stopTicker(String why) {
    if (_ticker != null) _log('stop ticker: $why');
    _ticker?.cancel();
    _ticker = null;
    _lastTickMs = 0;
  }

  void _tick() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final double dt =
        _lastTickMs == 0
            ? 0.016
            : ((now - _lastTickMs) / 1000).clamp(0.004, 0.05);
    _lastTickMs = now;

    if (!_pointerDown) {
      _stopTicker('手指已松开');
      return;
    }
    final _Probe? probe = _probe();
    if (probe == null) {
      _stopTicker('找不到输入框');
      return;
    }
    final RenderEditable re = probe.re;
    final ({double top, double bottom}) e = _dragEdges(re);

    final double overshoot;
    final int dir;
    if (_pointer.dy > e.bottom) {
      overshoot = _pointer.dy - e.bottom;
      dir = 1;
    } else if (_pointer.dy < e.top) {
      overshoot = e.top - _pointer.dy;
      dir = -1;
    } else {
      _stopTicker('手指回到框内');
      return;
    }

    // 越界越多滚得越快，但整体很慢（14~240 px/s）：手指只是略微越界时
    // 内容慢慢走，才能把选区停在中间某个位置
    final double speed = (overshoot * 2.4).clamp(14.0, 240.0);
    double step = speed * dt * dir;
    final double cap = re.preferredLineHeight; // 单帧最多一行，防卡顿后跳
    if (step.abs() > cap) step = step.sign * cap;

    final double applied = _scrollLayers(probe.layers, step);
    if (applied.abs() < 0.01) {
      _stopTicker('已到文本末尾/开头');
      return;
    }
    if (widget.showDebugBadge) {
      _badgeText.value = '${applied.toStringAsFixed(1)}px';
    }
    // 拖拽期间实时把端点钳到可视边缘（所见即所选）
    _rewriteEndpointToEdge();
    // 被拖的那一端已经顶到文本头/尾：再滚也没有可伸缩的内容了，停表
    if (_activeStuck(dir)) {
      _stopTicker('已选到文本末尾/开头');
    }
  }

  /// 逐层滚动：先滚值框内层，滚不动了再滚外层页面
  double _scrollLayers(List<ScrollableState> layers, double step) {
    for (final ScrollableState s in layers) {
      final ScrollPosition pos = s.position;
      final double next = (pos.pixels + step).clamp(0.0, pos.maxScrollExtent);
      final double applied = next - pos.pixels;
      if (applied.abs() > 0.01) {
        pos.jumpTo(next);
        return applied;
      }
    }
    return 0;
  }

  // ── 几何 ─────────────────────────────────────────────────────
  /// 值框可视窗口的屏幕矩形。
  ///
  /// RenderEditable 本身就是 EditableText 内层滚动层：它的 size 就是可视窗口
  /// 大小，滚动量只作用在文字绘制上（_paintOffset）。所以 localToGlobal 得到的
  /// 是**固定不动**的窗口左上角 —— 千万别再加 pixels，加了判定边界就会随滚动
  /// 向下漂移（越界判定失效、ticker 中途停摆）。
  Rect _viewportOf(RenderEditable re) =>
      re.localToGlobal(Offset.zero) & re.size;

  /// 拖拽时判定"越界"的上下边缘 = 值框可视窗口 ∩ 屏幕可用区。
  /// 值框底部经常被键盘盖住，被盖住的部分不算可见：手指到那里就停下来，
  /// 否则选中的内容自己都看不见（这正是"最底下的信息没显示出来"的来源）。
  ({double top, double bottom}) _dragEdges(RenderEditable re) {
    final Rect vp = _viewportOf(re);
    final MediaQueryData mq = MediaQuery.of(context);
    // 键盘顶边（键盘打开时它盖住的部分同样不算可见）
    final double imeTop = mq.size.height - mq.viewInsets.bottom;
    return (top: math.max(vp.top, 0), bottom: math.min(vp.bottom, imeTop));
  }

  Rect _boxOf(ScrollableState layer) {
    final RenderBox? b = layer.context.findRenderObject() as RenderBox?;
    if (b == null || !b.hasSize) return Rect.zero;
    return b.localToGlobal(Offset.zero) & b.size;
  }

  // ── 一次性取到输入框的关键对象（带缓存，指针事件高频不能每次 DFS）──
  _Probe? _probe() {
    final EditableTextState? editable = _editable();
    if (editable == null) return null;
    final RenderEditable re = editable.renderEditable;
    if (!re.attached || !re.hasSize) return null;
    final List<ScrollableState> layers = _layers(editable);
    if (layers.isEmpty) return null;
    return (editable: editable, re: re, layers: layers);
  }

  EditableTextState? _editable() {
    final EditableTextState? c = _editableCache;
    if (c != null && c.mounted && c.renderEditable.attached) return c;
    final EditableTextState? found = _findEditableTextState(
      _fieldKey.currentContext,
    );
    _editableCache = found;
    _layersCache = null;
    return found;
  }

  List<ScrollableState> _layers(EditableTextState editable) {
    final List<ScrollableState>? c = _layersCache;
    if (c != null &&
        c.every(
          (ScrollableState s) => s.mounted && s.position.hasContentDimensions,
        )) {
      return c;
    }
    final List<ScrollableState> found = _collectLayers(editable.context);
    if (found.isNotEmpty) _layersCache = found;
    return found;
  }

  // ── 祖先 Scrollable 收集（自内向外）─────────────────────────
  List<ScrollableState> _ancestorScrollables(BuildContext context) {
    final list = <ScrollableState>[];
    BuildContext? ctx = context;
    while (ctx != null) {
      final s = ctx.findAncestorStateOfType<ScrollableState>();
      if (s == null) break;
      list.add(s);
      ctx = s.context;
    }
    return list;
  }

  /// TextField 内部滚动层：EditableText 内部的 Scrollable 是其**子孙**（不是祖先），
  /// 必须从 editable.context 向下找。这是真正承载长文本滚动的那一层；
  /// 祖先层（如外层 SingleChildScrollView）只是页面级滚动，误滚它会"完全不跟"。
  ScrollableState? _findInnerScrollable(BuildContext editableCtx) {
    ScrollableState? result;
    void visit(Element e) {
      if (result != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        result = e.state as ScrollableState;
        return;
      }
      e.visitChildren(visit);
    }

    editableCtx.visitChildElements(visit);
    return result;
  }

  /// 滚动层集合：内层（TextField 内容滚动）→ 祖先层（页面滚动），去重。
  List<ScrollableState> _collectLayers(BuildContext editableCtx) {
    final list = <ScrollableState>[];
    final inner = _findInnerScrollable(editableCtx);
    if (inner != null) list.add(inner);
    for (final s in _ancestorScrollables(editableCtx)) {
      if (!list.contains(s)) list.add(s);
    }
    list.retainWhere((s) => s.position.hasContentDimensions);
    return list;
  }

  /// 从 TextField 子树中找到 EditableTextState（其 context 在内部 Scrollable 内，
  /// 向上找 ancestor Scrollable 才能拿到 TextField 内部滚动层）
  EditableTextState? _findEditableTextState(BuildContext? context) {
    if (context == null) return null;
    EditableTextState? result;
    void visit(Element e) {
      if (result != null) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        result = e.state as EditableTextState;
        return;
      }
      e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return result;
  }

  // ── 独立 TextPainter（maxLines:null 布局完整文本，绕开 getLocalRectForCaret 裁剪）──
  // 缓存：文本内容/宽度/缩放不变时不重建，避免每次 selection 全量 layout 卡顿。
  InlineSpan? _cacheSpan;
  double _cacheWidth = -1;
  TextScaler _cacheScaler = TextScaler.noScaling;
  TextDirection _cacheDir = TextDirection.ltr;
  TextPainter? _cachePainter;

  TextPainter? _fullTextPainter(RenderEditable re, EditableTextState editable) {
    final InlineSpan? span = re.text;
    if (span == null) return null;
    final double w = re.size.width;
    final TextScaler scaler =
        editable.widget.textScaler ?? TextScaler.noScaling;
    final TextDirection dir =
        editable.widget.textDirection ?? TextDirection.ltr;
    if (_cachePainter != null &&
        _cacheSpan == span &&
        _cacheWidth == w &&
        identical(_cacheScaler, scaler) &&
        _cacheDir == dir) {
      return _cachePainter;
    }
    try {
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: dir,
        textAlign: editable.widget.textAlign,
        textScaler: scaler,
        strutStyle: editable.widget.strutStyle,
        maxLines: null,
      )..layout(maxWidth: w);
      _cacheSpan = span;
      _cacheWidth = w;
      _cacheScaler = scaler;
      _cacheDir = dir;
      _cachePainter?.dispose();
      _cachePainter = tp;
      return tp;
    } catch (e) {
      _log('fullTextPainter ERR $e');
      return null;
    }
  }

  // ── 事件合并 / 快速路径缓存 ──────────────────────────────────
  // 长按密集时每帧只处理最新一次 selection（丢弃中间状态，滚动基于最新光标位置），
  // 避免 addPostFrameCallback 排队堆积。
  bool _followScheduled = false;
  TextSelection? _pendingSel;
  int _pendingActive = 0;
  // 快速路径缓存：文本内容与当前渲染一致时，直接复用上次"全文本 ≤ 视口
  // （无需滚动）"的测量结论，跳过全链路坐标换算（根治退出页面掉帧）
  String? _cachePlainText;
  bool _cacheFitsViewport = false;
  double _cacheViewportH = 0;

  // ── 屏幕角标（仅 debug）──────────────────────────────────────
  void _mountBadge() {
    if (!widget.showDebugBadge) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      _badgeEntry = OverlayEntry(
        builder:
            (_) => Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: ValueListenableBuilder<String>(
                valueListenable: _badgeText,
                builder:
                    (_, v, __) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SelFollow: $v',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
              ),
            ),
      );
      overlay.insert(_badgeEntry!);
      _log('badge mounted');
    });
  }
}

typedef _Probe =
    ({
      EditableTextState editable,
      RenderEditable re,
      List<ScrollableState> layers,
    });
