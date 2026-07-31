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
import 'package:qinglong_app/base/ui/animated_edit_mode_overlay.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slidable.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/base/ui/slidable_close_notifier.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/module/env/add_env_page.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/env/env_viewmodel.dart';
import 'package:qinglong_app/module/task/task_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../../base/ui/enable_widget.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class EnvPage extends ConsumerStatefulWidget {
  const EnvPage({Key? key}) : super(key: key);

  @override
  EnvPageState createState() => EnvPageState();
}

class EnvPageState extends ConsumerState<EnvPage>
    with TickerProviderStateMixin {
  String currentState = EnvViewModel.allStr;
  TextEditingController searchText = TextEditingController();
  Timer? _searchDebounce;
  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();

  bool editMode = false;
  Set<String> checkedIds = <String>{};
  bool buttonshow = false;
  GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

  /// Slidable 关闭信号值（用于生成 Key 重置卡片状态）
  int _slidableResetKey = 0;

  Future<void> scrollToTop() async {
    _scrollController.animateTo(
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

  List<EnvBean> getListByType(int index) {
    var model = ref.read(
      SingleAccountPageState.ofEnvProvider(context)(
        getProviderName(context),
      ).notifier,
    );
    if (index == 0) {
      return model.list;
    } else if (index == 1) {
      return model.enabledList;
    } else if (index == 2) {
      return model.disabledList;
    }
    return model.list;
  }

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(_onInnerTabChanged);

    super.initState();
    searchText.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {});
      });
    });
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController?.removeListener(_onInnerTabChanged);
    SlidableCloseNotifier.listenable.removeListener(_onSlidableClose);
    _editModeOverlay?.dispose();
    searchText.dispose();
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  double searchCellHeight = 55;

  SliverAppBar _buildAppBar(WidgetRef ref, EnvViewModel model) {
    return SliverAppBar(
      pinned: false,
      floating: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      snap: false,
      primary: false,
      toolbarHeight: searchCellHeight,
      flexibleSpace: searchCell(context, ref, model),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        appBar: QlAppBar(
          title:
              (editMode && checkedIds.isNotEmpty)
                  ? "当前选中 ${checkedIds.length} 个变量"
                  : "环境变量",
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
                  // searchText.text = "";
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
                      getListByType(_tabController?.index ?? 0).where((value) {
                        if (searchText.text.isEmpty ||
                            (value.name?.contains(
                                  searchText.text.toLowerCase(),
                                ) ??
                                false) ||
                            (value.value?.contains(
                                  searchText.text.toLowerCase(),
                                ) ??
                                false) ||
                            (value.remarks?.contains(
                                  searchText.text.toLowerCase(),
                                ) ??
                                false)) {
                          return true;
                        } else {
                          return false;
                        }
                      }).length) {
                    //全不选

                    checkedIds.clear();
                    setState(() {});
                  } else {
                    //全选
                    checkedIds.clear();
                    checkedIds.addAll(
                      getListByType(_tabController?.index ?? 0)
                          .where((value) {
                            if (searchText.text.isEmpty ||
                                (value.name?.contains(
                                      searchText.text.toLowerCase(),
                                    ) ??
                                    false) ||
                                (value.value?.contains(
                                      searchText.text.toLowerCase(),
                                    ) ??
                                    false) ||
                                (value.remarks?.contains(
                                      searchText.text.toLowerCase(),
                                    ) ??
                                    false)) {
                              return true;
                            } else {
                              return false;
                            }
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
                        builder: (context) => const AddEnvPage(),
                      ),
                    )
                    .then((value) {
                      ref
                          .read(
                            SingleAccountPageState.ofEnvProvider(context)(
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
                                    ).where((value) {
                                      if (searchText.text.isEmpty ||
                                          (value.name?.contains(
                                                searchText.text.toLowerCase(),
                                              ) ??
                                              false) ||
                                          (value.value?.contains(
                                                searchText.text.toLowerCase(),
                                              ) ??
                                              false) ||
                                          (value.remarks?.contains(
                                                searchText.text.toLowerCase(),
                                              ) ??
                                              false)) {
                                        return true;
                                      } else {
                                        return false;
                                      }
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
        body: BaseStateWidget<EnvViewModel>(
          builder: (ref, model, child) {
            final Widget content = NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (
                BuildContext context,
                bool innerBoxIsScrolled,
              ) {
                return [
                  _buildAppBar(ref, model),
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      floating: false,
                      delegate: GlassSegmentedTabDelegate(
                        tabs: [
                          EnvViewModel.allStr,
                          EnvViewModel.enabledStr,
                          EnvViewModel.disabledStr,
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
                notificationPredicate: (_) {
                  return true;
                },
                color: Theme.of(context).primaryColor,
                onRefresh: () async {
                  return model.loadData(context, false);
                },
                child: SlidableAutoCloseBehavior(
                  key: ValueKey('env_slidable_${_slidableResetKey}'),
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      EnvRecordListView(
                        list: model.list,
                        searchText: searchText.text,
                        editMode: editMode,
                        checked: checkedIds,
                        changed: (id) {
                          if (checkedIds.contains(id)) {
                            checkedIds.remove(id);
                          } else {
                            checkedIds.add(id);
                          }
                          setState(() {});
                        },
                      ),
                      EnvListView(
                        list: model.enabledList,
                        searchText: searchText.text,
                        editMode: editMode,
                        checked: checkedIds,
                        changed: (id) {
                          if (checkedIds.contains(id)) {
                            checkedIds.remove(id);
                          } else {
                            checkedIds.add(id);
                          }
                          setState(() {});
                        },
                      ),
                      EnvListView(
                        list: model.disabledList,
                        searchText: searchText.text,
                        editMode: editMode,
                        checked: checkedIds,
                        changed: (id) {
                          if (checkedIds.contains(id)) {
                            checkedIds.remove(id);
                          } else {
                            checkedIds.add(id);
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
            return isCyber ? CyberBackground(child: content) : content;
          },
          model: SingleAccountPageState.ofEnvProvider(context)(
            getProviderName(context),
          ),
          onReady: (viewModel) {
            viewModel.loadData(context);
          },
        ),
      ),
    );
  }

  Widget searchCell(BuildContext context, WidgetRef ref, EnvViewModel model) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
      height: searchCellHeight.toDouble(),
      child: SearchCell(controller: searchText),
    );
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
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
        );
      },
    );
    _editModeOverlay!.show();
  }

  void _executeCode(BuildContext context, String s) {
    if (checkedIds.isEmpty) {
      "至少选择1个变量".toast();
      return;
    }

    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text("确认$s"),
            content: Text("确认$s吗"),
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
                  editMode = false;
                  removeOverlay();
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    if (s == "启用") {
                      enableEnv();
                    } else if (s == "禁用") {
                      disableEnv();
                    } else if (s == "删除") {
                      deleteEnvs();
                    }
                  });
                  setState(() {});
                },
              ),
            ],
          ),
    );
  }

  void enableEnv() {
    ref
        .read(
          SingleAccountPageState.ofEnvProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .enableEnv(context, checkedIds.toList(), 1);
  }

  void disableEnv() {
    ref
        .read(
          SingleAccountPageState.ofEnvProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .enableEnv(context, checkedIds.toList(), 0);
  }

  void deleteEnvs() {
    ref
        .read(
          SingleAccountPageState.ofEnvProvider(context)(
            getProviderName(context),
          ).notifier,
        )
        .delEnvs(context, checkedIds.toList());
  }

  void removeOverlay() {
    _editModeOverlay?.hide();
  }
}

class EnvItemCell extends StatelessWidget {
  final EnvBean bean;
  final int index;
  final WidgetRef ref;
  final bool editMode;
  final bool editMode2;
  final bool checked;
  final ValueChanged<String> checkedCallback;

  const EnvItemCell(
    this.bean,
    this.index,
    this.ref, {
    Key? key,
    this.editMode = false,
    this.editMode2 = false,
    required this.checkedCallback,
    required this.checked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Widget cardContent = InkWell(
      onTap: () {
        if (editMode) {
          checkedCallback(bean.sId ?? "");
        } else {
          Navigator.of(
            context,
          ).pushNamed(Routes.routeEnvDetail, arguments: bean);
        }
      },
      child: Row(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: SizedBox(
              width: editMode ? 40 : 0,
              height: 40,
              child: Visibility(
                visible: editMode,
                child: GestureDetector(
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
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCyber ? 15 : AppleColors.spaceMd,
                vertical: 8,
              ),
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
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor(),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                "${getIndexByIndex(context, index)}",
                                style: TextStyle(
                                  color:
                                      isCyber
                                          ? ref
                                              .watch(themeProvider)
                                              .themeColor
                                              .descColor()
                                          : AppleColors.textSecondary,
                                  fontSize: isCyber ? 12 : 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  text: bean.name ?? "",
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    color:
                                        isCyber
                                            ? CyberColors.titleWhite
                                            : AppleColors.textPrimary,
                                    fontSize: isCyber ? 16 : 17,
                                    fontWeight:
                                        isCyber ? null : FontWeight.w600,
                                    fontFamily:
                                        isCyber ? CyberColors.monoFont : null,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text:
                                          (bean.remarks == null ||
                                                  bean.remarks!.isEmpty)
                                              ? ""
                                              : "(${bean.remarks})",
                                      style: TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                        color:
                                            isCyber
                                                ? ref
                                                    .watch(themeProvider)
                                                    .themeColor
                                                    .descColor()
                                                : AppleColors.textSecondary,
                                        fontSize: isCyber ? 14 : 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            bean.status == 1
                                ? const StatusWidget(
                                  title: "已禁用",
                                  color: Color(0xffFB5858),
                                )
                                : StatusWidget(
                                  title: "已启用",
                                  color: ref.watch(themeProvider).primaryColor,
                                ),
                          ],
                        ),
                      ),
                      SizedBox(width: isCyber ? 15 : AppleColors.spaceMd),
                      Visibility(
                        visible: !editMode2,
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            bean.updatedAt == null
                                ? Utils.formatGMTTime(bean.timestamp ?? "")
                                : Utils.formatTime2(bean.updatedAt),
                            maxLines: 1,
                            style: TextStyle(
                              overflow: TextOverflow.ellipsis,
                              color:
                                  isCyber
                                      ? ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor()
                                      : AppleColors.textSecondary,
                              fontSize: isCyber ? 12 : 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCyber ? 15 : AppleColors.spaceMd),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      bean.value ?? "",
                      maxLines: 1,
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
          Visibility(
            visible: editMode2,
            child: const IgnorePointer(
              ignoring: true,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Icon(
                  CupertinoIcons.line_horizontal_3,
                  color: Color(0xff999999),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (isCyber) {
      // 赛博模式：用 CyberSlidable（Material elevation 光晕 + BackdropFilter 折射）
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: CyberSlidable(
          slidableKey: ValueKey(bean.sId),
          enabled: !editMode,
          borderRadius: AppleColors.radiusCard,
          endActions: [
            CyberSlideAction(
              label: '编辑',
              icon: CupertinoIcons.pencil_outline,
              color: const Color(0xFF00F0FF),
              onTap: () {
                Navigator.of(context)
                    .push(
                      WallpaperPageRoute(
                        builder: (context) => AddEnvPage(envBean: bean),
                      ),
                    )
                    .then((value) {
                      ref
                          .read(
                            SingleAccountPageState.ofEnvProvider(context)(
                              getProviderName(context),
                            ).notifier,
                          )
                          .loadData(context, false);
                    });
              },
            ),
            CyberSlideAction(
              label: bean.status == 0 ? '禁用' : '启用',
              icon:
                  bean.status == 0
                      ? Icons.dnd_forwardslash
                      : Icons.check_circle_outline_sharp,
              color: const Color(0xFF333333),
              onTap: () => enableEnv(context),
            ),
            CyberSlideAction(
              label: '删除',
              icon: CupertinoIcons.delete,
              color: const Color(0xFFFF3D00),
              onTap: () {
                HapticFeedback.mediumImpact();
                delEnv(context, ref);
              },
            ),
          ],
          child: _buildCardChild(context, isCyber, cardContent),
        ),
      );
    }

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
            enabled: !editMode,
            key: ValueKey(bean.sId),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            // 3 按钮：等分 Pane 宽度（screen × 0.55 ≈ 198px ≈ 3×60+18）
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
                          builder: (context) => AddEnvPage(envBean: bean),
                        ),
                      )
                      .then((value) {
                        ref
                            .read(
                              SingleAccountPageState.ofEnvProvider(context)(
                                getProviderName(context),
                              ).notifier,
                            )
                            .loadData(context, false);
                      });
                },
              ),
              AppSlideButton(
                context: context,
                color: const Color(0xffA356D6),
                icon:
                    bean.status == 0
                        ? Icons.dnd_forwardslash
                        : Icons.check_circle_outline_sharp,
                label: bean.status == 0 ? '禁用' : '启用',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () => enableEnv(context),
              ),
              AppSlideButton(
                context: context,
                color: const Color(0xffEA4D3E),
                icon: CupertinoIcons.delete,
                label: '删除',
                cyberMode: isCyber,
                width: double.infinity,
                onTap: () => delEnv(context, ref),
              ),
            ],
          ),
          child: _buildCardChild(context, isCyber, cardContent),
        ),
        ),
      ),
    );
  }

  Widget _buildCardChild(
    BuildContext context,
    bool isCyber,
    Widget cardContent,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppleColors.radiusCard),
      child:
          isCyber
              ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10), sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10)),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: CyberColors.borderGlow, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: cardContent,
                  ),
                ),
              )
              : Material(color: Colors.transparent, child: cardContent),
    );
  }

  void enableEnv(BuildContext context) {
    ref
        .read(
          SingleAccountPageState.ofEnvProvider(context)(
            getProviderName(context),
          ),
        )
        .enableEnv(context, [bean.sId!], bean.status!);
  }

  void delEnv(BuildContext context1, WidgetRef ref) {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context1,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text("确认删除"),
            content: Text("确认删除环境变量 ${bean.name ?? ""} 吗"),
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
                        SingleAccountPageState.ofEnvProvider(context1)(
                          getProviderName(context1),
                        ),
                      )
                      .delEnv(context1, bean.sId!);
                },
              ),
            ],
          ),
    );
  }

  int getIndexByIndex(BuildContext context, int index) {
    return index + 1;
  }
}

