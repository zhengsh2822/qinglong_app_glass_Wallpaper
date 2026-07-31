import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/src/consumer.dart';
import 'package:qinglong_app/main.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../base/theme.dart';
import 'impl.dart';

class CodeMirrorView extends CodeMirrorViewImpl {
  final CodeMirrorOptions options;
  final ValueChanged<EditorController> onCreate;
  final Function(String val) onValue;

  const CodeMirrorView({
    Key? key,
    required this.options,
    required this.onCreate,
    required this.onValue,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return CodeMirrorViewState();
  }
}

class CodeMirrorViewState extends CodeMirrorViewImplState<CodeMirrorView> {
  WebViewController? _controller;
  bool readOnly = false;
  bool isLoaded = false;
  bool isShowSearch = false;

  String get theme => widget.options.theme;
  String get mode => widget.options.mode;

  Future<void> showSearchBar() async {
    if (isShowSearch) {
      await _controller?.runJavaScript('clearSearchText()');
    } else {
      await _controller?.runJavaScript('searchText()');
    }
    isShowSearch = !isShowSearch;
  }

  /// 应用层搜索：传入关键词，在编辑器中搜索并高亮所有匹配，跳转到第一个
  Future<void> appSearch(String query) async {
    // 用 JSON 编码以安全传入 JS
    final encoded = Uri.encodeComponent(query);
    await _controller?.runJavaScript(
      'appSearch(decodeURIComponent("$encoded"))',
    );
  }

  /// 跳转到下一个匹配
  Future<void> appSearchNext() async {
    await _controller?.runJavaScript('appSearchNext()');
  }

  /// 跳转到上一个匹配
  Future<void> appSearchPrev() async {
    await _controller?.runJavaScript('appSearchPrev()');
  }

  /// 清除应用层搜索高亮
  Future<void> clearAppSearch() async {
    await _controller?.runJavaScript('clearSearchText()');
  }

  @override
  Widget build(BuildContext context) {
    final codeBgColor = ref.watch(themeProvider).themeColor.codeBgColor();
    return LayoutBuilder(
      builder: (context, dimens) {
        return KeyboardVisibilityBuilder(
          builder: (context, isKeyboardVisible) {
            if (isLoaded) {
              _controller?.runJavaScript(
                'editor.setSize(${dimens.maxWidth},${dimens.maxHeight})',
              );
            }
            return Stack(
              children: [
                WebViewWidget(
                  controller:
                      _controller ??=
                          WebViewController()
                            ..setJavaScriptMode(JavaScriptMode.unrestricted)
                            ..addJavaScriptChannel(
                              'MessageInvoker',
                              onMessageReceived: (JavaScriptMessage message) {
                                widget.onValue(message.message);
                              },
                            )
                            ..setBackgroundColor(codeBgColor)
                            ..setNavigationDelegate(
                              NavigationDelegate(
                                onPageFinished: (url) {
                                  _controller?.runJavaScript(
                                    'initEditor("$theme","$mode")',
                                  );
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    _controller?.runJavaScript(
                                      'editor.setSize(${dimens.maxWidth},${dimens.maxHeight})',
                                    );
                                    widget.onCreate(
                                      EditorController(
                                        runJavaScript: (script) async {
                                          await _controller?.runJavaScript(
                                            script,
                                          );
                                        },
                                        setOptions: (val) async {
                                          readOnly = val.readOnly;
                                          _controller?.runJavaScript(
                                            'editor.setSize(${dimens.maxWidth},${dimens.maxHeight})',
                                          );
                                          await _controller?.runJavaScript(
                                            'editor.setOption("mode", "${val.mode}")',
                                          );
                                          await _controller?.runJavaScript(
                                            'editor.setOption("theme", "${val.theme}")',
                                          );
                                          await _controller?.runJavaScript(
                                            'editor.setOption("readOnly", ${val.readOnly ? '"nocursor"' : false})',
                                          );
                                          await _controller?.runJavaScript(
                                            'editor.setOption("lineNumbers", ${val.showLineNumber})',
                                          );
                                          await Future.delayed(
                                            const Duration(milliseconds: 200),
                                          );
                                          await _controller?.runJavaScript(
                                            'editor.refresh()',
                                          );
                                          await EasyLoading.dismiss();
                                        },
                                        setValue: (val) async {
                                          isLoaded = true;
                                          final raw = Uri.encodeComponent(val);
                                          _controller?.runJavaScript(
                                            'editor.setValue(decodeURIComponent("$raw"))',
                                          );
                                          if (mounted) setState(() {});
                                        },
                                        refresh: () async {
                                          await Future.delayed(
                                            const Duration(milliseconds: 50),
                                          );
                                          _controller?.runJavaScript(
                                            'editor.refresh()',
                                          );
                                        },
                                      ),
                                    );
                                  });
                                },
                              ),
                            )
                            ..loadFlutterAsset('assets/codemirror.html'),
                ),
                // 加载遮罩：覆盖WebView加载期间的黑色背景
                if (!isLoaded)
                  Positioned.fill(
                    child: ColoredBox(
                      color: codeBgColor,
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
