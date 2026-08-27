import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/base_state_widget.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_segmented_tab.dart';
import 'package:qinglong_app/base/ui/glow_card.dart';
import 'package:qinglong_app/base/ui/animated_edit_mode_overlay.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slidable.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/base/ui/slidable_close_notifier.dart';
import 'package:qinglong_app/module/task/add_task_page.dart';
import 'package:qinglong_app/module/task/intime_log/intime_log_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/module/task/task_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../../base/ui/notify.dart';
import '../../main.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class TaskPage extends ConsumerStatefulWidget {
  final bool loading;
  final bool onlyShowPullRepo;

  const TaskPage({
    Key? key,
    this.loading = false,
    this.onlyShowPullRepo = false,
  }) : super(key: key);

  @override
  TaskPageState createState() => TaskPageState();
}

class TaskPageState extends ConsumerState<TaskPage>
    with TickerProviderStateMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  TextEditingController searchText = TextEditingController();
  Timer? _searchDebounce;

  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();

  bool editMode = false;
  Set<String> checkedIds = <String>{};

  GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

  /// Slidable 关闭信号值（用于生成 Key 重置卡片状态）
  int _slidableResetKey = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref
          .read(
            SingleAccountPageState.ofTaskProvider(context)(
              getProviderName(context),
            ).notifier,
          )
          .loadData(context);
      if (MultiAccountPageState.actionRunAll ==
          MultiAccountPageState.useAction()) {
        ref
            .read(
              SingleAccountPageState.ofTaskProvider(context)(
                getProviderName(context),
              ).notifier,
            )
            .runAllTasked = false;
        ref
            .read(
              SingleAccountPageState.ofTaskProvider(context)(
                getProviderName(context),
              ).notifier,
            )
            .runAllTasks(context);
      }
    } else if (state == AppLifecycleState.inactive) {}
  }

  Future<void> scrollToTop() async {
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

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

  @override
  void initState() {
    _tabController = TabController(length: 4, vsync: this);
    _tabController!.addListener(_onInnerTabChanged);
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    searchText.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {});
      });
    });
    // 监听全局 tab 切换信号，重置 Slidable 状态
    SlidableCloseNotifier.listenable.addListener(_onSlidableClose);
  }

  int _lastInnerTabIndex = 0;
  void _onInnerTabChanged() {
    // 仅在 tab 动画结束后再重置 Slidable 状态，避免在动画过程中重建
    // TabBarView 导致的页面切换动画被中断（页面瞬间切换，没有滑动效果）
    if (_tabController!.index != _lastInnerTabIndex &&
        !_tabController!.indexIsChanging) {
      _lastInnerTabIndex = _tabController!.index;
      setState(() {
        _slidableResetKey++;
      });
    }
  }

  void _onSlidableClose() {
    setState(() {
      _slidableResetKey = SlidableCloseNotifier.value;
    });
  }

  double searchCellHeight = 55;

  SliverAppBar _buildAppBar(WidgetRef ref, TaskViewModel model) {
    return SliverAppBar(
      pinned: false,
      floating: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      snap: false,
      primary: false,
      toolbarHeight: searchCellHeight,
      flexibleSpace: searchCell(ref, model),
    );
  }

  List<TaskBean> getListByType(int index) {
    var model = ref.read(
      SingleAccountPageState.ofTaskProvider(context)(
        getProviderName(context),
      ).notifier,
    );
    if (index == 0) {
      return model.list;
    } else if (index == 1) {
      return model.running;
    } else if (index == 2) {
      return model.neverRunning;
    } else if (index == 3) {
      return model.disabled;
    }
    return model.list;
  }

  List<String> lastRunningTaskIds = [];
  List<String> runningTaskIds = [];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (widget.onlyShowPullRepo) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          appBar: QlAppBar(
            title: "拉库管理",
            canClick2Vip: !editMode,
            actions: [
              CupertinoButton(
                color: Colors.transparent,
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        WallpaperPageRoute(
                          builder:
                              (context) =>
                                  const AddTaskPage(hideUploadFile: false),
                        ),
                      )
                      .then((value) {
                        ref
                            .read(
                              SingleAccountPageState.ofTaskProvider(context)(
                                getProviderName(context),
                              ).notifier,
                            )
                            .loadData(context, false);
                      });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Center(
                    child:
                        editMode
                            ? Text(
                              checkedIds.length ==
                                      getListByType(
                                        _tabController?.index ?? 0,
                                      ).where((item) {
                                        if (searchText.text.isEmpty ||
                                            (item.name?.toLowerCase().contains(
                                                  searchText.text.toLowerCase(),
                                                ) ??
                                                false) ||
                                            (item.command
                                                    ?.toLowerCase()
                                                    .contains(
                                                      searchText.text
                                                          .toLowerCase(),
                                                    ) ??
                                                false) ||
                                            (item.schedule?.contains(
                                                  searchText.text.toLowerCase(),
                                                ) ??
                                                false)) {
                                          return true;
                                        }
                                        return false;
                                      }).length
                                  ? "全不选"
                                  : "全选",
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    Theme.of(
                                      context,
                                    ).appBarTheme.iconTheme?.color,
                              ),
                            )
                            : Icon(
                              CupertinoIcons.add,
                              size: 24,
                              color:
                                  Theme.of(
                                    context,
                                  ).appBarTheme.iconTheme?.color,
                            ),
                  ),
                ),
              ),
            ],
          ),
          body: BaseStateWidget<TaskViewModel>(
              builder: (ref, model, child) {
                return IconTheme(
                  data: const IconThemeData(size: 25),
                  child: NestedScrollView(
                    controller: _scrollController,
                    headerSliverBuilder: (
                      BuildContext context,
                      bool innerBoxIsScrolled,
                    ) {
                      return [_buildAppBar(ref, model)];
                    },
                    body: RefreshIndicator(
                      key: refreshKey,
                      color: Theme.of(context).primaryColor,
                      notificationPredicate: (_) => true,
                      onRefresh: () async {
                        return await model.loadData(context, false);
                      },
                      child: SlidableAutoCloseBehavior(
                        key: ValueKey('task_slidable_${_slidableResetKey}'),
                        child: body(model, model.notScripts, ref, true),
                      ),
                    ),
                  ),
                );
              },
              model: SingleAccountPageState.ofTaskProvider(context)(
                getProviderName(context),
              ),
              onReady: (viewModel) {
                viewModel.loadData(context);
              },
            ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        appBar: QlAppBar(
          title:
              (editMode && checkedIds.isNotEmpty)
                  ? "当前选中 ${checkedIds.length} 个任务"
                  : "定时任务",
          canClick2Vip: !editMode,
          backWidget: Builder(
            builder: (context) {
              return CupertinoButton(
                color: Colors.transparent,
                padding: EdgeInsets.zero,
                onPressed: () {
                  checkedIds.clear();
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    if (editMode) {
                      showOverlay(context);
                    } else {
                      removeOverlay();
                    }
                  });
                  editMode = !editMode;
                  // if (editMode) {
                  //   searchText.text = "";
                  // }
                  setState(() {});
                },
                child: Center(
                  child: Text(
                    editMode == true ? "完成" : "编辑",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).appBarTheme.iconTheme?.color,
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            CupertinoButton(
              color: Colors.transparent,
              padding: EdgeInsets.zero,
              onPressed: () {
                if (editMode) {
                  if (checkedIds.length ==
                      getListByType(_tabController?.index ?? 0).where((item) {
                        if (searchText.text.isEmpty ||
                            (item.name?.toLowerCase().contains(
                                  searchText.text.toLowerCase(),
                                ) ??
                                false) ||
                            (item.command?.toLowerCase().contains(
                                  searchText.text.toLowerCase(),
                                ) ??
                                false) ||
                            (item.schedule?.contains(
                                  searchText.text.toLowerCase(),
                                ) ??
                                false)) {
                          return true;
                        }
                        return false;
                      }).length) {
                    //全不选
                    checkedIds.clear();
                    setState(() {});
                  } else {
                    //全选
                    checkedIds.clear();
                    checkedIds.addAll(
                      getListByType(_tabController?.index ?? 0)
                          .where((item) {
                            if (searchText.text.isEmpty ||
                                (item.name?.toLowerCase().contains(
                                      searchText.text.toLowerCase(),
                                    ) ??
                                    false) ||
                                (item.command?.toLowerCase().contains(
                                      searchText.text.toLowerCase(),
                                    ) ??
                                    false) ||
                                (item.schedule?.contains(
                                      searchText.text.toLowerCase(),
                                    ) ??
                                    false)) {
                              return true;
                            }
                            return false;
                          })
                          .map((e) => e.sId ?? "")
                          .toList(),
                    );
                    setState(() {});
                  }
                  return;
                }

                Navigator.of(context)
                    .push(
                      WallpaperPageRoute(
                        builder:
                            (context) =>
                                const AddTaskPage(hideUploadFile: false),
                      ),
                    )
                    .then((value) {
                      ref
                          .read(
                            SingleAccountPageState.ofTaskProvider(context)(
                              getProviderName(context),
                            ).notifier,
                          )
                          .loadData(context, false);
                    });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Center(
                  child:
                      editMode
                          ? Text(
                            checkedIds.length ==
                                    getListByType(
                                      _tabController?.index ?? 0,
                                    ).where((item) {
                                      if (searchText.text.isEmpty ||
                                          (item.name?.toLowerCase().contains(
                                                searchText.text.toLowerCase(),
                                              ) ??
                                              false) ||
                                          (item.command?.toLowerCase().contains(
                                                searchText.text.toLowerCase(),
                                              ) ??
                                              false) ||
                                          (item.schedule?.contains(
                                                searchText.text.toLowerCase(),
                                              ) ??
                                              false)) {
                                        return true;
                                      }
                                      return false;
                                    }).length
                                ? "全不选"
                                : "全选",
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Theme.of(
                                    context,
                                  ).appBarTheme.iconTheme?.color,
                            ),
                          )
                          : Icon(
                            CupertinoIcons.add,
                            size: 24,
                            color:
                                Theme.of(context).appBarTheme.iconTheme?.color,
                          ),
                ),
              ),
            ),
          ],
        ),
        body: () {
            final Widget taskBody =
                widget.loading
                    ? const Center(child: LoadingWidget())
                    : BaseStateWidget<TaskViewModel>(
                      builder: (ref, model, child) {
                        return IconTheme(
                          data: const IconThemeData(size: 25),
                          child: NestedScrollView(
                            controller: _scrollController,
                            headerSliverBuilder: (
                              BuildContext context,
                              bool innerBoxIsScrolled,
                            ) {
                              return [
                                _buildAppBar(ref, model),
                                SliverOverlapAbsorber(
                                  handle:
                                      NestedScrollView.sliverOverlapAbsorberHandleFor(
                                        context,
                                      ),
                                  sliver: SliverPersistentHeader(
                                    pinned: true,
                                    floating: false,
                                    delegate: GlassSegmentedTabDelegate(
                                      tabs: [
                                        TaskViewModel.allStr,
                                        TaskViewModel.runningStr,
                                        TaskViewModel.neverStr,
                                        TaskViewModel.disableStr,
                                      ],
                                      tabController: _tabController!,
                                      editMode: editMode,
                                    ),
                                  ),
                                ),
                              ];
                            },
                            body: RefreshIndicator(
                              key: refreshKey,
                              edgeOffset: 15,
                              color: Theme.of(context).primaryColor,
                              notificationPredicate: (_) => true,
                              onRefresh: () async {
                                return await model.loadData(context, false);
                              },
                              child: SlidableAutoCloseBehavior(
                                key: ValueKey(
                                  'task_tab_slidable_${_slidableResetKey}',
                                ),
                                child: TabBarView(
                                  controller: _tabController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    body(model, model.list, ref, true),
                                    body(model, model.running, ref, false),
                                    body(model, model.neverRunning, ref, false),
                                    body(model, model.disabled, ref, false),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      model: SingleAccountPageState.ofTaskProvider(context)(
                        getProviderName(context),
                      ),
                      onReady: (viewModel) {
                        viewModel.loadData(context);
                      },
                    );
            return isCyber ? CyberBackground(child: taskBody) : taskBody;
          }(),
      ),
    );
  }

  Widget body(
    TaskViewModel model,
    List<TaskBean> list,
    WidgetRef ref,
    bool needController,
  ) {
    return LayoutBuilder(
      builder: (context, c) {
        return SizedBox(
          height: c.maxHeight,
          child: ListBodyWidget(
            model: model,
            list: list,
            searchText: searchText.text,
            editMode: editMode,
            checked: checkedIds,
            onlyShowPullRepo: widget.onlyShowPullRepo,
            changed: (id) {
              if (checkedIds.contains(id)) {
                checkedIds.remove(id);
              } else {
                checkedIds.add(id);
              }
              setState(() {});
            },
          ),
        );
      },
    );
  }

  Widget searchCell(WidgetRef context, TaskViewModel model) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
      height: searchCellHeight.toDouble(),
      child: SearchCell(controller: searchText),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController?.removeListener(_onInnerTabChanged);
    SlidableCloseNotifier.listenable.removeListener(_onSlidableClose);
    WidgetsBinding.instance.removeObserver(this);
    _editModeOverlay?.dispose();
    searchText.dispose();
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  AnimatedEditModeOverlay? _editModeOverlay;

  void showOverlay(BuildContext context) {
    // 已存在则继续进场（打断退场），否则创建新 overlay
    if (_editModeOverlay != null) {
      _editModeOverlay!.show();
      return;
    }
    _editModeOverlay = AnimatedEditModeOverlay(
      context: context,
      backgroundColorBuilder: (ref) =>
          ref
              .read(themeProvider)
              .currentTheme
              .bottomNavigationBarTheme
              .backgroundColor
              ?.withOpacity(1) ??
          Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
          Colors.black,
      builder: (BuildContext context) {
        return SizedBox(
          height: kBottomNavigationBarHeight,
          child: SingleChildScrollView(
            primary: true,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 15),
                EditModeButton(
                  "运行",
                  icon: CupertinoIcons.memories,
                  color: CyberColors.cyan,
                  onTap: () {
                    _executeCode(context, "运行");
                  },
                ),
                EditModeButton(
                  "停止",
                  icon: CupertinoIcons.stop_circle,
                  color: CyberColors.neonYellow,
                  onTap: () {
                    _executeCode(context, "停止");
                  },
                ),
                EditModeButton(
                  "启用",
                  icon: Icons.check_circle_outline_sharp,
                  color: CyberColors.neonGreen,
                  onTap: () {
                    _executeCode(context, "启用");
                  },
                ),
                EditModeButton(
                  "禁用",
                  icon: Icons.dnd_forwardslash,
                  color: CyberColors.cyan,
                  onTap: () {
                    _executeCode(context, "禁用");
                  },
                ),
                EditModeButton(
                  "置顶",
                  icon: CupertinoIcons.pin,
                  color: CyberColors.cyan,
                  onTap: () {
                    _executeCode(context, "置顶");
                  },
                ),
                EditModeButton(
                  "取消置顶",
                  icon: CupertinoIcons.pin_slash,
                  color: CyberColors.cyan,
                  onTap: () {
                    _executeCode(context, "取消置顶");
                  },
                ),
                EditModeButton(
                  "删除",
                  icon: CupertinoIcons.delete,
                  color: CyberColors.neonRed,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _executeCode(context, "删除");
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    _editModeOverlay!.show();
  }

  void removeOverlay() {
    _editModeOverlay?.hide();
  }

  void _executeCode(BuildContext context, String s) async {
    if (checkedIds.isEmpty) {
      "至少选择1个任务".toast();
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: "确认$s",
      content: "确认$s吗",
      confirmLabel: "确定",
      danger: s == "删除",
    );
    if (confirmed != true) return;
    editMode = false;
    removeOverlay();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (s == "运行") {
        runTasks();
      } else if (s == "停止") {
        stopTasks();
      } else if (s == "置顶") {
        pinTasks();
      } else if (s == "取消置顶") {
        unPinTasks();
      } else if (s == "启用") {
        enableTask();
      } else if (s == "禁用") {
        disableTasks();
      } else if (s == "删除") {
        deleteTasks();
      }
    });
    setState(() {});
  }

  void runTasks() {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .runCrons(context, checkedIds.toList());
  }

  void deleteTasks() {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .delCron(context, checkedIds.toList());
  }

  void disableTasks() {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .enableTask(context, checkedIds.toList(), 0);
  }

  void enableTask() {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .enableTask(context, checkedIds.toList(), 1);
  }

  void unPinTasks() {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .pinTask(context, checkedIds.toList(), 1);
  }

  void pinTasks() {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .pinTask(context, checkedIds.toList(), 0);
  }

  void stopTasks() {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .stopCrons(context, checkedIds.toList());
  }

  Notify? notify;

  void show(
    BuildContext context,
    String title,
    String name,
    String cronId,
    String command,
  ) {
    notify = Notify();
    notify!.show(
      context,
      view(context, "\"$title\"已结束", name, cronId, command, "点击查看具体日志"),
      topOffset: MediaQuery.of(context).viewPadding.top + 10,
      keepDuration: 3000,
    );
  }

  Widget view(
    BuildContext context,
    String title,
    String name,
    String cronId,
    String command,
    String? desc,
  ) {
    return GestureDetector(
      onTap: () {
        if (notify != null && notify!.isShown()) {
          notify?.dismiss(true);
        }

        Navigator.of(context).push(
          WallpaperPageRoute(
            blurSigma: 6,
            blurTintColor: CyberColors.bg.withOpacity(0.50),
            builder:
                (context) =>
                    InTimeLogPage(cronId, false, name, command: command),
          ),
        );
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Container(
          padding: const EdgeInsets.only(left: 15, top: 5, bottom: 5),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: ref.watch(themeProvider).themeColor.blackAndWhite(),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.asset("assets/images/ql.png", height: 45),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ref.watch(themeProvider).themeColor.titleColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Visibility(
                      visible: desc != null && desc.isNotEmpty,
                      child: Text(
                        desc ?? "",
                        style: TextStyle(
                          color:
                              ref.watch(themeProvider).themeColor.descColor(),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListBodyWidget extends ConsumerStatefulWidget {
  final TaskViewModel model;
  final List<TaskBean> list;
  final String searchText;
  final bool editMode;
  final Set<String> checked;
  final ValueChanged<String> changed;
  final bool onlyShowPullRepo;

  const ListBodyWidget({
    Key? key,
    required this.model,
    required this.list,
    required this.searchText,
    required this.editMode,
    required this.checked,
    required this.changed,
    required this.onlyShowPullRepo,
  }) : super(key: key);

  @override
  ConsumerState<ListBodyWidget> createState() => _ListBodyState();
}

class _ListBodyState extends ConsumerState<ListBodyWidget>
    with AutomaticKeepAliveClientMixin {
  bool _matchSearch(TaskBean item, String lowerSearch) {
    if (lowerSearch.isEmpty) return true;
    return (item.name?.toLowerCase().contains(lowerSearch) ?? false) ||
        (item.command?.toLowerCase().contains(lowerSearch) ?? false) ||
        (item.schedule?.toLowerCase().contains(lowerSearch) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lowerSearch = widget.searchText.toLowerCase();
    // 预过滤列表，避免为不匹配项构建 SizedBox.shrink 浪费资源
    final filteredList = lowerSearch.isEmpty
        ? widget.list
        : widget.list.where((item) => _matchSearch(item, lowerSearch)).toList();
    return ListView.separated(
      padding: EdgeInsets.only(
        bottom: kBottomNavigationBarHeight + 50,
        top: widget.onlyShowPullRepo ? 0 : 67,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemBuilder: (context, index) {
        TaskBean item = filteredList[index];
        return TaskItemCell(
          item,
          ref,
          editMode: widget.editMode,
          checkedCallback: (id) {
            widget.changed(id);
          },
          checked: widget.checked.contains(item.sId),
        );
      },
      itemCount: filteredList.length,
      separatorBuilder: (BuildContext context, int index) {
        // 卡片间距12px，不用分割线
        return const SizedBox(height: 12);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TaskItemCell extends StatelessWidget {
  final TaskBean bean;
  final WidgetRef ref;
  final bool editMode;
  final bool checked;
  final ValueChanged<String> checkedCallback;

  const TaskItemCell(
    this.bean,
    this.ref, {
    Key? key,
    this.editMode = false,
    required this.checkedCallback,
    required this.checked,
  }) : super(key: key);

  bool get isCyber => ref.read(themeProvider).themeMode == modeCyber;

  @override
  Widget build(BuildContext context) {
    // 【使用示例】赛博模式使用 CyberSlidable 统一组件
    // 左滑4个按钮（endActions）：编辑/置顶/禁用/删除
    // 右滑2个按钮（startActions）：运行停止/日志
    if (isCyber) {
      // 复用 CyberSlidable 组件（与 appkey_page/change_account_page 一致），
      // 它的 CustomSlidableAction 用 Material elevation 渲染赛博按钮光晕，
      // 配合主卡片 BackdropFilter 形成"光折射到主卡片"效果
      return CapsuleGlowCard(
        frost: false,
        isPinned: bean.isPinned == 1,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: CyberSlidable(
          slidableKey: ValueKey(bean.sId),
          enabled: !editMode,
          borderRadius: 18,
          startActions: [
            CyberSlideAction(
              label: bean.status! == 1 ? '运行' : '停止',
              icon:
                  bean.status! == 1
                      ? CupertinoIcons.memories
                      : CupertinoIcons.stop_circle,
              color: const Color(0xffD25535),
              onTap: () {
                if (bean.status! == 1) {
                  startCron(
                    context,
                    ref,
                    SpUtil.getBool(spAutoShowLog, defValue: true),
                  );
                } else {
                  stopCron(context, ref);
                }
              },
            ),
            CyberSlideAction(
              label: '日志',
              icon: CupertinoIcons.text_justifyleft,
              color: const Color(0xff606467),
              onTap: () => logCron(context, ref),
            ),
          ],
          endActions: [
            CyberSlideAction(
              label: '编辑',
              icon: CupertinoIcons.pencil_outline,
              color: const Color(0xFF00F0FF),
              onTap: () {
                Navigator.of(context).push(
                  WallpaperPageRoute(
                    builder:
                        (context) =>
                            AddTaskPage(taskBean: bean, hideUploadFile: true),
                  ),
                );
              },
            ),
            CyberSlideAction(
              label: (bean.isPinned ?? 0) == 0 ? '置顶' : '取消',
              icon:
                  (bean.isPinned ?? 0) == 0
                      ? CupertinoIcons.pin
                      : CupertinoIcons.pin_slash,
              color: const Color(0xFFFFC107),
              onTap: () {
                WidgetsBinding.instance.endOfFrame.then(
                  (_) => pinTask(context),
                );
              },
            ),
            CyberSlideAction(
              label: bean.isDisabled! == 0 ? '禁用' : '启用',
              icon:
                  bean.isDisabled! == 0
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.checkmark_alt_circle,
              color: const Color(0xFF333333),
              onTap: () {
                WidgetsBinding.instance.endOfFrame.then(
                  (_) => enableTask(context),
                );
              },
            ),
            CyberSlideAction(
              label: '删除',
              icon: CupertinoIcons.delete,
              color: const Color(0xFFFF3D00),
              onTap: () {
                HapticFeedback.mediumImpact();
                WidgetsBinding.instance.endOfFrame.then(
                  (_) => delTask(context, ref),
                );
              },
            ),
          ],
          child: _buildCardChild(context),
        ),
      );
    }

    return CapsuleGlowCard(
      frost: false,
      isPinned: bean.isPinned == 1,
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      child: Slidable(
            enabled: !editMode,
            key: ValueKey(bean.sId),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            // 4 按钮：等分 Pane 宽度（screen × 0.7 = 252px ≈ 4×60+12）
            extentRatio: 0.7,
            children: [
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFF00F0FF) : AppColors.success,
                icon: CupertinoIcons.pencil_outline,
                label: '编辑',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  Navigator.of(context).push(
                    WallpaperPageRoute(
                      builder:
                          (context) =>
                              AddTaskPage(taskBean: bean, hideUploadFile: true),
                    ),
                  );
                },
              ),
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFFFFC107) : AppColors.warning,
                icon:
                    (bean.isPinned ?? 0) == 0
                        ? CupertinoIcons.pin
                        : CupertinoIcons.pin_slash,
                label: (bean.isPinned ?? 0) == 0 ? '置顶' : '取消',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then(
                    (_) => pinTask(context),
                  );
                },
              ),
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFF333333) : AppColors.purple,
                icon:
                    bean.isDisabled! == 0
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.checkmark_alt_circle,
                label: bean.isDisabled! == 0 ? '禁用' : '启用',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then(
                    (_) => enableTask(context),
                  );
                },
              ),
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFFFF3D00) : AppColors.danger,
                icon: CupertinoIcons.delete,
                label: '删除',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then(
                    (_) => delTask(context, ref),
                  );
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
                color: const Color(0xffD25535),
                icon:
                    bean.status! == 1
                        ? CupertinoIcons.memories
                        : CupertinoIcons.stop_circle,
                label: bean.status! == 1 ? '运行' : '停止',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () {
                  if (bean.status! == 1) {
                    startCron(
                      context,
                      ref,
                      SpUtil.getBool(spAutoShowLog, defValue: true),
                    );
                  } else {
                    stopCron(context, ref);
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
                onTap: () => logCron(context, ref),
              ),
            ],
          ),
          child: _buildCardChild(context),
        ),
    );
  }

  /// 构建卡片主体内容（不含外层 margin/decoration，由调用方提供）
  Widget _buildCardChild(BuildContext context) {
    // 统一毛玻璃封装：sigma<=0 时自动退化为纯色（无 BackdropFilter）
    return OptimizedFrostedGlass(
      sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                bean.isPinned == 1 && isCyber
                    ? CyberColors.cyan.withValues(alpha: 0.6)
                    : (isCyber
                          ? CyberColors.borderGlow
                          : AppleColors.cardBorder),
            width: bean.isPinned == 1 && isCyber ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (editMode) {
                checkedCallback(bean.sId ?? "");
              } else {
                Navigator.of(
                  context,
                ).pushNamed(Routes.routeTaskDetail, arguments: bean);
              }
            },
            child: _buildCardContent(context),
          ),
        ),
      ),
    );
  }

  /// 构建卡片内容（任务名称、状态胶囊、定时规则、命令 + 运行按钮）
  /// 移植自主题版定时任务卡片新设计：左侧状态竖条 + 状态胶囊标签 +
  /// 运行/停止胶囊按钮，字重跟随全局粗细调节，配色使用壁纸动态反色。
  Widget _buildCardContent(BuildContext context) {
    final bool dark = isCyber;
    final bool isPinnedT = bean.isPinned == 1;
    final bool isDisabled = (bean.isDisabled ?? 0) == 1;
    final bool isRunning = !isDisabled && (bean.status ?? 1) == 0;
    final Color sc = _stateColor(isRunning, isDisabled);
    final Color accent = isCyber
        ? CyberColors.cyan
        : ref.watch(themeProvider).primaryColor;
    // 字重跟随全局粗细调节（四档 400/500/600/700）
    final FontWeight fw = FontWeight(ref.watch(textWeightProvider));
    final ThemeViewModel themeModel = ref.watch(themeProvider);

    // 禁用卡片：整体灰显
    final Color nameColor = isDisabled
        ? (dark ? const Color(0xFF5A5A6E) : const Color(0xFFB0B0B8))
        : themeModel.themeColor.titleColor();
    final Color timeColor = isDisabled
        ? (dark ? const Color(0xFF4A4A5E) : const Color(0xFF9A9AA0))
        : themeModel.themeColor.descColor();
    // 定时规则：始终保留青色强调
    final Color cronColor = isDisabled
        ? (dark ? const Color(0xFF4A4A5E) : const Color(0xFFB0B0B8))
        : CyberColors.cyan.withValues(alpha: 0.9);
    final Color commandColor = isDisabled
        ? (dark ? const Color(0xFF4A4A5E) : const Color(0xFFC4C4CC))
        : themeModel.themeColor.descColor();

    final String timeText =
        (bean.lastExecutionTime == null || bean.lastExecutionTime == 0)
            ? "-"
            : Utils.formatMessageTime(bean.lastExecutionTime!);

    return Row(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: SizedBox(
            width: editMode ? 40 : 0,
            height: 40,
            child: Visibility(
              visible: editMode,
              child: Padding(
                padding: EdgeInsets.only(
                  left: isCyber ? 15 : AppleColors.spaceMd,
                ),
                child: Icon(
                  checked
                      ? CupertinoIcons.checkmark_alt_circle
                      : CupertinoIcons.circle,
                  size: 25,
                  color:
                      checked
                          ? ref.watch(themeProvider).primaryColor
                          : ref.watch(themeProvider).themeColor.descColor(),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCyber ? 15 : AppleColors.spaceMd,
              vertical: 13,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧状态竖条
                Container(
                  width: 3,
                  height: 42,
                  margin: const EdgeInsets.only(right: 12, top: 2),
                  decoration: BoxDecoration(
                    color: sc,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isRunning
                        ? [
                            BoxShadow(
                              color: sc.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                ),
                // 中间内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称行：置顶图钉 + 名称 + 时间 + 状态点
                      Row(
                        children: [
                          if (isPinnedT) ...[
                            Icon(Icons.push_pin, size: 14, color: accent),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              bean.name ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: fw,
                                color: nameColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeText,
                            style: TextStyle(fontSize: 11, color: timeColor),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: sc,
                              shape: BoxShape.circle,
                              boxShadow: isRunning
                                  ? [
                                      BoxShadow(
                                        color: sc.withValues(alpha: 0.7),
                                        blurRadius: 5,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // 状态行：状态胶囊标签 + 定时规则
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: sc.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: sc.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _stateText(isRunning, isDisabled),
                              style: TextStyle(fontSize: 11, color: sc),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bean.schedule ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cronColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // 命令行：右侧嵌运行/停止按钮（与命令文案同行对齐，不撑大卡片）
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bean.command ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: commandColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildRunButton(
                            context,
                            isRunning: isRunning,
                            isDisabled: isDisabled,
                            accent: accent,
                            fw: fw,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 状态色：运行中主色 / 待机灰 / 禁用红
  Color _stateColor(bool isRunning, bool isDisabled) {
    final Color accent = isCyber
        ? CyberColors.cyan
        : ref.watch(themeProvider).primaryColor;
    if (isDisabled) {
      return isCyber ? CyberColors.neonRed : const Color(0xFFFF3B30);
    }
    if (isRunning) return accent;
    return isCyber ? CyberColors.idleGray : const Color(0xFFB0B0B8);
  }

  /// 状态文案：运行中 / 待机 / 已禁用
  String _stateText(bool isRunning, bool isDisabled) {
    if (isDisabled) return '已禁用';
    if (isRunning) return '运行中';
    return '待机';
  }

  /// 运行/停止胶囊按钮（卡片右下，与命令文案同行对齐）
  ///  - 运行中：红色"停止"
  ///  - 待机：主色"运行"
  ///  - 已禁用/编辑模式：灰色（不可点击）
  Widget _buildRunButton(
    BuildContext context, {
    required bool isRunning,
    required bool isDisabled,
    required Color accent,
    required FontWeight fw,
  }) {
    final bool dark = isCyber;
    final bool inactive = isDisabled || editMode;
    final Color c = inactive
        ? (dark ? const Color(0xFF4A4A5E) : const Color(0xFFB0B0B8))
        : (isRunning ? const Color(0xFFFF3D00) : accent);
    final IconData icon = isRunning ? Icons.stop : Icons.play_arrow;
    final String label = isRunning ? '停止' : '运行';

    return GestureDetector(
      onTap: inactive
          ? null
          : () {
              if (isRunning) {
                stopCron(context, ref);
              } else {
                startCron(
                  context,
                  ref,
                  SpUtil.getBool(spAutoShowLog, defValue: true),
                );
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withValues(alpha: 0.45), width: 1),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: 0.3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: fw, color: c),
            ),
          ],
        ),
      ),
    );
  }

  startCron(BuildContext context, WidgetRef ref, bool showLog) async {
    await ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .runCrons(context, [bean.sId!]);
    if (showLog) {
      logCron(context, ref);
    }
  }

  stopCron(BuildContext context, WidgetRef ref) {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .stopCrons(context, [bean.sId!]);
  }

  logCron(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(
          WallpaperPageRoute(
            blurSigma: 6,
            blurTintColor: CyberColors.bg.withOpacity(0.50),
            builder:
                (context) => InTimeLogPage(
                  bean.sId!,
                  true,
                  bean.name ?? "",
                  command: bean.command,
                ),
          ),
        )
        .then((value) {
          Future.delayed(const Duration(milliseconds: 500), () {
            ref
                .read(
                  SingleAccountPageState.ofTaskProvider(context)(
                    getProviderName(context),
                  ).notifier,
                )
                .loadData(context, false);
          });
        });
  }

  void enableTask(BuildContext context) {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .enableTask(context, [bean.sId!], bean.isDisabled!);
  }

  // 赛博模式滑动按钮统一使用 CyberSlideAction 组件（lib/base/ui/cyber/cyber_slide_action.dart）
  // 保持赛博模式所有页面滑动按钮风格一致：圆角 + 外发光 + 自适应宽度

  void pinTask(BuildContext context) {
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .pinTask(context, [bean.sId!], bean.isPinned ?? 0);
  }

  void delTask(BuildContext context1, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context1,
      title: "确认删除",
      content: "确认删除定时任务 ${bean.name ?? ""} 吗",
      confirmLabel: "确定",
      danger: true,
    );
    if (confirmed != true) return;
    ref
        .read(
          SingleAccountPageState.ofTaskProvider(context1)(
            getProviderName(context1),
          ),
        )
        .delCron(context1, [bean.sId!]);
  }
}

