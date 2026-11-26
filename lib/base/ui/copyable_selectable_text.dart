import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/ui/agent_toast.dart';

/// 统一的可选中复制文本（全项目共用）。
///
/// 相比原生 [SelectableText]：
/// - 选择手柄/菜单保持项目一致的 Cupertino 风格；
/// - 点击菜单「复制」后额外弹一个「已复制」轻提示，让用户确认复制成功；
/// - 其余菜单项（全选）保持系统默认行为。
///
/// 注意：`selectionControls` 必须使用混入 [TextSelectionHandleControls] 的
/// [cupertinoTextSelectionHandleControls]。若用普通的
/// `cupertinoTextSelectionControls`，Flutter 会为兼容旧版而忽略
/// [contextMenuBuilder]，直接走已废弃的 buildToolbar，复制提示将完全不生效。
class CopyableSelectableText extends StatelessWidget {
  const CopyableSelectableText(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.onTap,
    this.selectionHeightStyle,
    this.selectionWidthStyle,
  }) : textSpan = null;

  const CopyableSelectableText.rich(
    TextSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.onTap,
    this.selectionHeightStyle,
    this.selectionWidthStyle,
  }) : data = null;

  final String? data;
  final TextSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final VoidCallback? onTap;
  final BoxHeightStyle? selectionHeightStyle;
  final BoxWidthStyle? selectionWidthStyle;

  @override
  Widget build(BuildContext context) {
    final TextSpan? span = textSpan;
    if (span != null) {
      return SelectableText.rich(
        span,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        onTap: onTap,
        selectionHeightStyle: selectionHeightStyle,
        selectionWidthStyle: selectionWidthStyle,
        selectionControls: cupertinoTextSelectionHandleControls,
        contextMenuBuilder: _buildContextMenu,
      );
    }
    return SelectableText(
      data!,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      onTap: onTap,
      selectionHeightStyle: selectionHeightStyle,
      selectionWidthStyle: selectionWidthStyle,
      selectionControls: cupertinoTextSelectionHandleControls,
      contextMenuBuilder: _buildContextMenu,
    );
  }

  /// 「全选」瞬间冻结的菜单锚点（全局坐标）。
  ///
  /// 全选后选区横跨整篇文本，Flutter 重新计算的锚点会落到文档两端（屏幕外），
  /// 菜单会被排到屏幕外/屏幕边缘，用户就没法接着点「复制」。
  /// 记住点击前的锚点，让菜单保持原地不动，用户可以直接继续操作。
  static TextSelectionToolbarAnchors? _frozenAnchors;

  /// 自定义选择菜单：深色玻璃胶囊（与 AgentToast 视觉统一），
  /// 替代系统原生菜单；只保留「复制 / 全选」两个动作。
  static Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    const double screenPadding = 8;
    final EdgeInsets mediaPadding = MediaQuery.paddingOf(context);
    final TextEditingValue value = editableTextState.textEditingValue;
    final bool isAllSelected = value.selection.isValid &&
        value.selection.start == 0 &&
        value.selection.end == value.text.length;
    // 全文选中且存在冻结锚点时沿用冻结锚点，避免菜单跳动/跑出屏幕
    final TextSelectionToolbarAnchors anchors =
        (isAllSelected ? _frozenAnchors : null) ??
            editableTextState.contextMenuAnchors;
    // 非全文选中的菜单（新的长按选区）不应再受冻结锚点影响
    if (!isAllSelected) {
      _frozenAnchors = null;
    }

    return CustomSingleChildLayout(
      delegate: _SelectionMenuLayoutDelegate(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
        padding: EdgeInsets.fromLTRB(
          mediaPadding.left + screenPadding,
          mediaPadding.top + screenPadding,
          mediaPadding.right + screenPadding,
          mediaPadding.bottom + screenPadding,
        ),
      ),
      child: _SelectionMenu(
        onCopy: () {
          _frozenAnchors = null;
          // 原生复制（cause=toolbar 会自动收起菜单），再补一个轻提示
          editableTextState.copySelection(SelectionChangedCause.toolbar);
          AgentToast.show(context, '已复制');
        },
        onSelectAll: () {
          // 先记住当前（用户刚长按选区的）锚点，再全选
          _frozenAnchors = editableTextState.contextMenuAnchors;
          editableTextState.selectAll(SelectionChangedCause.toolbar);
          // 长文档全选后页面会自动滚动到选区起点，菜单若沿用滚动前的定位偏移，
          // 会出现「菜单看得见但点不中」；滚动结束后重建一次菜单即可恢复点击。
          void reshow() {
            if (!editableTextState.mounted) {
              return;
            }
            editableTextState.hideToolbar(false);
            editableTextState.showToolbar();
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            reshow();
            // 兜底：个别机型滚动会晚一帧完成
            Future<void>.delayed(const Duration(milliseconds: 120), reshow);
          });
        },
      ),
    );
  }
}

