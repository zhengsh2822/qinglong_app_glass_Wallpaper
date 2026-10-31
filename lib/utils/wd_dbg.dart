import 'dart:io';

/// 临时诊断：WebDAV 备份链路文件日志（定位卡死点后整体移除）
class WdDbg {
  static bool _failed = false;
  static void log(String msg) {
    if (_failed) return;
    try {
      File('${Directory.systemTemp.path}/wdtest.log').writeAsStringSync(
        '${DateTime.now().millisecondsSinceEpoch} $msg\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      _failed = true;
    }
  }
}
