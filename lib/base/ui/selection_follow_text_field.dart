import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 选区滚动跟随多行文本框 —— 嵌套滚动版本（v3，同步主题版）
///
/// 解决 IME "开始选择 → 方向键延伸"跨屏时视口不跟随 active 端点滚动的缺陷：
/// Flutter 的 `_showCaretOnScreen` 只以光标为基准、且被 maxLines 裁剪，选区头
/// 越界时不触发滚动（同屏循环/画面不跟随）。
///
/// 机制（逐层修正，事件驱动单步滚动）：
/// 1. 用独立 TextPainter(maxLines:null) 布局完整文本，算出 selection 活动端点
///    （谁移动跟谁：base 动跟 base，extent 动跟 extent）的文本行位置，绕开
///    getLocalRectForCaret 的 maxLines 裁剪。
/// 2. 收集滚动层：TextField 内层 Scrollable（EditableText 的**子孙**，真正承载
///    长文本滚动）→ 祖先页面 Scrollable。内层 viewport 用 renderEditable 推算
///    （scrollable.context.findRenderObject 返回内容全高容器，尺寸不可信）。
/// 3. 每事件把 caret 全局位置换算到各 viewport 局部坐标，越上/下边缘
///    (edgePadding) 时按"最小 delta"逐层修正：先内层、不足滚外层。
/// 4. 单次滚动步长跟随"光标实际越出视口的距离"（短按 1 行精确、长按深越界
///    滚到 maxStepPerEvent 上限默认 8 行快速选多行），配合滚动限频
///    scrollIntervalMs（默认 80ms）—— 不做 Ticker/lerp（lerp 会让 current 滞后
///    target，方向切换时 target 基于滞后的 current 重算，产生"超前堆积 +
///    猛冲乱跳"）。连续方向键事件限频滚动，按住时长决定滚动距离、松手即停；
///    光标越界后停靠在视口边缘内（edgePadding=1 行），始终能看到选中行。
/// 5. 边界：offset 严格 clamp 到 0..maxScrollExtent；文本首/尾停住，禁止回弹。
/// 6. 健壮性：caret offset 先 clamp 到 0..text.length；未挂载/无滚动层安全跳过。
///
/// 视觉：壁纸版胶囊形毛玻璃（OptimizedFrostedGlass + 卡片模糊 sigma + 0.5 描边），
/// 与 GlassTextField 风格一致。
///
/// 诊断：debugPrint("[SelFollow] ...") 输出挂载、滚动层链、selection 变化时的
/// 活动端点/caret 坐标/各层 delta；kDebugMode 下默认显示屏幕角标实时状态。
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

