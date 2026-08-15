import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/bottom_nav_bar.dart';
import 'package:qinglong_app/base/ui/slidable_close_notifier.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_page.dart';
import 'package:qinglong_app/module/env/env_page.dart';
import 'package:qinglong_app/module/home/version_history_bean.dart';
import 'package:qinglong_app/module/others/other_page.dart';
import 'package:qinglong_app/module/task/task_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/login_helper.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../../base/multi_account_userinfo_viewmodel.dart';
import '../../base/userinfo_viewmodel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  List<IndexBean> titles = [];

  @override
  void initState() {
    initTitles();
    super.initState();
    SingleAccountPageState.of(context)?.registerICloud();
    SingleAccountPageState.of(
      context,
    )?.registerHttp(SingleAccountPageState.ofUserInfo(context).host!);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      getSystemBean(context);
    });
  }

  static void updateVersionHistory(VersionHistoryBean versionHistoryBean) {
    String json = SpUtil.getString(spVersioCodeHistory, defValue: "[]");
    List<dynamic> temp = jsonDecode(json) as List<dynamic>;
    temp.add(versionHistoryBean.toJson());
    SpUtil.putString(spVersioCodeHistory, jsonEncode(temp));
  }

  static String? getCurrentVersion(String? host) {
    if (host != null && host.isNotEmpty) {
      String json = SpUtil.getString(spVersioCodeHistory, defValue: "[]");

      List<dynamic> temp = jsonDecode(json) as List<dynamic>;

      if (temp.isNotEmpty) {
        var list = temp.map((e) => VersionHistoryBean.fromJson(e)).toList();

        String? version =
            list
                .firstWhere(
                  (element) => element.host == host,
                  orElse: () {
                    return VersionHistoryBean();
                  },
                )
                .version;
        return version;
      }
    }
    return null;
  }

  bool getSystemBeanSuccess = false;

  void updateSystemBean() {
    setState(() {
      getSystemBeanSuccess = true;
    });
  }

  void getSystemBean(BuildContext context) async {
    var bean = await SingleAccountPageState.ofApi(context).system();

    if (!bean.success) {
      String? host = SingleAccountPageState.ofUserInfo(context).host;

      String? version = getCurrentVersion(host);

      if (version == null || version.isEmpty) {
        "获取版本号失败，请前往应用设置中添加".toast();
        updateVersionHistory(
          VersionHistoryBean(
            host: SingleAccountPageState.ofUserInfo(context).host,
            version: "2.10.13",
          ),
        );
        SingleAccountPageState.of(
          context,
        )?.registerSystemBean(bean.bean?.version ?? "2.10.13", false);
        updateSystemBean();
        return;
      }
    }

    if (bean.bean == null || bean.bean?.version == null) {
      //从历史记录里找版本号
      String? host = SingleAccountPageState.ofUserInfo(context).host;

      String? version = getCurrentVersion(host);

      if (version != null && version.isNotEmpty) {
        SingleAccountPageState.of(context)?.registerSystemBean(version, false);
        updateSystemBean();
        return;
      }

      "获取版本号失败，请手动配置".toast();
      TextEditingController controller = TextEditingController(text: "");
      showCupertinoDialog(
        useRootNavigator: false,
        context: context,
        builder:
            (context1) => CupertinoAlertDialog(
              title: const Text("请输入版本号:"),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: TextField(
                      textAlign: TextAlign.center,
                      controller: controller,
                      autofocus: false,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .title2Color(),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .title2Color(),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text(
                    "取消",
                    style: TextStyle(color: Color(0xff999999)),
                  ),
                  onPressed: () {
                    Navigator.of(context1).pop();
                    "已默认为2.10.13版本".toast();
                    updateVersionHistory(
                      VersionHistoryBean(host: host, version: "2.10.13"),
                    );
                    SingleAccountPageState.of(context)?.registerSystemBean(
                      bean.bean?.version ?? "2.10.13",
                      false,
                    );
                    updateSystemBean();
                  },
                ),
                CupertinoDialogAction(
                  child: Text(
                    "确定",
                    style: TextStyle(
                      color: ref.watch(themeProvider).primaryColor,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(context1).pop();
                    updateVersionHistory(
                      VersionHistoryBean(
                        host: host,
                        version: controller.text.trim(),
                      ),
                    );
                    SingleAccountPageState.of(
                      context,
                    )?.registerSystemBean(controller.text.trim(), false);
                    updateSystemBean();
                  },
                ),
              ],
            ),
      );
    } else {
      SingleAccountPageState.of(
        context,
      )?.registerSystemBean(bean.bean?.version ?? "2.10.13", true);
      updateSystemBean();
    }
  }

  @override
  void dispose() {
    MultiAccountPageState.clearAction();
    super.dispose();
  }

  bool showMask = false;

  GlobalKey<TaskPageState> taskKey = GlobalKey();
  GlobalKey<EnvPageState> envKey = GlobalKey();
  GlobalKey<OtherPageState> meKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            RepaintBoundary(
              child: Scaffold(
                extendBody: true,
                body: IndexedStack(
                  index: ref.watch<int>(
                    SingleAccountPageState.ofHomeIndexProvider(context)(
                      getProviderName(context),
                    ),
                  ),
                  children: [
                    TaskPage(key: taskKey, loading: !getSystemBeanSuccess),
                    EnvPage(key: envKey),
                    const ConfigPage(),
                    OtherPage(key: meKey),
                  ],
                ),
                bottomNavigationBar:
                    ref.read(themeProvider).themeMode == modeCyber
                        ? ClipRRect(
                          // ClipRRect必须放在最外层！
                          // BackdropFilter的高斯模糊会渲染到容器边界之外，
                          // BoxDecoration的borderRadius无法裁剪BackdropFilter，
                          // 只有ClipRRect的物理裁剪才能彻底消除圆角旁的直角溢出。
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10.0),
                              sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10.0),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: ref
                                    .watch(themeProvider)
                                    .currentTheme
                                    .bottomNavigationBarTheme
                                    .backgroundColor
                                    ?.withOpacity(0.65),
                              ),
                              height:
                                  kBottomNavigationBarHeight +
                                  MediaQuery.of(context).padding.bottom,
                              width: MediaQuery.of(context).size.width,
                              child: _buildBottomNav(context),
                            ),
                          ),
                        )
                        : Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x15000000),
                                blurRadius: 15,
                                offset: Offset(0, -3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10.0),
                                sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10.0),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppleColors.bgPrimary.withOpacity(
                                    0.75,
                                  ),
                                ),
                                height:
                                    kBottomNavigationBarHeight +
                                    MediaQuery.of(context).padding.bottom,
                                width: MediaQuery.of(context).size.width,
                                child: _buildBottomNav(context),
                              ),
                            ),
                          ),
                        ),
              ),
            ),
            Visibility(
              visible: showMask,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  setState(() {
                    showMask = false;
                  });
                },
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
            Positioned(
              child: Visibility(
                visible: showMask,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: _buildOtherAccounts(),
                      width: MediaQuery.of(context).size.width / 2,
                    ),
                    _buildOtherWidget(),
                  ],
                ),
              ),
              bottom: MediaQuery.of(context).viewPadding.bottom,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建底部导航栏内容
  Widget _buildBottomNav(BuildContext context) {
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    // 壁纸版本统一读 SP 自定义字体颜色，让底部 tab 文案跟随字体设置
    // 次字体颜色：优先读 SP[spSecondaryTextColor]，未设置（-1）回退 CyberColors.idleGray
    final customSecondary = SpUtil.getInt(spSecondaryTextColor, defValue: -1);
    final secondaryColor = customSecondary >= 0 ? Color(customSecondary) : CyberColors.idleGray;
    return BottomNavigationBar2(
      backgroundColor: Colors.transparent,
      selectedItemColor: isCyber ? null : ref.watch(themeProvider).primaryColor,
      unselectedItemColor: secondaryColor,
      items:
          titles
              .map(
                (e) => BottomNavigationBarItem(
                  icon: Image.asset(
                    e.icon,
                    fit: BoxFit.cover,
                    width: 20,
                    height: 20,
                  ),
                  activeIcon: Image.asset(
                    e.checkedIcon,
                    fit: BoxFit.cover,
                    width: 20,
                    height: 20,
                  ),
                  label: e.title,
                ),
              )
              .toList(),
      currentIndex: ref.watch<int>(
        SingleAccountPageState.ofHomeIndexProvider(context)(
          getProviderName(context),
        ),
      ),
      onTap: (index) async {
        final currentIdx = ref.read<int>(
          SingleAccountPageState.ofHomeIndexProvider(context)(
            getProviderName(context),
          ),
        );
        if (currentIdx == index) {
          if (index == 0) {
            await taskKey.currentState?.move2Top();
          } else if (index == 1) {
            await envKey.currentState?.move2Top();
          } else if (index == 3) {
            await meKey.currentState?.move2Top();
          }
          return;
        } else {
          // 切换 tab 时关闭所有打开的 Slidable 卡片
          SlidableCloseNotifier.notify();
          ref
              .read(
                SingleAccountPageState.ofHomeIndexProvider(context)(
                  getProviderName(context),
                ).notifier,
              )
              .state = index;
        }
      },
      elevation: 0,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      onLongTap: (index) async {
        if (index == 3) {
          HapticFeedback.mediumImpact();
          setState(() {
            showMask = true;
          });
        }
      },
    );
  }

  void initTitles() {
    titles.clear();
    titles.add(
      IndexBean(
        "assets/images/icon_cron.png",
        "assets/images/icon_cron_checked.png",
        "定时任务",
      ),
    );
    titles.add(
      IndexBean(
        "assets/images/icon_env.png",
        "assets/images/icon_env_checked.png",
        "环境变量",
      ),
    );
    titles.add(
      IndexBean(
        "assets/images/icon_file.png",
        "assets/images/icon_file_checked.png",
        "配置文件",
      ),
    );
    titles.add(
      IndexBean(
        "assets/images/icon_other.png",
        "assets/images/icon_other_checked.png",
        "我的",
      ),
    );
  }

  Widget _buildOtherWidget() {
    if (!showMask) return const SizedBox.shrink();
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: kBottomNavigationBarHeight,
      child: Row(
        children: [
          const Spacer(),
          const Spacer(),
          const Spacer(),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    "assets/images/icon_other.png",
                    fit: BoxFit.cover,
                    width: 20,
                    height: 20,
                  ),
                ),
                const Text(
                  "我的",
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherAccounts() {
    if (!showMask) return const SizedBox.shrink();
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final cardRadius = isCyber ? 10.0 : AppleColors.radiusCard;
    int count = getIt<MultiAccountUserInfoViewModel>().tokenBeans.length + 1;
    if (count > MultiAccountUserInfoViewModel.maxAccount) {
      count = MultiAccountUserInfoViewModel.maxAccount;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10), sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - kToolbarHeight * 2,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(cardRadius),
          ),
        child: SingleChildScrollView(
          child: Column(
            children:
                SpUtil.getBool(spSingleInstance, defValue: false) == true
                    ? _buildSingleInstance()
                    : List.generate(count, (index) {
                      if (index >=
                              getIt<MultiAccountUserInfoViewModel>()
                                  .tokenBeans
                                  .length ||
                          (getIt<MultiAccountUserInfoViewModel>()
                                      .tokenBeans
                                      .length <
                                  count &&
                              index == count - 1)) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              dismissMask();
                              WidgetsBinding.instance.addPostFrameCallback((
                                timeStamp,
                              ) {
                                context
                                    .findAncestorStateOfType<
                                      MultiAccountPageState
                                    >()
                                    ?.updateIndex(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.add,
                                    size: 15,
                                    color:
                                        ref
                                            .watch(themeProvider)
                                            .themeColor
                                            .titleColor(),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "添加账户",
                                    style: TextStyle(
                                      color:
                                          ref
                                              .watch(themeProvider)
                                              .themeColor
                                              .titleColor(),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      var userInfo = getIt<UserInfoViewModel>(
                        instanceName: index.toString(),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                dismissMask();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  timeStamp,
                                ) {
                                  context
                                      .findAncestorStateOfType<
                                        MultiAccountPageState
                                      >()
                                      ?.updateIndex(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  userInfo.host
                                          ?.replaceAll("http://", "")
                                          .replaceAll("https://", "") ??
                                      "",
                                  maxLines: 1,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        ref
                                            .watch(themeProvider)
                                            .themeColor
                                            .titleColor(),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(indent: 15, height: 1),
                        ],
                      );
                    }),
          ),
        ),
      ),
      ),
    );
  }

  void dismissMask() {
    setState(() {
      showMask = false;
    });
  }

  List<Widget> _buildSingleInstance() {
    int count = getIt<MultiAccountUserInfoViewModel>().historyAccounts.length;

    if (SpUtil.getInt(spVIP, defValue: typeNormal) == typeVIP) {
      if (count > 3) {
        count = 3;
      }
    }

    return List.generate(count + 1, (index) {
      if (index >= count) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              dismissMask();
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                Navigator.of(
                  context,
                ).pushNamed(Routes.routeLogin, arguments: true);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.add,
                    size: 15,
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "添加账户",
                    style: TextStyle(
                      color: ref.watch(themeProvider).themeColor.titleColor(),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      var userInfo =
          getIt<MultiAccountUserInfoViewModel>().historyAccounts[index];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                dismissMask();

                if (SingleAccountPageState.ofHttp(context)?.host ==
                    userInfo.host)
                  return;

                WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
                  await EasyLoading.show(status: " 登录中");

                  LoginHelper loginHelper = LoginHelper(
                    userInfo.host!,
                    userInfo.userName!,
                    userInfo.password!,
                    true,
                    userInfo.alias,
                  );
                  var response = await loginHelper.login(context);

                  EasyLoading.dismiss();

                  dealLoginResponse(loginHelper, response);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  userInfo.host
                          ?.replaceAll("http://", "")
                          .replaceAll("https://", "") ??
                      "",
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        SingleAccountPageState.ofHttp(context)?.host ==
                                userInfo.host
                            ? ref.watch(themeProvider).primaryColor
                            : ref.watch(themeProvider).themeColor.titleColor(),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const Divider(indent: 15, height: 1),
        ],
      );
    });
  }

  void twoFact(LoginHelper helper) {
    String twoFact = "";
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder:
          (_) => CupertinoAlertDialog(
            title: const Text("两步验证"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: TextField(
                    onChanged: (value) {
                      twoFact = value;
                    },
                    maxLines: 1,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                      hintText: "请输入code",
                    ),
                    autofocus: true,
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text(
                  "取消",
                  style: TextStyle(color: Color(0xff999999)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              CupertinoDialogAction(
                child: Text(
                  "确定",
                  style: TextStyle(
                    color: ref.watch(themeProvider).primaryColor,
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  var response = await helper.loginTwice(context, twoFact);
                  dealLoginResponse(helper, response);
                },
              ),
            ],
          ),
    ).then((value) {});
  }

  void dealLoginResponse(LoginHelper hepler, int response) {
    if (response == LoginHelper.success) {
      Navigator.of(context).pushReplacementNamed(Routes.routeHomePage);
    } else if (response == LoginHelper.failed) {
      EasyLoading.showError("登录失败，请检查账号");
    } else {
      twoFact(hepler);
    }
  }
}

class IndexBean {
  String icon;
  String checkedIcon;
  String title;
  String celebrate;

  IndexBean(this.icon, this.checkedIcon, this.title, {this.celebrate = ""});
}
