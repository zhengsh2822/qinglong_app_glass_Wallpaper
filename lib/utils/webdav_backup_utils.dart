import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/utils/crypto_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/webdav_client.dart';
import 'package:qinglong_app/utils/wd_dbg.dart';

/// 备份/还原进度回调：stage 为阶段文案，progress 为 0.0~1.0（null = 不确定态）
typedef WebDavProgressCallback = void Function(String stage, double? progress);

/// WebDAV 云备份编排层。
///
/// 两种备份：
/// 1. 数据快照（_data.qlbak）：环境变量 + config.sh + 订阅 + 账号连接信息，JSON 明文整体 AES-GCM 加密；
/// 2. 全量面板包（_full.qlbak）：面板导出 API 生成的 .tgz 原始字节加密上传。
///
/// 远端路径：`<远程目录>/<host清洗>/<yyyy-MM-dd_HH-mm-ss>[_data|_full].qlbak`。
/// 本模块不做任何 VIP 检查（本项目无 VIP 限制）。
class WebDavBackupUtils {
  /// 自动备份防抖间隔
  static const int _autoDebounceSeconds = 80;

  // ==================== 配置 ====================

  static String _cfg(String key) => SpUtil.getString(key, defValue: "").trim();

  /// 服务器配置是否齐全（自动备份守卫用，静默）
  static bool _isConfigured() {
    return _cfg(spWebDavUrl).isNotEmpty &&
        _cfg(spWebDavUser).isNotEmpty &&
        SpUtil.getString(spWebDavPassword, defValue: "").isNotEmpty &&
        SpUtil.getString(spWebDavEncryptPass, defValue: "").isNotEmpty;
  }

