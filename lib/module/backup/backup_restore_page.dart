import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/progress_ring_loader.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/glow_sheet.dart';
import 'package:qinglong_app/base/ui/selectable_chip.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/base/ui/spring_sheet.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/others/file_directory_page.dart';
import 'package:qinglong_app/module/others/other_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/file_picker_utils.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:share_plus/share_plus.dart';

/// 备份与恢复页（合并页）：
/// 上半部分 = 原文件备份页（三件套本地/iCloud 备份 + 自动备份开关）；
/// 下半部分 = 原「备份恢复」页（青龙面板 .tgz 全量包本地备份与恢复）。
class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage>
    with LazyLoadState<BackupRestorePage> {
  // ---- 面板 .tgz 备份选项（对齐青龙官方导出 API 的 type 枚举，共 10 项）----
  final Map<String, String> _backupOptions = {
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

  bool _processing = false;
  String _statusText = '';

  FontWeight _globalFw = FontWeight.w400;

  // ---- 三件套本地备份统计 ----
  String? fileNum = "-";
  String fileSizes = "-";

  int get _index => SingleAccountPageState.of(context)?.index ?? 0;

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    _globalFw = FontWeight(ref.watch(textWeightProvider));
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(title: "备份与恢复"),
      body: Stack(
        children: [
          SingleChildScrollView(
            primary: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),
                  const SectionHeader(
                    title: "当你添加,修改,删除的时候,将会自动备份",
                    padding: EdgeInsets.symmetric(horizontal: 15),
                  ),
                  const SizedBox(height: 5),
                  _buildAutoCard(),
                  const SizedBox(height: 5),
                  SectionHeader(
                    title: "当前已有备份文件 $fileNum 个,共占用 $fileSizes 容量",
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                  ),
                  const SizedBox(height: 15),
                  const SectionHeader(
                    title: "环境变量",
                    padding: EdgeInsets.symmetric(horizontal: 15),
                  ),
                  const SizedBox(height: 5),
                  _buildEnvCard(),
                  const SizedBox(height: 15),
                  SectionHeader(
                    title:
                        SpUtil.getInt(spVIP, defValue: typeNormal) == typeVIP
                            ? "config.sh文件"
                            : "配置文件",
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                  ),
                  const SizedBox(height: 5),
                  _buildConfigCard(),
                  const SizedBox(height: 5),
                  const SectionHeader(
                    title: "备份和还原配置文件",
                    padding: EdgeInsets.symmetric(horizontal: 15),
                  ),
                  const SizedBox(height: 15),
                  const SectionHeader(
                    title: "订阅管理",
                    padding: EdgeInsets.symmetric(horizontal: 15),
                  ),
                  const SizedBox(height: 5),
                  _buildSubscribeCard(),
                  const SizedBox(height: 15),
                  const SectionHeader(
                    title: "功能",
                    padding: EdgeInsets.symmetric(horizontal: 15),
                  ),
                  const SizedBox(height: 5),
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: SettingsTapRow(
                      title: "备份文件删除频率",
                      onTap: _delDuration,
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Visibility(
                    visible: Platform.isAndroid,
                    child: const SectionHeader(
                      title:
                          "Android用户为了数据安全,备份文件保存在/data/user/0/work.master.qinglongapp/files/文件夹下,非root用户无法通过文件浏览器查看,只可以点击页面顶部的查看文件按钮查看",
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildTgzBackupSection(),
                  const SizedBox(height: 15),
                  _buildTgzRestoreSection(),
                  const SizedBox(height: 20),
                  if (_statusText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              ref.watch(themeProvider).themeColor.descColor(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  // ==================== 三件套本地备份（原文件备份页内容） ====================

  Widget _buildAutoCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSwitchRow(
            title: "自动备份",
            value: SpUtil.getBool(spICloud, defValue: true),
            onChanged: (v) {
              SpUtil.putBool(spICloud, v);
              setState(() {});
            },
          ),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "查看文件", onTap: lookUpFiles),
        ],
      ),
    );
  }

  Widget _buildSyncRow({
    required String title,
    required String timeSpKey,
    required VoidCallback onTap,
  }) {
    return SettingsTapRow(
      title: title,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SpUtil.getString(timeSpKey, defValue: ""),
            style: TextStyle(
              fontSize: 16,
              color: ref.watch(themeProvider).themeColor.descColor(),
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

  Widget _buildEnvCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyncRow(
            title: "同步环境变量",
            timeSpKey: spEnvBackTime,
            onTap: () async {
              try {
                var result = await Api(_index).envs("");
                await getIt<ICloudUtils>(
                  instanceName: _index.toString(),
                ).asyncEnv(result.bean ?? [], focusUpdate: true);
                SpUtil.putString(spEnvBackTime, ICloudUtils.now());
                setState(() {});
              } catch (e) { /* ignore: failure is non-critical */ }
            },
          ),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "还原备份", onTap: lookUpFiles),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(
            title: "删除备份",
            onTap: () async {
              if (Platform.isAndroid) {
                "请点击页面下方备份文件删除频率按钮设置删除".toast2();
                return;
              }
              "请前往 \"文件\" App手动删除".toast();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyncRow(
            title: "同步config.sh文件",
            timeSpKey: spConfigBackTime,
            onTap: () async {
              String content;
              HttpResponse<String> result = await SingleAccountPageState.ofApi(
                context,
              ).content("config.sh");
              if (result.success && result.bean != null) {
                content = result.bean ?? "";
                await getIt<ICloudUtils>(
                  instanceName: _index.toString(),
                ).asyncConfig("config.sh", content, focusUpdate: true);
                SpUtil.putString(spConfigBackTime, ICloudUtils.now());
                setState(() {});
              } else {
                result.message!.toast();
              }
            },
          ),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "还原备份", onTap: lookUpFiles),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(
            title: "删除备份",
            onTap: () async {
              if (Platform.isAndroid) {
                "请点击页面下方备份文件删除频率按钮设置删除".toast2();
                return;
              }
              "请前往 \"文件\" App手动删除".toast();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyncRow(
            title: "同步订阅管理",
            timeSpKey: spSubscribeBackTime,
            onTap: () async {
              try {
                var result = await Api(_index).subscribes();
                await getIt<ICloudUtils>(
                  instanceName: _index.toString(),
                ).asyncSubscribe(result.bean ?? "", focusUpdate: true);
                SpUtil.putString(spSubscribeBackTime, ICloudUtils.now());
                setState(() {});
              } catch (e) { /* ignore: failure is non-critical */ }
            },
          ),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(title: "还原备份", onTap: lookUpFiles),
          const Divider(height: 1, indent: 15),
          SettingsTapRow(
            title: "删除备份",
            onTap: () async {
              if (Platform.isAndroid) {
                "请点击页面下方备份文件删除频率按钮设置删除".toast2();
                return;
              }
              "请前往 \"文件\" App手动删除".toast();
            },
          ),
        ],
      ),
    );
  }

  void _delDuration() async {
    final initial = SpUtil.getInt(
      spLocalBackUpFileExperiedTime,
      defValue: getDefaultLogExperiedTime(),
    );
    final days = await showFrequencyDialog(
      context,
      title: '备份文件删除频率',
      initialValue: initial,
      minValue: 1,
      maxValue: 100,
      unit: '天',
    );
    if (days != null) {
      SpUtil.putInt(spLocalBackUpFileExperiedTime, days);
      setState(() {});
    }
  }

  @override
  void onLazyLoad() async {
    try {
      Map<String, int> result = await compute(
        dirStatSync,
        await FileUtil(_index).sourcePath,
      );
      fileNum = result["fileNum"].toString();
      fileSizes = getFileSizeString(result["size"] ?? 0, 2);
      setState(() {});
    } catch (e) { /* ignore: failure is non-critical */ }
  }

  static String getFileSizeString(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)}${suffixes[i]}';
  }

  void lookUpFiles() async {
    String path = await FileUtil(_index).sourcePath;
    if (!mounted) return;
    Navigator.of(context).push(
      WallpaperPageRoute(builder: (context) => FileDirectoryPage(path: path)),
    );
  }

  // ==================== 面板 .tgz 全量包（原「备份恢复」页内容） ====================

  Widget _primaryButton(String text, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: _processing ? 0.5 : 1.0,
        child: GestureDetector(
          onTap: _processing ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: ref.watch(themeProvider).primaryColor,
              borderRadius: BorderRadius.circular(AppleColors.radiusButton),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _globalFw,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTgzBackupSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '面板数据备份',
            style: TextStyle(
              fontSize: 16,
              fontWeight: _globalFw,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '将青龙面板数据打包为 .tgz 压缩包，保存到本地',
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(themeProvider).themeColor.descColor(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '备份内容（基础数据固定包含，不可取消）',
            style: TextStyle(
              fontSize: 13,
              color: ref.watch(themeProvider).themeColor.descColor(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _backupOptions.entries.map((entry) {
                  final isBase = entry.key == _baseKey;
                  final selected = isBase || _selected.contains(entry.key);
                  return SelectableChip(
                    label: entry.value,
                    selected: selected,
                    disabled: _processing,
                    onToggle:
                        isBase
                            ? null
                            : (value) {
                              setState(() {
                                if (value) {
                                  _selected.add(entry.key);
                                } else {
                                  _selected.remove(entry.key);
                                }
                              });
                            },
                  );
                }).toList(),
          ),
          const SizedBox(height: 16),
          _primaryButton('开始备份', _doTgzBackup),
        ],
      ),
    );
  }

  Widget _buildTgzRestoreSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '数据恢复',
            style: TextStyle(
              fontSize: 16,
              fontWeight: _globalFw,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '选择本地 .tgz 备份文件上传恢复，恢复后会自动重载系统',
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(themeProvider).themeColor.descColor(),
            ),
          ),
          const SizedBox(height: 14),
          _primaryButton('选择文件恢复', _doTgzRestore),
        ],
      ),
    );
  }

  Future<void> _doTgzBackup() async {
    setState(() {
      _processing = true;
      _statusText = '正在生成备份...';
    });

    try {
      QlProgressOverlay.show(context, status: "导出面板数据");
      final fileUtil = FileUtil(_index);
      final basePath = await fileUtil.downloadFilePath;
      final backupDir = Directory(
        '$basePath${Platform.pathSeparator}qinglong_backup',
      );
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final savePath =
          '${backupDir.path}${Platform.pathSeparator}backup_${fileUtil.getHost()}_$timestamp.tgz';

      final typeList = _selected.toList();

      if (!mounted) return;
      final error = await SingleAccountPageState.ofApi(context).exportData(
        savePath,
        type: typeList,
        onReceiveProgress:
            (received, total) => QlProgressOverlay.update(
              status: "导出面板数据",
              progress: total > 0 ? received / total : null,
            ),
      );

      if (!mounted) return;
      QlProgressOverlay.dismiss();

      if (error == null) {
        if (mounted) {
          setState(() {
            _processing = false;
            _statusText = '备份成功\n$savePath';
          });
        }
        '备份成功'.toast();
        if (mounted) {
          await _showBackupResultSheet(savePath, isSuccess: true);
        }
      } else {
        if (mounted) setState(() => _statusText = '备份失败：$error');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusText = '备份失败：$e';
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _doTgzRestore() async {
    final source = await _showRestoreSourceSheet();
    if (source == null) return;

    String? selectedPath;

    if (source == 'recent') {
      setState(() {
        _processing = true;
        _statusText = '正在扫描备份文件...';
      });
      try {
        final fileUtil = FileUtil(_index);
        final basePath = await fileUtil.downloadFilePath;
        final backupDir = Directory(
          '$basePath${Platform.pathSeparator}qinglong_backup',
        );

        final tgzFiles = <File>[];
        if (await backupDir.exists()) {
          await for (final entity in backupDir.list()) {
            if (entity is File && entity.path.endsWith('.tgz')) {
              tgzFiles.add(entity);
            }
          }
        }

        if (!mounted) return;
        setState(() => _processing = false);

        if (tgzFiles.isEmpty) {
          setState(() => _statusText = '备份目录暂无 .tgz 文件\n请用"从文件管理器选择"导入');
          return;
        }

        tgzFiles.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );

        selectedPath = await _showFileSelectSheet(tgzFiles);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _processing = false;
          _statusText = '扫描失败：$e';
        });
        return;
      }
    } else if (source == 'manager') {
      try {
        final picked = await FilePickerUtils.pickFile();
        if (picked == null || picked.path == null) return;
        final lower = picked.path!.toLowerCase();
        if (!lower.endsWith('.tgz') &&
            !lower.endsWith('.tar.gz') &&
            !lower.endsWith('.tar')) {
          '请选择 .tgz / .tar.gz / .tar 备份文件'.toast();
          return;
        }
        selectedPath = picked.path;
      } catch (e) {
        setState(() => _statusText = '选择文件失败：$e');
        return;
      }
    }

    if (selectedPath == null) return;
    await _performTgzRestore(selectedPath);
  }

  Future<void> _performTgzRestore(String selectedPath) async {
    setState(() {
      _processing = true;
      _statusText = '正在上传恢复...';
    });

    try {
      final api = SingleAccountPageState.ofApi(context);
      QlProgressOverlay.show(context, status: "导入面板");
      final importResult = await api.importData(
        selectedPath,
        onSendProgress:
            (sent, total) => QlProgressOverlay.update(
              status: "导入面板",
              progress: total > 0 ? sent / total : null,
            ),
      );

      if (!mounted) return;
      QlProgressOverlay.dismiss();

      if (!importResult.success) {
        setState(() {
          _processing = false;
          _statusText = '恢复失败：${importResult.message ?? "未知错误"}';
        });
        return;
      }

      setState(() => _statusText = '正在重载系统...');
      final reloadResult = await api.reloadSystem('data');

      if (!mounted) return;

      setState(() => _processing = false);

      if (reloadResult.success) {
        setState(() => _statusText = '恢复成功，系统已重载');
        '恢复成功'.toast();
      } else {
        setState(() {
          _statusText =
              '文件已上传，但重载失败：${reloadResult.message ?? "未知错误"}\n请手动在青龙面板执行 ql reload';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusText = '恢复失败：$e';
      });
    }
  }

  Future<String?> _showRestoreSourceSheet() async {
    return showSpringSheet<String>(
      context: context,
      builder: (context) {
        final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: GlowSheetContainer(
            isCyber: isCyber,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ref
                            .watch(themeProvider)
                            .themeColor
                            .descColor()
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '选择恢复来源',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: _globalFw,
                            color:
                                isCyber
                                    ? CyberColors.titleWhite
                                    : AppleColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        CupertinoIcons.clock,
                        color: isCyber ? CyberColors.cyan : AppleColors.accent,
                      ),
                      title: Text(
                        '从最近备份选择',
                        style: TextStyle(
                          color:
                              isCyber
                                  ? CyberColors.titleWhite
                                  : AppleColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '扫描应用备份目录的 .tgz 文件',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isCyber
                                  ? CyberColors.descColor
                                  : AppleColors.textSecondary,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, 'recent'),
                    ),
                    ListTile(
                      leading: Icon(
                        CupertinoIcons.folder,
                        color: isCyber ? CyberColors.cyan : AppleColors.accent,
                      ),
                      title: Text(
                        '从文件管理器选择',
                        style: TextStyle(
                          color:
                              isCyber
                                  ? CyberColors.titleWhite
                                  : AppleColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '调用系统文件管理器选任意 .tgz 文件',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isCyber
                                  ? CyberColors.descColor
                                  : AppleColors.textSecondary,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, 'manager'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBackupResultSheet(
    String savePath, {
    required bool isSuccess,
  }) async {
    if (!mounted) return;
    await showSpringSheet<void>(
      context: context,
      builder: (context) {
        final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: GlowSheetContainer(
            isCyber: isCyber,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ref
                            .watch(themeProvider)
                            .themeColor
                            .descColor()
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isSuccess
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.xmark_circle_fill,
                          color:
                              isSuccess
                                  ? ref.watch(themeProvider).primaryColor
                                  : Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSuccess ? '备份成功' : '备份失败',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: _globalFw,
                            color:
                                isCyber
                                    ? CyberColors.titleWhite
                                    : AppleColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isCyber ? CyberColors.cyan : AppleColors.accent)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        savePath,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isCyber
                                  ? CyberColors.descColor
                                  : AppleColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isSuccess)
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            await Share.shareXFiles([
                              XFile(savePath),
                            ], text: '青龙面板备份文件');
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: ref.watch(themeProvider).primaryColor,
                              borderRadius: BorderRadius.circular(
                                AppleColors.radiusButton,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.share,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '分享/保存到文件管理器',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: _globalFw,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                isCyber
                                    ? CyberColors.descColor
                                    : AppleColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showFileSelectSheet(List<File> files) async {
    return showSpringSheet<String>(
      context: context,
      builder: (context) {
        final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: GlowSheetContainer(
            isCyber: isCyber,
            child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ref
                          .watch(themeProvider)
                          .themeColor
                          .descColor()
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '选择备份文件',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: _globalFw,
                            color:
                                isCyber
                                    ? CyberColors.titleWhite
                                    : AppleColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 22,
                            color:
                                isCyber
                                    ? CyberColors.descColor
                                    : AppleColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: files.length,
                      separatorBuilder:
                          (_, __) => const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final stat = file.statSync();
                        final name =
                            file.path.split(Platform.pathSeparator).last;
                        final sizeKB = stat.size / 1024;
                        final sizeStr =
                            sizeKB >= 1024
                                ? '${(sizeKB / 1024).toStringAsFixed(2)} MB'
                                : '${sizeKB.toStringAsFixed(1)} KB';
                        final time = stat.modified.toString().substring(0, 16);
                        return InkWell(
                          onTap: () => Navigator.pop(context, file.path),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.doc,
                                  size: 28,
                                  color:
                                      isCyber
                                          ? CyberColors.cyan
                                          : AppleColors.accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: _globalFw,
                                          color:
                                              isCyber
                                                  ? CyberColors.titleWhite
                                                  : AppleColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$sizeStr · $time',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              isCyber
                                                  ? CyberColors.descColor
                                                  : AppleColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.right_chevron,
                                  size: 16,
                                  color:
                                      isCyber
                                          ? CyberColors.descColor
                                          : AppleColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ),
        );
      },
    );
  }
}

Map<String, int> dirStatSync(String dirPath) {
  int fileNum = 0;
  int totalSize = 0;
  var dir = Directory(dirPath);
  try {
    if (dir.existsSync()) {
      dir.listSync(recursive: true, followLinks: false).forEach((
        FileSystemEntity entity,
      ) {
        if (entity is File) {
          fileNum++;
          totalSize += entity.lengthSync();
        }
      });
    }
  } catch (e) { /* ignore: failure is non-critical */ }

  return {'fileNum': fileNum, 'size': totalSize};
}
