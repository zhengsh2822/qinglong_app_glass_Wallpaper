import 'package:flutter/services.dart';

class NativeEditorResult {
  final String? content;

  NativeEditorResult({this.content});
}

class NativeEditorUtils {
  static const MethodChannel _channel = MethodChannel('com.qlapp.qinglong_app/webview');

  static Future<NativeEditorResult?> openEditor({
    required String theme,
    required String mode,
    String content = '',
  }) async {
    try {
      final result = await _channel.invokeMethod('openEditor', {
        'theme': theme,
        'mode': mode,
        'content': content,
      });
      if (result != null && result is String) {
        return NativeEditorResult(content: result);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
