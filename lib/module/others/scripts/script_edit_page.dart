import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/glass_dialog.dart';
import 'package:qinglong_app/base/ui/highlight/selectable_code_view.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../code_editor/codemirror/io.dart';
import '../../code_editor/editor.dart';
import '../../config/config_detail_page.dart';

class ScriptEditPage extends ConsumerStatefulWidget {
  final String content;
  final String title;
  final String path;

  const ScriptEditPage(this.title, this.path, this.content, {Key? key})
    : super(key: key);

  @override
  _ScriptEditPageState createState() => _ScriptEditPageState();
}

class _ScriptEditPageState extends ConsumerState<ScriptEditPage> {
  late String result;
  late String preResult;
  late CodeMirrorOptions options;
  EditorController? controller;

  // 应用层脚本搜索（点击弹出搜索栏）
  final TextEditingController _searchTextCtrl = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearchOpen = false;

  /// 选择模式：切换到原生 [SelectableCodeView] 以启用 iOS 风格文本选择放大镜
  /// false = 编辑模式（CodeMirror WebView）；true = 选择模式（原生 SelectableText + 放大镜）
  bool _isSelectionMode = false;

  @override
  void dispose() {
    EasyLoading.dismiss();
    _searchDebounce?.cancel();
    _searchTextCtrl.removeListener(_onSearchTextChanged);
    _searchTextCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    options = CodeMirrorOptions().copyWith(
      readOnly: false,
      mode: getLanguageType(widget.title),
    );
    result = widget.content;
    preResult = widget.content;
    super.initState();
    _searchTextCtrl.addListener(_onSearchTextChanged);
  }

  // ============ 应用层脚本搜索 ============

  void _onSearchTextChanged() {
    final text = _searchTextCtrl.text;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (text.isEmpty) {
        codeKey.currentState?.clearAppSearch();
        return;
      }
      codeKey.currentState?.appSearch(text);
    });
  }

  void _toggleSearchBar() {
    if (_isSearchOpen) {
      _closeSearchBar();
    } else {
      setState(() {
        _isSearchOpen = true;
      });
    }
  }

  void _closeSearchBar() {
    _searchDebounce?.cancel();
    _searchTextCtrl.clear();
    codeKey.currentState?.clearAppSearch();
    setState(() {
      _isSearchOpen = false;
    });
  }

  void _onSearchNext() {
    codeKey.currentState?.appSearchNext();
  }

  void _onSearchPrev() {
    codeKey.currentState?.appSearchPrev();
  }

  Widget _buildSearchBar() {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final iconColor = isCyber ? CyberColors.cyan : const Color(0xff5D5E70);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: SearchCell(controller: _searchTextCtrl),
          ),
          const SizedBox(width: 4),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _onSearchPrev,
            child: Icon(
              CupertinoIcons.chevron_up,
              size: 20,
              color: iconColor,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _onSearchNext,
            child: Icon(
              CupertinoIcons.chevron_down,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 4),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _closeSearchBar,
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 22,
              color: iconColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;

    // 【CyberBackground套用位置】赛博模式下，CyberBackground作为根布局包裹Scaffold
    // Scaffold的backgroundColor设为Colors.transparent，让底层光影渐变透出来
    final Widget scaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          FocusManager.instance.primaryFocus?.unfocus();

          if (preResult == result) {
            Navigator.of(context).pop();
          } else {
            _showExitConfirm(isCyber);
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
                  // 切到选择模式时关闭搜索栏与键盘
                  _closeSearchBar();
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
              onPressed: () {
                _toggleSearchBar();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Center(
                  child: Icon(
                    Icons.search,
                    color:
                        isCyber
                            ? CyberColors.cyan
                            : Theme.of(context).appBarTheme.iconTheme?.color,
                    size: 22,
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
                await EasyLoading.show(status: " 提交中");
                HttpResponse<NullResponse> response =
                    await SingleAccountPageState.ofApi(
                      context,
                    ).updateScript(widget.title, widget.path, result);
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
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Text(
                  "提交",
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        isCyber
                            ? CyberColors.cyan
                            : Theme.of(context).appBarTheme.iconTheme?.color,
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
        child: Column(
          children: [
            // 点击弹出的搜索栏（仅编辑模式可用）
            if (!_isSelectionMode && _isSearchOpen) _buildSearchBar(),
            // 选择模式：原生 SelectableCodeView（启用 iOS 风格文本选择放大镜）
            // 编辑模式：CodeMirror WebView
            Expanded(
              child:
                  _isSelectionMode
                      ? SelectableCodeView(
                        source: result,
                        language: getLanguageType(widget.title),
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
          ],
        ),
      ),
    );

    // 赛博模式：CyberBackground包裹透明Scaffold，光影渐变穿透整个页面
    return isCyber
        ? CyberBackground(showGradient: true, child: scaffold)
        : scaffold;
  }

  /// 退出确认弹窗（赛博模式用高斯模糊弹窗，非赛博用CupertinoAlertDialog）
  void _showExitConfirm(bool isCyber) {
    if (isCyber) {
      showCyberConfirmDialog(
        context,
        title: "温馨提示",
        content: "你编辑的内容还没用提交,确定退出吗?",
        confirmLabel: "确定",
      ).then((confirmed) {
        if (confirmed == true) {
          Navigator.of(context).pop();
        }
      });
    } else {
      showGlassDialog(
        context: context,
        useRootNavigator: false,
        title: const Text("温馨提示"),
        content: const Text("你编辑的内容还没用提交,确定退出吗?"),
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
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }
  }

  GlobalKey<CodeMirrorViewState> codeKey = GlobalKey();
}
