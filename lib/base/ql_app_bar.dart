import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/account_page_transition.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class QlAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? backCall;
  final bool canBack;
  final Widget? backWidget;

  /// 是否允许点击标题 / 空白区域进入账号切换页
  final bool canClick2Vip;

  /// 左侧区域宽度（容纳"编辑+名称"双按钮时透传给 AppBar）
  final double? leadingWidth;

  const QlAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backCall,
    this.canBack = true,
    this.backWidget,
    this.canClick2Vip = true,
    this.leadingWidth,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<QlAppBar> createState() => _QlAppBarState();
}

class _QlAppBarState extends State<QlAppBar> {
  /// 标题区域（含左右空白）：共享转场的源矩形
  final GlobalKey _titleKey = GlobalKey();
  bool _opening = false;
  TextStyle? _titleStyle;

  void _openAccountPage() {
    if (_opening) return;
    if (!widget.canClick2Vip) return;
    if (SpUtil.getBool(spSingleInstance, defValue: false)) return;

    final RenderBox? box =
        _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      // 兜底：布局未完成时保持原行为
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder:
              (context, animation1, animation2) => const ChangeAccountPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    }

    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    final TextStyle style = _titleStyle ?? DefaultTextStyle.of(context).style;

    HapticFeedback.lightImpact();
    setState(() => _opening = true);

    pushAccountPageFromTitle(
      context: context,
      sourceRect: rect,
      sourceChild: Center(
        child: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _opening = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget back;

    if (widget.backWidget != null) {
      back = widget.backWidget!;
    } else {
      back = CupertinoButton(
        color: Colors.transparent,
        padding: EdgeInsets.zero,
        onPressed: () {
          if (widget.backCall != null) {
            widget.backCall!();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Center(
            child: Icon(
              CupertinoIcons.left_chevron,
              color: Theme.of(context).appBarTheme.iconTheme?.color,
            ),
          ),
        ),
      );
    }

    // AppBar 默认 primary: true，自动处理状态栏 padding，
    // toolbar 内容会被推到状态栏下方；preferredSize 必须包含状态栏高度，
    // 否则 Scaffold 给 appBar 的空间不足，toolbar 内容会被压缩。
    // 用 flexibleSpace 让 GlassAppBarContainer 覆盖整个 AppBar 区域
    // （包含状态栏 padding 部分），实现毛玻璃沉浸式效果。
    return AppBar(
      backgroundColor: Colors.transparent,
      primary: true,
      leading: widget.canBack ? back : null,
      leadingWidth: widget.leadingWidth,
      automaticallyImplyLeading: widget.canBack,
      title: Builder(
        builder: (titleContext) {
          final TextStyle style = DefaultTextStyle.of(titleContext).style;
          _titleStyle = style;
          // 整个标题区（含左右空白）统一触发账号页；
          // 返回键 / actions 仍是独立子节点，不会被这里吞掉。
          return GestureDetector(
            key: _titleKey,
            behavior: HitTestBehavior.opaque,
            onTap: _openAccountPage,
            child: Opacity(
              opacity: _opening ? 0 : 1,
              child: SizedBox(
                width: double.infinity,
                height: kToolbarHeight,
                child: Center(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      centerTitle: true,
      // titleSpacing 默认 16 会吃中间区 32px：360 逻辑宽设备上 env 页标题被截断成"环境…"，
      // 收窄至 4 给标题让出空间（标题与左右按钮实际间隙由各页 leading/actions 间距控制）
      titleSpacing: 4,
      actions: [...?widget.actions],
      // AppBar 空白区域（状态栏下沿、标题两侧）也统一触发账号页：
      // flexibleSpace 在 toolbar 下层，返回键/标题/actions 命中时优先响应，
      // 仅空白处落到这里。
      flexibleSpace: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openAccountPage,
        child: const GlassAppBarContainer(child: SizedBox.expand()),
      ),
    );
  }
}
