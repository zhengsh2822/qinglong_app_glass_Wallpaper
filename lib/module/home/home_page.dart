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
import 'package:qinglong_app/base/ui/spring_depth_page_track.dart';
import 'package:qinglong_app/base/cupertino_sheet.dart';
import 'package:qinglong_app/base/ui/glow_sheet.dart';
import 'package:qinglong_app/base/ui/spring_sheet.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/liquid_glass_shapes.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/base/ui/slidable_close_notifier.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_page.dart';
import 'package:qinglong_app/module/env/env_page.dart';
import 'package:qinglong_app/module/home/version_history_bean.dart';
import 'package:qinglong_app/module/others/other_page.dart';
import 'package:qinglong_app/module/others/about_page.dart';
import 'package:qinglong_app/module/task/task_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/login_helper.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../base/multi_account_userinfo_viewmodel.dart';
import '../../base/userinfo_viewmodel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  // 底部 tab 页面轨道：底部胶囊的 travel 弹簧是唯一物理源（连续页位置外发到
  // _navTravel），页面景深轨道直接跟随 —— 点击/连点打断/长按拖拽抓取全场景同步。
  // 惰性初始化：initial 值需读 provider，等首次 build 再建
  ValueNotifier<double>? _navTravel;

  @override
  void initState() {
    super.initState();
    SingleAccountPageState.of(context)?.registerICloud();
    SingleAccountPageState.of(
      context,
    )?.registerHttp(SingleAccountPageState.ofUserInfo(context).host!);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      getSystemBean(context);
    });
    // 主动提醒新版安装包：启动后延迟 5 秒检查一次 GitHub，
    // 同一 release 只提醒一次（检测到新包即写入 SP，下次启动不再重复）
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        AboutPage.checkGithubUpdate(context, autoRemind: true);
      }
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
    _navTravel?.dispose();
    MultiAccountPageState.clearAction();
    super.dispose();
  }

  /// 长按「我的」→ 账号切换弹层（与配置文件长按弹层同款组件，
  /// 弹簧动效/拖拽收起/取消胶囊由 showSpringSheet 内置）
  /// 弹层重入防抖：长按手势会触发两次 onLongTapItem（间隔 ~30ms，组件双报），
  /// 不防抖会压入两张叠着的弹层路由（翻两次才能关完）
  DateTime? _lastSheetAt;

  GlobalKey<TaskPageState> taskKey = GlobalKey();
  GlobalKey<EnvPageState> envKey = GlobalKey();
  GlobalKey<ConfigPageState> configKey = GlobalKey();
  GlobalKey<OtherPageState> meKey = GlobalKey();

  /// 底部导航双击回顶判定：记录上次点击的 tab 与时间
  int _lastNavTapIndex = -1;
  DateTime _lastNavTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 双击同一 tab（500ms 内第二次点击当前 tab）时回到该页顶部；
  /// 单击当前 tab 保持无动作，切换 tab 正常切页。
  void _onNavTapRepeated(int index) {
    final now = DateTime.now();
    final isDoubleTap =
        index == _lastNavTapIndex &&
        now.difference(_lastNavTapAt) < const Duration(milliseconds: 500);
    _lastNavTapIndex = index;
    _lastNavTapAt = now;
    if (!isDoubleTap) return;
    switch (index) {
      case 0:
        taskKey.currentState?.move2Top();
        break;
      case 1:
        envKey.currentState?.move2Top();
        break;
      case 2:
        configKey.currentState?.move2Top();
        break;
      case 3:
        meKey.currentState?.move2Top();
        break;
    }
  }

  /// 双击顶部状态栏区域：让当前激活 tab 页面回到顶部
  void _onStatusBarDoubleTap(int homeIndex) {
    switch (homeIndex) {
      case 0:
        taskKey.currentState?.move2Top();
        break;
      case 1:
        envKey.currentState?.move2Top();
        break;
      case 2:
        configKey.currentState?.move2Top();
        break;
      case 3:
        meKey.currentState?.move2Top();
        break;
    }
  }

  /// 长按「我的」→ 账号切换弹层（弹簧动效/拖拽收起由 showSpringSheet 内置）
  void _showAccountSheet() {
    final DateTime now = DateTime.now();
    if (_lastSheetAt != null &&
        now.difference(_lastSheetAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastSheetAt = now;
    HapticFeedback.mediumImpact();
    final viewModel = getIt<MultiAccountUserInfoViewModel>();
    final List<Widget> rows = [];

    if (SpUtil.getBool(spSingleInstance, defValue: false)) {
      // 单账号模式：历史账号重登（与当前面板相同的仅收起）+ 登录新账号
      final int count =
          SpUtil.getInt(spVIP, defValue: typeNormal) == typeVIP
              ? (viewModel.historyAccounts.length > 3
                  ? 3
                  : viewModel.historyAccounts.length)
              : viewModel.historyAccounts.length;
      for (int index = 0; index < count; index++) {
        final userInfo = viewModel.historyAccounts[index];
        rows.add(
          CupertinoSheer(
            title: (userInfo.host ?? "")
                .replaceAll("http://", "")
                .replaceAll("https://", ""),
            onTap: () {
              // 与当前面板相同：仅收起弹层
              if (SingleAccountPageState.ofHttp(context)?.host ==
                  userInfo.host) {
                return;
              }
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
          ),
        );
      }
      rows.add(
        CupertinoSheer(
          title: "登录新账号",
          onTap: () {
            Navigator.of(context).pushNamed(Routes.routeLogin, arguments: true);
          },
        ),
      );
    } else {
      // 多账号模式：账号切换 + 添加账户
      final int maxAccount = MultiAccountUserInfoViewModel.maxAccount;
      int count = viewModel.tokenBeans.length + 1;
      if (count > maxAccount) {
        count = maxAccount;
      }
      for (int index = 0; index < count; index++) {
        final bool isAddRow =
            index >= viewModel.tokenBeans.length ||
            (viewModel.tokenBeans.length < count && index == count - 1);
        if (isAddRow) {
          rows.add(
            CupertinoSheer(
              title: "添加账户",
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  context
                      .findAncestorStateOfType<MultiAccountPageState>()
                      ?.updateIndex(index);
                });
              },
            ),
          );
        } else {
          final userInfo = getIt<UserInfoViewModel>(
            instanceName: index.toString(),
          );
          rows.add(
            CupertinoSheer(
              title: (userInfo.host ?? "")
                  .replaceAll("http://", "")
                  .replaceAll("https://", ""),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  context
                      .findAncestorStateOfType<MultiAccountPageState>()
                      ?.updateIndex(index);
                });
              },
            ),
          );
        }
      }
    }

    // 单卡结构：取消行并入主卡（账号切换弹层不用"主卡+取消胶囊"两层式）
    showSpringSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GlowSheetContainer(
                isCyber: ref.read(themeProvider).themeMode == modeCyber,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DragHandle(
                      isCyber: ref.read(themeProvider).themeMode == modeCyber,
                    ),
                    ...rows.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final CupertinoSheer item = entry.value as CupertinoSheer;
                      return CupertinoSheer(
                        title: item.title,
                        onTap: item.onTap,
                        danger: item.danger,
                        showDivider: index != rows.length - 1,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int homeIndex = ref.watch<int>(
      SingleAccountPageState.ofHomeIndexProvider(context)(
        getProviderName(context),
      ),
    );
    // 惰性创建 travel 值（首次 build 时 provider 才可读）；胶囊弹簧是唯一驱动源，
    // provider 只改 selectedIndex → 胶囊弹簧 → 页面跟随，无需 ref.listen 驱动画
    _navTravel ??= ValueNotifier<double>(homeIndex.toDouble());
    // 底部导航"我的"按钮几何（与官方 LiquidGlassTabBar 的胶囊侧边距 16 +
    // itemPadding=3 保持一致），用于长按"我的"弹窗对齐悬浮"我的"位置
    final double screenW = MediaQuery.of(context).size.width;
    const double navSide = 16.0;
    const double navInnerPad = 3.0;
    return PopScope(
      canPop: true,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            RepaintBoundary(
              child: Scaffold(
                extendBody: true,
                // 弹簧景深整页切换（S1 纯盖上，主题版 release_110~112 验收方案）：
                // 页面位移跟随底部胶囊 travel 弹簧（同一物理，滑块与页面像素级同步）；
                // 进入页全尺寸盖上、离开页原样沉底被盖，零缩放/零变暗/零投影。
                // 页面保活：轨道惰性挂载后常驻（滚动位置不丢）；
                // 功耗：轨道内非当前页 TickerMode 自动关闭，静止时零动画重绘
                body: SpringDepthPageTrack(
                  position: _navTravel!,
                  current: homeIndex,
                  children: [
                    TaskPage(key: taskKey, loading: !getSystemBeanSuccess),
                    EnvPage(key: envKey),
                    ConfigPage(key: configKey),
                    OtherPage(key: meKey),
                  ],
                ),
              ),
            ),
            // 官方液态玻璃底部导航（withImpeller：双管道自包含，实时采样页面背景）
            _buildLiquidGlassNav(context, homeIndex),
            // 安卓双击状态栏区域回到顶部：
            // 沉浸式 edgeToEdge 下内容延伸到状态栏后方，此处放状态栏高度的
            // 透明双击层，双击即让当前激活 tab 页面回到顶部（仅拦截双击，
            // 高程位于最上层；单击不响应，不影响 AppBar 内按钮）。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).padding.top,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _onStatusBarDoubleTap(homeIndex),
                child: const SizedBox(width: double.infinity),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 官方液态玻璃底部导航（withImpeller 双管道：实时采样页面背景，
  /// morph pill 滑动 + 长按拖拽抓取 + 变形，移植自主题版已验证方案）
  Widget _buildLiquidGlassNav(BuildContext context, int homeIndex) {
    final theme = ref.watch(themeProvider);
    final double screenW = MediaQuery.of(context).size.width;
    final double barWidth = (screenW - 16 * 2).clamp(280.0, 560.0);
    // 选中色：主色（cyan）；未选中：壁纸反色次要文字（SP 自定义/壁纸反色）
    final activeColor = theme.primaryColor;
    final inactiveColor = theme.themeColor.title2Color();

    return LiquidGlassTabBar.withImpeller(
      items: _navItems,
      selectedIndex: homeIndex,
      onChanged: (index) async {
        final currentIdx = ref.read<int>(
          SingleAccountPageState.ofHomeIndexProvider(context)(
            getProviderName(context),
          ),
        );
        if (currentIdx == index) {
          // 点击当前 tab：双击判定（500ms 内第二次点击 → 回顶）
          _onNavTapRepeated(index);
          return;
        } else {
          // 切换 tab：重置双击记录，双击语义只针对"连续两次点击当前 tab"
          _lastNavTapIndex = -1;
          _lastNavTapAt = DateTime.fromMillisecondsSinceEpoch(0);
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
      width: barWidth,
      height: 60,
      itemPadding: 3,
      // 每帧外发胶囊连续位置 → 页面景深轨道跟随（滑块与页面同一物理）
      travelListenable: _navTravel,
      // 悬浮胶囊下边距 2（safe-area inset 由 withImpeller 内部自动加）
      margin: const EdgeInsets.only(bottom: 2),
      style: LiquidGlassStyle(
        // 壁纸版仅赛博模式：固定深色半透明胶囊 + 光学边框
        shape: cyberShape(30),
        appearance: const LiquidGlassAppearance(
          // 底色不透明度 0xB3(约70%)：壁纸版需适配大量背景元素，保证可读性又不过黑
          color: Color(0xB312121A), // 半透明深色（对齐主题版赛博结构，透出壁纸）
          // 模糊值 5→2：降低底部导航毛玻璃模糊（对齐主题版"液态玻璃曾试改2/3最终确定2"）
          blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
          shadow: LiquidGlassShadow(blur: 9, opacity: 0.2),
        ),
        refraction: const LiquidGlassRefraction(
          distortion: 0.06,
          distortionWidth: 26,
        ),
      ),
      itemStyle: LiquidGlassTabItemStyle(
        selectedColor: activeColor,
        unselectedColor: inactiveColor,
        iconSize: 24,
        labelFontSize: 10,
        iconLabelGap: 2,
        underGlassIconSize: 30,
        underGlassLabelFontSize: 10,
        selectedFontWeight: FontWeight.w700,
        unselectedFontWeight: FontWeight.w600,
      ),
      pillStyle: LiquidGlassTabPillStyle(
        mode: LiquidGlassPillMode.both,
        // travel 弹簧：统一弹簧规格，与弹窗卡片共用 SpringSheetSpec.open
        // （全局唯一，ζ≈0.74 过冲≈3%；页面景深轨道跟随此弹簧，天然同步）
        travelStiffness: SpringSheetSpec.open.stiffness,
        travelDamping: SpringSheetSpec.open.damping,
        rest: LiquidGlassStyle(
          shape: cyberShape(28),
          appearance: const LiquidGlassAppearance(
            // 选中 pill 统一浅灰微光，深色胶囊上可见（不再深色隐没）
            color: Color(0x2EAEAEB2),
          ),
        ),
      ),
      // 长按识别：其余 tab 默认 0.1s 抓取拖拽（放大镜跟随）；仅"我的"tab 覆盖为
      // 0.5s —— 满 0.5s 未滑动才弹账号窗，0.5s 内滑动位置仍走 Pan 抓取放大镜
      longPressDuration: const Duration(milliseconds: 100),
      longPressDurationByIndex: const {3: Duration(milliseconds: 500)},
      onLongTapItem: (i) {
        if (i == 3) {
          _showAccountSheet();
          return true;
        }
        return false;
      },
      // 按住胶囊直接左右滑动切换（无需长按等待，对齐 demo 手感）
      directDragSwitch: true,
      // q 弹（按压缩放）：按下导航栏区域整栏放大（胶囊+图标+文案），松开
      // easeOutBack 回弹；1.0256 = 放大量 0.0256（对齐主题版 demo 最终方案）
      pressScale: 1.0256,
    );
  }

  /// 底部导航项（图标与 demo 一致，随 active 着色 + 选中发光）
  static final List<LiquidGlassTabBarItem> _navItems = _buildNavItems();

  static List<LiquidGlassTabBarItem> _buildNavItems() {
    const labels = ['定时任务', '环境变量', '配置文件', '我的'];
    const icons = [
      (Icons.schedule_outlined, Icons.schedule),
      (Icons.settings_ethernet_outlined, Icons.settings_ethernet),
      (Icons.description_outlined, Icons.description),
      (Icons.person_outline, Icons.person),
    ];
    return List.generate(4, (i) {
      final (outlined, filled) = icons[i];
      return LiquidGlassTabBarItem(
        label: labels[i],
        iconBuilder:
            (context, g) => Icon(
              g.selected ? filled : outlined,
              size: g.underGlass == true ? 24 : 24,
              color: g.color,
              shadows:
                  g.selected
                      ? [
                        Shadow(
                          color: g.color.withValues(alpha: 0.85),
                          blurRadius: 14,
                        ),
                      ]
                      : null,
            ),
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
