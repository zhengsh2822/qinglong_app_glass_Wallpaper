import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/selectable_chip.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/file_picker_utils.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:share_plus/share_plus.dart';

/// 压缩包备份与恢复页面
///
/// 基于青龙面板服务端 API：
/// - PUT /api/system/data/export - 导出 .tgz 压缩包备份
/// - PUT /api/system/data/import - 上传 .tgz 恢复
/// - PUT /api/system/reload - 恢复后重载生效
///
/// 备份内容可勾选：config / scripts / deps / log（默认包含 db + upload）
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({Key? key}) : super(key: key);

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  // 备份内容选项（对齐青龙官方导出数据 API 的 type 枚举，共 10 项）
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
  // 基础数据固定包含，不可取消（对齐网页版）
  static const String _baseKey = 'base';

  final Set<String> _selected = {'base', 'config', 'scripts'};

  bool _processing = false;
  String _statusText = '';

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: QlAppBar(
            title: '备份与恢复',
            canBack: true,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppleColors.spaceMd,
              right: AppleColors.spaceMd,
              top: AppleColors.spaceMd,
              bottom: MediaQuery.of(context).viewPadding.bottom + 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBackupSection(),
                const SizedBox(height: AppleColors.spaceMd),
                _buildRestoreSection(),
                const SizedBox(height: 20),
                if (_statusText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: CyberColors.descColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_processing)
          Positioned.fill(
            child: AbsorbPointer(
              child: Center(
                child: LoadingWidget(color: CyberColors.cyan, size: 30),
              ),
            ),
          ),
      ],
    );
  }

  /// 备份区域
  Widget _buildBackupSection() {
    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '数据备份',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CyberColors.titleWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '将青龙面板数据打包为 .tgz 压缩包，保存到本地',
            style: TextStyle(fontSize: 12, color: CyberColors.descColor),
          ),
          const SizedBox(height: 14),
          Text(
            '备份内容（基础数据固定包含，不可取消）',
            style: TextStyle(fontSize: 13, color: CyberColors.descColor),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _backupOptions.entries.map((entry) {
              final isBase = entry.key == _baseKey;
              // 基础数据固定选中不可取消（对齐网页版），其余可勾选
              final selected = isBase || _selected.contains(entry.key);
              return SelectableChip(
                label: entry.value,
                selected: selected,
                disabled: _processing,
                onToggle: isBase
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
          SizedBox(
            width: double.infinity,
            child: GlassCard(
              sigma: 10,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: _processing ? null : _doBackup,
              child: Center(
                child: Text(
                  '开始备份',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CyberColors.cyan,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 恢复区域
  Widget _buildRestoreSection() {
    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '数据恢复',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CyberColors.titleWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '选择本地 .tgz 备份文件上传恢复，恢复后会自动重载系统',
            style: TextStyle(fontSize: 12, color: CyberColors.descColor),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GlassCard(
              sigma: 10,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: _processing ? null : _doRestore,
              child: Center(
                child: Text(
                  '选择文件恢复',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CyberColors.cyan,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 执行备份
  Future<void> _doBackup() async {
    setState(() {
      _processing = true;
      _statusText = '正在生成备份...';
    });

    try {
      final fileUtil = FileUtil(
        SingleAccountPageState.of(context)?.index ?? 0,
      );
      // 保存到外部存储目录，文件管理器可见
      final basePath = await fileUtil.downloadFilePath;
      final backupDir = Directory('$basePath${Platform.pathSeparator}qinglong_backup');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final savePath = '${backupDir.path}${Platform.pathSeparator}backup_${fileUtil.getHost()}_$timestamp.tgz';

      final typeList = _selected.toList();

      final error = await SingleAccountPageState.ofApi(context).exportData(
        savePath,
        type: typeList,
      );

      if (!mounted) return;

      if (error == null) {
        if (mounted) setState(() {
          _processing = false;
          _statusText = '备份成功\n$savePath';
        });
        '备份成功'.toast();
        // 弹出操作面板：分享/完成
        if (mounted) {
          await _showBackupResultSheet(savePath, isSuccess: true);
        }
      } else {
        if (mounted) setState(() => _statusText = '备份失败：$error');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = '备份失败：$e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// 执行恢复：先选择文件来源（最近备份/文件管理器）
  Future<void> _doRestore() async {
    // 先让用户选择来源
    final source = await _showRestoreSourceSheet();
    if (source == null) return;

    String? selectedPath;

    if (source == 'recent') {
      // 扫描备份目录的 .tgz 文件
      setState(() {
        _processing = true;
        _statusText = '正在扫描备份文件...';
      });
      try {
        final fileUtil = FileUtil(
          SingleAccountPageState.of(context)?.index ?? 0,
        );
        final basePath = await fileUtil.downloadFilePath;
        final backupDir = Directory('$basePath${Platform.pathSeparator}qinglong_backup');

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

        // 按修改时间倒序排列
        tgzFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

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
      // 调用系统文件管理器选择 .tgz 文件（项目自有 FilePickerUtils）
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
    await _performRestore(selectedPath);
  }

  /// 实际执行恢复上传 + 系统重载
  Future<void> _performRestore(String selectedPath) async {
    setState(() {
      _processing = true;
      _statusText = '正在上传恢复...';
    });

    try {
      final api = SingleAccountPageState.ofApi(context);

      // 1. 上传 .tgz 文件
      final importResult = await api.importData(selectedPath);

      if (!mounted) return;

      if (!importResult.success) {
        setState(() {
          _processing = false;
          _statusText = '恢复失败：${importResult.message ?? "未知错误"}';
        });
        return;
      }

      // 2. 重载系统使配置生效
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

  /// 选择恢复来源：最近备份 / 从文件管理器选择
  Future<String?> _showRestoreSourceSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isCyber ? CyberColors.bg : AppleColors.bgSecondary).withOpacity(0.85),
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
                          color: CyberColors.descColor.withOpacity(0.5),
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
                              fontWeight: FontWeight.w600,
                              color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
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
                            color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '扫描应用备份目录的 .tgz 文件',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
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
                            color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '调用系统文件管理器选任意 .tgz 文件',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
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
          ),
        );
      },
    );
  }

  /// 备份完成后的操作面板：分享文件 / 完成
  Future<void> _showBackupResultSheet(String savePath, {required bool isSuccess}) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isCyber ? CyberColors.bg : AppleColors.bgSecondary).withOpacity(0.85),
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
                          color: CyberColors.descColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isSuccess ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
                            color: isSuccess ? CyberColors.cyan : Colors.redAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSuccess ? '备份成功' : '备份失败',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isCyber ? CyberColors.cyan : AppleColors.accent).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          savePath,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (isSuccess)
                        SizedBox(
                          width: double.infinity,
                          child: GlassCard(
                            sigma: 10,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            onTap: () async {
                              Navigator.pop(context);
                              await Share.shareXFiles([XFile(savePath)],
                                  text: '青龙面板备份文件');
                            },
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.share, size: 18, color: CyberColors.cyan),
                                  const SizedBox(width: 8),
                                  Text(
                                    '分享/保存到文件管理器',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: CyberColors.cyan,
                                    ),
                                  ),
                                ],
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
                              color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 文件选择 BottomSheet（85% 高度，确保长文件名显示完整）
  Future<String?> _showFileSelectSheet(List<File> files) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isCyber ? CyberColors.bg : AppleColors.bgSecondary).withOpacity(0.85),
                child: Column(
                  children: [
                    // 顶部拖拽条
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CyberColors.descColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '选择备份文件',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 22,
                              color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 文件列表
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: files.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final file = files[index];
                          final stat = file.statSync();
                          final name = file.path.split(Platform.pathSeparator).last;
                          final sizeKB = stat.size / 1024;
                          final sizeStr = sizeKB >= 1024
                              ? '${(sizeKB / 1024).toStringAsFixed(2)} MB'
                              : '${sizeKB.toStringAsFixed(1)} KB';
                          final time = stat.modified.toString().substring(0, 16);
                          return InkWell(
                            onTap: () => Navigator.pop(context, file.path),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.doc,
                                    size: 28,
                                    color: isCyber ? CyberColors.cyan : AppleColors.accent,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$sizeStr · $time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.right_chevron,
                                    size: 16,
                                    color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
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
            ),
          ),
        );
      },
    );
  }
}