class _SelectionFollowTextFieldState
    extends ConsumerState<SelectionFollowTextField> {
  final GlobalKey _fieldKey = GlobalKey();
  TextSelection? _lastSelection;
  double _lastDeltaPx = 0;

  // ── 抑制 Flutter 自身的错乱滚动（_showCaretOnScreen 用被 maxLines 裁剪的
  //    getLocalRectForCaret，selection 变化时会把内层 offset 滚到错乱位置，
  //    与我们的修正互相拉锯 → 方向切换时 cur 43→19→0 反复抖动）────────
  ScrollPosition? _innerPos;
  bool _suppressActive = false;
  bool _applying = false;
  Timer? _suppressTimer;
  int _lastScrollAtMs = 0;
  double _lastAppliedPos = 0;

  // ── 屏幕角标 ─────────────────────────────────────────────────
  OverlayEntry? _badgeEntry;
  final ValueNotifier<String> _badgeText = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _log('initState: mounted on <${widget.debugLabel}>, '
        'controllerHash=0x${widget.controller.hashCode.toRadixString(16)}, '
        'enableFollow=${widget.enableFollow}, edgePadding=${widget.edgePadding}, '
        'maxStep=${widget.maxStepPerEvent}');
    widget.controller.addListener(_onSelectionChanged);
    _mountBadge();
    // 首帧后打印滚动层链（诊断 3）
    WidgetsBinding.instance.addPostFrameCallback((_) => _dumpScrollableChain());
  }

  @override
  void didUpdateWidget(covariant SelectionFollowTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_onSelectionChanged);
      _log('controller swapped: old=0x${oldWidget.controller.hashCode.toRadixString(16)} '
          'new=0x${widget.controller.hashCode.toRadixString(16)}');
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    _suppressTimer?.cancel();
    _innerPos?.removeListener(_onInnerPosChanged);
    _cachePainter?.dispose();
    _badgeEntry?.remove();
    _badgeText.dispose();
    super.dispose();
  }

  /// 内层 offset 被 Flutter/外部改动时，若正处于跟随抑制窗口，拉回"我们实际
  /// 滚到的位置"（_lastAppliedPos，不是最终目标 _targetCur），只消除 Flutter 的
  /// 错乱滚动干扰、不破坏限频与平滑。
  void _onInnerPosChanged() {
    if (_applying || !_suppressActive) return;
    final pos = _innerPos;
    if (pos == null) return;
    if ((pos.pixels - _lastAppliedPos).abs() > 0.5) {
      _applying = true;
      pos.jumpTo(_lastAppliedPos.clamp(0.0, pos.maxScrollExtent));
      _applying = false;
    }
  }

  /// selection 变化期间（跟随抑制窗口）持续续期；松手后窗口结束不再干预。
  void _armSuppress() {
    _suppressActive = true;
    _suppressTimer?.cancel();
    _suppressTimer = Timer(const Duration(milliseconds: 300), () {
      _suppressActive = false;
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
      _log('  [$type] max=${s.position.maxScrollExtent.toStringAsFixed(0)} '
          'pixels=${s.position.pixels.toStringAsFixed(0)} '
          'canScroll=${s.position.maxScrollExtent > 0}');
    }
  }

  // ── UI（壁纸版胶囊形毛玻璃视觉，与 GlassTextField 一致）──────
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;
    // 与卡片同色系描边，宽度 0.5（与 GlassTextField 一致）
    final borderColor = isDark ? CyberColors.borderGlow : AppleColors.cardBorder;
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
      e.visitChildElements(visit);
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
    final TextScaler scaler = editable.widget.textScaler ?? TextScaler.noScaling;
    final TextDirection dir = editable.widget.textDirection ?? TextDirection.ltr;
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

  // ── selection 变化 → caret 全局可见性修正（诊断 5）──────────
  // 事件合并：长按密集时每帧只处理最新一次 selection（丢弃中间状态，
  // 滚动基于最新光标位置），避免 addPostFrameCallback 排队堆积。
  bool _followScheduled = false;
  TextSelection? _pendingSel;
  int _pendingActive = 0;

  void _onSelectionChanged() {
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
    final int activeOffset = _resolveActiveOffset(sel, prev);
    _armSuppress();
    _pendingSel = sel;
    _pendingActive = activeOffset;
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
      final editable = _findEditableTextState(_fieldKey.currentContext);
      if (editable == null) {
        _log('scroll: EditableTextState not mounted, skip');
        return;
      }
      final RenderEditable re = editable.renderEditable;
      if (!re.attached) {
        _log('scroll: renderEditable not attached, skip');
        return;
      }
      final List<ScrollableState> scrollables = _collectLayers(editable.context);
      if (scrollables.isEmpty) {
        _log('scroll: no scrollable layer, skip');
        return;
      }
      // 绑定内层 position：抑制 Flutter 自身的错乱滚动（首次挂 listener）
      final ScrollPosition innerPos = scrollables.first.position;
      if (!identical(_innerPos, innerPos)) {
        _innerPos?.removeListener(_onInnerPosChanged);
        _innerPos = innerPos;
        _innerPos!.addListener(_onInnerPosChanged);
      }

      // caret offset（先 clamp 到文本长度）
      final int len = re.text?.toPlainText().length ?? 0;
      final int offset = activeOffset.clamp(0, math.max(0, len));

      // —— 关键：getLocalRectForCaret 受 TextField(maxLines) 裁剪，仅布局可视行，
      //    对超出可视行的 offset 返回错乱坐标。改用独立 TextPainter(maxLines:null)
      //    布局完整文本，算出 caret 在文本中的真实行位置（文本坐标，未滚动）。
      double oldDy;
      try {
        oldDy = re.getLocalRectForCaret(
          TextPosition(offset: offset, affinity: sel.affinity),
        ).top;
      } catch (e) {
        oldDy = double.nan;
      }
      final TextPainter? tp = _fullTextPainter(re, editable);
      if (tp == null) {
        _log('scroll: fullTextPainter failed, skip');
        return;
      }
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
        //  - 内层（li==0，含 renderEditable）：用 re 推算。scrollable.context 的
        //    findRenderObject 返回"内容全高容器"而非可视视口，不可直接取尺寸。
        //  - 外层：用其自身 RenderBox（页面级 viewport，尺寸可靠）。
        double vpTop, vpBottom;
        if (li == 0) {
          vpTop = re.localToGlobal(Offset.zero).dy + cur;
          vpBottom = vpTop + pos.viewportDimension;
        } else {
          final RenderBox? vp =
              layer.context.findRenderObject() as RenderBox?;
          if (vp == null || !vp.hasSize) continue;
          vpTop = vp.localToGlobal(Offset.zero).dy;
          vpBottom = vpTop + vp.size.height;
        }
        final double edge = widget.edgePadding;
        final double localTop = caretTop - vpTop;
        final double localBottom = caretBottom - vpTop;

        double delta = 0;
        if (localTop < edge) {
          delta = localTop - edge; // 负：向上滚
          delta = delta.clamp(-cur, 0.0); // 不低于 0（首行停住）
        } else if (localBottom > pos.viewportDimension - edge) {
          // 注意：localBottom 是相对 vpTop 的局部坐标，必须与视口高度比较，
          // 不能与 vpBottom（全局绝对坐标）比，否则要等光标越出视口很远才触发。
          delta = localBottom - (pos.viewportDimension - edge); // 正：向下滚
          delta = delta.clamp(0.0, max - cur); // 不超过 max（末行停住）
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
        // 每 scrollIntervalMs 最多实际滚动一次，滚动速度固定低速匀速，
        // 按住时长决定滚动距离、松手即停。
        final int now = DateTime.now().millisecondsSinceEpoch;
        final bool didScroll = _lastScrollAtMs == 0 ||
            now - _lastScrollAtMs >= widget.scrollIntervalMs;
        if (didScroll) {
          _applying = true;
          pos.jumpTo(nextCur);
          _applying = false;
          _lastScrollAtMs = now;
          _lastAppliedPos = nextCur;
        }
        caretTop += delta;
        caretBottom += delta;
        totalDelta += delta;
        sb.write('\n  [${layer.runtimeType.toString().split('.').last}] '
            'vp=${vpTop.toStringAsFixed(0)}~${vpBottom.toStringAsFixed(0)} '
            'cur=${cur.toStringAsFixed(0)} next=${nextCur.toStringAsFixed(0)} '
            'delta=${delta.toStringAsFixed(0)} max=${max.toStringAsFixed(0)} '
            '${didScroll ? "scrolled" : "throttled"}');
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

  // ── 屏幕角标（仅 debug）──────────────────────────────────────
  void _mountBadge() {
    if (!widget.showDebugBadge) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      _badgeEntry = OverlayEntry(
        builder: (_) => Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: ValueListenableBuilder<String>(
            valueListenable: _badgeText,
            builder: (_, v, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'SelFollow: $v',
                style: const TextStyle(color: Colors.white, fontSize: 12),
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