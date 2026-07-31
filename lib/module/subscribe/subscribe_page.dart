import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/base_state_widget.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/enable_widget.dart';
import 'package:qinglong_app/base/ui/running_widget.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/base/ui/slidable_close_notifier.dart';
import 'package:qinglong_app/module/subscribe/add_subscribe_page.dart';
import 'package:qinglong_app/module/task/intime_log/intime_subscribe_log_page.dart';
import 'package:qinglong_app/module/task/task_viewmodel.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import 'subscribe_viewmodel.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class SubscribePage extends ConsumerStatefulWidget {
  const SubscribePage({Key? key}) : super(key: key);

  @override
  _SubscribePageState createState() => _SubscribePageState();
}

class _SubscribePageState extends ConsumerState<SubscribePage> {
  TextEditingController searchText = TextEditingController();
  Timer? _searchDebounce;

  String currentState = TaskViewModel.allStr;
  ScrollController controller = ScrollController();

  bool buttonshow = false;

  /// Slidable 关闭信号值（用于生成 Key 重置卡片状态）
  int _slidableResetKey = 0;

  void scrollToTop() {
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(floatingButtonVisibility);
    searchText.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {});
      });
    });
    SlidableCloseNotifier.listenable.addListener(_onSlidableClose);
  }

  void _onSlidableClose() {
    setState(() {
      _slidableResetKey = SlidableCloseNotifier.value;
    });
  }

  void floatingButtonVisibility() {
    double y = controller.offset;
    if (y > MediaQuery.of(context).size.height / 2) {
      if (buttonshow == true) return;
      setState(() {
        buttonshow = true;
      });
    } else {
      if (buttonshow == false) return;
      setState(() {
        buttonshow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Visibility(
        visible: buttonshow,
        child: FloatingActionButton(
          mini: true,
          onPressed: () {
            scrollToTop();
          },
          elevation: 2,
          backgroundColor: isCyber ? CyberColors.cyan : Colors.white,
          child: Icon(
            CupertinoIcons.up_arrow,
            color: isCyber ? CyberColors.bg : Colors.black,
          ),
        ),
      ),
      appBar: QlAppBar(
        title: "订阅管理",
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context)
                  .push(
                    WallpaperPageRoute(
                      builder:
                          (context) => const AddSubscribePage(taskBean: {}),
                    ),
                  )
                  .then((value) {
                    if (value != null && value == true) {
                      ref
                          .read(
                            SingleAccountPageState.ofSubscribeProvider(context)(
                              getProviderName(context),
                            ),
                          )
                          .loadData(context);
                    }
                  });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Center(child: Icon(CupertinoIcons.add, size: 24)),
            ),
          ),
        ],
      ),
      body: BaseStateWidget<SubscribeViewModel>(
        builder: (ref, model, child) {
          return body(model, getListByType(model), ref);
        },
        model: SingleAccountPageState.ofSubscribeProvider(context)(
          getProviderName(context),
        ),
        lazyLoad: true,
        onReady: (viewModel) {
          viewModel.loadData(context);
        },
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  Widget body(
    SubscribeViewModel model,
    List<Map<String, dynamic>> list,
    WidgetRef ref,
  ) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return Column(
      children: [
        searchCell(ref),
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).primaryColor,
            onRefresh: () async {
              return model.loadData(context, false);
            },
            child: IconTheme(
              data: const IconThemeData(size: 25),
              child: SlidableAutoCloseBehavior(
                key: ValueKey('subscribe_slidable_${_slidableResetKey}'),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  controller: controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> item = list[index];
                    if (searchText.text.isEmpty ||
                        (item["name"]?.toLowerCase().contains(
                              searchText.text.toLowerCase(),
                            ) ??
                            false) ||
                        (item["url"]?.toLowerCase().contains(
                              searchText.text.toLowerCase(),
                            ) ??
                            false)) {
                      return TaskItemCell(item, ref);
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                  itemCount: list.length,
                  separatorBuilder: (BuildContext context, int index) {
                    Map<String, dynamic> item = list[index];
                    if (searchText.text.isEmpty ||
                        (item["name"]?.toLowerCase().contains(
                              searchText.text.toLowerCase(),
                            ) ??
                            false) ||
                        (item["url"]?.toLowerCase().contains(
                              searchText.text.toLowerCase(),
                            ) ??
                            false)) {
                      // 赛博模式：用 SizedBox 间距替代 Divider
                      if (isCyber) return const SizedBox(height: 12);
                      // Apple主题：卡片间距12px，无分割线
                      return const SizedBox(height: 12);
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget searchCell(WidgetRef context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SearchCell(controller: searchText),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    SlidableCloseNotifier.listenable.removeListener(_onSlidableClose);
    searchText.dispose();
    controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getListByType(SubscribeViewModel model) {
    return model.list.where((item) {
      if (searchText.text.isEmpty ||
          (item["name"]?.toLowerCase().contains(
                searchText.text.toLowerCase(),
              ) ??
              false) ||
          (item["url"]?.toLowerCase().contains(searchText.text.toLowerCase()) ??
              false)) {
        return true;
      } else {
        return false;
      }
    }).toList();
  }
}

class TaskItemCell extends StatelessWidget {
  final Map<String, dynamic> bean;
  final WidgetRef ref;

  const TaskItemCell(this.bean, this.ref, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (isCyber) {
      return _buildCyber(context);
    }
    return _buildNormal(context);
  }

  // 注意：_buildCyber 内部 Slidable 直接读 ref.themeProvider 获取 isCyber

  /// 赛博模式：Slidable + 赛博颜色（与非赛博模式结构一致）
  Widget _buildCyber(BuildContext context) {
    final bool isCyber = true; // build() 已判断为赛博模式
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Slidable(
          key: ValueKey(bean["id"] as int),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            // 3 按钮：等分 Pane 宽度（screen × 0.55 ≈ 198px ≈ 3×60+18）
            extentRatio: 0.55,
            children: [
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFF00F0FF) : AppColors.success,
                icon: CupertinoIcons.pencil_outline,
                label: '编辑',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  Navigator.of(context)
                      .push(
                        WallpaperPageRoute(
                          builder:
                              (context) => AddSubscribePage(taskBean: bean),
                        ),
                      )
                      .then((value) {
                        if (value != null && value == true) {
                          ref
                              .read(
                                SingleAccountPageState.ofSubscribeProvider(
                                  context,
                                )(getProviderName(context)),
                              )
                              .loadData(context);
                        }
                      });
                },
              ),
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFFA356D6) : AppColors.purple,
                icon:
                    (bean["is_disabled"] ?? 0) != 1
                        ? Icons.dnd_forwardslash
                        : Icons.check_circle_outline_sharp,
                label: (bean["is_disabled"] ?? 0) != 1 ? '禁用' : '启用',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then((value) {
                    _enableSubscribe(context, bean["is_disabled"] ?? 0);
                  });
                },
              ),
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFFFF3D5C) : AppColors.danger,
                icon: CupertinoIcons.delete,
                label: '删除',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then((value) {
                    _delSubscribe(context, ref);
                  });
                },
              ),
            ],
          ),
          startActionPane: ActionPane(
            motion: const ScrollMotion(),
            // 2 按钮：等分 Pane 宽度（screen × 0.4 = 144px）
            extentRatio: 0.4,
            children: [
              AppSlideButton(
                context: context,
                color: const Color(0xFFFFB800),
                icon:
                    bean["status"] == 1
                        ? CupertinoIcons.memories
                        : CupertinoIcons.stop_circle,
                label: bean["status"] == 1 ? '运行' : '停止',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  if (bean["status"] == 1) {
                    _startCron(context, ref, true);
                  } else {
                    _stopCron(context, ref);
                  }
                },
              ),
              AppSlideButton(
                context: context,
                color: const Color(0xFF00FF94),
                icon: CupertinoIcons.text_justifyleft,
                label: '日志',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  Future.delayed(const Duration(milliseconds: 250), () {
                    logCron(context, ref);
                  });
                },
              ),
            ],
          ),
          child: _buildCardChild(context, isCyber: true),
        ),
      ),
    );
  }

  /// 非赛博模式：保留原 Slidable 实现
  Widget _buildNormal(BuildContext context) {
    final bool isCyber = false; // build() 已判断为非赛博模式
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppleColors.radiusCard),
        border: Border.all(color: AppleColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppleColors.radiusCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10), sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10)),
          child: Slidable(
            key: ValueKey(bean["id"] as int),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.55,
            children: [
              AppSlideButton(
                context: context,
                color: const Color(0xff5D5E70),
                icon: CupertinoIcons.pencil_outline,
                label: '编辑',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  Navigator.of(context)
                      .push(
                        WallpaperPageRoute(
                          builder:
                              (context) => AddSubscribePage(taskBean: bean),
                        ),
                      )
                      .then((value) {
                        if (value != null && value == true) {
                          ref
                              .read(
                                SingleAccountPageState.ofSubscribeProvider(
                                  context,
                                )(getProviderName(context)),
                              )
                              .loadData(context);
                        }
                      });
                },
              ),
              AppSlideButton(
                context: context,
                color: const Color(0xffA356D6),
                icon:
                    (bean["is_disabled"] ?? 0) != 1
                        ? Icons.dnd_forwardslash
                        : Icons.check_circle_outline_sharp,
                label: (bean["is_disabled"] ?? 0) != 1 ? '禁用' : '启用',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then((value) {
                    _enableSubscribe(context, bean["is_disabled"] ?? 0);
                  });
                },
              ),
              AppSlideButton(
                context: context,
                color: const Color(0xffEA4D3E),
                icon: CupertinoIcons.delete,
                label: '删除',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then((value) {
                    _delSubscribe(context, ref);
                  });
                },
              ),
            ],
          ),
          startActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.4,
            children: [
              AppSlideButton(
                context: context,
                color: const Color(0xffD25535),
                icon:
                    bean["status"] == 1
                        ? CupertinoIcons.memories
                        : CupertinoIcons.stop_circle,
                label: bean["status"] == 1 ? '运行' : '停止',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  if (bean["status"] == 1) {
                    _startCron(context, ref, true);
                  } else {
                    _stopCron(context, ref);
                  }
                },
              ),
              AppSlideButton(
                context: context,
                color: const Color(0xff606467),
                icon: CupertinoIcons.text_justifyleft,
                label: '日志',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  Future.delayed(const Duration(milliseconds: 250), () {
                    logCron(context, ref);
                  });
                },
              ),
            ],
          ),
          child: _buildCardChild(context, isCyber: false),
        ),
        ),
      ),
    );
  }

  /// 卡片主体内容（赛博/非赛博共用）
  Widget _buildCardChild(BuildContext context, {required bool isCyber}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(Routes.routeSubscribeDetail, arguments: bean);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10), sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10)),
            child: Container(
              width: MediaQuery.of(context).size.width,
              decoration:
                  isCyber
                      ? BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CyberColors.borderGlow,
                          width: 1,
                        ),
                      )
                      : null,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints.loose(
                                Size.fromWidth(
                                  MediaQuery.of(context).size.width / 2,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  bean["name"] ?? "",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    color:
                                        isCyber
                                            ? CyberColors.titleWhite
                                            : ref
                                                .watch(themeProvider)
                                                .themeColor
                                                .titleColor(),
                                    fontSize: 16,
                                    fontFamily:
                                        isCyber ? CyberColors.monoFont : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            bean["status"] == 0
                                ? const RunningWidget()
                                : const SizedBox.shrink(),
                            const SizedBox(width: 7),
                            (bean["is_disabled"] ?? 0) == 1
                                ? const StatusWidget(
                                  title: "已禁用",
                                  color: Color(0xffFB5858),
                                )
                                : const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      bean["schedule"] ?? "",
                      maxLines: 1,
                      style: TextStyle(
                        overflow: TextOverflow.ellipsis,
                        color:
                            isCyber
                                ? CyberColors.cyan.withValues(alpha: 0.7)
                                : ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor(),
                        fontSize: 12,
                        fontFamily: isCyber ? CyberColors.monoFont : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      bean["url"] ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        overflow: TextOverflow.ellipsis,
                        color:
                            isCyber
                                ? CyberColors.descColor
                                : ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor(),
                        fontSize: 12,
                        fontFamily: isCyber ? CyberColors.monoFont : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _startCron(BuildContext context, WidgetRef ref, bool showLog) async {
    await ref
        .read(
          SingleAccountPageState.ofSubscribeProvider(context)(
            getProviderName(context),
          ),
        )
        .runCrons(context, bean["id"]);
    if (showLog) {
      Future.delayed(const Duration(milliseconds: 250), () {
        logCron(context, ref);
      });
    }
  }

  _stopCron(BuildContext context, WidgetRef ref) {
    ref
        .read(
          SingleAccountPageState.ofSubscribeProvider(context)(
            getProviderName(context),
          ),
        )
        .stopCrons(context, bean["id"]);
  }

  logCron(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      WallpaperPageRoute(
        builder:
            (context) =>
                InTimeSubscribeLogPage(bean["id"], true, bean["name"] ?? ""),
      ),
    );
  }

  void _delSubscribe(BuildContext context1, WidgetRef ref) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (isCyber) {
      showCyberConfirmDialog(
        context1,
        title: '确认删除',
        content: '确认删除订阅 ${bean["name"] ?? ""} 吗',
        danger: true,
      ).then((confirmed) {
        if (confirmed == true) {
          ref
              .read(
                SingleAccountPageState.ofSubscribeProvider(context1)(
                  getProviderName(context1),
                ),
              )
              .delSubscribe(context1, bean["id"]);
        }
      });
      return;
    }
    showCupertinoDialog(
      context: context1,
      useRootNavigator: false,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text("确认删除"),
            content: Text("确认删除订阅 ${bean["name"] ?? ""} 吗"),
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
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(
                        SingleAccountPageState.ofSubscribeProvider(context1)(
                          getProviderName(context1),
                        ),
                      )
                      .delSubscribe(context1, bean["id"]);
                },
              ),
            ],
          ),
    );
  }

  void _enableSubscribe(BuildContext context, int disabled) {
    ref
        .read(
          SingleAccountPageState.ofSubscribeProvider(context)(
            getProviderName(context),
          ),
        )
        .enableSubscribe(context, bean["id"], disabled);
  }
}
