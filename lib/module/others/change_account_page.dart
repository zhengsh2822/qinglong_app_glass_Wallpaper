import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slidable.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../main.dart';

class ChangeAccountPage extends ConsumerStatefulWidget {
  const ChangeAccountPage({Key? key}) : super(key: key);

  @override
  _ChangeAccountPageState createState() => _ChangeAccountPageState();
}

class _ChangeAccountPageState extends ConsumerState<ChangeAccountPage> {
  @override
  void initState() {
    super.initState();

    FocusManager.instance.primaryFocus?.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (MultiAccountUserInfoViewModel.maxAccount == 1 &&
          SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal) {
        "请杀掉App重新进入,即可启用多账号切换功能".toast();
      }
    });
  }

  bool get _isCyber => ref.watch(themeProvider).themeMode == modeCyber;

  @override
  Widget build(BuildContext context) {
    int count = getIt<MultiAccountUserInfoViewModel>().tokenBeans.length + 1;
    if (count > MultiAccountUserInfoViewModel.maxAccount) {
      count = MultiAccountUserInfoViewModel.maxAccount;
    }
    final bool isCyber = _isCyber;
    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            (ref.watch(themeProvider).themeMode == modeDark || isCyber)
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
        child: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: kToolbarHeight,
                      ),
                      child: Icon(
                        CupertinoIcons.clear_thick,
                        size: 24,
                        color: isCyber ? CyberColors.cyan : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "轻触账号以切换身份使用",
                  style: TextStyle(
                    color:
                        isCyber
                            ? Colors.blueGrey
                            : ref.watch(themeProvider).themeColor.descColor(),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 30),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (index >=
                              getIt<MultiAccountUserInfoViewModel>()
                                  .tokenBeans
                                  .length ||
                          (getIt<MultiAccountUserInfoViewModel>()
                                      .tokenBeans
                                      .length <
                                  count &&
                              index == count - 1)) {
                        return addAccount(context, index);
                      }

                      var userInfo = getIt<UserInfoViewModel>(
                        instanceName: index.toString(),
                      );
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          context
                              .findAncestorStateOfType<MultiAccountPageState>()
                              ?.updateIndex(index);
                          Navigator.of(context).pop();
                        },
                        child: _buildAccountCard(userInfo, index, isCyber),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemCount: count,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (isCyber) {
      return CyberBackground(child: scaffold);
    }
    return scaffold;
  }

  /// 构建账号卡片（赛博/非赛博统一布局，仅颜色不同）
  Widget _buildAccountCard(
    UserInfoViewModel userInfo,
    int index,
    bool isCyber,
  ) {
    final child = _buildCell(userInfo, index, isCyber);

    if (userInfo.host == null || userInfo.host!.isEmpty) {
      return child;
    }

    // 卡片容器
    Widget card;
    if (isCyber) {
      card = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: OptimizedFrostedGlass(
          sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CyberColors.borderGlow, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
          ),
        ),
      );
    } else {
      card = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: OptimizedFrostedGlass(
          sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppleColors.cardBorder, width: 0.5),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
          ),
        ),
      );
    }

    // 滑动删除
    if (isCyber) {
      return CyberSlidable(
        slidableKey: ValueKey(userInfo.host),
        endActions: [
          CyberSlideAction(
            label: '删除',
            icon: CupertinoIcons.delete,
            color: const Color(0xFFFF3D5C),
            onTap: () => _confirmDelete(userInfo, index),
          ),
        ],
        child: card,
      );
    }

    return Slidable(
      key: ValueKey(userInfo.host),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          AppSlideButton(
            context: context,
            color: const Color(0xffEA4D3E),
            icon: CupertinoIcons.delete,
            onTap: () => _confirmDelete(userInfo, index),
            cyberMode: false,
            width: double.infinity,
            cornerRadius: 12,
            iconSize: 22,
            outerGap: 5,
            innerGap: 6,
          ),
        ],
      ),
      child: card,
    );
  }

  /// 确认删除（统一弹窗）
  void _confirmDelete(UserInfoViewModel model, int index) {
    if (model.token != null && model.token!.isNotEmpty) {
      "请先退出登录，再删除".toast();
      return;
    }
    showConfirmDialog(
      context,
      title: '温馨提示',
      content: '确定删除吗?',
      danger: true,
    ).then((confirmed) {
      if (confirmed == true) {
        getIt<MultiAccountUserInfoViewModel>().removeHistoryAccount(model.host);
        getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).clearCurrentInfo(index);
        setState(() {});
      }
    });
  }

  /// 账号单元格内容（赛博/非赛博统一布局：host + alias + 状态指示器）
  Widget _buildCell(UserInfoViewModel model, int index, bool isCyber) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.host ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'MiSans',
                    color:
                        isCyber
                            ? CyberColors.titleWhite
                            : ref.watch(themeProvider).themeColor.titleColor(),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  model.alias ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isCyber
                            ? CyberColors.descColor
                            : ref.watch(themeProvider).themeColor.descColor(),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatus(model, isCyber),
        ],
      ),
    );
  }

  /// 状态指示器（赛博/非赛博统一：圆点 + 文本）
  Widget _buildStatus(UserInfoViewModel model, bool isCyber) {
    final bool loggedIn = model.token != null && model.token!.isNotEmpty;
    final Color color =
        loggedIn
            ? (isCyber ? CyberColors.neonGreen : AppleColors.accent)
            : (isCyber ? CyberColors.neonRed : const Color(0xffFB5858));
    final String text = loggedIn ? "已登录" : "未登录";
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow:
                isCyber ? [BoxShadow(color: color, blurRadius: 4)] : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  /// 添加账号按钮（赛博/非赛博统一布局）
  Widget addAccount(BuildContext context, int index) {
    final bool isCyber = _isCyber;
    final accentColor =
        isCyber ? CyberColors.cyan : ref.watch(themeProvider).primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.findAncestorStateOfType<MultiAccountPageState>()?.updateIndex(
          index,
        );
        Navigator.of(context).pop();
      },
      child:
          isCyber
              ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: OptimizedFrostedGlass(
                  sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: CyberColors.borderGlow,
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: _buildAddAccountContent(accentColor),
                    ),
                  ),
                ),
              )
              : Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: OptimizedFrostedGlass(
                  sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppleColors.cardBorder,
                        width: 0.5,
                      ),
                    ),
                    child: _buildAddAccountContent(accentColor),
                  ),
                ),
              ),
    );
  }

  /// 添加账号内容（统一布局：圆形图标 + 文本）
  Widget _buildAddAccountContent(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(CupertinoIcons.add, color: accentColor),
          ),
          const SizedBox(width: 15),
          Text("添加账号", style: TextStyle(color: accentColor, fontSize: 15)),
        ],
      ),
    );
  }
}