class EnvListView extends ConsumerStatefulWidget {
  final List<EnvBean> list;
  final String searchText;
  final bool editMode;
  final Set<String> checked;
  final ValueChanged<String> changed;

  const EnvListView({
    Key? key,
    required this.list,
    required this.searchText,
    required this.editMode,
    required this.checked,
    required this.changed,
  }) : super(key: key);

  @override
  ConsumerState<EnvListView> createState() => _EnvListViewState();
}

class _EnvListViewState extends ConsumerState<EnvListView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 先过滤出匹配项，确保搜索后序号从 1 开始连续递增
    List<EnvBean> filtered = [];
    for (int i = 0; i < widget.list.length; i++) {
      EnvBean value = widget.list[i];
      if (widget.searchText.isEmpty ||
          (value.name?.contains(widget.searchText) ?? false) ||
          (value.value?.contains(widget.searchText) ?? false) ||
          (value.remarks?.contains(widget.searchText) ?? false)) {
        filtered.add(value);
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.only(
        bottom: kBottomNavigationBarHeight + 50,
        top: 67,
      ),
      separatorBuilder: (BuildContext context, int i) {
        return const SizedBox(height: 12);
      },
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int i) {
        EnvBean value = filtered[i];
        return EnvItemCell(
          value,
          i,
          ref,
          key: ValueKey(value.sId),
          editMode: widget.editMode,
          editMode2: false,
          checkedCallback: (id) {
            widget.changed(id);
          },
          checked: widget.checked.contains(value.sId),
        );
      },
    );
  }
}

