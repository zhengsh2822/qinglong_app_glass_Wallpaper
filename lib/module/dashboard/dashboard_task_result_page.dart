import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/log_entry_button.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/module/task/intime_log/intime_log_page.dart';

/// 今日成功 / 今日失败 任务明细页
///
/// 对齐青龙 Web 面板仪表盘「今日成功」「今日失败」两张统计卡的点击效果：
/// GET /dashboard/successes | /dashboard/failures（无参数，服务端已按次数降序）
/// 返回 [{ id, name, command, successCount | failCount, deleted }]
class DashboardTaskResultPage extends ConsumerStatefulWidget {
  /// true = 今日成功，false = 今日失败
  final bool isSuccess;

  const DashboardTaskResultPage({Key? key, required this.isSuccess})
    : super(key: key);

  @override
  DashboardTaskResultPageState createState() => DashboardTaskResultPageState();
}

class DashboardTaskResultPageState extends ConsumerState<DashboardTaskResultPage> {
  /// 全局字重（build 顶部统一 watch，供 helper 方法使用）
  FontWeight _globalFw = FontWeight.w400;
  bool _loading = true;
  String? _errorMsg;

  /// 明细列表（服务端按次数降序返回）
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final api = SingleAccountPageState.ofApi(context);
    final res =
        widget.isSuccess
            ? await api.dashboardSuccesses()
            : await api.dashboardFailures();
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

  /// 打开该任务的最新日志（复用实时日志页）
  void _openLog(int id, String name, String command) {
    if (id <= 0) return;
    Navigator.of(context).push(
      WallpaperPageRoute(
        blurSigma: 6,
        blurTintColor: CyberColors.bg.withOpacity(0.50),
        builder: (context) => InTimeLogPage('$id', true, name, command: command),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    _globalFw = FontWeight(ref.watch(textWeightProvider));
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;

    Widget body;
    if (_loading) {
      body = _buildLoading(isCyber);
    } else if (_items.isEmpty) {
      body = _buildEmpty(isCyber);
    } else {
      body = _buildContent(isCyber);
    }

    if (isCyber) {
      body = CyberBackground(child: body);
    }

    return Scaffold(
      // 壁纸版：Scaffold 背景必须透明，由路由级 WallpaperBackground 提供背景
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(
        title: widget.isSuccess ? '今日成功' : '今日失败',
        canBack: true,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            onPressed: _loadData,
            child: Icon(
              CupertinoIcons.refresh,
              color: isCyber ? CyberColors.cyan : AppleColors.accent,
              size: 22,
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildLoading(bool isCyber) {
    return Center(
      child: LoadingWidget(
        color: isCyber ? CyberColors.cyan : AppleColors.accent,
        size: 30,
      ),
    );
  }

  Widget _buildEmpty(bool isCyber) {
    final String text =
        _errorMsg ??
        (widget.isSuccess ? '今日暂无成功的任务' : '今日暂无失败的任务');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                isCyber ? CyberColors.descColor : AppleColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isCyber) {
    return RefreshIndicator(
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
        separatorBuilder: (_, _) => const SizedBox(height: AppleColors.spaceMd),
        itemBuilder: (context, index) => _buildItemCard(isCyber, index),
      ),
    );
  }

  /// 单个任务明细卡片：任务名（+已删除标签）/ 命令 + 次数 + 最新日志入口
  Widget _buildItemCard(bool isCyber, int index) {
    final row = _items[index];
    final int id = (row['id'] as num?)?.toInt() ?? 0;
    final String name = row['name']?.toString() ?? '-';
    final String command = row['command']?.toString() ?? '';
    // 任务已被删除时服务端对应 cron 已不存在，禁用日志入口（与网页版一致）
    final bool deleted = row['deleted'] == true;
    final int count =
        (row[widget.isSuccess ? 'successCount' : 'failCount'] as num?)
            ?.toInt() ??
        0;
    final Color countColor =
        widget.isSuccess ? CyberColors.neonGreen : CyberColors.neonRed;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 排名序号
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: _globalFw,
                color:
                    isCyber ? CyberColors.descColor : AppleColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCyber ? 14 : 15,
                          fontWeight: _globalFw,
                          color:
                              isCyber
                                  ? CyberColors.titleWhite
                                  : AppleColors.textPrimary,
                        ),
                      ),
                    ),
                    if (deleted) ...[
                      const SizedBox(width: 6),
                      _buildDeletedTag(isCyber),
                    ],
                  ],
                ),
                if (command.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    command,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isCyber
                              ? CyberColors.descColor
                              : AppleColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                LogEntryButton(
                  enabled: !deleted,
                  onTap: () => _openLog(id, name, command),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 次数
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: isCyber ? 20 : 18,
                  fontWeight: _globalFw,
                  color:
                      isCyber ? countColor : AppleColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '次',
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
        ],
      ),
    );
  }

  // 已删除任务标记
  Widget _buildDeletedTag(bool isCyber) {
    final Color color =
        isCyber ? CyberColors.descColor : AppleColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text('已删除', style: TextStyle(fontSize: 10, color: color)),
    );
  }
}