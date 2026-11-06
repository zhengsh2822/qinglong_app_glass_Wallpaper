import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/progress_ring_loader.dart';
import 'package:qinglong_app/base/ui/selectable_chip.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/wd_dbg.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/webdav_backup_utils.dart';
import 'package:qinglong_app/utils/webdav_client.dart';

/// WebDAV 云备份页：数据快照（自动+手动）+ 全量面板包（手动），加密上传到用户自己的 WebDAV。
class WebDavPage extends ConsumerStatefulWidget {
  const WebDavPage({super.key});

  @override
  ConsumerState<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends ConsumerState<WebDavPage>
    with LazyLoadState<WebDavPage> {
  /// 全量备份内容选项（对齐青龙官方导出 API 的 type 枚举，与备份页一致）
  static const Map<String, String> _backupOptions = {
    'base': '基础数据',
    'config': '配置文件',
    'scripts': '脚本文件',
    'log': '日志文件',
    'deps': '依赖文件',
    'syslog': '系统日志',
    'dep_cache': '依赖缓存',
    'raw': '远程脚本缓存',
    'repo': '远程仓库缓存',
    'ssh.d': 'SSH 文件缓存',
  };
  static const String _baseKey = 'base';
  final Set<String> _selected = {'base', 'config', 'scripts'};

  int get _index => SingleAccountPageState.of(context)?.index ?? 0;

  String _cfg(String key) => SpUtil.getString(key, defValue: "").trim();

  String _err(Object e) =>
      e.toString().replaceFirst(RegExp(r"^Exception:\s*"), "");

  /// 备份时若无口令则现场设置；口令可随时在服务器配置中更改
  Future<bool> _ensureEncryptPass() async {
    if (SpUtil.getString(spWebDavEncryptPass, defValue: "").isNotEmpty) {
      return true;
    }
    final v = await showInputDialog(
      context,
      title: "设置加密口令",
      content: "本次备份将使用该口令加密，之后可在服务器配置中更改；还原对应备份时需输入备份时的口令",
      hintText: "加密口令",
      obscureText: true,
    );
    if (v == null || v.trim().isEmpty) return false;
    SpUtil.putString(spWebDavEncryptPass, v.trim());
    return true;
  }

  /// 还原时输入加密口令
  Future<String?> _inputDecryptPass() {
    return showInputDialog(
      context,
      title: "请输入加密口令",
      hintText: "备份时设置的加密口令",
      obscureText: true,
    );
  }

  @override
  void onLazyLoad() {}

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(title: "WebDAV备份"),
      body: SingleChildScrollView(
        primary: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              const SectionHeader(
                title: "备份到你自己的 WebDAV 服务器（坚果云 / 群晖NAS / OpenList 等）",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              _buildServerCard(),
              const SizedBox(height: 5),
              _buildAutoCard(),
              const SizedBox(height: 15),
              const SectionHeader(
                title: "数据快照（环境变量 / config.sh / 订阅 / 账号信息）",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              _buildSnapshotCard(),
              const SizedBox(height: 15),
              const SectionHeader(
                title: "全量面板包（.tgz，仅手动）",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              _buildFullCard(),
              const SizedBox(height: 15),
              _buildTips(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  // ==================== 服务器配置 ====================

  Widget _buildServerCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _configRow(
            "服务器地址",
            spWebDavUrl,
            hint: "https://dav.jianguoyun.com/dav/",
          ),
          const Divider(height: 1, indent: 15),
          _configRow("账号", spWebDavUser),
          const Divider(height: 1, indent: 15),
          _configRow("应用密码", spWebDavPassword, obscure: true),
          const Divider(height: 1, indent: 15),
          _configRow("远程目录", spWebDavDir, hint: "默认 /qinglong_app_backup"),
          const Divider(height: 1, indent: 15),
          _configRow("加密口令", spWebDavEncryptPass, obscure: true),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(
            title: "测试连接",
            onTap: () async {
              try {
                QlProgressOverlay.show(context, status: "连接中");
                await WebDavBackupUtils.testConnection();
                QlProgressOverlay.dismiss();
                "连接成功".toast();
              } catch (e) {
                QlProgressOverlay.dismiss();
                _err(e).toast2();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _configRow(
    String title,
    String key, {
    String hint = "",
    bool obscure = false,
  }) {
    final String value = _cfg(key);
    String display;
    if (obscure) {
      display = value.isEmpty ? "未设置" : "已设置";
    } else if (value.isEmpty) {
      display = hint.isEmpty ? "未设置" : hint;
    } else {
      display = value;
    }
    return SettingsTapRow(
      title: title,
      onTap: () async {
        final v = await showInputDialog(
          context,
          title: "请输入$title",
          initialValue: obscure ? "" : value,
          hintText: hint,
          obscureText: obscure,
        );
        if (v == null) return;
        SpUtil.putString(key, v.trim());
        setState(() {});
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: ref.watch(themeProvider).themeColor.descColor(),
              ),
            ),
          ),
          Icon(
            CupertinoIcons.right_chevron,
            size: 16,
            color: ref.watch(themeProvider).themeColor.descColor(),
          ),
        ],
      ),
    );
  }

  // ==================== 自动备份 ====================

  Widget _buildAutoCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSwitchRow(
            title: "自动备份",
            value: SpUtil.getBool(spWebDavAuto, defValue: false),
            onChanged: (v) {
              SpUtil.putBool(spWebDavAuto, v);
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
            child: Text(
              "环境变量 / config / 订阅变更时自动上传，80 秒内只上传一次",
              style: TextStyle(
                fontSize: 12,
                color: ref.watch(themeProvider).themeColor.descColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 数据快照 ====================

  Widget _buildSnapshotCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsTapRow(
            title: "立即备份",
            onTap: _doBackupAll,
            trailing: _timeTrailing(
              SpUtil.getString(spWebDavLastBackTime, defValue: ""),
            ),
          ),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "还原备份", onTap: () => _doRestoreSnapshot()),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "删除备份", onTap: () => _doDelete("any")),
        ],
      ),
    );
  }

  Widget _timeTrailing(String time) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            color: ref.watch(themeProvider).themeColor.descColor(),
          ),
        ),
        Icon(
          CupertinoIcons.right_chevron,
          size: 16,
          color: ref.watch(themeProvider).themeColor.descColor(),
        ),
      ],
    );
  }

  Future<void> _doBackupAll() async {
    WdDbg.log("A0 tap");
    if (!await _ensureEncryptPass()) return;
    WdDbg.log("A1 pass ok");
    if (!mounted) return;
    try {
      QlProgressOverlay.show(context, status: "备份中");
      WdDbg.log("A2 overlay");
      await WebDavBackupUtils.backupAll(
        _index,
        onProgress:
            (stage, progress) =>
                QlProgressOverlay.update(status: stage, progress: progress),
      );
      QlProgressOverlay.dismiss();
      "备份成功".toast();
      setState(() {});
    } catch (e) {
      QlProgressOverlay.dismiss();
      _err(e).toast2();
    }
  }

  Future<void> _doRestoreSnapshot() async {
    final file = await _pickFile("data");
    if (file == null || !mounted) return;
    final bool? ok = await showConfirmDialog(
      context,
      title: "还原备份",
      content: "将清空面板现有环境变量后按备份重建，订阅和 config.sh 也会被覆盖，确认继续？",
      danger: true,
    );
    if (ok != true || !mounted) return;
    final pass = await _inputDecryptPass();
    if (pass == null || pass.isEmpty || !mounted) return;
    try {
      QlProgressOverlay.show(context, status: "下载备份");
      final bytes = await WebDavBackupUtils.downloadBackup(
        _index,
        file.name,
        onReceiveProgress:
            (received, total) => QlProgressOverlay.update(
              status: "下载备份",
              progress: total > 0 ? received / total : null,
            ),
      );
      await WebDavBackupUtils.restoreSnapshot(
        bytes,
        _index,
        pass,
        onProgress:
            (stage, progress) =>
                QlProgressOverlay.update(status: stage, progress: progress),
      );
      QlProgressOverlay.dismiss();
      "还原完成，请刷新面板数据查看".toast();
    } catch (e) {
      QlProgressOverlay.dismiss();
      _err(e).toast2();
    }
  }

  Future<void> _doDelete(String kind) async {
    final file = await _pickFile(kind);
    if (file == null || !mounted) return;
    final bool? ok = await showConfirmDialog(
      context,
      title: "删除备份",
      content: "确定删除远程备份「${file.name}」？删除后不可恢复。",
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      QlProgressOverlay.show(context, status: "删除中");
      await WebDavBackupUtils.deleteBackup(_index, file.name);
      QlProgressOverlay.dismiss();
      "删除成功".toast();
    } catch (e) {
      QlProgressOverlay.dismiss();
      _err(e).toast2();
    }
  }

  // ==================== 全量面板包 ====================

  Widget _buildFullCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 8),
            child: Text(
              "备份内容（基础数据固定包含，不可取消）",
              style: TextStyle(
                fontSize: 13,
                color: ref.watch(themeProvider).themeColor.descColor(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _backupOptions.entries.map((entry) {
                    final isBase = entry.key == _baseKey;
                    final selected = isBase || _selected.contains(entry.key);
                    return SelectableChip(
                      label: entry.value,
                      selected: selected,
                      onToggle:
                          isBase
                              ? null
                              : (v) {
                                setState(() {
                                  v
                                      ? _selected.add(entry.key)
                                      : _selected.remove(entry.key);
                                });
                              },
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "备份并上传全量包", onTap: _doBackupFull),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "还原全量包", onTap: _doRestoreFull),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "删除备份", onTap: () => _doDelete("full")),
        ],
      ),
    );
  }

  Future<void> _doBackupFull() async {
    if (!await _ensureEncryptPass()) return;
    if (!mounted) return;
    try {
      QlProgressOverlay.show(context, status: "全量备份中");
      await WebDavBackupUtils.backupFullPanel(
        _index,
        _selected.toList(),
        onProgress:
            (stage, progress) =>
                QlProgressOverlay.update(status: stage, progress: progress),
      );
      QlProgressOverlay.dismiss();
      "备份成功".toast();
    } catch (e) {
      QlProgressOverlay.dismiss();
      _err(e).toast2();
    }
  }

  Future<void> _doRestoreFull() async {
    final file = await _pickFile("full");
    if (file == null || !mounted) return;
    final bool? ok = await showConfirmDialog(
      context,
      title: "还原全量包",
      content: "将用备份覆盖面板数据（脚本/配置等），导入后自动重载面板，确认继续？",
      danger: true,
    );
    if (ok != true || !mounted) return;
    final pass = await _inputDecryptPass();
    if (pass == null || pass.isEmpty || !mounted) return;
    try {
      QlProgressOverlay.show(context, status: "下载备份");
      await WebDavBackupUtils.restoreFullPanel(
        _index,
        file.name,
        pass,
        onProgress:
            (stage, progress) =>
                QlProgressOverlay.update(status: stage, progress: progress),
      );
      QlProgressOverlay.dismiss();
      "还原完成，面板正在重载数据".toast();
    } catch (e) {
      QlProgressOverlay.dismiss();
      _err(e).toast2();
    }
  }

  // ==================== 远程文件选择 ====================

  /// kind: data=仅数据快照 / full=仅全量包 / any=全部
  Future<WebDavFile?> _pickFile(String kind) async {
    List<WebDavFile> files;
    try {
      QlProgressOverlay.show(context, status: "获取列表");
      files = await WebDavBackupUtils.listBackups(_index);
      QlProgressOverlay.dismiss();
    } catch (e) {
      QlProgressOverlay.dismiss();
      _err(e).toast2();
      return null;
    }
    final target =
        files.where((f) {
          if (kind == "data") return f.name.endsWith("_data.qlbak");
          if (kind == "full") return f.name.endsWith("_full.qlbak");
          return true;
        }).toList();
    if (target.isEmpty) {
      "远程还没有备份文件".toast();
      return null;
    }
    if (!mounted) return null;
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return showModalBottomSheet<WebDavFile>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color:
                isCyber
                    ? CyberColors.bg
                    : ref.watch(themeProvider).themeMode == modeDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                "选择备份文件",
                style: TextStyle(
                  fontSize: 16,
                  color: ref.watch(themeProvider).themeColor.titleColor(),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: target.length,
                  itemBuilder: (itemContext, i) {
                    final f = target[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              ref.watch(themeProvider).themeColor.titleColor(),
                        ),
                      ),
                      subtitle: Text(
                        _fileSubtitle(f),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              ref.watch(themeProvider).themeColor.descColor(),
                        ),
                      ),
                      trailing: Text(
                        f.name.endsWith("_data.qlbak") ? "快照" : "全量",
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              ref.watch(themeProvider).themeColor.descColor(),
                        ),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(f),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 10),
            ],
          ),
        );
      },
    );
  }

  String _fileSubtitle(WebDavFile f) {
    final parts = <String>[];
    if (f.modified != null) {
      parts.add(DateFormat("yyyy-MM-dd HH:mm").format(f.modified!));
    }
    parts.add(_formatSize(f.size));
    return parts.join(" · ");
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "-";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";
  }

  // ==================== 底部说明 ====================

  Widget _buildTips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "· 坚果云：网页端「账户信息 → 安全选项 → 添加应用密码」生成专用密码",
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(themeProvider).themeColor.descColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "· 备份使用当时的加密口令加密，口令可随时更改（只影响之后的备份）；还原时输入该备份对应的口令，遗忘将无法还原",
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(themeProvider).themeColor.descColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "· 全量包勾选日志/缓存类内容体积会较大，上传耗时与流量相应增加",
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(themeProvider).themeColor.descColor(),
            ),
          ),
        ],
      ),
    );
  }
}
