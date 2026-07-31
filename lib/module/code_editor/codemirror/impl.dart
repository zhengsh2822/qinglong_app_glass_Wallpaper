import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class CodeMirrorOptions {
  CodeMirrorOptions({this.mode = 'shell', this.readOnly = false}) {
    final int style = SpUtil.getInt(spThemeStyle, defValue: modeCyber);
    theme = (style == modeDark || style == modeCyber) ? "3024-night" : "neat";
    showLineNumber = SpUtil.getBool(spShowLine, defValue: false);
  }

  late final bool showLineNumber;
  final String mode;
  late final String theme;
  final bool readOnly;

  CodeMirrorOptions copyWith({String? mode, String? theme, bool? readOnly}) {
    return CodeMirrorOptions(
      mode: mode ?? this.mode,
      readOnly: readOnly ?? this.readOnly,
    );
  }
}

class EditorController {
  EditorController({
    required this.setValue,
    required this.setOptions,
    required this.refresh,
    this.runJavaScript,
  });

  final void Function(String val) setValue;
  final void Function(CodeMirrorOptions val) setOptions;
  final void Function() refresh;

  /// 可选：直接执行 WebView 中的 JS（搜索/跳转等场景使用）
  final Future<void> Function(String script)? runJavaScript;
}

abstract class CodeMirrorViewImpl extends ConsumerStatefulWidget {
  const CodeMirrorViewImpl({Key? key}) : super(key: key);
}

abstract class CodeMirrorViewImplState<T extends CodeMirrorViewImpl>
    extends ConsumerState<T> {}
