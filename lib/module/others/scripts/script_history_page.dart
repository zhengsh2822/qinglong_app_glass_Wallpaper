import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/empty_widget.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/module/others/scripts/script_code_detail_page.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 单个历史版本元数据（对应面板 GET /scripts/history 的 versions 项）
class ScriptHistoryVersion {
  final String id;
  final String createdAt;
  final String source; // baseline / save / restore / external
  final int size;
  final bool identical; // 内容与当前已保存文件一致

  const ScriptHistoryVersion({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.size,
    required this.identical,
  });

  static ScriptHistoryVersion fromJson(Map<String, dynamic> json) {
    return ScriptHistoryVersion(
      id: json['id']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      source: json['source']?.toString() ?? 'save',
      size: (json['size'] as num?)?.toInt() ?? 0,
      identical: json['identical'] == true,
    );
  }

  String get sourceLabel {
    switch (source) {
      case 'baseline':
        return '首次修改前';
      case 'restore':
        return '从历史版本恢复';
      case 'external':
        return '面板外修改后';
      default:
        return '手动保存';
    }
  }

  String get timeLabel {
    final DateTime? time = DateTime.tryParse(createdAt);
    if (time == null) return createdAt;
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(time.toLocal());
  }

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}

/// 脚本编辑历史（青龙 2.23.0+）
///
/// [hasUnsavedChanges] 为真（编辑页存在未提交草稿）时禁止恢复，
/// 与面板网页端一致：必须先保存或取消当前修改。
/// 恢复成功时以恢复后的文件内容作为路由返回值。
class ScriptHistoryPage extends ConsumerStatefulWidget {
  final String title;
  final String? path;
  final bool hasUnsavedChanges;

  const ScriptHistoryPage({
    super.key,
    required this.title,
    this.path,
    this.hasUnsavedChanges = false,
  });

  @override
  ConsumerState<ScriptHistoryPage> createState() => _ScriptHistoryPageState();
}

class _ScriptHistoryPageState extends ConsumerState<ScriptHistoryPage> {
  List<ScriptHistoryVersion> _versions = [];
  String? _currentHash;
  int _limit = 20;
  bool _loading = true;
  bool _restoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await SingleAccountPageState.ofApi(
      context,
    ).scriptHistory(widget.title, widget.path);
    if (!mounted) return;
    if (!response.success) {
      setState(() {
        _loading = false;
        _error = response.message ?? '加载失败';
      });
      return;
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(response.bean ?? '{}') as Map<String, dynamic>;
      final List<dynamic> raw = (data['versions'] as List<dynamic>?) ?? [];
      setState(() {
        _versions =
            raw
                .map((e) => ScriptHistoryVersion.fromJson(e as Map<String, dynamic>))
                .toList();
        _currentHash = data['currentHash']?.toString();
        _limit = (data['limit'] as num?)?.toInt() ?? 20;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '历史版本数据解析失败';
      });
    }
  }

  Future<void> _preview(ScriptHistoryVersion version) async {
    EasyLoading.show(status: "加载中");
    final response = await SingleAccountPageState.ofApi(
      context,
    ).scriptHistoryDetail(widget.title, widget.path, version.id);
    EasyLoading.dismiss();
    if (!mounted) return;
    if (!response.success) {
      (response.message ?? '加载历史内容失败').toast();
      return;
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(response.bean ?? '{}') as Map<String, dynamic>;
      final Map<String, dynamic>? ver =
          data['version'] as Map<String, dynamic>?;
      final String content = ver?['content']?.toString() ?? '';
      Navigator.of(context).push(
        WallpaperPageRoute(
          builder:
              (context) => ScriptCodeDetailPage(
                title: '${widget.title} · 历史版本',
                content: content,
              ),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withValues(alpha: 0.50),
        ),
      );
    } catch (e) {
      '历史内容解析失败'.toast();
    }
  }

  Future<void> _restore(ScriptHistoryVersion version) async {
    if (_restoring) return;
    if (widget.hasUnsavedChanges) {
      '请先保存或取消当前修改，再恢复历史版本'.toast();
      return;
    }
    final String? hash = _currentHash;
    if (hash == null || hash.isEmpty) {
      '缺少当前文件校验值，请刷新后重试'.toast();
      return;
    }
    final bool? confirmed = await showConfirmDialog(
      context,
      title: '恢复此版本',
      content:
          '${version.timeLabel} · ${version.sourceLabel}\n当前已保存的内容会保留在历史版本中。',
      confirmLabel: '恢复此版本',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    EasyLoading.show(status: "恢复中");
    final response = await SingleAccountPageState.ofApi(
      context,
    ).restoreScriptHistory(widget.title, widget.path, version.id, hash);
    EasyLoading.dismiss();
    if (!mounted) return;
    setState(() => _restoring = false);

    if (!response.success) {
      if (response.code == 409) {
        '文件已被修改，请重新打开历史版本'.toast();
        _load();
      } else {
        (response.message ?? '恢复失败').toast();
      }
      return;
    }
    String content = '';
    try {
      final Map<String, dynamic> data =
          jsonDecode(response.bean ?? '{}') as Map<String, dynamic>;
      content = data['content']?.toString() ?? '';
    } catch (_) {}
    '已恢复，恢复前的内容已保留'.toast();
    Navigator.of(context).pop(content);
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Color primaryText = ref.watch(themeProvider).customPrimaryTextColor;
    final Color secondaryText =
        ref.watch(themeProvider).customSecondaryTextColor;
    final Color accent = ref.watch(themeProvider).primaryColor;

    final Widget body;
    if (_loading) {
      body = const Center(child: LoadingWidget());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: secondaryText)),
            const SizedBox(height: 12),
            CupertinoButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    } else if (_versions.isEmpty) {
      body = const EmptyWidget();
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: _versions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final ScriptHistoryVersion version = _versions[index];
          return GlassListItemCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            onTap: () => _preview(version),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                version.timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight(
                                    ref.watch(textWeightProvider),
                                  ),
                                  color: primaryText,
                                ),
                              ),
                            ),
                            if (version.identical) ...[
                              const SizedBox(width: 6),
                              Text(
                                '与当前一致',
                                style: TextStyle(fontSize: 11, color: accent),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${version.sourceLabel} · ${version.sizeLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    onPressed:
                        version.identical ? null : () => _restore(version),
                    child: Text(
                      '恢复',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            version.identical
                                ? secondaryText.withValues(alpha: 0.4)
                                : accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final Widget scaffold = Scaffold(
      backgroundColor: isCyber ? Colors.transparent : null,
      appBar: QlAppBar(canBack: true, title: '历史版本'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              '仅记录通过面板保存的修改；最多保留 $_limit 个历史版本，容量不足时自动清理旧历史。',
              style: TextStyle(fontSize: 12, color: secondaryText),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }
}
