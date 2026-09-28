import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 任务历史运行实例页（青龙 2.22 新增）
///
/// 对应 Web 面板「任务详情 - 历史运行实例」：
/// GET  /crons/:id/instances                  按 started_at 倒序
/// POST /crons/:id/instances/:instanceId/stop 停止单个运行实例
///
/// 实例字段：id / cron_id / pid / log_path / started_at(unix 秒)
///          / finished_at(unix 秒|null) / status / exit_code
/// status: 0 运行中、1 已完成、2 已停止、3 错误
class CronInstancesPage extends ConsumerStatefulWidget {
  final String cronId;
  final String cronName;

  const CronInstancesPage({
    Key? key,
    required this.cronId,
    required this.cronName,
  }) : super(key: key);

  @override
  CronInstancesPageState createState() => CronInstancesPageState();
}

class CronInstancesPageState extends ConsumerState<CronInstancesPage> {
  /// 全局字重（build 顶部统一 watch，供 helper 方法使用）
  FontWeight _globalFw = FontWeight.w400;
  bool _loading = true;
  String? _errorMsg;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (widget.cronId.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg = '任务 ID 无效';
      });
      return;
    }
    final res = await SingleAccountPageState.ofApi(
      context,
    ).cronInstances(widget.cronId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = _parseList(res.bean);
      _errorMsg = res.success ? null : (res.message ?? '加载失败');
    });
  }

  List<Map<String, dynamic>> _parseList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) {
          return data.whereType<Map<String, dynamic>>().toList(growable: false);
        }
        return const [];
      }
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 停止单个运行实例
  Future<void> _stopInstance(int instanceId) async {
    EasyLoading.show(status: "停止中");
    final res = await SingleAccountPageState.ofApi(
      context,
    ).stopCronInstance(widget.cronId, instanceId);
    await EasyLoading.dismiss();
    if (res.success) {
      "实例已停止".toast();
      await _loadData();
    } else {
      (res.message ?? "停止失败").toast();
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
    } else if (_items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            _errorMsg ?? '暂无历史运行记录',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ref.watch(themeProvider).themeColor.descColor(),
              fontSize: 14,
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: AppleColors.spaceMd,
            right: AppleColors.spaceMd,
            top: AppleColors.spaceMd,
            bottom: MediaQuery.of(context).viewPadding.bottom + 30,
          ),
          itemCount: _items.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppleColors.spaceMd),
          itemBuilder: (context, index) => _buildItemCard(isCyber, index),
        ),
      );
    }

    if (isCyber) {
      body = CyberBackground(child: body);
    }

    return Scaffold(
      // 壁纸版：Scaffold 背景必须透明，由路由级 WallpaperBackground 提供背景
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(
        title: widget.cronName.isEmpty ? '运行实例' : widget.cronName,
        canBack: true,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            onPressed: _loadData,
            child: Icon(
              CupertinoIcons.refresh,
              color: ref.watch(themeProvider).primaryColor,
              size: 22,
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  // status: 0 运行中、1 已完成、2 已停止、3 错误
  Color _statusColor(int status) {
    switch (status) {
      case 0:
        return CyberColors.neonGreen;
      case 2:
        return AppColors.warning;
      case 3:
        return CyberColors.neonRed;
      default:
        return CyberColors.cyan;
    }
  }

  String _statusText(int status) {
    switch (status) {
      case 0:
        return '运行中';
      case 1:
        return '已完成';
      case 2:
        return '已停止';
      case 3:
        return '错误';
      default:
        return '未知';
    }
  }

  String _formatUnix(num? seconds) {
    if (seconds == null) return '-';
    final int s = seconds.toInt();
    if (s <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(s * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String _formatDuration(num? start, num? end) {
    if (start == null || start.toInt() <= 0) return '-';
    final int finish =
        (end == null || end.toInt() <= 0)
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000
            : end.toInt();
    int diff = finish - start.toInt();
    if (diff < 0) diff = 0;
    if (diff < 60) return '${diff}s';
    final int minutes = diff ~/ 60;
    if (minutes < 60) return '${minutes}m${diff % 60}s';
    final int hours = minutes ~/ 60;
    return '${hours}h${minutes % 60}m';
  }

  Widget _buildItemCard(bool isCyber, int index) {
    final row = _items[index];
    final int id = (row['id'] as num?)?.toInt() ?? 0;
    final int status = (row['status'] as num?)?.toInt() ?? 1;
    final num? started = row['started_at'] as num?;
    final num? finished = row['finished_at'] as num?;
    final String pid = row['pid']?.toString() ?? '-';
    final String exitCode = row['exit_code']?.toString() ?? '-';
    final Color statusColor = _statusColor(status);
    final bool running = status == 0;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _statusText(status),
                style: TextStyle(
                  fontSize: isCyber ? 14 : 15,
                  fontWeight: _globalFw,
                  color:
                      isCyber
                          ? statusColor
                          : ref.watch(themeProvider).themeColor.titleColor(),
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(started, finished),
                style: TextStyle(
                  fontSize: 13,
                  color: ref.watch(themeProvider).themeColor.descColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoLine('开始', _formatUnix(started)),
          const SizedBox(height: 4),
          _buildInfoLine('结束', _formatUnix(finished)),
          if (!running) ...[
            const SizedBox(height: 4),
            _buildInfoLine('退出码', exitCode),
          ],
          const SizedBox(height: 4),
          _buildInfoLine('PID', pid),
          if (running) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                color: CyberColors.neonRed.withValues(alpha: 0.15),
                onPressed: () => _stopInstance(id),
                child: Text(
                  '停止该实例',
                  style: TextStyle(fontSize: 12, color: CyberColors.neonRed),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(label, style: TextStyle(fontSize: 12, color: desc)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
          ),
        ),
      ],
    );
  }
}