import 'package:flutter/services.dart';

class FilePickerResult {
  final String? path;
  final String? name;

  FilePickerResult({this.path, this.name});
}

class FilePickerUtils {
  static const MethodChannel _channel = MethodChannel('com.qlapp.qinglong_app/file_picker');

  static Future<FilePickerResult?> pickFile() async {
    try {
      final result = await _channel.invokeMethod('pickFile');
      if (result != null && result is Map) {
        return FilePickerResult(
          path: result['path'] as String?,
          name: result['name'] as String?,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
