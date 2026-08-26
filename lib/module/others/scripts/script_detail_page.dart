import 'dart:math';

import 'package:qinglong_app/utils/share_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/cupertino_sheet.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/highlight/selectable_code_view.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/task/add_task_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:path/path.dart' as p;
import 'package:qinglong_app/utils/icloud_utils.dart';

import '../../../main.dart';
import '../../config/config_detail_page.dart';
import '../../home/system_bean.dart';
import 'script_upload_page.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class ScriptDetailPage extends ConsumerStatefulWidget {
  final String title;
  final String? path;

  const ScriptDetailPage({Key? key, required this.title, this.path})
    : super(key: key);

  @override
  _ScriptDetailPageState createState() => _ScriptDetailPageState();
}

class _ScriptDetailPageState extends ConsumerState<ScriptDetailPage>
    with LazyLoadState<ScriptDetailPage> {
  String? content;

  List<Widget> actions = [];

  String getLanguageType(String title) {
    if (title.endsWith(".js")) {
      return 'javascript';
    }

    if (title.endsWith(".sh")) {
      return 'shell';
    }

    if (title.endsWith(".py")) {
      return 'python';
    }
    if (title.endsWith(".json")) {
      return 'json';
    }
    if (title.endsWith(".yaml")) {
      return 'yaml';
    }
    return "shell";
  }

  @override
  void initState() {
    super.initState();
    actions.addAll([
      CupertinoSheer(
        title: "添加到任务",
        onTap: () {
          if (content == null || content!.isEmpty) {
            "未获取到脚本内容,请稍候重试".toast();
            return;
          }
          String command =
              "task ${widget.path}${(widget.path != null && widget.path!.isNotEmpty) ? p.separator : ""}${widget.title} ";
          String? cron = ScriptUploadPageState.getCronString(
            content!,
            widget.title,
          );

          Navigator.of(context).push(
            WallpaperPageRoute(
              builder:
                  (context) => AddTaskPage(
                    taskBean: TaskBean(
                      name: widget.title,
                      command: command,
                      schedule: cron,
                    ),
                    hideUploadFile: true,
                  ),
            ),
          );
        },
      ),
      addDivider(),
      CupertinoSheer(
        title: "编辑",
        onTap: () {
          if (content == null || content!.isEmpty) {
            "未获取到脚本内容,请稍候重试".toast();
            return;
          }
          Navigator.of(context)
              .pushNamed(
                Routes.routeScriptUpdate,
                arguments: {
                  "title": widget.title,
                  "path": widget.path,
                  "content": content,
                },
              )
              .then((value) {
                if (value != null) {
                  content = value.toString();
                  setState(() {});
                }
              });
        },
      ),
      addDivider(),
      CupertinoSheer(
        title: "分享",
        onTap: () {
          ShareUtils.share(content ?? "");
        },
      ),
      addDivider(),
      CupertinoSheer(
        title: "下载",
        onTap: () async {
          try {
            String name = "${Random().nextInt(40000)}_${widget.title}";
            var file = await FileUtil(0).writeDownloadFile(name, content ?? "");
            "已写入qinglong_app文件夹下,文件名$name".toast2();
          } catch (e) {
            e.toString().toast();
          }
        },
      ),
      addDivider(),
      CupertinoSheer(
        title: "删除",
        onTap: () async {
          HapticFeedback.mediumImpact();
          final bool cyber = ref.read(themeProvider).themeMode == modeCyber;

          if (cyber) {
            // 赛博模式：高斯模糊确认弹窗
            final confirmed = await showCyberConfirmDialog(
              context,
              title: "确认删除",
              content: "确认删除该脚本吗",
              confirmLabel: "确定",
              danger: true,
            );
            if (confirmed != true) return;
            await _deleteScript();
          } else {
            // 非赛博模式：使用三模式通用 frosted glass 确认弹窗
            final confirmed = await showConfirmDialog(
              context,
              title: "确认删除",
              content: "确认删除该脚本吗",
              confirmLabel: "确定",
              danger: true,
            );
            if (confirmed != true) return;
            await _deleteScript();
          }
        },
      ),
    ]);
  }

  /// 删除脚本（提取公共逻辑，供赛博/非赛博弹窗共用）
  Future<void> _deleteScript() async {
    SystemBean? systemBean;
    try {
      systemBean = getIt<SystemBean>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString(),
      );
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }
    HttpResponse<NullResponse> result;
    if (systemBean.isUpperVersion2_14_5()) {
      result = await SingleAccountPageState.ofApi(
        context,
      ).delScriptNewVersion(widget.title, widget.path ?? "");
    } else {
      result = await SingleAccountPageState.ofApi(
        context,
      ).delScript(widget.title, widget.path ?? "");
    }
    if (result.success) {
      "删除成功".toast();
      Navigator.of(context).pop(true);
    } else {
      result.message?.toast();
    }
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;

    // 【CyberBackground套用位置】赛博模式下，CyberBackground作为根布局包裹Scaffold
    // Scaffold的backgroundColor设为Colors.transparent，让底层光影渐变透出来
    final Widget scaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          isCyber
              ? Colors.transparent
              : ref.watch(themeProvider).themeColor.codeBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          Navigator.of(context).pop();
        },
        title: widget.title,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () async {
              await hideKeyboardFocus();
              showMoreOperate(context, actions);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Icon(
                  Icons.more_horiz,
                  size: 26,
                  color:
                      isCyber
                          ? CyberColors.cyan
                          : Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ),
            ),
          ),
        ],
      ),
      body:
          content == null
              ? Center(
                child: LoadingWidget(
                  color:
                      isCyber
                          ? CyberColors.cyan
                          : ref.watch(themeProvider).primaryColor,
                ),
              )
              : Container(
                color:
                    isCyber
                        ? Colors.transparent
                        : ref.watch(themeProvider).themeColor.codeBgColor(),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SelectableCodeView(
                    source: content ?? "",
                    language: getLanguageType(widget.title),
                  ),
                ),
              ),
    );

    // 赛博模式：CyberBackground包裹透明Scaffold，光影渐变穿透整个页面
    return isCyber
        ? CyberBackground(child: scaffold)
        : scaffold;
  }

  Future<void> loadData() async {
    HttpResponse<String> response = await SingleAccountPageState.ofApi(
      context,
    ).scriptDetail(widget.title, widget.path);

    if (response.success) {
      content = response.bean;
      setState(() {});
    } else {
      response.message?.toast();
    }
  }

  @override
  void onLazyLoad() {
    loadData();
  }
}
