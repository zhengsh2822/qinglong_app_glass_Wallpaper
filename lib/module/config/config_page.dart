import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/base_state_widget.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/card_transition_source.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/empty_widget.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/add_config_page.dart';
import 'package:qinglong_app/module/config/config_actions.dart';
import 'package:qinglong_app/module/config/config_bean.dart';
import 'package:qinglong_app/module/config/config_detail_page.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../home/home_page.dart';
import 'config_viewmodel.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({Key? key}) : super(key: key);

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends ConsumerState<ConfigPage>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  BuildContext? childContext;
  String? configContent;
  bool gotoConfigDetailed = false;
  final ScrollController _scrollController = ScrollController();

  /// 双击底部导航"配置"tab / 双击状态栏区域时回到列表顶部
  Future<void> move2Top() async {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 0) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadConfigData(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (MultiAccountPageState.actionEditConfig ==
          MultiAccountPageState.useAction()) {
        gotoConfigDetailed = false;
        loadConfigData(context);
      }
    }
  }

  Future<void> loadConfigData(BuildContext context) async {
    HttpResponse<String> result = await SingleAccountPageState.ofApi(
      context,
    ).content("config.sh");
    if (result.success && result.bean != null) {
      configContent = result.bean;

      if (MultiAccountPageState.actionEditConfig ==
              MultiAccountPageState.useAction() &&
          !gotoConfigDetailed) {
        gotoConfigDetailed = true;
        Navigator.of(context)
            .pushNamed(
              Routes.routeConfigEdit,
              arguments: {"title": "config.sh", "content": configContent},
            )
            .then((value) {
              loadConfigData(context);
            });
      }
    }
  }

  /// 重新拉取配置文件列表（删除成功后刷新；列表页 keepAlive 需主动刷新）
  void refreshConfigList() {
    ref
        .read(
          SingleAccountPageState.ofConfigProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .loadData(context, false);
  }

  /// 长按配置文件卡片 → 更多操作弹层（编辑/分享/下载/删除）
  ///
  /// 自带文件不显示删除项，仅自建文件可删；删除成功后刷新列表。
  void _showActions(BuildContext context, ConfigBean bean) {
    HapticFeedback.mediumImpact();
    showConfigActions(context, bean: bean, onDeleted: refreshConfigList);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return Scaffold(
      appBar: QlAppBar(
        canBack: false,
        title: "配置文件",
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context)
                  .push(
                    WallpaperPageRoute(
                      builder: (context) => const AddConfigPage(),
                    ),
                  )
                  .then((value) {
                    if (value != null && value == true) {
                      ref
                          .read(
                            SingleAccountPageState.ofConfigProvider(context)(
                              getProviderName(context),
                            ).notifier,
                          )
                          .loadData(context, false);
                    }
                  });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Icon(
                  CupertinoIcons.add,
                  size: 24,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ),
            ),
          ),
        ],
      ),
      body: BaseStateWidget<ConfigViewModel>(
        builder: (ref, model, child) {
          List<Widget> list = [];
          for (int i = 0; i < model.list.length; i++) {
            ConfigBean value = model.list[i];

            // 兜底删除用的锚点目录（青龙配置目录下的隐藏辅助目录）不展示给用户
            if (value.title == kConfigDeleteAnchor) continue;

            if (value.title?.toLowerCase() == "config.sh") {
              list.add(
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // 长按 → 配置文件更多操作（编辑/分享/下载/删除）
                  onLongPress: () => _showActions(context, value),
                  onDoubleTap: () {
                    Navigator.of(context)
                        .pushNamed(
                          Routes.routeConfigEdit,
                          arguments: {
                            "title": value.title,
                            "content": configContent,
                          },
                        )
                        .then((value) {
                          Future.delayed(const Duration(seconds: 1), () {
                            loadConfigData(context);
                          });
                        });
                  },
                  child: ConfigCell(bean: value, onDeleted: refreshConfigList),
                ),
              );
            } else {
              list.add(
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _showActions(context, value),
                  child: ConfigCell(bean: value, onDeleted: refreshConfigList),
                ),
              );
            }
          }

          final Widget content =
              model.list.isEmpty
                  ? const EmptyWidget()
                  : RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    onRefresh: () async {
                      await loadConfigData(context);
                      return model.loadData(context, false);
                    },
                    child: ListView(
                      controller: _scrollController,
                      primary: false,
                      padding: const EdgeInsets.only(
                        bottom: kBottomNavigationBarHeight + 50,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: list,
                    ),
                  );
          return isCyber ? CyberBackground(child: content) : content;
        },
        model: SingleAccountPageState.ofConfigProvider(context)(
          getProviderName(context),
        ),
        onReady: (viewModel) {
          viewModel.loadData(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ConfigCell extends ConsumerWidget {
  final ConfigBean bean;

  /// 详情页里删除成功返回 true 时回调（用于刷新列表）
  final VoidCallback? onDeleted;

  const ConfigCell({Key? key, required this.bean, this.onDeleted})
    : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;

    final Widget configContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              bean.title ?? "",
              maxLines: 1,
              style: TextStyle(
                overflow: TextOverflow.ellipsis,
                color:
                    isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
                fontSize: 17,
                fontWeight: isCyber ? null : FontWeight.w600,
                fontFamily: 'MiSans',
              ),
            ),
          ),
          Image.asset(
            "assets/images/icon_right.png",
            fit: BoxFit.cover,
            width: 18,
          ),
        ],
      ),
    );

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: isCyber ? 12 : AppleColors.spaceMd,
              vertical: 6,
            ),
            // 卡片共享展开：点击卡片 → 卡片隐藏 → 容器从卡片矩形展开详情页
            child: CardTransitionSource(
              child: OptimizedFrostedGlass(
                sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
                borderRadius: BorderRadius.circular(AppleColors.radiusCard),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppleColors.radiusCard),
                    // 单层描边：统一明显青色描边（cardStroke）
                    border: Border.all(color: CyberColors.cardStroke, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppleColors.radiusCard),
                    child: configContent,
                  ),
                ),
              ),
              sourceBuilder: (ctx) => configContent,
              pageBuilder: (context) => ConfigDetailPage(bean: bean),
              blurSigma: 6,
              blurTintColor: CyberColors.bg.withOpacity(0.50),
              onResult: (value) {
                // 详情页里删除成功会 pop(true)：回到列表时同步刷新
                if (value == true) onDeleted?.call();
              },
            ),
          ),
          isCyber ? const SizedBox.shrink() : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
