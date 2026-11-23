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
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/highlight/selectable_code_view.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../../main.dart';
import '../../code_editor/codemirror/io.dart';
import '../../code_editor/editor.dart';
import '../../config/config_detail_page.dart';
import '../../home/system_bean.dart';
import 'script_history_page.dart';

class ScriptEditPage extends ConsumerStatefulWidget {
  final String content;
  final String title;
  final String path;

  const ScriptEditPage(this.title, this.path, this.content, {super.key});

  @override
  ConsumerState<ScriptEditPage> createState() => _ScriptEditPageState();
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
          Expanded(child: SearchCell(controller: _searchTextCtrl)),
          const SizedBox(width: 4),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _onSearchPrev, minimumSize: Size(0, 0),
            child: Icon(CupertinoIcons.chevron_up, size: 20, color: iconColor),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _onSearchNext, minimumSize: Size(0, 0),
            child: Icon(
              CupertinoIcons.chevron_down,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 4),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _closeSearchBar, minimumSize: Size(0, 0),
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 22,
              color: iconColor.withValues(alpha: 0.5),
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
    // Scaffold的backgroundColor设为Colors.transparent，让全局壁纸透出来
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
          if (_supportsHistory())
            CupertinoButton(
              color: Colors.transparent,
              padding: EdgeInsets.zero,
              onPressed: _openHistory,
              child: Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Center(
                  child: Icon(
                    Icons.history,
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
                if (!context.mounted) return;
                final api = SingleAccountPageState.ofApi(context);
                HttpResponse<NullResponse> response = await api.updateScript(
                  widget.title,
                  widget.path,
                  result,
                );
                // 2.23.0+：文件或新内容超出历史记录范围（>1 MiB / 非 UTF-8 文本）时，
                // 面板返回 413 + historyUnavailable + currentHash；
                // 用户确认后以 skipHistory + expectedHash 重试（本次不留档）
                if (!response.success &&
                    response.code == 413 &&
                    response.extra?['historyUnavailable'] == true) {
                  final String? currentHash =
                      response.extra?['currentHash']?.toString();
                  await EasyLoading.dismiss();
                  if (!context.mounted) return;
                  final bool? confirmed = await showConfirmDialog(
                    context,
                    title: '不记录历史直接保存？',
                    content: '当前文件或新内容超出历史记录范围，本次覆盖前的内容不会保留。',
                    confirmLabel: '仍然保存',
                  );
                  if (confirmed != true || !context.mounted) return;
                  await EasyLoading.show(status: " 提交中");
                  if (!context.mounted) return;
                  response = await api.updateScript(
                    widget.title,
                    widget.path,
                    result,
                    skipHistory: true,
                    expectedHash: currentHash,
                  );
                }
                await EasyLoading.dismiss();
                if (!context.mounted) return;
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

    // 赛博模式：CyberBackground包裹透明Scaffold，背景透明透出全局壁纸
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  /// 退出确认弹窗（赛博模式用 cyber 弹窗，其余用统一确认弹窗）
  void _showExitConfirm(bool isCyber) {
    if (isCyber) {
      showConfirmDialog(
        context,
        title: "温馨提示",
        content: "你编辑的内容还没用提交,确定退出吗?",
        confirmLabel: "确定",
      ).then((confirmed) {
        if (!mounted) return;
        if (confirmed == true) {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    showConfirmDialog(
      context,
      title: "温馨提示",
      content: "你编辑的内容还没用提交,确定退出吗?",
      confirmLabel: "确定",
    ).then((confirmed) {
      if (!mounted) return;
      if (confirmed != true) return;
      Navigator.of(context).pop();
    });
  }

  /// 面板是否支持脚本历史（2.23.0+ 且为账号密码登录）
  bool _supportsHistory() {
    try {
      if (SingleAccountPageState.ofUserInfo(context).useSecretLogined) {
        return false;
      }
      return getIt<SystemBean>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString(),
      ).isUpperVersion2_23_0();
    } catch (_) {
      return false;
    }
  }

  /// 打开历史版本页；有未提交草稿时禁止恢复（与面板网页端一致）
  Future<void> _openHistory() async {
    final dynamic value = await Navigator.of(context).push(
      WallpaperPageRoute(
        builder:
            (context) => ScriptHistoryPage(
              title: widget.title,
              path: widget.path,
              hasUnsavedChanges: preResult != result,
            ),
        blurSigma: 6,
        blurTintColor: CyberColors.bg.withValues(alpha: 0.50),
      ),
    );
    if (!mounted) return;
    if (value is String && value.isNotEmpty && value != result) {
      _applyRestoredContent(value);
    }
  }

  /// 恢复历史版本后同步编辑器与"未保存"基准
  void _applyRestoredContent(String content) {
    setState(() {
      result = content;
      preResult = content;
    });
    controller?.setValue(content);
  }

  GlobalKey<CodeMirrorViewState> codeKey = GlobalKey();
}
