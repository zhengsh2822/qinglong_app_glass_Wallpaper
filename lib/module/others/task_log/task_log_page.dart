import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slidable.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';
import 'package:qinglong_app/module/task/intime_log/intime_history_log_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../../main.dart';
import '../../home/system_bean.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class TaskLogPage extends ConsumerStatefulWidget {
  final String? searchText;

  const TaskLogPage({Key? key, this.searchText}) : super(key: key);

  @override
  _TaskLogPageState createState() => _TaskLogPageState();
}

class _TaskLogPageState extends ConsumerState<TaskLogPage>
    with LazyLoadState<TaskLogPage> {
  List<TaskLogBean> list = [];

  TextEditingController searchText = TextEditingController();
  Timer? _searchDebounce;

  ScrollController controller = ScrollController();

  bool buttonshow = false;

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
    // 提前发起网络请求，与路由 push 动画并行，不等动画完成。
    // LazyLoadState.onLazyLoad 仍作为兜底（若请求未完成则无副作用）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (list.isEmpty) {
        loadData();
      }
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

  Widget searchCell(WidgetRef context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: SearchCell(controller: searchText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final scaffold = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Visibility(
          visible: buttonshow,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              scrollToTop();
            },
            elevation: 2,
            child: const Icon(CupertinoIcons.up_arrow),
          ),
        ),
        appBar: QlAppBar(
          canBack: true,
          backCall: () {
            Navigator.of(context).pop();
          },
          title: "任务日志",
        ),
        body: GlassPageBackground(
          child:
            list.isEmpty
                ? const Center(child: LoadingWidget())
                : Column(
                  children: [
                    searchCell(ref),
                    Expanded(
                      child: SlidableAutoCloseBehavior(
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewPadding.bottom + 50,
                          ),
                          controller: controller,
                          physics: const AlwaysScrollableScrollPhysics(),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemBuilder: (context, index) {
                            TaskLogBean item = list[index];

                            if (searchText.text.isNotEmpty &&
                                !(item.name?.contains(searchText.text) ??
                                    false)) {
                              return const SizedBox.shrink();
                            }

                            if ((item.isDir ?? false)) {
                              if (isCyber) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: CyberSlidable(
                                  slidableKey: ValueKey(item.name ?? ""),
                                  endActions: [
                                    CyberSlideAction(
                                      label: '删除',
                                      icon: CupertinoIcons.delete,
                                      color: const Color(0xffEA4D3E),
                                      onTap: () {
                                        showCupertinoDialog(
                                          context: context,
                                          useRootNavigator: false,
                                          builder:
                                              (context) => CupertinoAlertDialog(
                                                title: const Text("确认删除"),
                                                content: const Text(
                                                  "确定删除这个文件夹吗",
                                                ),
                                                actions: [
                                                  CupertinoDialogAction(
                                                    child: const Text(
                                                      "取消",
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xff999999,
                                                        ),
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                    },
                                                  ),
                                                  CupertinoDialogAction(
                                                    child: Text(
                                                      "确定",
                                                      style: TextStyle(
                                                        color:
                                                            ref
                                                                .watch(
                                                                  themeProvider,
                                                                )
                                                                .primaryColor,
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      deleteFold(item);
                                                    },
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
                                    ),
                                  ],
                                  child: OptimizedFrostedGlass(
                                    sigma: SpUtil.getDouble(
                                      spCardBlurSigma,
                                      defValue: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          18,
                                        ),
                                        border: Border.all(
                                          color: CyberColors.borderGlow,
                                          width: 1,
                                        ),
                                      ),
                                      child: ExpansionTile(
                                    title: Text(
                                      item.name ?? "",
                                      style: TextStyle(
                                        color:
                                            ref
                                                .watch(themeProvider)
                                                .themeColor
                                                .titleColor(),
                                        fontSize: 16,
                                      ),
                                    ),
                                    children:
                                        (item.files?.isNotEmpty ?? false)
                                            ? item.files!
                                                .map(
                                                  (e) => ListTile(
                                                    onTap: () {
                                                      Navigator.of(
                                                        context,
                                                      ).push(
                                                        WallpaperPageRoute(
                                                          blurSigma: 6,
                                                          blurTintColor: CyberColors.bg.withOpacity(0.50),
                                                          builder:
                                                              (
                                                                context,
                                                              ) => InTimeHistoryLogPage(
                                                                path:
                                                                    item.name ??
                                                                    "",
                                                                title: e,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    title: Text(
                                                      e,
                                                      style: TextStyle(
                                                        color:
                                                            ref
                                                                .watch(
                                                                  themeProvider,
                                                                )
                                                                .themeColor
                                                                .titleColor(),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList()
                                            : (item.children ?? [])
                                                .map(
                                                  (e) => ListTile(
                                                    onTap: () {
                                                      Navigator.of(context)
                                                          .push(
                                                            WallpaperPageRoute(
                                                              blurSigma: 6,
                                                              blurTintColor: CyberColors.bg.withOpacity(0.50),
                                                              builder:
                                                                  (
                                                                    context,
                                                                  ) => InTimeHistoryLogPage(
                                                                    path:
                                                                        item.name ??
                                                                        "",
                                                                    title:
                                                                        e.title ??
                                                                        "",
                                                                  ),
                                                            ),
                                                          )
                                                          .then((value) {
                                                            if (value != null &&
                                                                value == true) {
                                                              loadData();
                                                            }
                                                          });
                                                    },
                                                    title: Text(
                                                      e.title ?? "",
                                                      style: TextStyle(
                                                        color:
                                                            ref
                                                                .watch(
                                                                  themeProvider,
                                                                )
                                                                .themeColor
                                                                .titleColor(),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              .toList(),
                                  ),
                                ),
                              ),
                            ),
                          );
                              }
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppleColors.cardBorder,
                                  ),
                                ),
                                child: OptimizedFrostedGlass(
                                  sigma: SpUtil.getDouble(
                                    spCardBlurSigma,
                                    defValue: 4,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Slidable(
                                  key: ValueKey(item.name ?? ""),
                                  endActionPane: ActionPane(
                                    motion: const ScrollMotion(),
                                    extentRatio: 0.22,
                                    children: [
                                      AppSlideButton(
                                        context: context,
                                        color: const Color(0xffEA4D3E),
                                        icon: CupertinoIcons.delete,
                                        onTap: () {
                                          showCupertinoDialog(
                                            context: context,
                                            useRootNavigator: false,
                                            builder:
                                                (context) => CupertinoAlertDialog(
                                                  title: const Text("确认删除"),
                                                  content: const Text(
                                                    "确定删除这个文件夹吗",
                                                  ),
                                                  actions: [
                                                    CupertinoDialogAction(
                                                      child: const Text(
                                                        "取消",
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xff999999,
                                                          ),
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                      },
                                                    ),
                                                    CupertinoDialogAction(
                                                      child: Text(
                                                        "确定",
                                                        style: TextStyle(
                                                          color:
                                                              ref
                                                                  .watch(
                                                                    themeProvider,
                                                                  )
                                                                  .primaryColor,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        deleteFold(item);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                          );
                                        },
                                        cyberMode: false,
                                        width: double.infinity,
                                        cornerRadius: 12,
                                        iconSize: 22,
                                        outerGap: 5,
                                        innerGap: 6,
                                      ),
                                    ],
                                  ),
                                  child: ExpansionTile(
                                  title: Text(
                                    item.name ?? "",
                                    style: TextStyle(
                                      color:
                                          ref
                                              .watch(themeProvider)
                                              .themeColor
                                              .titleColor(),
                                      fontSize: 16,
                                    ),
                                  ),
                                  children:
                                      (item.files?.isNotEmpty ?? false)
                                          ? item.files!
                                              .map(
                                                (e) => ListTile(
                                                  onTap: () {
                                                    Navigator.of(context).push(
                                                      WallpaperPageRoute(
                                                        blurSigma: 6,
                                                        blurTintColor: CyberColors.bg.withOpacity(0.50),
                                                        builder:
                                                            (
                                                              context,
                                                            ) => InTimeHistoryLogPage(
                                                              path:
                                                                  item.name ??
                                                                  "",
                                                              title: e,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  title: Text(
                                                    e,
                                                    style: TextStyle(
                                                      color:
                                                          ref
                                                              .watch(
                                                                themeProvider,
                                                              )
                                                              .themeColor
                                                              .titleColor(),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList()
                                          : (item.children ?? [])
                                              .map(
                                                (e) => ListTile(
                                                  onTap: () {
                                                    Navigator.of(context)
                                                        .push(
                                                          WallpaperPageRoute(
                                                            blurSigma: 6,
                                                            blurTintColor: CyberColors.bg.withOpacity(0.50),
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => InTimeHistoryLogPage(
                                                                  path:
                                                                      item.name ??
                                                                      "",
                                                                  title:
                                                                      e.title ??
                                                                      "",
                                                                ),
                                                          ),
                                                        )
                                                        .then((value) {
                                                          if (value != null &&
                                                              value == true) {
                                                            loadData();
                                                          }
                                                        });
                                                  },
                                                  title: Text(
                                                    e.title ?? "",
                                                    style: TextStyle(
                                                      color:
                                                          ref
                                                              .watch(
                                                                themeProvider,
                                                              )
                                                              .themeColor
                                                              .titleColor(),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                ),
                                ),
                              ),
                              );
                            } else {
                              if (isCyber) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: CyberSlidable(
                                  slidableKey: ValueKey(item.name ?? ""),
                                  endActions: [
                                    CyberSlideAction(
                                      label: '删除',
                                      icon: CupertinoIcons.delete,
                                      color: const Color(0xffEA4D3E),
                                      onTap: () {
                                        showCupertinoDialog(
                                          context: context,
                                          useRootNavigator: false,
                                          builder:
                                              (context) => CupertinoAlertDialog(
                                                title: const Text("确认删除"),
                                                content: const Text(
                                                  "确定删除这个文件吗",
                                                ),
                                                actions: [
                                                  CupertinoDialogAction(
                                                    child: const Text(
                                                      "取消",
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xff999999,
                                                        ),
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                    },
                                                  ),
                                                  CupertinoDialogAction(
                                                    child: Text(
                                                      "确定",
                                                      style: TextStyle(
                                                        color:
                                                            ref
                                                                .watch(
                                                                  themeProvider,
                                                                )
                                                                .primaryColor,
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      deleteFold(item);
                                                    },
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
                                    ),
                                  ],
                                  child: OptimizedFrostedGlass(
                                    sigma: SpUtil.getDouble(
                                      spCardBlurSigma,
                                      defValue: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          18,
                                        ),
                                        border: Border.all(
                                          color: CyberColors.borderGlow,
                                          width: 1,
                                        ),
                                      ),
                                      child: ListTile(
                                    onTap: () {
                                      if (item.isDir ?? false) {
                                        "该文件夹为空".toast();
                                        return;
                                      }

                                      Navigator.of(context).push(
                                        WallpaperPageRoute(
                                          blurSigma: 6,
                                          blurTintColor: CyberColors.bg.withOpacity(0.50),
                                          builder:
                                              (context) => InTimeHistoryLogPage(
                                                path: "",
                                                title: item.name ?? "",
                                              ),
                                        ),
                                      );
                                    },
                                    title: Text(
                                      item.name ?? "",
                                      style: TextStyle(
                                        color:
                                            ref
                                                .watch(themeProvider)
                                                .themeColor
                                                .titleColor(),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                              }
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppleColors.cardBorder,
                                  ),
                                ),
                                child: OptimizedFrostedGlass(
                                  sigma: SpUtil.getDouble(
                                    spCardBlurSigma,
                                    defValue: 4,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Slidable(
                                  key: ValueKey(item.name ?? ""),
                                  endActionPane: ActionPane(
                                    motion: const ScrollMotion(),
                                    extentRatio: 0.22,
                                    children: [
                                      AppSlideButton(
                                        context: context,
                                        color: const Color(0xffEA4D3E),
                                        icon: CupertinoIcons.delete,
                                        onTap: () {
                                          showCupertinoDialog(
                                            context: context,
                                            useRootNavigator: false,
                                            builder:
                                                (context) => CupertinoAlertDialog(
                                                  title: const Text("确认删除"),
                                                  content: const Text(
                                                    "确定删除这个文件吗",
                                                  ),
                                                  actions: [
                                                    CupertinoDialogAction(
                                                      child: const Text(
                                                        "取消",
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xff999999,
                                                          ),
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                      },
                                                    ),
                                                    CupertinoDialogAction(
                                                      child: Text(
                                                        "确定",
                                                        style: TextStyle(
                                                          color:
                                                              ref
                                                                  .watch(
                                                                    themeProvider,
                                                                  )
                                                                  .primaryColor,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        deleteFold(item);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                          );
                                        },
                                        cyberMode: false,
                                        width: double.infinity,
                                        cornerRadius: 12,
                                        iconSize: 22,
                                        outerGap: 5,
                                        innerGap: 6,
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                  onTap: () {
                                    if (item.isDir ?? false) {
                                      "该文件夹为空".toast();
                                      return;
                                    }

                                    Navigator.of(context).push(
                                      WallpaperPageRoute(
                                        blurSigma: 6,
                                        blurTintColor: CyberColors.bg.withOpacity(0.50),
                                        builder:
                                            (context) => InTimeHistoryLogPage(
                                              path: "",
                                              title: item.name ?? "",
                                            ),
                                      ),
                                    );
                                  },
                                  title: Text(
                                    item.name ?? "",
                                    style: TextStyle(
                                      color:
                                          ref
                                              .watch(themeProvider)
                                              .themeColor
                                              .titleColor(),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                ),
                              ),
                              );
                            }
                          },
                          itemCount: list.length,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  bool _loading = false;

  Future<void> loadData() async {
    if (_loading) return;
    _loading = true;
    HttpResponse<List<TaskLogBean>> response =
        await SingleAccountPageState.ofApi(context).taskLog();

    if (response.success) {
      if (response.bean == null || response.bean!.isEmpty) {
        "暂无数据".toast();
      }
      list.clear();
      list.addAll(response.bean ?? []);
      if (widget.searchText != null) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          searchText.text = widget.searchText!;
        });
      }
      setState(() {});
    } else {
      response.message?.toast();
    }
    _loading = false;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchText.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  void deleteFold(TaskLogBean item) async {
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString(),
      );
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }
    if (!systemBean.isUpperVersion2_14_5()) {
      "该功能仅支持v2.14.5及以上版本".toast();
      return;
    }

    EasyLoading.show(status: "删除中...");
    var temp =
        item.isDir == true
            ? await SingleAccountPageState.ofApi(
              context,
            ).deleteLogFold(item.name ?? "", "")
            : await SingleAccountPageState.ofApi(
              context,
            ).deleteLog(item.name ?? "", "");
    EasyLoading.dismiss();
    if (temp.success) {
      "已删除".toast();
      await loadData();
    } else {
      temp.message?.toast();
    }
  }
}
