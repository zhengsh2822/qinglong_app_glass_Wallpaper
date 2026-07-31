import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_dialog.dart';
import 'package:qinglong_app/base/ui/highlight/selectable_code_view.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_detail_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/language_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../base/sp_const.dart';
import '../code_editor/codemirror/io.dart';
import '../code_editor/editor.dart';

class ConfigEditPage extends ConsumerStatefulWidget {
  final String content;
  final String title;

  const ConfigEditPage(this.title, this.content, {Key? key}) : super(key: key);

  @override
  _ConfigEditPageState createState() => _ConfigEditPageState();
}

class _ConfigEditPageState extends ConsumerState<ConfigEditPage> {
  CodeMirrorOptions options = CodeMirrorOptions();
  EditorController? controller;
  late String result;
  late String preResult;
  List<String> operateList = [];

  /// 选择模式：切换到原生 [SelectableCodeView] 以启用 iOS 风格文本选择放大镜
  /// false = 编辑模式（CodeMirror WebView）；true = 选择模式（原生 SelectableText + 放大镜）
  bool _isSelectionMode = false;

  void remindKeyboard(WidgetRef ref, BuildContext context) {
    if (Platform.isIOS) return;
    if (SpUtil.getBool(spAndroidKeyboardError, defValue: false) == true) {
      return;
    }
    SpUtil.putBool(spAndroidKeyboardError, true);
    showGlassDialog(
      context: context,
      useRootNavigator: false,
      title: const Text("温馨提示"),
      content: const Text("由于Android适配问题,如果你的键盘无法正常使用,请长按文：即可弹出键盘"),
      actions: [
        GlassDialogAction(
          textStyle: TextStyle(
            color: ref.watch(themeProvider).primaryColor,
          ),
          child: const Text("知道："),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    focusNode.dispose();
    EasyLoading.dismiss();
    MultiAccountPageState.clearAction();
    super.dispose();
  }

  @override
  void initState() {
    result = widget.content;
    preResult = widget.content;
    super.initState();
    generateOperateList();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      focusNode.requestFocus();
      checkClipBoard();
      remindKeyboard(ref, context);
    });
  }

  Future<void> notifyICloud(
    BuildContext context,
    String title,
    String content,
  ) async {
    await getIt<ICloudUtils>(
      instanceName: SingleAccountPageState.of(context)?.index.toString() ?? "0",
    ).asyncConfig(title, content);
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          FocusManager.instance.primaryFocus?.unfocus();

          if (preResult == result) {
            Navigator.of(context).pop();
          } else {
            showGlassDialog(
              context: context,
              useRootNavigator: false,
              title: const Text("温馨提示"),
              content: const Text("你编辑的内容还没用提：确定退出吗?"),
              actions: [
                GlassDialogAction(
                  textStyle: const TextStyle(color: Color(0xff999999)),
                  child: const Text("取消"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                GlassDialogAction(
                  textStyle: TextStyle(
                    color: ref.watch(themeProvider).primaryColor,
                  ),
                  child: const Text("确定"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
        },
        title: '编辑${widget.title}',
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (_isSelectionMode) {
                  hideKeyboardFocus();
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Center(
                child: Icon(
                  _isSelectionMode ? Icons.edit : Icons.text_fields,
                  color:
                      isCyber
                          ? CyberColors.cyan
                          : Theme.of(context).appBarTheme.iconTheme?.color,
                  size: 22,
                ),
              ),
            ),
          ),
          if (!_isSelectionMode)
            CupertinoButton(
              color: Colors.transparent,
              padding: EdgeInsets.zero,
              onPressed: () async {
                codeKey.currentState?.showSearchBar();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Center(
                  child: Icon(
                    Icons.search,
                    color: Theme.of(context).appBarTheme.iconTheme?.color,
                    size: 22,
                  ),
                ),
              ),
            ),
          if (!_isSelectionMode)
            Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                onSelected: (String result) {
                  updateValueBykey(result);
                },
                itemBuilder:
                    (BuildContext context) => <PopupMenuEntry<String>>[
                      ...operateList
                          .map(
                            (e) =>
                                PopupMenuItem<String>(child: Text(e), value: e),
                          )
                          .toList(),
                    ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Center(
                    child: Icon(CupertinoIcons.arrow_up_right_diamond, size: 20),
                  ),
                ),
              ),
            ),
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () async {
              try {
                await hideKeyboardFocus();
                await EasyLoading.show(status: " 提交：");
                HttpResponse<NullResponse> response =
                    await SingleAccountPageState.ofApi(
                      context,
                    ).saveFile(widget.title, result);
                if (Platform.isIOS) {
                  await notifyICloud(context, widget.title, result);
                }
                await EasyLoading.dismiss();
                if (response.success) {
                  "提交成功".toast();
                  Navigator.of(context).pop(result);
                } else {
                  (response.message ?? "").toast();
                }
              } catch (e) {
                EasyLoading.dismiss();
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Center(
                child: Text(
                  "提交",
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).appBarTheme.iconTheme?.color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child:
            _isSelectionMode
                ? SelectableCodeView(
                  source: result,
                  language: LanguageUtils.fromFileName(widget.title),
                )
                : Editor(
                  codeMirrorKey: codeKey,
                  options: options,
                  onCreate: (val) {
                    controller = val;
                    controller?.setOptions(options);
                    controller?.setValue(result);
                  },
                  onValue: (val) {
                    result = val;
                  },
                ),
      ),
    );
  }

  GlobalKey<CodeMirrorViewState> codeKey = GlobalKey();

  FocusNode focusNode = FocusNode();

  void generateOperateList() {
    operateList.clear();
    List<String> array = result.split("\n");
    for (String a in array) {
      String t = a.replaceAll(" ", "");
      if (t.trim().startsWith("export")) {
        try {
          int i = t.indexOf("export") + 6;
          int j = t.indexOf("=");
          operateList.add(t.substring(i, j));
        } catch (e) {}
      }
    }
  }

  void updateValueBykey(String key) async {
    String defaultValue = "";
    try {
      var clipBoard = await Clipboard.getData(Clipboard.kTextPlain);

      if (clipBoard != null && clipBoard.text != null) {
        String tempText = clipBoard.text!;

        if (tempText.trim().contains("export")) {
          int i = tempText.trim().indexOf("\"");
          int j = tempText.trim().lastIndexOf("\"");

          if (i == -1 || j == -1) {
            i = tempText.trim().indexOf("'");
            j = tempText.trim().lastIndexOf("'");
          }

          defaultValue = tempText.trim().substring(i + 1, j);
        } else {
          defaultValue = tempText;
        }
      }
    } catch (e) {}

    TextEditingController controller = TextEditingController(
      text: defaultValue.replaceAll("\"", "").replaceAll("'", ""),
    );
    showGlassDialog(
      useRootNavigator: false,
      context: context,
      title: Text(
        "编辑$key:",
        style: const TextStyle(fontWeight: FontWeight.w400),
      ),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          isDense: true,
          hintText: "请输入：",
        ),
        autofocus: false,
      ),
      actions: [
        GlassDialogAction(
          textStyle: const TextStyle(color: Color(0xff999999)),
          child: const Text("取消"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        GlassDialogAction(
          textStyle: TextStyle(
            color: ref.watch(themeProvider).primaryColor,
          ),
          child: const Text("确定"),
          onPressed: () async {
            Navigator.of(context).pop();
            updateValueByKey(key, controller.text);
          },
        ),
      ],
    );
  }

  void updateValueByKey(String key, String text) {
    List<String> array = result.split("\n");
    for (String a in array) {
      String t = a.replaceAll(" ", "");
      if (t.trim().startsWith("export")) {
        int i = t.indexOf("export") + 6;
        int j = t.indexOf("=");

        String tempResult = t.substring(i, j);

        if (tempResult == key) {
          result = result.replaceAll(a, "\nexport $key=\"$text\"\n");
          controller?.setValue(result);
          break;
        }
      }
    }
    setState(() {});
    "已修：".toast();
  }

  void checkClipBoard() async {
    try {
      String key = "";
      String value = "";
      var clipBoard = await Clipboard.getData(Clipboard.kTextPlain);

      if (clipBoard != null && clipBoard.text != null) {
        String tempText = clipBoard.text!;

        if (tempText.trim().contains("export")) {
          int kI = tempText.trim().indexOf("export");
          int kJ = tempText.trim().indexOf("=");

          key = tempText.trim().substring(kI + 6, kJ).trim();

          int i = tempText.trim().indexOf("\"");
          int j = tempText.trim().lastIndexOf("\"");

          if (i == -1 || j == -1) {
            i = tempText.trim().indexOf("'");
            j = tempText.trim().lastIndexOf("'");
          }
          value = tempText.trim().substring(i + 1, j);

          if (key.isNotEmpty && result.contains(key) && value.isNotEmpty) {
            WidgetsBinding.instance.endOfFrame.then((v) {
              updateValueBykey(key);
            });
          }
        }
      }
    } catch (e) {}
  }
}
