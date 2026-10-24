import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 调试日志：写入应用私有文档目录 ql_debug.log。
///
/// 设备 logcat 被 MIUI/HyperOS 禁用（ring buffer 0 可读）时的替代通道；
/// debug 包可用 `adb exec-out run-as com.qlapp.qinglong_app cat files/ql_debug.log`
/// 读取（applicationDocumentsDirectory 即 /data/user/0/<pkg>/app_flutter）。
/// 仅调试构建启用，release 零开销。
class QlDebugLog {
  static File? _file;
  static Future<void> _queue = Future.value();

  /// 挂接全局错误收集（Flutter 框架异常 + 未捕获异步异常）。
  static void init() {
    if (!kDebugMode) return;
    FlutterError.onError = (details) {
      write('FLUTTER ERROR: ${details.exception}\n${details.stack}');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      write('UNCAUGHT ERROR: $error\n$stack');
      return true;
    };
  }

  static void write(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
    _queue = _queue.then((_) async {
      try {
        _file ??= File(
          '${(await getApplicationDocumentsDirectory()).path}/ql_debug.log',
        );
        final stamp = DateTime.now().toString().substring(11, 23);
        await _file!.writeAsString('$stamp $message\n', mode: FileMode.append);
      } catch (_) {}
    });
  }
}