class EnvRecordListView extends ConsumerStatefulWidget {
  final List<EnvBean> list;
  final String searchText;
  final bool editMode;
  final Set<String> checked;
  final ValueChanged<String> changed;

  const EnvRecordListView({
    Key? key,
    required this.list,
    required this.searchText,
    required this.editMode,
    required this.checked,
    required this.changed,
  }) : super(key: key);

  @override
  ConsumerState<EnvRecordListView> createState() => _EnvRecordListViewState();
}

class _EnvRecordListViewState extends ConsumerState<EnvRecordListView>
    with AutomaticKeepAliveClientMixin {
  final List<Widget> list = [];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    list.clear();
    int displayIndex = 0;
    for (int i = 0; i < widget.list.length; i++) {
      EnvBean value = widget.list[i];
      if (widget.searchText.isEmpty ||
          (value.name?.contains(widget.searchText) ?? false) ||
          (value.value?.contains(widget.searchText) ?? false) ||
          (value.remarks?.contains(widget.searchText) ?? false)) {
        list.add(
          Padding(
            key: ValueKey(value.sId),
            padding: const EdgeInsets.only(bottom: 12),
            child: EnvItemCell(
              value,
              displayIndex,
              ref,
              editMode: widget.editMode,
              editMode2: widget.editMode,
              checkedCallback: (id) {
                widget.changed(id);
              },
              checked: widget.checked.contains(value.sId),
            ),
          ),
        );
        displayIndex++;
      }
    }
    return ReorderableListView(
      padding: const EdgeInsets.only(
        bottom: kBottomNavigationBarHeight + 50,
        top: 67,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      onReorder: (int oldIndex, int newIndex) {
        if (widget.searchText.isNotEmpty) {
          "请先清空搜索关键词".toast();
          return;
        }

        setState(() {
          //交换数据
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final EnvBean item = widget.list.removeAt(oldIndex);
          widget.list.insert(newIndex, item);

          ref
              .read(
                SingleAccountPageState.ofEnvProvider(context)(
                  getProviderName(context),
                ).notifier,
              )
              .update(context, item.sId ?? "", newIndex, oldIndex);
        });
      },
      children: list,
    );
  }
}
