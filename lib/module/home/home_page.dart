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
import 'package:qinglong_app/base/ui/liquid_glass_shapes.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
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
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../base/multi_account_userinfo_viewmodel.dart';
import '../../base/userinfo_viewmodel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  // 底部 tab 页面控制器：与顶部 TabBar 同机制（PageView + animateToPage）
  // NeverScrollableScrollPhysics 禁手势，仅由底部 tab 点击驱动平滑滑动
  // 惰性初始化：initialPage 需读 provider，需等 build 有 context 后创建
  PageController? _pageController;

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
    _pageController?.dispose();
    MultiAccountPageState.clearAction();
    super.dispose();
  }

  bool showMask = false;

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

  @override
  Widget build(BuildContext context) {
    final int homeIndex = ref.watch<int>(
      SingleAccountPageState.ofHomeIndexProvider(context)(
        getProviderName(context),
      ),
    );
    // 惰性创建 PageController（首次 build 时 provider 才可读）
    final PageController pageController =
        _pageController ??= PageController(initialPage: homeIndex);
    // provider 为唯一数据源：底部 tab 点击/外部跳转改 index，统一驱动平滑滑动
    ref.listen<int>(
      SingleAccountPageState.ofHomeIndexProvider(context)(
        getProviderName(context),
      ),
      (previous, next) {
        if (!pageController.hasClients) return;
        if (pageController.page?.round() != next) {
          // 对齐顶部 GlassSegmentedTab 参数（300ms + easeOutCubic）：
          // 起步快、收尾缓，保证两处切换手感一致（easeInOutCubic 中间段慢、收尾拖沓）
          pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );
    // 底部导航"我的"按钮几何（与官方 LiquidGlassTabBar 的胶囊侧边距 16 +
    // itemPadding=3 保持一致），用于长按"我的"弹窗对齐悬浮"我的"位置
    final double screenW = MediaQuery.of(context).size.width;
    const double navSide = 16.0;
    const double navInnerPad = 3.0;
    final double navItemW = (screenW - navSide * 2 - navInnerPad * 2) / 4;
    final double meCenter = navSide + navInnerPad + 3.5 * navItemW;
    return PopScope(
      canPop: true,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            RepaintBoundary(
              child: Scaffold(
                extendBody: true,
                // 与顶部 TabBar 同机制：PageView 轨道式整页滑动切换
                // 页面保活见各页面 AutomaticKeepAliveClientMixin（滚动位置不丢）
                //
                // 功耗优化：TickerMode 包裹非当前 tab，切走后自动暂停该页
                // 全部动画 ticker（AnimationController/Slidable 弹簧等），
                // 静止时零动画重绘；TickerMode 不影响 paint，滑动切入时正常显示
                body: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    TickerMode(
                      enabled: homeIndex == 0,
                      child: TaskPage(key: taskKey, loading: !getSystemBeanSuccess),
                    ),
                    TickerMode(
                      enabled: homeIndex == 1,
                      child: EnvPage(key: envKey),
                    ),
                    TickerMode(
                      enabled: homeIndex == 2,
                      child: ConfigPage(key: configKey),
                    ),
                    TickerMode(
                      enabled: homeIndex == 3,
                      child: OtherPage(key: meKey),
                    ),
                  ],
                ),
              ),
            ),
            // 官方液态玻璃底部导航（withImpeller：双管道自包含，实时采样页面背景）
            _buildLiquidGlassNav(context, homeIndex),
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
              bottom: MediaQuery.of(context).viewPadding.bottom,
              child: Visibility(
                visible: showMask,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      // 右缘对齐"我的"按钮右缘，弹窗锚定在悬浮"我的"上
                      margin: EdgeInsets.only(
                        right: screenW - meCenter - navItemW / 2,
                      ),
                      width: MediaQuery.of(context).size.width / 2,
                      child: _buildOtherAccounts(),
                    ),
                    _buildOtherWidget(meCenter: meCenter),
                  ],
                ),
              ),
            ),
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
      // 切页流畅度优化：双管道默认每帧全分辨率采样整页背景（切页动画期间
      // 开销最大）。采样档位：0.5 略糊，1=官方原版全分辨率（观感最佳，
      // 用户选定；GPU 开销最大但配合纯色模式/刷新率低档可接受）。
      pixelRatio: 1,
      refreshRate: LiquidGlassRefreshRate.low,
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
      // 悬浮胶囊下边距 2（safe-area inset 由 withImpeller 内部自动加）
      margin: const EdgeInsets.only(bottom: 2),
      style: LiquidGlassStyle(
        // 壁纸版仅赛博模式：固定深色半透明胶囊 + 光学边框
        shape: cyberShape(30),
        appearance: const LiquidGlassAppearance(
          color: Color(0x8C12121A), // 深色半透明（对齐主题版赛博结构）
          blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
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
        rest: LiquidGlassStyle(
          shape: cyberShape(28),
          appearance: const LiquidGlassAppearance(
            // 选中 pill 统一浅灰微光，深色胶囊上可见（不再深色隐没）
            color: Color(0x2EAEAEB2),
          ),
        ),
      ),
      // 长按 500ms：我的弹窗（onLongTapItem 返回 true 消费长按，不拖拽 pill）；
      // 其他 tab 保留官方长按抓取拖拽（longPressDuration 同步为 500ms，与旧自研一致）
      longPressDuration: const Duration(milliseconds: 500),
      onLongTapItem: (i) {
        if (i == 3) {
          HapticFeedback.mediumImpact();
          setState(() => showMask = true);
          return true;
        }
        return false;
      },
      // 按住胶囊直接左右滑动切换（无需长按等待，对齐 demo 手感）
      directDragSwitch: true,
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
        iconBuilder: (context, g) => Icon(
          g.selected ? filled : outlined,
          size: g.underGlass == true ? 24 : 24,
          color: g.color,
          shadows: g.selected
              ? [Shadow(color: g.color.withValues(alpha: 0.85), blurRadius: 14)]
              : null,
        ),
      );
    });
  }

  Widget _buildOtherWidget({double? meCenter}) {
    if (!showMask) return const SizedBox.shrink();
    final double w = MediaQuery.of(context).size.width;
    final double cx = meCenter ?? w / 2;
    return SizedBox(
      width: w,
      height: kBottomNavigationBarHeight,
      child: Stack(
        children: [
          // "我的"指针：改用与底部导航一致的新图标，水平居中于悬浮"我的"按钮
          Positioned(
            left: cx - 20,
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Icon(Icons.person, size: 20, color: Colors.white),
                SizedBox(height: 2),
                Text(
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
    return OptimizedFrostedGlass(
      sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
      borderRadius: BorderRadius.circular(cardRadius),
      child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - kToolbarHeight * 2,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(cardRadius),
            // 边框对齐"我的"页面其他 GlassCard 卡片（cyber青微光 / 浅色浅灰）
            border: Border.all(
              color: isCyber ? CyberColors.borderGlow : AppleColors.cardBorder,
              width: 1,
            ),
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