/// 选择菜单定位：优先贴在选区上方，放不下则贴到下方。
///
/// 与 [TextSelectionToolbarLayoutDelegate] 的区别：**最终位置会夹回可视区域**。
/// 长文档里滚动后或点击「全选」时，锚点可能落在视口之外（选区横跨整篇文本），
/// 原生 delegate 会把菜单排到屏幕外，表现就是「点了全选菜单消失、无法复制」。
class _SelectionMenuLayoutDelegate extends SingleChildLayoutDelegate {
  const _SelectionMenuLayoutDelegate({
    required this.anchorAbove,
    required this.anchorBelow,
    required this.padding,
  });

  final Offset anchorAbove;
  final Offset anchorBelow;

  /// 菜单与屏幕边缘（含系统安全区）的最小间距
  final EdgeInsets padding;

  static const double _gap = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double minTop = padding.top;
    final double maxTop = math.max(
      minTop,
      size.height - padding.bottom - childSize.height,
    );

    // 优先选区上方，放不下改到选区下方
    double top = anchorAbove.dy - _gap - childSize.height;
    if (top < minTop) {
      top = anchorBelow.dy + _gap;
    }
    // 锚点在视口外时兜底贴边，保证菜单始终可见
    top = top.clamp(minTop, maxTop);

    final double maxLeft = math.max(
      padding.left,
      size.width - padding.right - childSize.width,
    );
    final double left =
        (anchorAbove.dx - childSize.width / 2).clamp(padding.left, maxLeft);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_SelectionMenuLayoutDelegate oldDelegate) {
    return anchorAbove != oldDelegate.anchorAbove ||
        anchorBelow != oldDelegate.anchorBelow ||
        padding != oldDelegate.padding;
  }
}

/// 深色玻璃选择菜单：复制 / 全选
class _SelectionMenu extends StatelessWidget {
  const _SelectionMenu({required this.onCopy, required this.onSelectAll});