  /// 构造客户端（未配置则抛异常）
  static WebDavClient _requireClient() {
    final url = _cfg(spWebDavUrl);
    final user = _cfg(spWebDavUser);
    final pass = SpUtil.getString(spWebDavPassword, defValue: "");
    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      throw Exception("请先配置 WebDAV 服务器地址、账号和应用密码");
    }
    return WebDavClient(url, user: user, password: pass);
  }

  static String _requireEncryptPass() {
    final pass = SpUtil.getString(spWebDavEncryptPass, defValue: "");
    if (pass.isEmpty) {
      throw Exception("请先设置备份加密口令");
    }
    return pass;
  }

  /// 远端 host 子目录（相对路径，不含首尾斜杠），如 qinglong_app_backup/example.com-5700
  static Future<String> hostDir(int index) async {
    String base = _cfg(spWebDavDir);
    if (base.isEmpty) base = "/qinglong_app_backup";
    base = base.replaceAll(RegExp(r"^/+"), "").replaceAll(RegExp(r"/+$"), "");
    if (base.isEmpty) base = "qinglong_app_backup";
    return "$base/${sanitizeHost(currentHost(index))}";
  }

  /// 当前账号面板地址（取不到返回 null）
  static String? currentHost(int index) {
    try {
      return getIt<UserInfoViewModel>(instanceName: index.toString()).host;
    } catch (_) {
      return null;
    }
  }

  /// host 清洗为目录名（与 ICloudUtils.FileUtil.getHost 同规则）
  static String sanitizeHost(String? host) {
    if (host == null) return "unknown";
    final temp = host
        .trim()
        .replaceAll("http://", "")
        .replaceAll("https://", "")
        .replaceAll("/", "-")
        .replaceAll("\\", "-")
        .replaceAll(":", "-")
        .replaceAll("*", "_")
        .replaceAll("??", "_")
        .replaceAll("<", "_")
        .replaceAll(">", "_")
        .replaceAll("|", "_");
    return temp.isEmpty ? "unknown" : temp;
  }

  static String _stamp() =>
      DateFormat("yyyy-MM-dd_HH-mm-ss").format(DateTime.now());

  static String _nowText() =>
      DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());

  // ==================== 测试连接 ====================

  static Future<void> testConnection() async {
    final client = _requireClient();
    await client.ping();
  }

  // ==================== 数据快照 ====================

  /// 拉取三件套 + 账号信息并加密上传。失败抛 Exception。
  static Future<void> backupAll(
    int index, {
    WebDavProgressCallback? onProgress,
  }) async {
    WdDbg.log("B0 enter");
    final client = _requireClient();
    WdDbg.log("B1 client ok");
    final encPass = _requireEncryptPass();
    WdDbg.log("B2 pass ok");

    onProgress?.call("拉取面板数据", 0.0);
    final payload = await _collectPayload(index, onProgress);
    WdDbg.log("B3 payload size=${payload.toString().length}");
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    WdDbg.log("B4 encoded ${plain.length}");

    onProgress?.call("加密备份", null);
    final encrypted = await CryptoUtils.encryptBytes(plain, encPass);
    WdDbg.log("B5 encrypted ${encrypted.length}");

    final dir = await hostDir(index);
    WdDbg.log("B6 dir=$dir");
    await client.mkcolAll(dir);
    WdDbg.log("B7 mkcol ok");
    await client.putBytes(
      "$dir/${_stamp()}_data.qlbak",
      encrypted,
      onSendProgress:
          (sent, total) =>
              onProgress?.call("上传备份", total > 0 ? sent / total : null),
    );
    WdDbg.log("B8 put done");
    await SpUtil.putString(spWebDavLastBackTime, _nowText());
    WdDbg.log("B9 all done");
  }

  /// 汇总备份 payload（env / config.sh / 订阅 / 账号）
  static Future<Map<String, dynamic>> _collectPayload(
    int index,
    WebDavProgressCallback? onProgress,
  ) async {
    WdDbg.log("C0 collect start");
    onProgress?.call("拉取面板数据", 0.05);
    final api = Api(index);

    final envResult = await api.envs("");
    WdDbg.log("C1 envs done success=${envResult.success}");
    onProgress?.call("拉取面板数据", 0.45);
    if (!envResult.success) {
      throw Exception("拉取环境变量失败：${envResult.message ?? "未知错误"}");
    }

    String configContent = "";
    try {
      final cfgResult = await api.content("config.sh");
      WdDbg.log("C2 config done");
      onProgress?.call("拉取面板数据", 0.65);
      if (cfgResult.success) {
        configContent = cfgResult.bean ?? "";
      }
    } catch (_) {
      // config.sh 拉取失败不阻塞整体备份（部分面板可能无权限）
    }

    List<dynamic> subList = [];
    try {
      final subResult = await api.subscribes();
      WdDbg.log("C3 subs done");
      onProgress?.call("拉取面板数据", 0.85);
      final raw = subResult.bean;
      if (subResult.success && raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) subList = decoded;
      }
    } catch (_) {}

    List<dynamic> historyList = [];
    List<dynamic> tokenList = [];
    try {
      final h = jsonDecode(SpUtil.getString(spLoginHistory, defValue: "[]"));
      if (h is List) historyList = h;
    } catch (_) {}
    try {
      final t = jsonDecode(SpUtil.getString(spTokenBeanList, defValue: "[]"));
      if (t is List) tokenList = t;
    } catch (_) {}

    WdDbg.log("C4 sp done");
    onProgress?.call("拉取面板数据", 1.0);
    return {
      "v": 1,
      "createdAt": _nowText(),
      "host": currentHost(index) ?? "",
      "env": envResult.bean?.map((e) => e.toJson()).toList() ?? [],
      "config": {"title": "config.sh", "content": configContent},
      "subscribe": subList,
      "accounts": {"history": historyList, "tokens": tokenList},
    };
  }

  /// 自动备份入口：开关开启 + 配置齐全 + 80 秒防抖；静默失败不打扰用户。
  static Future<void> maybeAutoBackup(int index) async {
    try {
      if (!SpUtil.getBool(spWebDavAuto, defValue: false)) return;
      if (!_isConfigured()) return;
      final last = SpUtil.getString(spWebDavLastAutoBackTime, defValue: "");
      if (last.isNotEmpty) {
        final t = DateTime.tryParse(last);
        if (t != null &&
            DateTime.now().difference(t).inSeconds < _autoDebounceSeconds) {
          return;
        }
      }
      // 先记时间再上传，避免连发请求排队堆积
      await SpUtil.putString(
        spWebDavLastAutoBackTime,
        DateTime.now().toIso8601String(),
      );
      await backupAll(index);
    } catch (e) {
      logger.e("WebDAV 自动备份失败: $e");
    }
  }

  /// 下载数据快照并还原（env 清空重建 / 订阅重建 / config 覆盖 / 账号合并）。
  /// [encPass] 为用户在还原时手动输入的加密口令。失败抛 Exception。
  static Future<void> restoreSnapshot(
    Uint8List encrypted,
    int index,
    String encPass, {
    WebDavProgressCallback? onProgress,
  }) async {
    if (encPass.isEmpty) {
      throw Exception("请先输入加密口令");
    }
    onProgress?.call("还原数据", null);
    final plain = await CryptoUtils.decryptBytes(encrypted, encPass);
    final payload = jsonDecode(utf8.decode(plain));
    if (payload is! Map<String, dynamic>) {
      throw Exception("备份内容格式错误");
    }
    await _restorePayload(payload, index);
  }

  static Future<void> _restorePayload(
    Map<String, dynamic> payload,
    int index,
  ) async {
    final api = Api(index);

    // ---- 环境变量：清空现有后重建（与 iCloud 还原行为一致）----
    final envList = payload["env"];
    if (envList is List && envList.isNotEmpty) {
      final envs =
          envList
              .whereType<Map>()
              .map((e) => EnvBean.fromJson(Map<String, dynamic>.from(e)))
              .toList();
      try {
        final exist = await api.envs("");
        if (exist.success && exist.bean != null && exist.bean!.isNotEmpty) {
          await api.delEnvs(exist.bean!.map((e) => e.sId!).toList());
        }
      } catch (_) {}
      for (final v in envs) {
        if (v.name == null || v.value == null) continue;
        await api.addEnv(v.name!, v.value!, v.remarks ?? "");
      }
    }

    // ---- 订阅：去掉服务端生成字段后逐条重建 ----
    final subList = payload["subscribe"];
    if (subList is List) {
      for (final item in subList) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        map.remove("id");
        map.remove("status");
        map.remove("pid");
        map.remove("is_disabled");
        map.remove("log_path");
        map.remove("createdAt");
        map.remove("updatedAt");
        try {
          await api.addSubscribes(map);
        } catch (_) {}
      }
    }

    // ---- config.sh：直接覆盖保存 ----
    final cfg = payload["config"];
    if (cfg is Map && cfg["content"] != null) {
      final title = (cfg["title"] ?? "config.sh").toString();
      try {
        await api.saveFile(title, cfg["content"].toString());
      } catch (_) {}
    }

    // ---- 账号连接信息：按 host 去重合并 ----
    _mergeAccounts(payload["accounts"]);
  }

  static void _mergeAccounts(dynamic accounts) {
    if (accounts is! Map) return;
    final vm = getIt<MultiAccountUserInfoViewModel>();

    final history = accounts["history"];
    if (history is List) {
      for (final item in history) {
        try {
          if (item is! Map) continue;
          final bean = UserInfoBean.fromJson(Map<String, dynamic>.from(item));
          if (bean.host == null) continue;
          if (!vm.historyAccounts.any((e) => e.host == bean.host)) {
            vm.save2HistoryAccount(bean);
          }
        } catch (_) {}
      }
    }

    final tokens = accounts["tokens"];
    if (tokens is List) {
      for (final item in tokens) {
        try {
          if (item is! Map) continue;
          final bean = TokenBean.fromJson(Map<String, dynamic>.from(item));
          if (bean.host == null || bean.token == null) continue;
          if (!vm.tokenBeans.any((e) => e.host == bean.host)) {
            vm.updateToken(
              vm.tokenBeans.length,
              bean.host,
              bean.token,
              bean.useSecretLogined,
              bean.alias,
            );
          }
        } catch (_) {}
      }
    }
  }

  // ==================== 全量面板包 ====================

  /// 面板导出 .tgz → 分块流式加密 → 流式上传。
  /// types 为勾选的数据目录（base 固定包含）。大文件全程不整体载入内存。
  static Future<void> backupFullPanel(
    int index,
    List<String> types, {
    WebDavProgressCallback? onProgress,
  }) async {
    final client = _requireClient();
    final encPass = _requireEncryptPass();

    final tmpDir = Directory(
      "${(await getTemporaryDirectory()).path}${Platform.pathSeparator}webdav_full",
    );
    await tmpDir.create(recursive: true);
    final stamp = _stamp();
    final tgzPath = "${tmpDir.path}${Platform.pathSeparator}full_$stamp.tgz";
    final encPath = "${tmpDir.path}${Platform.pathSeparator}full_$stamp.qlbak";

    try {
      onProgress?.call("导出面板数据", null);
      final error = await Api(index).exportData(
        tgzPath,
        type: types,
        onReceiveProgress:
            (received, total) =>
                onProgress?.call("导出面板数据", total > 0 ? received / total : null),
      );
      if (error != null) {
        throw Exception("面板导出失败：$error");
      }
      if (await File(tgzPath).length() <= 0) {
        throw Exception("面板导出内容为空");
      }

      onProgress?.call("加密备份", 0.0);
      // 分块流式加密 + 独立 isolate + 逐块进度上报（主线程零运算，进度环带百分比）
      await CryptoUtils.encryptFileToContainer(
        tgzPath,
        encPath,
        encPass,
        onProgress: (p) => onProgress?.call("加密备份", p),
      );

      final dir = await hostDir(index);
      await client.mkcolAll(dir);
      await client.putFile(
        "$dir/${stamp}_full.qlbak",
        File(encPath),
        onSendProgress:
            (sent, total) =>
                onProgress?.call("上传备份", total > 0 ? sent / total : null),
      );
    } finally {
      try {
        await File(tgzPath).delete();
      } catch (_) {}
      try {
        await File(encPath).delete();
      } catch (_) {}
    }
  }

  /// 流式下载全量包 → 分块流式解密 → 临时 .tgz → importData 覆盖面板 → reloadSystem。
  /// [encPass] 为用户在还原时手动输入的加密口令。
  static Future<void> restoreFullPanel(
    int index,
    String fileName,
    String encPass, {
    WebDavProgressCallback? onProgress,
  }) async {
    if (encPass.isEmpty) {
      throw Exception("请先输入加密口令");
    }
    final client = _requireClient();

    final tmpDir = Directory(
      "${(await getTemporaryDirectory()).path}${Platform.pathSeparator}webdav_restore",
    );
    await tmpDir.create(recursive: true);
    final stamp = _stamp();
    final encPath =
        "${tmpDir.path}${Platform.pathSeparator}restore_$stamp.qlbak";
    final tgzPath = "${tmpDir.path}${Platform.pathSeparator}restore_$stamp.tgz";

    try {
      final dir = await hostDir(index);
      onProgress?.call("下载备份", null);
      await client.downloadToFile(
        "$dir/$fileName",
        encPath,
        onReceiveProgress:
            (received, total) =>
                onProgress?.call("下载备份", total > 0 ? received / total : null),
      );
      onProgress?.call("解密备份", 0.0);
      // 分块流式解密 + 独立 isolate + 逐块进度上报
      await CryptoUtils.decryptFileContainer(
        encPath,
        tgzPath,
        encPass,
        onProgress: (p) => onProgress?.call("解密备份", p),
      );

      onProgress?.call("导入面板", null);
      final result = await Api(index).importData(
        tgzPath,
        onSendProgress:
            (sent, total) =>
                onProgress?.call("导入面板", total > 0 ? sent / total : null),
      );
      if (!result.success) {
        throw Exception(result.message ?? "面板导入失败");
      }
      onProgress?.call("重载面板", null);
      await Api(index).reloadSystem("data");
    } finally {
      try {
        await File(encPath).delete();
      } catch (_) {}
      try {
        await File(tgzPath).delete();
      } catch (_) {}
    }
  }

  // ==================== 文件列表 / 删除 ====================

  /// 列出远端备份文件（.qlbak，新的在前）
  static Future<List<WebDavFile>> listBackups(int index) async {
    final client = _requireClient();
    final dir = await hostDir(index);
    return client.list(dir);
  }

  /// 下载指定备份文件（传文件名，自动拼 host 目录）
  static Future<Uint8List> downloadBackup(
    int index,
    String fileName, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final client = _requireClient();
    final dir = await hostDir(index);
    return client.getBytes(
      "$dir/$fileName",
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 删除指定备份文件
  static Future<void> deleteBackup(int index, String fileName) async {
    final client = _requireClient();
    final dir = await hostDir(index);
    await client.delete("$dir/$fileName");
  }
}
