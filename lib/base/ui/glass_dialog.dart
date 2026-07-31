import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 毛玻璃风格弹窗，替代 [CupertinoAlertDialog]。
///
/// 背景使用 [BackdropFilter] + 半透明深色，与项目全局毛玻璃卡片风格一致。
/// API 尽量兼容 [CupertinoAlertDialog]（title/content/actions），
/// 配合 [showGlassDialog] 使用以获得与 [showCupertinoDialog] 一致的调用体验。
class GlassAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  const GlassAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 20);
    final List<Widget> children = [];
    if (title != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CyberColors.titleWhite,
            ),
            textAlign: TextAlign.center,
            child: title!,
          ),
        ),
      );
    }
    if (content != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 13, color: CyberColors.descColor),
            textAlign: TextAlign.center,
            child: content!,
          ),
        ),
      );
    }
    if (actions.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildActions(context),
          ),
        ),
      );
    } else {
      children.add(const SizedBox(height: 20));
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        constraints: const BoxConstraints(maxWidth: 270),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: effectiveSigma, sigmaY: effectiveSigma),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CyberColors.borderGlow, width: 0.5),
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final List<Widget> result = [];
    for (int i = 0; i < actions.length; i++) {
      if (i > 0) {
        result.add(
          Container(
            height: 0.5,
            color: CyberColors.borderGlow.withOpacity(0.5),
          ),
        );
      }
      result.add(actions[i]);
    }
    return result;
  }
}

/// 毛玻璃弹窗的 [CupertinoDialogAction] 等价物。
///
/// 默认文字使用 [CupertinoColors.activeBlue]（与 CupertinoAlertDialog 一致），
/// 可通过 [textStyle] 自定义颜色（如 [Theme.of(context).primaryColor]）。
class GlassDialogAction extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final TextStyle? textStyle;
  final bool isDestructiveAction;

  const GlassDialogAction({
    super.key,
    required this.child,
    this.onPressed,
    this.textStyle,
    this.isDestructiveAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isDestructiveAction
        ? CupertinoColors.destructiveRed
        : (textStyle?.color ?? Theme.of(context).primaryColor);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      minSize: 0,
      onPressed: onPressed,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        textAlign: TextAlign.center,
        child: child,
      ),
    );
  }
}

/// 展示毛玻璃弹窗，替代 [showCupertinoDialog]。
///
/// 使用 [showGeneralDialog] + [GlassAlertDialog] 实现，
/// 弹窗背景为 [BackdropFilter] 毛玻璃 + [CyberColors.bg] 半透明深色，
/// 与项目全局毛玻璃卡片风格一致。
///
/// 示例：
/// ```dart
/// showGlassDialog(
///   context: context,
///   title: Text("温馨提示"),
///   content: Text("确定退出吗?"),
///   actions: [
///     GlassDialogAction(
///       child: Text("取消"),
///       onPressed: () => Navigator.of(context).pop(),
///     ),
///     GlassDialogAction(
///       child: Text("确定"),
///       onPressed: () {
///         Navigator.of(context).pop();
///         // ...
///       },
///     ),
///   ],
/// );
/// ```
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  Widget? title,
  Widget? content,
  List<Widget> actions = const [],
  bool useRootNavigator = false,
  bool barrierDismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return GlassAlertDialog(
        title: title,
        content: content,
        actions: actions,
      );
    },
  );
}
