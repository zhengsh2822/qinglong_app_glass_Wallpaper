import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/base_state_widget.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slidable.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/base/ui/tag_chip.dart';
import 'package:qinglong_app/module/appkey/appkey_detail_page.dart';
import 'package:qinglong_app/module/appkey/appkey_viewmodel.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import 'add_appkey_page.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class AppKeyPage extends ConsumerStatefulWidget {
  const AppKeyPage({Key? key}) : super(key: key);

  @override
  _AppKeyPageState createState() => _AppKeyPageState();
}

class _AppKeyPageState extends ConsumerState<AppKeyPage> {
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
      // 赛博模式下设为透明，让全局壁纸透出
      backgroundColor: Colors.transparent,
      floatingActionButton: Visibility(
        visible: buttonshow,
        child: FloatingActionButton(
          mini: true,
          onPressed: () {
            scrollToTop();
          },
          elevation: 2,
          backgroundColor: Colors.white,
          child: const Icon(CupertinoIcons.up_arrow),
        ),
      ),
      appBar: QlAppBar(
        title: "应用管理",
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context)
                  .push(
                    WallpaperPageRoute(
                      blurSigma: 6,
                      blurTintColor: CyberColors.bg.withOpacity(0.50),
                      builder: (context) => const AddAppKeyPage(bean: {}),
                    ),
                  )
                  .then((value) {
                    if (value != null && value == true) {
                      ref
                          .read(
                            SingleAccountPageState.ofAppKeyProvider(context)(
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
      body: BaseStateWidget<AppKeyViewModel>(
        builder: (ref, model, child) {
          return body(model, getListByType(model), ref);
        },
        model: SingleAccountPageState.ofAppKeyProvider(context)(
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
    AppKeyViewModel model,
    List<Map<String, dynamic>> list,
    WidgetRef ref,
  ) {
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
                            false)) {
                      return AppKeyItemCell(item, ref);
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
                            false)) {
                      // 卡片间距12px，不用分割线（与定时任务/环境变量一致）
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
    searchText.dispose();
    controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getListByType(AppKeyViewModel model) {
    return model.list;
  }
}

class AppKeyItemCell extends StatelessWidget {
  final Map<String, dynamic> bean;
  final WidgetRef ref;

  const AppKeyItemCell(this.bean, this.ref, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 对齐定时任务卡片方案：外层 margin 12 + CyberSlidable + _buildCardChild(BackdropFilter + 边框光晕)
    // 滑动内容（操作按钮）在 CyberSlidable 的设计下与卡片分离，符合赛博模式视觉规范
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: CyberSlidable(
        slidableKey: ValueKey(getAppKeyId(bean)),
        borderRadius: 18,
        endActions: [
          CyberSlideAction(
            label: '编辑',
            icon: CupertinoIcons.pencil_outline,
            color: const Color(0xFF00F0FF),
            onTap: () {
              Navigator.of(context)
                  .push(
                    WallpaperPageRoute(
                      blurSigma: 6,
                      blurTintColor: CyberColors.bg.withOpacity(0.50),
                      builder: (context) => AddAppKeyPage(bean: bean),
                    ),
                  )
                  .then((value) {
                    if (value != null && value == true) {
                      ref
                          .read(
                            SingleAccountPageState.ofAppKeyProvider(context)(
                              getProviderName(context),
                            ),
                          )
                          .loadData(context);
                    }
                  });
            },
          ),
          CyberSlideAction(
            label: '重置',
            icon: CupertinoIcons.arrow_2_circlepath,
            color: const Color(0xFFA356D6),
            onTap: () {
              WidgetsBinding.instance.endOfFrame.then((value) {
                _reset(context);
              });
            },
          ),
          CyberSlideAction(
            label: '删除',
            icon: CupertinoIcons.delete,
            color: const Color(0xFFFF3D5C),
            onTap: () {
              WidgetsBinding.instance.endOfFrame.then((value) {
                _del(context, ref);
              });
            },
          ),
        ],
        child: _buildCardChild(context),
      ),
    );
  }

  /// 卡片主体：统一毛玻璃封装（sigma<=0 时退化为纯色）+ 边框光晕（与定时任务一致）
  Widget _buildCardChild(BuildContext context) {
    return OptimizedFrostedGlass(
      sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CyberColors.borderGlow, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                WallpaperPageRoute(
                  builder: (context) => AppKeyDetailDetailPage(bean),
                ),
              );
            },
            child: _buildCardContent(context),
          ),
        ),
      ),
    );
  }

  /// 卡片内容：应用名 + scopes 标签
  Widget _buildCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: Text(
              bean["name"] ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                overflow: TextOverflow.ellipsis,
                color: ref.watch(themeProvider).themeColor.titleColor(),
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            runSpacing: 5,
            spacing: 5,
            children: AppKeyViewModel.getScopeNames(
              (bean["scopes"] as List<dynamic>?),
            ).map((e) => TagChip(label: e)).toList(),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  void _del(BuildContext context1, WidgetRef ref) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (isCyber) {
      showCyberConfirmDialog(
        context1,
        title: "确认删除",
        content: "确认删除应用 ${bean["name"] ?? ""} 吗",
        danger: true,
      ).then((confirmed) {
        if (confirmed == true) {
          ref
              .read(
                SingleAccountPageState.ofAppKeyProvider(context1)(
                  getProviderName(context1),
                ),
              )
              .delAppKey(context1, getAppKeyId(bean));
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
            content: Text("确认删除应用 ${bean["name"] ?? ""} 吗"),
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
                        SingleAccountPageState.ofAppKeyProvider(context1)(
                          getProviderName(context1),
                        ),
                      )
                      .delAppKey(context1, getAppKeyId(bean));
                },
              ),
            ],
          ),
    );
  }

  void _reset(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (isCyber) {
      showCyberConfirmDialog(
        context,
        title: "确认重置应用 ${bean["name"]} 的Secret吗",
        content: "重置Secret会让当前应用所有token失效",
        danger: true,
      ).then((confirmed) {
        if (confirmed == true) {
          ref
              .read(
                SingleAccountPageState.ofAppKeyProvider(context)(
                  getProviderName(context),
                ),
              )
              .resetAppKey(context, getAppKeyId(bean));
        }
      });
      return;
    }
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text("确认重置应用 ${bean["name"]} 的Secret吗"),
            content: const Text("重置Secret会让当前应用所有token失效"),
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
                        SingleAccountPageState.ofAppKeyProvider(context)(
                          getProviderName(context),
                        ),
                      )
                      .resetAppKey(context, getAppKeyId(bean));
                },
              ),
            ],
          ),
    );
  }
}

String getAppKeyId(Map<String, dynamic> bean) {
  if (bean.containsKey("_id")) {
    return bean["_id"] ?? "";
  }
  return bean["id"]?.toString() ?? "";
}
