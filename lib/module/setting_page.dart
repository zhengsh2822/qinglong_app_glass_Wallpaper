import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/button.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/home/home_page.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/home/version_history_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../base/ql_app_bar.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString(),
      );
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }

    // 全局壁纸架构：Scaffold 背景必须透明，让 WallpaperBackground 透过
    final scaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(title: "系统设置"),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible:
                  Platform.isIOS ||
                  SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),
                  const SectionHeader(title: "VIP功能"),
                  const SizedBox(height: 10),
                  SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsSwitchRow(
                          icon: CupertinoIcons.smiley,
                          title: "使用Face ID解锁",
                          value: SpUtil.getBool(spOpenAuth, defValue: false),
                          onChanged: (open) async {
                            await SpUtil.putBool(spOpenAuth, open);
                            setState(() {});
                          },
                        ),
                        settingsDivider,
                        SettingsSwitchRow(
                          icon: CupertinoIcons.wand_stars_inverse,
                          title: "单实例模式",
                          value: SpUtil.getBool(
                            spSingleInstance,
                            defValue: false,
                          ),
                          onChanged: (open) async {
                            SpUtil.putBool(spSingleInstance, open);
                            setState(() {});
                          },
                          trailing: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              showConfirmDialog(
                                context,
                                title: '温馨提示',
                                content:
                                    '开启后可关闭多容器同时在线功能，减少APP对系统内存的消耗，通过长按首页 我的 切换账号',
                                cancelLabel: '知道了',
                                confirmLabel: '确定',
                                danger: false,
                              );
                            },
                            child: const Icon(
                              CupertinoIcons.question_circle,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const SectionHeader(title: "通用功能"),
            const SizedBox(height: 10),
            SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSwitchRow(
                    icon: CupertinoIcons.doc_text,
                    title: "任务自动弹出日志",
                    value: SpUtil.getBool(spAutoShowLog, defValue: true),
                    onChanged: (open) async {
                      await SpUtil.putBool(spAutoShowLog, open);
                      setState(() {});
                    },
                  ),
                  settingsDivider,
                  SettingsSwitchRow(
                    icon: Icons.abc_sharp,
                    title: "代码显示行号",
                    value: SpUtil.getBool(spShowLine, defValue: false),
                    onChanged: (open) async {
                      await SpUtil.putBool(spShowLine, open);
                      setState(() {});
                    },
                  ),
                  settingsDivider,
                  SettingsSwitchRow(
                    icon: CupertinoIcons.arrow_down_doc,
                    title: "日志内容自动滚动",
                    value: SpUtil.getBool(
                      spLogAutoJump2Bottom,
                      defValue: false,
                    ),
                    onChanged: (open) async {
                      await SpUtil.putBool(spLogAutoJump2Bottom, open);
                      setState(() {});
                    },
                  ),
                  Visibility(
                    visible: !(systemBean.fromAutoGet ?? false),
                    child: settingsDivider,
                  ),
                  Visibility(
                    visible: !(systemBean.fromAutoGet ?? false),
                    child: SettingsTapRow(
                      icon: CupertinoIcons.paperplane,
                      title: "变更服务器版本号",
                      onTap: () => _updateVersion(context),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "(${systemBean.version})",
                            style: TextStyle(
                              color:
                                  ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .descColor(),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 40,
                child: ButtonWidget(
                  title: "退出登录",
                  onTap: () {
                    showConfirmDialog(
                      context,
                      title: '确认退出登录吗?',
                      content: '',
                      danger: true,
                      confirmLabel: '退出',
                    ).then((confirmed) {
                      if (confirmed == true) {
                        SingleAccountPageState.ofUserInfo(context).updateToken(
                          SingleAccountPageState.of(context)?.index ?? 0,
                          SingleAccountPageState.ofUserInfo(context).host,
                          "",
                          false,
                          // 使用 rawAlias 避免退出登录时把 host 当作 alias 保存
                          SingleAccountPageState.ofUserInfo(context).rawAlias,
                        );
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.routeLogin,
                          (p) {
                            return false;
                          },
                        );
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 40,
                child: ButtonWidget(
                  title: "退出登录并清空本地数据",
                  onTap: () {
                    showConfirmDialog(
                      context,
                      title: '确认退出登录并清空账号本地数据吗?',
                      content: '',
                      danger: true,
                      confirmLabel: '清空并退出',
                    ).then((confirmed) {
                      if (confirmed == true) {
                        clearData(context);
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.routeLogin,
                          (p) {
                            return false;
                          },
                        );
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  void clearData(BuildContext context) {
    getIt<MultiAccountUserInfoViewModel>().removeHistoryAccount(
      SingleAccountPageState.ofUserInfo(context).host,
    );
    SingleAccountPageState.ofUserInfo(
      context,
    ).clearCurrentInfo(SingleAccountPageState.of(context)?.index ?? 0);
  }

  void _updateVersion(BuildContext context) async {
    String? host = SingleAccountPageState.ofUserInfo(context).host;

    String currentVersion =
        getIt<SystemBean>(
          instanceName:
              (SingleAccountPageState.of(context)?.index ?? 0).toString(),
        ).version ??
        '';

    final result = await showInputDialog(
      context,
      title: '请输入版本号',
      content: '当前版本: $currentVersion',
      hintText: '请输入版本号',
      initialValue: currentVersion,
    );

    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return;

    HomePageState.updateVersionHistory(
      VersionHistoryBean(host: host, version: trimmed),
    );
    SingleAccountPageState.of(context)?.registerSystemBean(trimmed, false);
    setState(() {});
  }

  void commitLogDel(int time) async {
    var response = await SingleAccountPageState.ofApi(context).logDelTime(time);
    if (response.success) {
      "修改成功".toast();
    } else {
      response.message?.toast();
    }
  }
}
