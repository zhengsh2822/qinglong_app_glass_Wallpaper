import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';

import '../../base/commit_button.dart';
import '../../main.dart';

class SortAccountPage extends ConsumerStatefulWidget {
  const SortAccountPage({Key? key}) : super(key: key);

  @override
  _ChangeAccountPageState createState() => _ChangeAccountPageState();
}

class _ChangeAccountPageState extends ConsumerState<SortAccountPage> {
  List<TokenBean> list = [];

  @override
  void initState() {
    try {
      String json = jsonEncode(
        getIt<MultiAccountUserInfoViewModel>().tokenBeans,
      );
      list.addAll(
        (jsonDecode(json) as List).map((e) => TokenBean.fromJson(e)).toList(),
      );
    } catch (e) {}

    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: QlAppBar(
        title: "账号排序",
        actions: [
          CommitButton(
            title: "保存",
            onTap: () {
              getIt<MultiAccountUserInfoViewModel>().resetTokenBeans(list);
              final bool isCyber =
                  ref.read(themeProvider).themeMode == modeCyber;
              if (isCyber) {
                showCyberConfirmDialog(
                  context,
                  title: '保存成功',
                  content: '重启APP后,新的顺序开始生效',
                  confirmLabel: '知道了',
                  danger: false,
                ).then((confirmed) {
                  // 原代码仅关闭弹窗，无额外操作
                });
                return;
              }
              showCupertinoDialog(
                useRootNavigator: false,
                context: context,
                builder:
                    (context) => CupertinoAlertDialog(
                      title: const Text("保存成功"),
                      content: const Text("重启APP后,新的顺序开始生效"),
                      actions: [
                        CupertinoDialogAction(
                          child: Text(
                            "知道了",
                            style: TextStyle(
                              color: ref.watch(themeProvider).primaryColor,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 30),
        buildDefaultDragHandles: true,
        // 拖动浮层（Overlay）：背景改为全透明，保留阴影以体现层级；
        // 内容由卡片自身（半透明毛玻璃）呈现，不再加不透明底色
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(animation.value);
              return Material(
                color: Colors.transparent,
                elevation: 6 * t,
                borderRadius: BorderRadius.circular(18),
                child: child,
              );
            },
          );
        },
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            //交换数据
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final TokenBean item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
          });
        },
        itemCount: list.length,
        itemBuilder: (context, index) {
          final e = list[index];
          return GlassListItemCard(
            // 关键修复：ReorderableListView 要求每张卡片 key 唯一。
            // 之前用 ValueKey(e.host) 做 key——当多个账号登录同一 host
            // （同样登录账号）或存在 host 相同的账号时，key 会重复，
            // 导致卡片只显示一部分、长按自动下移/跳动等异常。
            // 改用 ObjectKey(e)（每个 TokenBean 对象引用唯一），
            // 且重排时对象引用不变，key 保持稳定，拖动正常。
            key: ObjectKey(e),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sigma: 10,
            // 恢复卡片毛玻璃（BackdropFilter）：真正根因是 key 重复而非模糊。
            // GlassListItemCard 内部 OptimizedFrostedGlass 在 enableScrollCache:false
            // 时不会创建 GlobalKey（不会与 ReorderableListView 拖动复制子树冲突），
            // 拖动浮层由 proxyDecorator 提供不透明底色兜底，故可安全恢复模糊。
            child: buildCell(e),
          );
        },
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  Widget buildCell(TokenBean model) {
    Widget child = ListTile(
      title: Text(
        model.host ?? "",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ref.watch(themeProvider).themeColor.titleColor(),
        ),
      ),
      subtitle: Text(
        model.alias ?? "",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ref.watch(themeProvider).themeColor.descColor(),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
      minVerticalPadding: 10,
      trailing:
          (model.token != null && model.token!.isNotEmpty)
              ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: ref.watch(themeProvider).primaryColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  "已登录",
                  style: TextStyle(
                    color: ref.watch(themeProvider).primaryColor,
                    fontSize: 12,
                  ),
                ),
              )
              : Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.danger, width: 1),
                ),
                child: const Text(
                  "未登录",
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
    );
    if (model.host == null || model.host!.isEmpty) {
      return child;
    }

    return child;
  }
}
