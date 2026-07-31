import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/highlight/selectable_code_view.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/glass_dialog.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';

class ScriptCodeDetailPage extends ConsumerStatefulWidget {
  final String title;
  final String content;
  final bool canRestore;
  final String? absPath;

  const ScriptCodeDetailPage({
    Key? key,
    required this.title,
    required this.content,
    this.absPath,
    this.canRestore = false,
  }) : super(key: key);

  @override
  ScriptCodeDetailPageState createState() => ScriptCodeDetailPageState();
}

class ScriptCodeDetailPageState extends ConsumerState<ScriptCodeDetailPage>
    with LazyLoadState<ScriptCodeDetailPage> {
  bool buttonshow = false;

  getLanguageType(String title) {
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
      return 'shell';
    }
    if (title.endsWith(".yaml")) {
      return 'yaml';
    }
    return "shell";
  }

  bool showTable = true;
  String? content;

  bool isJsonFile() {
    return (widget.absPath?.endsWith(".${FileUtil.env}") ?? false) ||
        (widget.absPath?.endsWith(".${FileUtil.subscribe}") ?? false);
  }

  String getPrettyJSONString() {
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    String jsonString = encoder.convert(jsonDecode(content ?? "[]"));
    return jsonString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          isJsonFile()
              ? FloatingActionButton(
                child: const Icon(Icons.grid_on),
                onPressed: () {
                  setState(() {
                    showTable = !showTable;
                  });
                },
              )
              : const Visibility(visible: false, child: SizedBox.shrink()),
      appBar: QlAppBar(
        canBack: true,
        actions: [
          !widget.canRestore
              ? const SizedBox.shrink()
              : CupertinoButton(
                color: Colors.transparent,
                padding: EdgeInsets.zero,
                onPressed: () {
                  showGlassDialog(
                    context: context,
                    useRootNavigator: false,
                    title: const Text("温馨提示"),
                    content: const Text("确定还原吗?"),
                    actions: [
                      GlassDialogAction(
                        child: const Text("取消"),
                        textStyle: const TextStyle(color: Color(0xff999999)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      GlassDialogAction(
                        child: const Text("确定"),
                        textStyle: TextStyle(
                          color: ref.watch(themeProvider).primaryColor,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          if (widget.title.endsWith(".${FileUtil.env}")) {
                            getIt<ICloudUtils>(
                              instanceName:
                                  (SingleAccountPageState.of(
                                            context,
                                          )?.index ??
                                          0)
                                      .toString(),
                            ).restoreEnv(widget.absPath!);
                          } else if (widget.title.endsWith(
                            ".${FileUtil.config}",
                          )) {
                            getIt<ICloudUtils>(
                              instanceName:
                                  (SingleAccountPageState.of(
                                            context,
                                          )?.index ??
                                          0)
                                      .toString(),
                            ).restoreConfig(widget.absPath!);
                          } else if (widget.title.endsWith(
                            ".${FileUtil.subscribe}",
                          )) {
                            getIt<ICloudUtils>(
                              instanceName:
                                  (SingleAccountPageState.of(
                                            context,
                                          )?.index ??
                                          0)
                                      .toString(),
                            ).restoreSubscribe(widget.absPath!);
                          } else {
                            "不支持还原该文件".toast();
                          }
                        },
                      ),
                    ],
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Center(
                    child: Text(
                      "还原",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).appBarTheme.iconTheme?.color,
                      ),
                    ),
                  ),
                ),
              ),
        ],
        title: widget.title,
      ),
      body:
          (content == null)
              ? const Center(child: LoadingWidget())
              : SafeArea(
                top: false,
                child:
                    isJsonFile()
                        ? json()
                        : SelectableCodeView(
                          source: content ?? "",
                          language: getLanguageType(widget.title),
                        ),
              ),
    );
  }

  Widget json() {
    return Center(
      child: SelectableText(
        getPrettyJSONString(),
        selectionControls: cupertinoTextSelectionControls,
        selectionWidthStyle: BoxWidthStyle.max,
        selectionHeightStyle: BoxHeightStyle.max,
      ),
    );
  }

  @override
  void onLazyLoad() {
    content = widget.content;
    setState(() {});
  }
}
