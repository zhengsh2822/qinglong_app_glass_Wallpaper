import 'dart:io';

/// 「下载/备份」类功能的公共落盘目录约定。
///
/// Android：系统公共下载目录 /storage/emulated/0/Download 下的子目录，
/// 文件管理器直接可见；Android 11+ 应用经 File API 写公共 Download 无需存储权限。
/// 写入不可用时（Android 10 及以下缺存储权限等）返回 null，调用方自行回退原目录。
/// 非 Android 平台返回 null，调用方沿用各自默认目录（iOS 暂无设备，保持原逻辑）。

/// 脚本/配置「下载」子目录名
const String scriptDownloadFolderName = 'qinglong';

/// 备份导出/扫描子目录名
const String backupFolderName = 'qinglong_backup';

/// 解析 Android 公共下载目录下的指定子目录。
///
/// 目录不存在会自动创建，并用探针文件实测可写（mkdir 成功但写入被拒的场景也能兜住）。
/// 返回 null 表示当前不可用（非 Android 或写入失败），调用方回退各自默认目录。
Future<Directory?> resolveAndroidPublicDownloadSubDirectory(
  String folderName,
) async {
  if (!Platform.isAndroid) {
    return null;
  }
  try {
    final Directory dir = Directory('/storage/emulated/0/Download/$folderName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final File probe = File(
      '${dir.path}/.ql_probe_${DateTime.now().millisecondsSinceEpoch}',
    );
    await probe.writeAsString('');
    await probe.delete();
    return dir;
  } catch (e) {
    return null;
  }
}

/// Android 脚本/配置下载目录：Download/qinglong
Future<Directory?> resolveAndroidScriptDownloadDirectory() {
  return resolveAndroidPublicDownloadSubDirectory(scriptDownloadFolderName);
}

/// Android 备份导出/扫描目录：Download/qinglong_backup
Future<Directory?> resolveAndroidBackupDirectory() {
  return resolveAndroidPublicDownloadSubDirectory(backupFolderName);
}
