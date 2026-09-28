import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/glass_text_field.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 存储保留策略与清理（青龙 2.22 新增）
///
/// 对应 Web 面板「系统设置 - 存储清理」：
/// PUT  /system/storage-retention/config   保存保留策略
/// POST /system/storage-retention/preview  清理预览
/// POST /system/storage-retention/cleanup  执行清理（body 需带 confirmation:'CLEAN'）
///
/// 策略字段：runningInstanceRetentionDays / cronStatRetentionDays（0 表示不清理，最大 3650）
class StorageRetentionPage extends ConsumerStatefulWidget {
  const StorageRetentionPage({Key? key}) : super(key: key);

  @override
  StorageRetentionPageState createState() => StorageRetentionPageState();
}

class StorageRetentionPageState extends ConsumerState<StorageRetentionPage> {
  static const int _maxDays = 3650;

  /// 全局字重（build 顶部统一 watch，供 helper 方法使用）
  FontWeight _globalFw = FontWeight.w400;
  bool _loading = true;
  String? _errorMsg;

  final TextEditingController _runDaysController = TextEditingController(
    text: '0',
  );
  final TextEditingController _statDaysController = TextEditingController(
    text: '0',
  );

  bool _cacheNode = false;
  bool _cachePython3 = false;
  bool _compactDatabase = false;

