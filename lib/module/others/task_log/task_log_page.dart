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
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/floating_search_bar_area.dart';
import 'package:qinglong_app/base/ui/selector_card.dart';
import 'package:qinglong_app/base/ui/swipe_glass_card.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';
import 'package:qinglong_app/module/task/intime_log/intime_history_log_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/ql_debug_log.dart';

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

  // 初始筛选文本在 initState 写入构造参数，保证首帧渲染即是筛选后的列表，
  // 避免「先展示全部日志、预填搜索词后再筛掉」的闪变。
  late final TextEditingController searchText;

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
    searchText = TextEditingController(text: widget.searchText);
    QlDebugLog.write(
      'QLLOG TaskLog initState search="${widget.searchText}" '
      'controllerText="${searchText.text}"',
    );
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

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (list.isNotEmpty) {
      final visible =
          list
              .where(
                (e) =>
                    searchText.text.isEmpty ||
                    (e.name ?? "").contains(searchText.text),
              )
              .length;
      QlDebugLog.write(
        'QLLOG TaskLog build total=${list.length} visible=$visible '
        'search="${searchText.text}"',
      );
    }
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
                  : FloatingSearchBarArea(
                    controller: searchText,
                    listView: SlidableAutoCloseBehavior(
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          top: 64,
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
                            return SwipeGlassCard(
                              slidableKey: ValueKey(item.name ?? ""),
                              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              radius: 18,
                              endActions: [
                                SwipeActionSpec(
                                  label: '删除',
                                  icon: CupertinoIcons.delete,
                                  color: const Color(0xffEA4D3E),
                                  onTap: () {
                                    showConfirmDialog(
                                      context,
                                      title: "确认删除",
                                      content: "确定删除这个文件夹吗",
                                      danger: true,
                                    ).then((confirmed) {
                                      if (confirmed != true) return;
                                      deleteFold(item);
                                    });
                                  },
                                ),
                              ],
                              child: SelectorCard(
                                title: item.name ?? "",
                                collapseOnSelect: false,
                                items:
                                    (item.files?.isNotEmpty ?? false)
                                        ? item.files!
                                            .map(
                                              (e) => SelectorCardItem(
                                                title: e,
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    WallpaperPageRoute(
                                                      blurSigma: 6,
                                                      blurTintColor: CyberColors
                                                          .bg
                                                          .withOpacity(0.50),
                                                      builder:
                                                          (context) =>
                                                              InTimeHistoryLogPage(
                                                                path:
                                                                    item.name ??
                                                                    "",
                                                                title: e,
                                                              ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                            .toList()
                                        : (item.children ?? [])
                                            .map(
                                              (e) => SelectorCardItem(
                                                title: e.title ?? "",
                                                onTap: () {
                                                  Navigator.of(context)
                                                      .push(
                                                        WallpaperPageRoute(
                                                          blurSigma: 6,
                                                          blurTintColor:
                                                              CyberColors.bg
                                                                  .withOpacity(
                                                                    0.50,
                                                                  ),
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
                                              ),
                                            )
                                            .toList(),
                              ),
                            );
                          } else {
                            return SwipeGlassCard(
                              slidableKey: ValueKey(item.name ?? ""),
                              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              radius: 18,
                              endActions: [
                                SwipeActionSpec(
                                  label: '删除',
                                  icon: CupertinoIcons.delete,
                                  color: const Color(0xffEA4D3E),
                                  onTap: () {
                                    showConfirmDialog(
                                      context,
                                      title: "确认删除",
                                      content: "确定删除这个文件吗",
                                      danger: true,
                                    ).then((confirmed) {
                                      if (confirmed != true) return;
                                      deleteFold(item);
                                    });
                                  },
                                ),
                              ],
                              child: ListTile(
                                onTap: () {
                                  if (item.isDir ?? false) {
                                    "该文件夹为空".toast();
                                    return;
                                  }

                                  Navigator.of(context).push(
                                    WallpaperPageRoute(
                                      blurSigma: 6,
                                      blurTintColor: CyberColors.bg.withOpacity(
                                        0.50,
                                      ),
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
                            );
                          }
                        },
                        itemCount: list.length,
                      ),
                    ),
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
    QlDebugLog.write(
      'QLLOG TaskLog loadData start search="${searchText.text}"',
    );
    HttpResponse<List<TaskLogBean>> response =
        await SingleAccountPageState.ofApi(context).taskLog();

    if (response.success) {
      if (response.bean == null || response.bean!.isEmpty) {
        "暂无数据".toast();
      }
      list.clear();
      list.addAll(response.bean ?? []);
      QlDebugLog.write(
        'QLLOG TaskLog loadData done total=${list.length} '
        'search="${searchText.text}"',
      );
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
    QlDebugLog.write('QLLOG TaskLog onLazyLoad fired list=${list.length}');
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
