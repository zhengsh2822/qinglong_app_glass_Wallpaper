import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/other_page_card.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/module/in_app_purchase_page.dart';
import 'package:qinglong_app/module/others/backup_page.dart';
import 'package:qinglong_app/module/others/blur_settings_page.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_setting_page.dart';
import 'package:qinglong_app/module/others/sort_account_page.dart';
import 'package:qinglong_app/module/others/text_size_page.dart';
import 'package:qinglong_app/module/others/update_password_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/floating_clock_service.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:path/path.dart' as ints;

import '../../main.dart';
import '../appkey/appkey_page.dart';
import '../home/system_bean.dart';
import '../push_setting_page.dart';
import '../scan_page.dart';
import '../task/task_page.dart';
import '../update_max_account_page.dart';

class OtherPage extends ConsumerStatefulWidget {
  const OtherPage({Key? key}) : super(key: key);

  @override
  OtherPageState createState() => OtherPageState();
}

class OtherPageState extends ConsumerState<OtherPage>
    with LazyLoadState<OtherPage>, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  var toggleValue = false;
  String? userIcon;
  String userName = "青龙客户端";
  var desc = "欢迎使用青龙客户端".obs;
  Map<String, dynamic> poetData = {};
  /// 功能按钮字重（build 顶部 watch textWeightProvider，跟随全局四档调节）
  FontWeight _featureFw = FontWeight.w400;

  @override
  void initState() {
    super.initState();
    delLogsByExperiedDate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final ScrollController _scrollController = ScrollController();
  GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

  Future<void> move2Top() async {
    if (_scrollController.offset !=
        _scrollController.position.minScrollExtent) {
      await scrollToTop();
    } else {
      if (refreshKey.currentState?.mounted ?? false) {
        await refreshKey.currentState?.show();
      }
    }
  }

  Future<void> scrollToTop() async {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  /// 长按修改账号名称（别名）
  void _editAlias() {
    final userInfo = SingleAccountPageState.ofUserInfo(context);
    final currentIndex = SingleAccountPageState.of(context)?.index ?? 0;
    // 使用 rawAlias 获取真实别名（不回退到 host），避免 initialValue 显示成 host
    final currentAlias = userInfo.rawAlias ?? "";
    showInputDialog(
      context,
      title: '修改名称',
      hintText: '请输入名称',
      initialValue: currentAlias,
      inputFormatters: [LengthLimitingTextInputFormatter(20)],
    ).then((newAlias) {
      if (newAlias == null) return;
      final trimmed = newAlias.trim();
      if (trimmed == currentAlias) return;
      final alias = trimmed.isEmpty ? null : trimmed;
      userInfo.updateToken(
        currentIndex,
        userInfo.host,
        userInfo.token,
        userInfo.useSecretLogined,
        alias,
      );
      // 同步更新 historyAccounts，若没有匹配 host 的 bean 则新建一个保存
      final multiVM = getIt<MultiAccountUserInfoViewModel>();
      bool found = false;
      for (final bean in multiVM.historyAccounts) {
        if (bean.host == userInfo.host) {
          bean.alias = alias;
          multiVM.save2HistoryAccount(bean);
          found = true;
          break;
        }
      }
      if (!found) {
        multiVM.save2HistoryAccount(
          UserInfoBean(
            host: userInfo.host,
            alias: alias,
            userName: userInfo.userName,
            password: userInfo.passWord,
            useSecretLogined: userInfo.useSecretLogined,
          ),
        );
      }
      "名称已更新".toast();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final _ = ref.watch(themeProvider);
    // 功能按钮字重跟随全局设置（我的页各功能入口统一）
    _featureFw = FontWeight(ref.watch(textWeightProvider));
    Widget body = RefreshIndicator(
      key: refreshKey,
      onRefresh: () async {
        await loadPoet();
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom:
                MediaQuery.of(context).viewPadding.bottom +
                kBottomNavigationBarHeight +
                50,
          ),
          child: Column(
            children: [
              // 顶部用户信息区（替代原 250px 图片色块，使用毛玻璃卡片）
              _buildUserHeader(),
              const SizedBox(height: AppleColors.spaceLg),
              // APP功能介绍
              _buildAppIntroCard(),
              const SizedBox(height: AppleColors.spaceLg),
              // 多帐号设置/第三方功能
              _buildMultiAccountCard(),
              const SizedBox(height: AppleColors.spaceLg),
              // 高级功能
              _buildAdvancedCard(),
              const SizedBox(height: AppleColors.spaceLg),
              // 基础功能
              _buildBasicCard(),
              SizedBox(
                height:
                    kBottomNavigationBarHeight +
                    MediaQuery.of(context).viewPadding.bottom,
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: body,
    );
  }

  /// 顶部用户信息区：透明毛玻璃卡片
  Widget _buildUserHeader() {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    return OtherPageCard(
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 20, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (SpUtil.getInt(spVIP, defValue: typeNormal) ==
                    typeNormal) {
                  Navigator.of(context).push(
                    WallpaperPageRoute(
                      builder:
                          (context) => const InAppPurchasePage(
                            fromDirectly: true,
                          ),
                    ),
                  );
                  return;
                } else {
                  if (SpUtil.getBool(
                    spSingleInstance,
                    defValue: false,
                  )) {
                    return;
                  }
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder:
                          (context, animation1, animation2) =>
                              const ChangeAccountPage(),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                }
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        (userIcon != null && userIcon!.isNotEmpty)
                            ? Image.network(
                              userIcon!,
                              width: 60,
                              height: 60,
                              cacheWidth: 120,
                              cacheHeight: 120,
                              errorBuilder: (_, __, ___) {
                                return Image.asset(
                                  getImageByVIPLogo(),
                                  width: 60,
                                  height: 60,
                                );
                              },
                            )
                            : Image.asset(
                              getImageByVIPLogo(),
                              width: 60,
                              height: 60,
                            ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        GestureDetector(
                          onLongPress: () => _editAlias(),
                          child: Text(
                            (SingleAccountPageState.ofUserInfo(
                                          context,
                                        ).alias ==
                                        null ||
                                    SingleAccountPageState.ofUserInfo(
                                      context,
                                    ).alias!.isEmpty)
                                ? userName
                                : SingleAccountPageState.ofUserInfo(
                                  context,
                                ).alias!,
                            maxLines: 1,
                            style: TextStyle(
                              color:
                                  isCyber
                                      ? CyberColors.titleWhite
                                      : ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .titleColor(),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Obx(
                          () => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (poetData.isEmpty) return;
                              // 与官方一致：点击随机更换诗句，而非跳转详情页
                              loadPoet();
                            },
                            child: Text(
                              desc.value,
                              style: TextStyle(
                                color:
                                    isCyber
                                        ? CyberColors.descColor
                                        : AppleColors.textSecondary,
                                fontSize: isCyber ? 12 : 13,
                              ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFeatureButton(
                  title: "仪表盘",
                  imagePath: "assets/images/icon_c.png",
                  iconSize: 28,
                  fontSize: 15,
                  onTap: () {
                    Navigator.of(context).pushNamed(Routes.routeDashboard);
                  },
                ),
                _buildFeatureButton(
                  title:
                      getIt<SystemBean>(
                            instanceName:
                                (SingleAccountPageState.of(
                                          context,
                                        )?.index ??
                                        0)
                                    .toString(),
                          ).isUpperVersion2_13_0()
                          ? "订阅管理"
                          : "拉库管理",
                  imagePath: "assets/images/icon_subsctibe.png",
                  iconSize: 28,
                  fontSize: 15,
                  onTap: () {
                    if (getIt<SystemBean>(
                      instanceName:
                          (SingleAccountPageState.of(
                                    context,
                                  )?.index ??
                                  0)
                              .toString(),
                    ).isUpperVersion2_13_0()) {
                      Navigator.of(context).pushNamed(Routes.routeSubscribeList);
                    } else {
                      Navigator.of(context).push(
                        WallpaperPageRoute(
                          builder:
                              (context) => const TaskPage(
                                onlyShowPullRepo: true,
                              ),
                        ),
                      );
                    }
                  },
                ),
                _buildFeatureButton(
                  title: "脚本管理",
                  imagePath: "assets/images/icon_s.png",
                  iconSize: 28,
                  fontSize: 15,
                  onTap: () {
                    Navigator.of(context).pushNamed(Routes.routeScript);
                  },
                ),
                _buildFeatureButton(
                  title: "依赖管理",
                  imagePath: "assets/images/icon_d.png",
                  iconSize: 28,
                  fontSize: 15,
                  onTap: () {
                    Navigator.of(context).pushNamed(Routes.routeDependency);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// APP功能介绍卡片
  Widget _buildAppIntroCard() {
    return OtherPageCard(
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      onTap: () {
        Navigator.of(context)
            .push(
              WallpaperPageRoute(
                builder:
                    (context) =>
                        const InAppPurchasePage(fromDirectly: true),
              ),
            )
            .then((value) {
              setState(() {});
            });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Text(
              "APP功能介绍",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// 多帐号设置/第三方功能卡片
  Widget _buildMultiAccountCard() {
    return OtherPageCard(
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Text(
            "多帐号设置/第三方功能",
            style: TextStyle(
              fontWeight: FontWeight(ref.watch(textWeightProvider)),
              fontSize: 17,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
          const SizedBox(height: 10),
          // 功能按钮按内容宽度居中分布（spaceEvenly），字号缩放时随内容自然居中缩放，
          // 与「高级功能」卡片布局一致；避免固定宽度拉伸导致缩放右对齐不居中
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureButton(
                title: "多账号数",
                icon: CupertinoIcons.infinite,
                onTap: () {
                  if (SpUtil.getBool(
                    spSingleInstance,
                    defValue: false,
                  )) {
                    '请先进入 系统设置 关闭单实例模式'.toast();
                    return;
                  }
                  Navigator.of(context).push(
                    WallpaperPageRoute(
                      builder:
                          (context) => const UpdateMaxAccountPage(),
                    ),
                  );
                },
              ),
              _buildFeatureButton(
                title: "京东助手",
                icon: CupertinoIcons.gift,
                onTap: () {
                  Navigator.of(context).pushNamed(Routes.routeJdck);
                },
              ),
              _buildFeatureButton(
                title: "悬浮时间",
                icon: CupertinoIcons.clock,
                onTap: () async {
                  final started =
                      await FloatingClockService.toggleFloating();
                  if (!started) {
                    '请授予悬浮窗权限后再次点击'.toast();
                  } else {
                    '悬浮时钟已开启'.toast();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 高级功能卡片
  Widget _buildAdvancedCard() {
    return OtherPageCard(
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Text(
            "高级功能",
            style: TextStyle(
              fontWeight: FontWeight(ref.watch(textWeightProvider)),
              fontSize: 17,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureButton(
                title: "扫描依赖",
                icon: CupertinoIcons.doc_text_search,
                onTap: () {
                  Navigator.of(context).push(
                    WallpaperPageRoute(
                      builder: (context) => const ScanPage(),
                      blurSigma: 6,
                      blurTintColor: CyberColors.bg.withOpacity(0.50),
                    ),
                  );
                },
              ),
              _buildFeatureButton(
                title: "字体大小",
                icon: CupertinoIcons.textformat_size,
                onTap: () {
                  Navigator.of(context).push(
                    WallpaperPageRoute(
                      builder: (context) => const TextSizePage(),
                    ),
                  );
                },
              ),
              _buildFeatureButton(title: "文件备份", icon: CupertinoIcons.cloud_upload, onTap: () {
                Navigator.of(context).pushNamed(Routes.routeICloud);
              }),
              if (!SpUtil.getBool(spSingleInstance, defValue: false))
                _buildFeatureButton(title: "账号排序", icon: CupertinoIcons.arrow_swap, onTap: () {
                  Navigator.of(context).push(
                    WallpaperPageRoute(
                      builder: (context) => const SortAccountPage(),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// 基础功能卡片
  Widget _buildBasicCard() {
    return OtherPageCard(
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Text(
            "基础功能",
            style: TextStyle(
              fontWeight: FontWeight(ref.watch(textWeightProvider)),
              fontSize: 17,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureButton(
                title: "任务日志",
                icon: CupertinoIcons.square_stack_3d_down_right,
                onTap: () {
                  Navigator.of(context).pushNamed(Routes.routeTaskLog);
                },
              ),
              _buildFeatureButton(
                title: "登录日志",
                icon: CupertinoIcons.text_badge_checkmark,
                onTap: () {
                  if (SingleAccountPageState.ofUserInfo(
                    context,
                  ).useSecretLogined) {
                    "使用client_id方式登录无法获取登录日志".toast();
                  } else {
                    Navigator.of(context).pushNamed(Routes.routeLoginLog);
                  }
                },
              ),
              _buildFeatureButton(title: "应用设置", icon: CupertinoIcons.gear_alt, onTap: () {
                Navigator.of(context).push(
                  WallpaperPageRoute(
                    builder: (context) => const AppKeyPage(),
                  ),
                );
              }),
              _buildFeatureButton(title: "通知设置", icon: CupertinoIcons.envelope, onTap: () {
                Navigator.of(context).push(
                  WallpaperPageRoute(
                    builder: (context) => const PushSettingPage(),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureButton(title: "修改密码", icon: CupertinoIcons.lock_shield, onTap: () {
                if (SingleAccountPageState.ofUserInfo(
                  context,
                ).useSecretLogined) {
                  "使用client_id方式登录无法修改密码".toast();
                } else {
                  Navigator.of(context).push(
                    WallpaperPageRoute(
                      builder: (context) => const UpdatePasswordPage(),
                    ),
                  );
                }
              }),
              _buildFeatureButton(
                title: "日志设置",
                icon: CupertinoIcons.gobackward_30,
                onTap: () {
                  _delLog(context);
                },
              ),
              _buildFeatureButton(
                title: "系统设置",
                icon: CupertinoIcons.shield_lefthalf_fill,
                onTap: () {
                  Navigator.of(context).pushNamed(Routes.routeSetting);
                },
              ),
              _buildFeatureButton(title: "关于软件", icon: CupertinoIcons.info_circle, onTap: () {
                Navigator.of(context).pushNamed(Routes.routeAbout);
              }),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureButton(title: "壁纸设置", icon: CupertinoIcons.photo, onTap: () {
                Navigator.of(context).pushNamed(Routes.routeWallpaperSetting);
              }),
              _buildFeatureButton(title: "模糊调节", icon: CupertinoIcons.circle_grid_3x3, onTap: () {
                Navigator.of(context).push(
                  WallpaperPageRoute(
                    builder: (context) => const BlurSettingsPage(),
                  ),
                );
              }),
              _buildFeatureButton(title: "依赖设置", icon: CupertinoIcons.cube_box, onTap: () {
                Navigator.of(context).push(
                  WallpaperPageRoute(
                    builder: (context) => const DependencySettingPage(),
                  ),
                );
              }),
              _buildFeatureButton(title: "备份恢复", icon: CupertinoIcons.cloud_upload, onTap: () {
                Navigator.of(context).push(
                  WallpaperPageRoute(
                    builder: (context) => const BackupPage(),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _delLog(BuildContext context) async {
    final days = await showFrequencyDialog(
      context,
      title: '日志删除频率',
      initialValue: 30,
      maxValue: 1000,
      valueLoader: () async {
        var response = await SingleAccountPageState.ofApi(context).logDel();
        if (response.success) {
          final bean = response.bean;
          if (bean != null) {
            final freq = bean.info?.logRemoveFrequency ??
                bean.frequency ??
                bean.info?.frequency;
            if (freq != null) {
              return freq;
            }
          }
        }
        return null;
      },
    );
    if (days != null) {
      commitLogDel(days);
    }
  }

  void commitLogDel(int time) async {
    var response = await SingleAccountPageState.ofApi(context).logDelTime(time);
    if (response.success) {
      "修改成功".toast();
    } else {
      response.message?.toast();
    }
  }

  /// 统一功能按钮组件（支持图片或图标）
  /// 顶部4按钮用图片28x28+fontSize15，其余用图标24x24+fontSize16
  Widget _buildFeatureButton({
    required String title,
    required GestureTapCallback onTap,
    String? imagePath,
    IconData? icon,
    double iconSize = 24,
    double fontSize = 16,
  }) {
    final theme = ref.watch(themeProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null)
                Image.asset(imagePath, width: iconSize, height: iconSize, fit: BoxFit.contain)
              else
                Icon(icon, color: theme.primaryColor, size: iconSize),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  // 显式指定 MiSans：CupertinoButton 默认 DefaultTextStyle 为
                  // CupertinoSystemText(inherit:false)，不指定会回退系统字体导致字重映射异常（粗一级）
                  fontFamily: 'MiSans',
                  fontSize: fontSize,
                  fontWeight: _featureFw,
                  color: theme.themeColor.titleColor(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String getImageByVIPLogo() {
    return "assets/images/ql.png";
  }

  @override
  void onLazyLoad() async {
    var response = await SingleAccountPageState.ofApi(context).user();

    if (response.success) {
      userIcon = response.bean?.avatar;
      userName = response.bean?.username ?? "青龙客户端";
      if (userIcon != null && userIcon!.isNotEmpty) {
        userIcon =
            "${SingleAccountPageState.ofUserInfo(context).host}/api/static/$userIcon";
      }
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadPoet();
    });
  }

  void delLogsByExperiedDate() async {
    try {
      int before = SpUtil.getInt(
        spLocalBackUpFileExperiedTime,
        defValue: getDefaultLogExperiedTime(),
      );
      String now = DateFormat('yyyy-MM-dd').format(DateTime.now());

      Directory directory = Directory(
        "${await FileUtil(SingleAccountPageState.of(context)?.index ?? 0).localPath}/",
      );

      List<FileSystemEntity> list = directory.listSync();

      for (FileSystemEntity file in list) {
        String date = ints.basename(file.path);
        var a = DateTime.tryParse(date);
        var b = DateTime.tryParse(now);

        if (a != null && b != null) {
          if (b.difference(a).inDays > before) {
            if (await file.exists()) {
              await file.delete(recursive: true);
            }
          }
        }
      }
    } catch (e) {
      // 静默处理：日志清理失败不影响应用使用
    }
  }

  Future<void> loadPoet() async {
    try {
      Dio dio = Dio(
        BaseOptions(
          receiveTimeout: Duration(milliseconds: 10000),
          connectTimeout: Duration(milliseconds: 10000),
        ),
      );

      if (!SpUtil.haveKey(spPoetToken)) {
        var tokenResponse = await dio.get("https://v2.jinrishici.com/token");

        if (tokenResponse.statusCode == 200) {
          String? token = tokenResponse.data["data"];
          if (token != null && token.isNotEmpty) {
            SpUtil.putString(spPoetToken, token);
          }
        }
      }

      var response = await dio.get(
        "https://v2.jinrishici.com/one.json",
        options: Options(
          headers: {
            "X-User-Token": SpUtil.getString(spPoetToken, defValue: ""),
          },
        ),
      );
      if (response.statusCode == 200) {
        poetData.clear();
        poetData.addAll(response.data as Map<String, dynamic>);
        desc.value = poetData["data"]?["content"]?.toString() ?? "欢迎使用青龙客户端";
      }
    } catch (e) {}
  }
}

int getDefaultLogExperiedTime() {
  int count = 5;
  if (SpUtil.getInt(spVIP, defValue: typeNormal) == typeVIP) {
    count = 5;
  } else {
    count = 30;
  }
  return count;
}