  bool _previewing = false;
  Map<String, dynamic>? _preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _runDaysController.dispose();
    _statDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final res = await SingleAccountPageState.ofApi(context).systemConfig();
    if (!mounted) return;
    final Map<String, dynamic>? data = _parseObject(res.bean);
    setState(() {
      _loading = false;
      if (data != null) {
        final int runDays =
            (data['runningInstanceRetentionDays'] as num?)?.toInt() ?? 0;
        final int statDays =
            (data['cronStatRetentionDays'] as num?)?.toInt() ?? 0;
        _runDaysController.text = '$runDays';
        _statDaysController.text = '$statDays';
      } else if (!res.success) {
        _errorMsg = res.message ?? '读取当前策略失败，可手动填写后直接清理';
      }
    });
  }

  Map<String, dynamic>? _parseObject(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final data = decoded['data'] ?? decoded;
      if (data is! Map) return null;
      // GET /system/config 的字段在 info 下（runningInstanceRetentionDays /
      // cronStatRetentionDays 与「日志清理时间」logRemoveFrequency 同层）；
      // preview/cleanup 的返回没有 info，直接取 data
      final info = data['info'];
      return (info is Map ? info : data).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  int _days(TextEditingController c) {
    final int v = int.tryParse(c.text.trim()) ?? 0;
    return v.clamp(0, _maxDays);
  }

  Map<String, dynamic> _buildBody() {
    final List<String> types = [];
    if (_cacheNode) types.add('node');
    if (_cachePython3) types.add('python3');
    return {
      'runningInstanceRetentionDays': _days(_runDaysController),
      'cronStatRetentionDays': _days(_statDaysController),
      'dependenceCacheTypes': types,
      'compactDatabase': _compactDatabase,
    };
  }

  Future<void> _savePolicy() async {
    EasyLoading.show(status: "保存中");
    final res = await SingleAccountPageState.ofApi(context).updateRetentionConfig(
      _days(_runDaysController),
      _days(_statDaysController),
    );
    await EasyLoading.dismiss();
    if (res.success) {
      "策略已保存".toast();
      await _loadData();
    } else {
      (res.message ?? "保存失败").toast();
    }
  }

  Future<void> _doPreview() async {
    setState(() => _previewing = true);
    final res = await SingleAccountPageState.ofApi(
      context,
    ).previewRetention(_buildBody());
    if (!mounted) return;
    setState(() {
      _previewing = false;
      if (res.success) {
        _preview = _parseObject(res.bean);
      }
    });
    if (!res.success) {
      (res.message ?? "预览失败").toast();
    }
  }

  Future<void> _doCleanup() async {
    final bool? ok = await showCupertinoDialog<bool>(
      context: context,
      builder:
          (childContext) => CupertinoAlertDialog(
            title: const Text('确认清理'),
            content: const Text('将按上面的保留天数永久删除历史运行实例与执行统计，并清空勾选的依赖缓存，操作不可撤销。'),
            actions: [
              CupertinoDialogAction(
                child: const Text('取消'),
                onPressed: () => Navigator.of(childContext).pop(false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('确认清理'),
                onPressed: () => Navigator.of(childContext).pop(true),
              ),
            ],
          ),
    );
    if (ok != true) return;

    EasyLoading.show(status: "清理中");
    final res = await SingleAccountPageState.ofApi(
      context,
    ).cleanupRetention(_buildBody());
    await EasyLoading.dismiss();
    if (res.success) {
      final Map<String, dynamic>? data = _parseObject(res.bean);
      final Map<String, dynamic>? deleted =
          (data?['deleted'] as Map<String, dynamic>?);
      final int instances = (deleted?['runningInstances'] as num?)?.toInt() ?? 0;
      final int stats = (deleted?['cronStats'] as num?)?.toInt() ?? 0;
      final bool compacted = data?['compactedDatabase'] == true;
      "已清理：运行实例 $instances 条、执行统计 $stats 条${compacted ? '，数据库已压缩' : ''}".toast();
      setState(() => _preview = null);
      await _loadData();
    } else {
      (res.message ?? "清理失败").toast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    _globalFw = FontWeight(ref.watch(textWeightProvider));
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;

    Widget body;
    if (_loading) {
      body = Center(
        child: LoadingWidget(
          color: ref.watch(themeProvider).primaryColor,
          size: 30,
        ),
      );
    } else {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: AppleColors.spaceMd,
          right: AppleColors.spaceMd,
          top: AppleColors.spaceMd,
          bottom: MediaQuery.of(context).viewPadding.bottom + 30,
        ),
        children: [
          _buildPolicyCard(isCyber),
          const SizedBox(height: AppleColors.spaceMd),
          _buildCleanupCard(isCyber),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(title: '存储清理', canBack: true),
      body: GlassPageBackground(child: body),
    );
  }

  Widget _buildCardTitle(String title, bool isCyber) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isCyber ? 15 : 16,
        fontWeight: _globalFw,
        color: ref.watch(themeProvider).themeColor.titleColor(),
      ),
    );
  }

  Widget _buildDaysField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: desc)),
        const SizedBox(height: 6),
        GlassTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          hintText: hint,
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            color: ref.watch(themeProvider).themeColor.titleColor(),
          ),
        ),
      ],
    );
  }

  // 保留策略
  Widget _buildPolicyCard(bool isCyber) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('保留策略', isCyber),
          const SizedBox(height: 6),
          Text(
            '超过保留天数的历史数据会被清理；填 0 表示不清理该类型（最大 $_maxDays 天）',
            style: TextStyle(fontSize: 12, color: desc),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 6),
            Text(
              _errorMsg!,
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 14),
          _buildDaysField('运行实例保留天数', '0', _runDaysController),
          const SizedBox(height: 12),
          _buildDaysField('执行统计保留天数', '0', _statDaysController),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: ref.watch(themeProvider).primaryColor.withValues(
                alpha: 0.15,
              ),
              onPressed: _savePolicy,
              child: Text(
                '保存策略',
                style: TextStyle(
                  fontSize: 13,
                  color: ref.watch(themeProvider).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 清理
  Widget _buildCleanupCard(bool isCyber) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    final Map<String, dynamic>? p = _preview;

    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('立即清理', isCyber),
          const SizedBox(height: 6),
          Text(
            '按上面的天数清理历史数据，并可清空依赖安装缓存、压缩数据库',
            style: TextStyle(fontSize: 12, color: desc),
          ),
          const SizedBox(height: 12),
          _buildCheckRow(
            '清空 node 依赖缓存',
            _cacheNode,
            (v) => setState(() => _cacheNode = v),
          ),
          _buildCheckRow(
            '清空 python3 依赖缓存',
            _cachePython3,
            (v) => setState(() => _cachePython3 = v),
          ),
          _buildCheckRow(
            '清理后压缩数据库（VACUUM）',
            _compactDatabase,
            (v) => setState(() => _compactDatabase = v),
          ),
          const SizedBox(height: 10),
          if (p != null) ...[
            Text(
              '预览结果',
              style: TextStyle(fontSize: 12, color: desc),
            ),
            const SizedBox(height: 6),
            _buildInfoLine('历史运行实例', '${p['runningInstances'] ?? 0} 条'),
            const SizedBox(height: 4),
            _buildInfoLine('执行统计', '${p['cronStats'] ?? 0} 条'),
            const SizedBox(height: 4),
            _buildInfoLine(
              '依赖缓存',
              _formatBytes((p['dependenceCacheBytes'] as num?)?.toDouble() ?? 0),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                color: ref.watch(themeProvider).primaryColor.withValues(
                  alpha: 0.15,
                ),
                onPressed: _previewing ? null : _doPreview,
                child: Text(
                  _previewing ? '预览中…' : '预览',
                  style: TextStyle(
                    fontSize: 13,
                    color: ref.watch(themeProvider).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                color: CyberColors.neonRed.withValues(alpha: 0.15),
                onPressed: _doCleanup,
                child: Text(
                  '执行清理',
                  style: TextStyle(fontSize: 13, color: CyberColors.neonRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: CupertinoSwitch(
            activeColor: ref.watch(themeProvider).primaryColor,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoLine(String label, String value) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(fontSize: 12, color: desc)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
        ),
      ],
    );
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}