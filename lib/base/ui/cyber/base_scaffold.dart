import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

/// 统一基础Scaffold组件
///
/// 赛博模式下使用极致纯净的深空黑底色(#050505)，
/// 参考Gemini的深邃纯净感，摒弃花哨纹理。
/// 所有页面应使用BaseScaffold替代直接Scaffold，确保全局背景统一。
class BaseScaffold extends ConsumerWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final bool resizeToAvoidBottomInset;
  final Color? backgroundColor;

  const BaseScaffold({
    Key? key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.resizeToAvoidBottomInset = true,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      // 赛博模式：统一深空黑；其他模式：使用主题背景色
      backgroundColor:
          backgroundColor ??
          (isCyber
              ? CyberColors.bg
              : ref.watch(themeProvider).currentTheme.scaffoldBackgroundColor),
    );
  }
}
