import 'dart:math' show pi;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../app_colors.dart';
import '../../theme.dart';
import '../../ui/cyber/cyber_slide_action.dart';
import 'tree_view.dart';
import 'tree_view_theme.dart';
import 'expander_theme_data.dart';
import 'models/script_data.dart';

const double _kBorderWidth = 0.75;

/// Defines the [TreeNode] widget.
///
/// This widget is used to display a tree node and its children. It requires
/// a single [ScriptData] value. It uses this node to display the state of the
/// widget. It uses the [TreeViewTheme] to handle the appearance and the
/// [TreeView] properties to handle to user actions.
///
/// __This class should not be used directly!__
/// The [TreeView] and [TreeViewController] handlers the data and rendering
/// of the nodes.
class TreeNode extends ConsumerStatefulWidget {
  /// The node object used to display the widget state
  final ScriptData node;

  const TreeNode({super.key, required this.node});

  @override
  _TreeNodeState createState() => _TreeNodeState();
}

class _TreeNodeState extends ConsumerState<TreeNode> with SingleTickerProviderStateMixin {
  static final Animatable<double> _easeInTween = CurveTween(curve: Curves.easeIn);

  late AnimationController _controller;
  late Animation<double> _heightFactor;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _heightFactor = _controller.drive(_easeInTween);
    _isExpanded = widget.node.expanded;
    if (_isExpanded) _controller.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    TreeView? treeView = TreeView.of(context);
    _controller.duration = treeView!.theme.expandSpeed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TreeNode oldWidget) {
    if (widget.node.expanded != oldWidget.node.expanded) {
      setState(() {
        _isExpanded = widget.node.expanded;
        if (_isExpanded) {
          _controller.forward();
        } else {
          _controller.reverse().then<void>((void value) {
            if (!mounted) return;
            setState(() {});
          });
        }
      });
    } else if (widget.node != oldWidget.node) {
      setState(() {});
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleExpand() {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse().then<void>((void value) {
          if (!mounted) return;
          setState(() {});
        });
      }
    });
    if (treeView!.onExpansionChanged != null) treeView.onExpansionChanged!(widget.node.key, _isExpanded);
  }

  void _handleDeleteSelf() {
    TreeView? treeView = TreeView.of(context);
    if (treeView!.onDeleteSelfClick != null) treeView.onDeleteSelfClick!(widget.node);
  }

  void _handleTap() {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    if (treeView!.onNodeTap != null) {
      treeView.onNodeTap!(widget.node.key);
    }
  }

  void _handleDoubleTap() {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    if (treeView!.onNodeDoubleTap != null) {
      treeView.onNodeDoubleTap!(widget.node.key);
    }
  }

  Widget _buildNodeExpander() {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    TreeViewTheme theme = treeView!.theme;
    if (theme.expanderTheme.type == ExpanderType.none) return Container();
    return widget.node.isParent
        ? GestureDetector(
            onTap: () => _handleExpand(),
            child: _TreeNodeExpander(
              speed: _controller.duration!,
              expanded: widget.node.expanded,
              themeData: theme.expanderTheme,
            ),
          )
        : Container(width: theme.expanderTheme.size);
  }

  Widget _buildNodeIcon() {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    TreeViewTheme theme = treeView!.theme;
    bool isSelected = treeView.controller.selectedKey != null && treeView.controller.selectedKey == widget.node.key;
    return Container(
      alignment: Alignment.center,
      width: theme.iconTheme.size! + theme.iconPadding,
      child: widget.node.isParent
          ? Icon(
              widget.node.expanded ? CupertinoIcons.folder_badge_minus : CupertinoIcons.folder_badge_plus,
              size: theme.iconTheme.size,
              color: isSelected ? ref.watch(themeProvider).primaryColor : ref.watch(themeProvider).themeColor.titleColor(),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildNodeLabel() {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    TreeViewTheme theme = treeView!.theme;
    final icon = _buildNodeIcon();
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: theme.verticalSpacing ?? (theme.dense ? 10 : 15),
        horizontal: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          icon,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 5,
              ),
              child: Text(
                widget.node.title,
                style: widget.node.isParent
                    ? TextStyle(
                        fontSize: 16,
                        color: ref.watch(themeProvider).customPrimaryTextColor,
                      )
                    : TextStyle(
                        fontSize: 16,
                        color: ref.watch(themeProvider).customPrimaryTextColor,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget() {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    TreeViewTheme theme = treeView!.theme;
    bool isSelected = treeView.controller.selectedKey != null && treeView.controller.selectedKey == widget.node.key;
    bool canSelectParent = treeView.allowParentSelect;
    final arrowContainer = _buildNodeExpander();
    final labelContainer = treeView.nodeBuilder != null ? treeView.nodeBuilder!(context, widget.node) : _buildNodeLabel();
    Widget tappable = treeView.onNodeDoubleTap != null
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onDoubleTap: _handleDoubleTap,
            child: labelContainer,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: labelContainer,
          );
    if (widget.node.isParent) {
      if (treeView.supportParentDoubleTap && canSelectParent) {
        tappable = GestureDetector(
          onTap: canSelectParent ? _handleTap : _handleExpand,
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            _handleExpand();
            _handleDoubleTap();
          },
          child: labelContainer,
        );
      } else if (treeView.supportParentDoubleTap) {
        tappable = GestureDetector(
          onTap: _handleExpand,
          onDoubleTap: _handleDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: labelContainer,
        );
      } else {
        tappable = GestureDetector(
          onTap: canSelectParent ? _handleTap : _handleExpand,
          behavior: HitTestBehavior.opaque,
          child: labelContainer,
        );
      }
    }
    return Container(
      color: isSelected ? theme.colorScheme.primary : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: theme.expanderTheme.position == ExpanderPosition.end
            ? <Widget>[
                Expanded(
                  child: tappable,
                ),
                arrowContainer,
              ]
            : <Widget>[
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: tappable,
                ),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TreeView? treeView = TreeView.of(context);
    assert(treeView != null, 'TreeView must exist in context');
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final bool closed = (!_isExpanded || !widget.node.expanded) && _controller.isDismissed;
    final nodeWidget = _buildNodeWidget();

    Widget buildSlidable({required Widget child}) {
      return Slidable(
        enabled: closed,
        key: ValueKey(widget.node.key),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.18,
          children: [
            AppSlideButton(
              context: context,
              color: isCyber ? CyberColors.neonRed : const Color(0xffEA4D3E),
              icon: CupertinoIcons.delete,
              cyberMode: isCyber,
              width: 60,
              onTap: () {
                WidgetsBinding.instance.endOfFrame.then((timeStamp) {
                  _handleDeleteSelf();
                });
              },
            ),
          ],
        ),
        child: child,
      );
    }

    return widget.node.isParent
        ? AnimatedBuilder(
            animation: _controller.view,
            builder: (BuildContext context, Widget? child) {
              return buildSlidable(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    nodeWidget,
                    ClipRect(
                      child: Align(
                        heightFactor: _heightFactor.value,
                        child: child,
                      ),
                    ),
                  ],
                ),
              );
            },
            child: closed
                ? null
                : Container(
                    margin: EdgeInsets.only(left: treeView!.theme.horizontalSpacing ?? treeView.theme.iconTheme.size!),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.node.children.map((ScriptData node) {
                          return TreeNode(node: node);
                        }).toList()),
                  ),
          )
        : buildSlidable(child: nodeWidget);
  }
}