  final VoidCallback onCopy;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          // 胶囊：圆角取高度一半，无需连续曲率
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SelectionMenuAction(
              icon: Icons.copy_rounded,
              label: '复制',
              onTap: onCopy,
            ),
            Container(
              width: 1,
              height: 16,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            _SelectionMenuAction(
              icon: Icons.select_all_rounded,
              label: '全选',
              onTap: onSelectAll,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionMenuAction extends StatelessWidget {
  const _SelectionMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可跨块选择的文本区域（全项目共用）。
///
/// 用于「分块懒加载」的长文本（例如 [SelectableCodeView] 的超长脚本）：
/// 分块只负责渲染性能，把各块内容改成普通 [Text]/[Text.rich]，
/// 外层统一包一个 [SelectionArea]，选择域就从「每块一个」变成「整片一个」，
/// 可以跨块连续拖选/复制，不再卡在块边界。
///
/// 选择菜单沿用深色玻璃胶囊（复制 / 全选），复制后弹「已复制」；
/// 未加载的块不在选择域内，这是懒加载的固有边界。
class CopyableSelectionArea extends StatefulWidget {
  const CopyableSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<CopyableSelectionArea> createState() => _CopyableSelectionAreaState();
}

class _CopyableSelectionAreaState extends State<CopyableSelectionArea> {
  /// 点「全选」瞬间冻结的锚点：全选后选区覆盖整片内容，锚点会落到
  /// 屏幕外，菜单容易被排到边缘/不可点区域；冻结后保持原地不动。
  TextSelectionToolbarAnchors? _frozenAnchors;
  Timer? _frozenTimer;

  @override
  void dispose() {
    _frozenTimer?.cancel();
    super.dispose();
  }

  void _clearFrozenAnchors() {
    _frozenTimer?.cancel();
    _frozenTimer = null;
    _frozenAnchors = null;
  }

  /// 触发 Flutter 原生菜单项（复制/全选），保证剪贴板与选区行为一致
  void _invoke(SelectableRegionState state, ContextMenuButtonType type) {
    for (final ContextMenuButtonItem item in state.contextMenuButtonItems) {
      if (item.type == type && item.onPressed != null) {
        item.onPressed!();
        return;
      }
    }
  }

  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState state,
  ) {
    const double screenPadding = 8;
    final EdgeInsets mediaPadding = MediaQuery.paddingOf(context);
    final TextSelectionToolbarAnchors anchors =
        _frozenAnchors ?? state.contextMenuAnchors;

    return CustomSingleChildLayout(
      delegate: _SelectionMenuLayoutDelegate(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
        padding: EdgeInsets.fromLTRB(
          mediaPadding.left + screenPadding,
          mediaPadding.top + screenPadding,
          mediaPadding.right + screenPadding,
          mediaPadding.bottom + screenPadding,
        ),
      ),
      child: _SelectionMenu(
        onCopy: () {
          _clearFrozenAnchors();
          // 先弹提示：复制成功后菜单会被销毁，若放在后面可能因上下文失效丢提示
          AgentToast.show(context, '已复制');
          _invoke(state, ContextMenuButtonType.copy);
        },
        onSelectAll: () {
          // 冻结当前锚点，让菜单在全选后原地保留
          _frozenAnchors = state.contextMenuAnchors;
          _frozenTimer?.cancel();
          _frozenTimer = Timer(
            const Duration(seconds: 1),
            _clearFrozenAnchors,
          );
          _invoke(state, ContextMenuButtonType.selectAll);
          // 全选会让 Flutter 重建菜单覆盖层，个别时机下新菜单不可点击：
          // 此时点「复制」会穿透到下层文本（菜单消失、选区折叠、无提示）。
          // 下一帧再触发一次全选（幂等），把菜单重新插到 Overlay 顶部恢复可点。
          void reshow() {
            if (!mounted) return;
            state.selectAll(SelectionChangedCause.toolbar);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            reshow();
            Future<void>.delayed(const Duration(milliseconds: 120), reshow);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: _buildContextMenu,
      child: widget.child,
    );
  }
}

/// 输入框统一长按菜单（TextField / TextFormField / CupertinoTextField 通用）。
///
/// 用法：`TextField(contextMenuBuilder: copyableEditableTextMenu, ...)`。
///
/// 背景：Flutter 默认走 [AdaptiveTextSelectionToolbar]，菜单项由各平台/ROM
/// 自适应决定；部分机型长按不出菜单或缺少「粘贴」，体验不一致。这里统一为
/// 项目深色玻璃胶囊，动作直接调用 [EditableTextState] 的公开方法：
/// 剪切 / 复制 / 粘贴 / 全选。「粘贴」不依赖 clipboardStatus 的异步查询
/// （部分设备查询失败会导致默认菜单缺项），点击时才读取剪贴板。
Widget copyableEditableTextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  const double screenPadding = 8;
  final EdgeInsets mediaPadding = MediaQuery.paddingOf(context);
  final TextEditingValue value = editableTextState.textEditingValue;
  final bool isAllSelected =
      value.selection.isValid &&
      value.selection.start == 0 &&
      value.selection.end == value.text.length;
  // 全选后选区横跨整段文本，锚点会落到屏幕外；沿用冻结锚点让菜单原地保留
  final TextSelectionToolbarAnchors anchors =
      (isAllSelected ? _editableFrozenAnchors : null) ??
      editableTextState.contextMenuAnchors;
  if (!isAllSelected) {
    _editableFrozenAnchors = null;
  }

  final List<_EditableMenuEntry> entries = <_EditableMenuEntry>[
    if (editableTextState.cutEnabled)
      _EditableMenuEntry(
        icon: Icons.content_cut_rounded,
        label: '剪切',
        onTap: () {
          editableTextState.cutSelection(SelectionChangedCause.toolbar);
          AgentToast.show(context, '已剪切');
        },
      ),
    if (editableTextState.copyEnabled)
      _EditableMenuEntry(
        icon: Icons.copy_rounded,
        label: '复制',
        onTap: () {
          editableTextState.copySelection(SelectionChangedCause.toolbar);
          AgentToast.show(context, '已复制');
        },
      ),
    if (!editableTextState.widget.readOnly)
      _EditableMenuEntry(
        icon: Icons.content_paste_rounded,
        label: '粘贴',
        onTap: () {
          editableTextState.pasteText(SelectionChangedCause.toolbar);
        },
      ),
    if (editableTextState.selectAllEnabled)
      _EditableMenuEntry(
        icon: Icons.select_all_rounded,
        label: '全选',
        onTap: () {
          _editableFrozenAnchors = editableTextState.contextMenuAnchors;
          editableTextState.selectAll(SelectionChangedCause.toolbar);
          // 全选会让 Flutter 重建菜单覆盖层，个别时机下新菜单不可点击；
          // 下一帧再重建一次，把菜单重新插到 Overlay 顶部恢复可点。
          void reshow() {
            if (!editableTextState.mounted) {
              return;
            }
            editableTextState.hideToolbar(false);
            editableTextState.showToolbar();
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            reshow();
            Future<void>.delayed(const Duration(milliseconds: 120), reshow);
          });
        },
      ),
  ];

  if (entries.isEmpty) {
    return const SizedBox.shrink();
  }

  return CustomSingleChildLayout(
    delegate: _SelectionMenuLayoutDelegate(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      padding: EdgeInsets.fromLTRB(
        mediaPadding.left + screenPadding,
        mediaPadding.top + screenPadding,
        mediaPadding.right + screenPadding,
        mediaPadding.bottom + screenPadding,
      ),
    ),
    child: _EditableSelectionMenu(entries: entries),
  );
}

/// 全选瞬间冻结的输入框菜单锚点（全局坐标）
TextSelectionToolbarAnchors? _editableFrozenAnchors;

class _EditableMenuEntry {
  const _EditableMenuEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// 输入框选择菜单：深色玻璃胶囊，动作由可用性动态决定（粘贴在密码框也保留）
class _EditableSelectionMenu extends StatelessWidget {
  const _EditableSelectionMenu({required this.entries});

  final List<_EditableMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < entries.length; i++) {
      if (i > 0) {
        children.add(
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        );
      }
      children.add(
        _SelectionMenuAction(
          icon: entries[i].icon,
          label: entries[i].label,
          onTap: entries[i].onTap,
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          // 胶囊：圆角取高度一半，无需连续曲率
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