class _TreeNodeExpander extends StatefulWidget {
  final ExpanderThemeData themeData;
  final bool expanded;
  final Duration _expandSpeed;

  const _TreeNodeExpander({
    required Duration speed,
    required this.themeData,
    required this.expanded,
  }) : _expandSpeed = speed;

  @override
  _TreeNodeExpanderState createState() => _TreeNodeExpanderState();
}

class _TreeNodeExpanderState extends State<_TreeNodeExpander> with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    bool isEnd = widget.themeData.position == ExpanderPosition.end;
    if (widget.themeData.type != ExpanderType.plusMinus) {
      controller = AnimationController(
        duration: widget.themeData.animated
            ? isEnd
                ? widget._expandSpeed * 0.625
                : widget._expandSpeed
            : Duration(milliseconds: 0),
        vsync: this,
      );
      animation = Tween<double>(
        begin: 0,
        end: isEnd ? 180 : 90,
      ).animate(controller);
    } else {
      controller = AnimationController(duration: Duration(milliseconds: 0), vsync: this);
      animation = Tween<double>(begin: 0, end: 0).animate(controller);
    }
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TreeNodeExpander oldWidget) {
    if (widget.themeData != oldWidget.themeData || widget.expanded != oldWidget.expanded) {
      bool isEnd = widget.themeData.position == ExpanderPosition.end;
      setState(() {
        if (widget.themeData.type != ExpanderType.plusMinus) {
          controller.duration = widget.themeData.animated
              ? isEnd
                  ? widget._expandSpeed * 0.625
                  : widget._expandSpeed
              : Duration(milliseconds: 0);
          animation = Tween<double>(
            begin: 0,
            end: isEnd ? 180 : 90,
          ).animate(controller);
        } else {
          controller.duration = Duration(milliseconds: 0);
          animation = Tween<double>(begin: 0, end: 0).animate(controller);
        }
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  Color? _onColor(Color? color) {
    if (color != null) {
      if (color.computeLuminance() > 0.6) {
        return Colors.black;
      } else {
        return Colors.white;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    IconData arrow;
    double iconSize = 16;
    double borderWidth = 0;
    BoxShape shapeBorder = BoxShape.rectangle;
    Color backColor = Colors.transparent;
    Color? iconColor = widget.themeData.color ?? Theme.of(context).iconTheme.color;
    switch (widget.themeData.modifier) {
      case ExpanderModifier.none:
        break;
      case ExpanderModifier.circleFilled:
        shapeBorder = BoxShape.circle;
        backColor = widget.themeData.color ?? Colors.black;
        iconColor = _onColor(backColor);
        break;
      case ExpanderModifier.circleOutlined:
        borderWidth = _kBorderWidth;
        shapeBorder = BoxShape.circle;
        break;
      case ExpanderModifier.squareFilled:
        backColor = widget.themeData.color ?? Colors.black;
        iconColor = _onColor(backColor);
        break;
      case ExpanderModifier.squareOutlined:
        borderWidth = _kBorderWidth;
        break;
    }
    // case ExpanderType.chevron:
    // _arrow = Icons.expand_more;
    // break;
    // case ExpanderType.arrow:
    //   _arrow = Icons.arrow_downward;
    //   _iconSize = widget.themeData.size > 20 ? widget.themeData.size - 8 : widget.themeData.size;
    //   break;
    // case ExpanderType.none:
    // case ExpanderType.caret:
    //   _arrow = Icons.arrow_drop_down;
    //   break;
    // case ExpanderType.plusMinus:
    arrow = widget.expanded ? Icons.remove : Icons.add;
    //   break;
    // }

    Icon icon = Icon(
      arrow,
      size: iconSize,
      color: iconColor,
    );

    if (widget.expanded) {
      controller.reverse();
    } else {
      controller.forward();
    }
    return Container(
      width: widget.themeData.size + 2,
      height: widget.themeData.size + 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: shapeBorder,
        border: borderWidth == 0
            ? null
            : Border.all(
                width: borderWidth,
                color: widget.themeData.color ?? Colors.black,
              ),
        color: backColor,
      ),
      child: AnimatedBuilder(
        animation: controller,
        child: icon,
        builder: (context, child) {
          return Transform.rotate(
            angle: animation.value * (-pi / 180),
            child: child,
          );
        },
      ),
    );
  }
}
