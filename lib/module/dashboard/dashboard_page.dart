import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../main.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends ConsumerState<DashboardPage> {
  bool _loading = true;
  String? _errorMsg;

  // 概览数据
  Map<String, dynamic>? _overview;
  // 系统资源数据
  Map<String, dynamic>? _system;
  // 运行时数据
  Map<String, dynamic>? _runtime;
  // 近 7 日趋势
  List<Map<String, dynamic>> _trend = [];
  // 今日耗时 Top 5
  List<Map<String, dynamic>> _topTime = [];
  // 今日执行次数 Top 5
  List<Map<String, dynamic>> _topCount = [];
  // 标签统计
  List<Map<String, dynamic>> _labels = [];
  // 版本号
  String _version = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final systemBean = getIt<SystemBean>(
      instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString(),
    );
    _version = systemBean.version ?? '未知';

    final api = SingleAccountPageState.ofApi(context);

    final results = await Future.wait([
      api.dashboardOverview(),
      api.dashboardSystem(),
      api.dashboardRuntime(),
      api.dashboardTrend(days: 7),
      api.dashboardTopTime(),
      api.dashboardTopCount(),
      api.dashboardLabels(),
    ]);

    final overviewRes = results[0];
    final systemRes = results[1];
    final runtimeRes = results[2];
    final trendRes = results[3];
    final topTimeRes = results[4];
    final topCountRes = results[5];
    final labelsRes = results[6];

    setState(() {
      _loading = false;
      _overview = _parseObject(overviewRes.bean);
      _system = _parseObject(systemRes.bean);
      _runtime = _parseObject(runtimeRes.bean);
      _trend = _parseList(trendRes.bean);
      _topTime = _parseList(topTimeRes.bean);
      _topCount = _parseList(topCountRes.bean);
      _labels = _parseList(labelsRes.bean);

      // 仅当所有接口都失败时显示错误（容忍老版本部分接口不存在）
      if (!overviewRes.success &&
          !systemRes.success &&
          !runtimeRes.success &&
          !trendRes.success &&
          !topTimeRes.success &&
          !topCountRes.success &&
          !labelsRes.success) {
        _errorMsg =
            (overviewRes.message ?? '').isNotEmpty
                ? overviewRes.message
                : '当前版本不支持仪表盘，请将青龙更新到最新版';
      }
    });
  }

  Map<String, dynamic>? _parseObject(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
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

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;

    Widget body =
        _loading
            ? _buildLoading(isCyber)
            : (_errorMsg != null &&
                    _overview == null &&
                    _system == null &&
                    _runtime == null &&
                    _trend.isEmpty &&
                    _topTime.isEmpty &&
                    _topCount.isEmpty &&
                    _labels.isEmpty
                ? _buildError(isCyber)
                : _buildContent(isCyber));

    if (isCyber) {
      body = CyberBackground(child: body);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(
        title: '仪表盘',
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

  Widget _buildError(bool isCyber) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Text(
          _errorMsg ?? '加载失败',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isCyber) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: AppleColors.spaceMd,
          right: AppleColors.spaceMd,
          top: AppleColors.spaceMd,
          bottom: MediaQuery.of(context).viewPadding.bottom + 30,
        ),
        child: Column(
          children: [
            _buildVersionCard(isCyber),
            const SizedBox(height: AppleColors.spaceMd),
            if (_overview != null) ...[
              _buildOverviewCard(isCyber),
              const SizedBox(height: AppleColors.spaceMd),
            ],
            if (_trend.isNotEmpty) ...[
              _buildTrendCard(isCyber),
              const SizedBox(height: AppleColors.spaceMd),
            ],
            if (_topTime.isNotEmpty) ...[
              _buildTopTimeCard(isCyber),
              const SizedBox(height: AppleColors.spaceMd),
            ],
            if (_topCount.isNotEmpty) ...[
              _buildTopCountCard(isCyber),
              const SizedBox(height: AppleColors.spaceMd),
            ],
            if (_labels.isNotEmpty) ...[
              _buildLabelsCard(isCyber),
              const SizedBox(height: AppleColors.spaceMd),
            ],
            if (_runtime != null) ...[
              _buildRuntimeCard(isCyber),
              const SizedBox(height: AppleColors.spaceMd),
            ],
            if (_system != null) ...[
              _buildSystemCard(isCyber),
              const SizedBox(height: AppleColors.spaceMd),
            ],
          ],
        ),
      ),
    );
  }

  // 版本信息卡片
  Widget _buildVersionCard(bool isCyber) {
    return _buildCard(
      isCyber: isCyber,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isCyber ? CyberColors.cyan : AppleColors.accent)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.info,
              color: isCyber ? CyberColors.cyan : AppleColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '青龙版本',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        isCyber
                            ? CyberColors.descColor
                            : AppleColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _version,
                  style: TextStyle(
                    fontSize: isCyber ? 20 : 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: isCyber ? CyberColors.monoFont : null,
                    color:
                        isCyber
                            ? CyberColors.titleWhite
                            : AppleColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 任务概览卡片
  Widget _buildOverviewCard(bool isCyber) {
    final total = (_overview!['total'] as num?)?.toInt() ?? 0;
    final enabled = (_overview!['enabled'] as num?)?.toInt() ?? 0;
    final disabled = (_overview!['disabled'] as num?)?.toInt() ?? 0;
    final todayRuns = (_overview!['todayRuns'] as num?)?.toInt() ?? 0;
    final todaySuccess = (_overview!['todaySuccess'] as num?)?.toInt() ?? 0;
    final todayFail = (_overview!['todayFail'] as num?)?.toInt() ?? 0;
    final successRate = _overview!['successRate']?.toString() ?? '0';
    final avgTime = (_overview!['avgTime'] as num?)?.toInt() ?? 0;

    return _buildSectionCard(
      isCyber: isCyber,
      title: '任务概览',
      icon: CupertinoIcons.chart_bar,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCell(isCyber, '总任务', '$total', CyberColors.cyan),
            ),
            Expanded(
              child: _buildStatCell(
                isCyber,
                '已启用',
                '$enabled',
                CyberColors.neonGreen,
              ),
            ),
            Expanded(
              child: _buildStatCell(
                isCyber,
                '已禁用',
                '$disabled',
                CyberColors.descColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCell(
                isCyber,
                '今日执行',
                '$todayRuns',
                CyberColors.cyan,
              ),
            ),
            Expanded(
              child: _buildStatCell(
                isCyber,
                '今日成功',
                '$todaySuccess',
                CyberColors.neonGreen,
              ),
            ),
            Expanded(
              child: _buildStatCell(
                isCyber,
                '今日失败',
                '$todayFail',
                CyberColors.neonRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCell(
                isCyber,
                '成功率',
                '$successRate%',
                CyberColors.neonGreen,
              ),
            ),
            Expanded(
              child: _buildStatCell(
                isCyber,
                '平均耗时',
                _formatTime(avgTime),
                CyberColors.cyan,
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  // 近 7 日趋势卡片（折线图）
  Widget _buildTrendCard(bool isCyber) {
    return _buildSectionCard(
      isCyber: isCyber,
      title: '近 7 日趋势',
      icon: CupertinoIcons.graph_circle,
      children: [
        SizedBox(
          height: 160,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendChartPainter(data: _trend, isCyber: isCyber),
          ),
        ),
      ],
    );
  }

  // 今日耗时 Top 5 卡片
  Widget _buildTopTimeCard(bool isCyber) {
    return _buildSectionCard(
      isCyber: isCyber,
      title: '今日耗时 Top 5',
      icon: CupertinoIcons.timer,
      children: [
        _buildTableHeader(
          isCyber,
          ['#', '定时任务', '平均耗时', '最长单次'],
          flex: [1, 3, 2, 2],
        ),
        const SizedBox(height: 6),
        ..._topTime.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return _buildTableRow(
            isCyber,
            [
              '${row['rank'] ?? (i + 1)}',
              row['name']?.toString() ?? '-',
              _formatTime((row['avgTime'] as num?)?.toInt() ?? 0),
              _formatTime((row['maxTime'] as num?)?.toInt() ?? 0),
            ],
            flex: [1, 3, 2, 2],
            highlight: i == 0,
          );
        }),
      ],
    );
  }

  // 今日执行次数 Top 5 卡片
  Widget _buildTopCountCard(bool isCyber) {
    return _buildSectionCard(
      isCyber: isCyber,
      title: '今日执行次数 Top 5',
      icon: CupertinoIcons.flame,
      children: [
        _buildTableHeader(
          isCyber,
          ['#', '定时任务', '次数', '平均耗时', '成功率'],
          flex: [1, 3, 1, 2, 2],
        ),
        const SizedBox(height: 6),
        ..._topCount.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final rate = row['successRate']?.toString() ?? '0';
          return _buildTableRow(
            isCyber,
            [
              '${row['rank'] ?? (i + 1)}',
              row['name']?.toString() ?? '-',
              '${row['runCount'] ?? 0}',
              _formatTime((row['avgTime'] as num?)?.toInt() ?? 0),
              '$rate%',
            ],
            flex: [1, 3, 1, 2, 2],
            highlight: i == 0,
          );
        }),
      ],
    );
  }

  // 标签统计卡片
  Widget _buildLabelsCard(bool isCyber) {
    return _buildSectionCard(
      isCyber: isCyber,
      title: '标签统计',
      icon: CupertinoIcons.tag,
      children: [
        _buildTableHeader(
          isCyber,
          ['标签', '任务数', '今日执行', '成功率', '平均耗时'],
          flex: [3, 1, 2, 2, 2],
        ),
        const SizedBox(height: 6),
        ..._labels.map((row) {
          return _buildTableRow(
            isCyber,
            [
              row['label']?.toString() ?? '-',
              '${row['count'] ?? 0}',
              '${row['todayRuns'] ?? 0}',
              '${row['successRate'] ?? 0}%',
              _formatTime((row['avgTime'] as num?)?.toInt() ?? 0),
            ],
            flex: [3, 1, 2, 2, 2],
          );
        }),
      ],
    );
  }

  // 实时运行态卡片
  Widget _buildRuntimeCard(bool isCyber) {
    final runningCount = (_runtime!['runningCount'] as num?)?.toInt() ?? 0;
    final queuedCount = (_runtime!['queuedCount'] as num?)?.toInt() ?? 0;
    final running = (_runtime!['running'] as List?) ?? const [];
    final idleTasks = (_runtime!['idleTasks'] as List?) ?? const [];

    return _buildSectionCard(
      isCyber: isCyber,
      title: '实时运行态',
      icon: CupertinoIcons.bolt,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCell(
                isCyber,
                '运行中',
                '$runningCount',
                CyberColors.neonGreen,
              ),
            ),
            Expanded(
              child: _buildStatCell(
                isCyber,
                '排队中',
                '$queuedCount',
                AppColors.warning,
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
        if (running.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '正在运行的任务',
            style: TextStyle(
              fontSize: isCyber ? 12 : 13,
              color:
                  isCyber ? CyberColors.descColor : AppleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...running.take(5).map((item) {
            final m = item as Map<String, dynamic>;
            final name = m['name']?.toString() ?? '-';
            final pid = m['pid']?.toString() ?? '-';
            final elapsed = (m['elapsed'] as num?)?.toInt() ?? 0;
            return _buildRunningTask(isCyber, name, pid, elapsed);
          }),
        ],
        if (idleTasks.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '24 小时未运行（最多 5 个）',
            style: TextStyle(
              fontSize: isCyber ? 12 : 13,
              color:
                  isCyber ? CyberColors.descColor : AppleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...idleTasks.take(5).map((item) {
            final m = item as Map<String, dynamic>;
            final name = m['name']?.toString() ?? '-';
            final lastRun = m['lastRun']?.toString() ?? '-';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: isCyber ? CyberColors.monoFont : null,
                        color:
                            isCyber
                                ? CyberColors.titleWhite
                                : AppleColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lastRun,
                    style: TextStyle(
                      fontSize: isCyber ? 12 : 13,
                      color:
                          isCyber
                              ? CyberColors.descColor
                              : AppleColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildRunningTask(bool isCyber, String name, String pid, int elapsed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: CyberColors.neonGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontFamily: isCyber ? CyberColors.monoFont : null,
                color:
                    isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
              ),
            ),
          ),
          if (pid != '-' && pid.isNotEmpty) ...[
            Text(
              'PID $pid',
              style: TextStyle(
                fontSize: 11,
                color:
                    isCyber ? CyberColors.descColor : AppleColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _formatTime(elapsed * 1000),
            style: TextStyle(
              fontSize: isCyber ? 12 : 13,
              color:
                  isCyber ? CyberColors.descColor : AppleColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 系统资源卡片
  Widget _buildSystemCard(bool isCyber) {
    final platform = _system!['platform']?.toString() ?? '-';
    final uptime = (_system!['uptime'] as num?)?.toInt() ?? 0;
    final memTotal = (_system!['memTotal'] as num?)?.toDouble() ?? 0;
    final memFree = (_system!['memFree'] as num?)?.toDouble() ?? 0;
    final memPercent = _system!['memUsagePercent']?.toString() ?? '0';
    final heapUsed = (_system!['heapUsed'] as num?)?.toDouble() ?? 0;
    final heapTotal = (_system!['heapTotal'] as num?)?.toDouble() ?? 0;
    final cpus = (_system!['cpus'] as num?)?.toInt() ?? 0;
    final loadAvg = _system!['loadAvg'] as List?;
    final memUsed = memTotal - memFree;
    final memPercentVal = double.tryParse(memPercent.replaceAll('%', '')) ?? 0;

    // CPU 使用率（青龙开源后端 /api/dashboard/system 未返回此字段）
    // 预留解析位置：后端扩展 cpuUsage 字段后可直接展示
    final cpuUsageRaw = _system!['cpuUsage'];
    final cpuUsagePercent = cpuUsageRaw != null
        ? (double.tryParse(cpuUsageRaw.toString().replaceAll('%', '')) ?? 0)
        : null;

    return _buildSectionCard(
      isCyber: isCyber,
      title: '系统资源',
      icon: CupertinoIcons.gauge,
      children: [
        _buildInfoRow(isCyber, '系统平台', platform),
        _buildInfoRow(isCyber, 'CPU 核心', '$cpus'),
        if (cpuUsagePercent != null) ...[
          const SizedBox(height: 8),
          _buildProgress(
            isCyber,
            'CPU 使用率',
            '${cpuUsagePercent.toStringAsFixed(1)}%',
            cpuUsagePercent / 100,
          ),
        ],
        if (loadAvg != null && loadAvg.length >= 3) ...[
          const SizedBox(height: 8),
          _buildLoadAvgChart(isCyber, cpus, loadAvg),
        ],
        _buildInfoRow(isCyber, '运行时长', _formatUptime(uptime)),
        const SizedBox(height: 10),
        _buildProgress(
          isCyber,
          '内存使用',
          '${_formatBytes(memUsed)} / ${_formatBytes(memTotal)}',
          memPercentVal / 100,
        ),
        const SizedBox(height: 8),
        _buildProgress(
          isCyber,
          '堆内存',
          '${heapUsed.toStringAsFixed(1)} MB / ${heapTotal.toStringAsFixed(1)} MB',
          heapTotal > 0 ? heapUsed / heapTotal : 0,
        ),
      ],
    );
  }

  // 系统平均负载可视化图表
  // loadAvg 为 1/5/15 分钟平均负载，以 CPU 核心数为基准计算负载比率
  // 比率 < 70% 绿色（轻松），70-100% 橙色（较忙），> 100% 红色（过载）
  Widget _buildLoadAvgChart(bool isCyber, int cpus, List<dynamic> loadAvg) {
    final labels = ['1分钟', '5分钟', '15分钟'];
    final values = loadAvg
        .map((e) => (e as num?)?.toDouble() ?? 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '系统负载',
              style: TextStyle(
                fontSize: isCyber ? 12 : 13,
                color: isCyber
                    ? CyberColors.descColor
                    : AppleColors.textSecondary,
              ),
            ),
            Text(
              '基准: ${cpus}核',
              style: TextStyle(
                fontSize: isCyber ? 11 : 11,
                fontFamily: isCyber ? CyberColors.monoFont : null,
                color: isCyber
                    ? CyberColors.descColor
                    : AppleColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(3, (i) {
          final ratio = cpus > 0 ? values[i] / cpus : 0.0;
          final percentDisplay = (ratio * 100).clamp(0, 999);
          // 颜色分级：绿色 <70%，橙色 70-100%，红色 >100%
          final Color color;
          if (ratio < 0.7) {
            color = isCyber ? CyberColors.neonGreen : const Color(0xFF34C759);
          } else if (ratio <= 1.0) {
            color = isCyber ? CyberColors.neonYellow : AppColors.warning;
          } else {
            color = isCyber ? CyberColors.neonRed : AppColors.danger;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: isCyber ? 12 : 12,
                        color: isCyber
                            ? CyberColors.descColor
                            : AppleColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${values[i].toStringAsFixed(2)}  ${percentDisplay.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: isCyber ? 12 : 12,
                        fontFamily: isCyber ? CyberColors.monoFont : null,
                        color: isCyber
                            ? CyberColors.titleWhite
                            : AppleColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    // 进度条最大到 100%，过载时显示满格
                    value: ratio.clamp(0.0, 1.0),
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 表格行
  Widget _buildTableHeader(
    bool isCyber,
    List<String> cells, {
    required List<int> flex,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: List.generate(cells.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Text(
              cells[i],
              style: TextStyle(
                fontSize: isCyber ? 11 : 12,
                color:
                    isCyber ? CyberColors.descColor : AppleColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: i == 0 ? TextAlign.start : TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTableRow(
    bool isCyber,
    List<String> cells, {
    required List<int> flex,
    bool highlight = false,
  }) {
    final textColor =
        highlight
            ? (isCyber ? CyberColors.cyan : AppleColors.accent)
            : (isCyber ? CyberColors.titleWhite : AppleColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: List.generate(cells.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Text(
              cells[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isCyber ? 12 : 13,
                fontFamily: isCyber ? CyberColors.monoFont : null,
                fontWeight: highlight && i == 0 ? FontWeight.w600 : null,
                color: textColor,
              ),
              textAlign: i == 0 ? TextAlign.start : TextAlign.center,
            ),
          );
        }),
      ),
    );
  }

  // 统计单元格
  Widget _buildStatCell(bool isCyber, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isCyber ? 12 : 13,
            color: isCyber ? CyberColors.descColor : AppleColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isCyber ? 18 : 17,
            fontWeight: FontWeight.w600,
            fontFamily: isCyber ? CyberColors.monoFont : null,
            color: isCyber ? color : AppleColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // 进度条
  Widget _buildProgress(
    bool isCyber,
    String label,
    String value,
    double percent,
  ) {
    final color = isCyber ? CyberColors.cyan : AppleColors.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isCyber ? 12 : 13,
                color:
                    isCyber ? CyberColors.descColor : AppleColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isCyber ? 12 : 13,
                fontFamily: isCyber ? CyberColors.monoFont : null,
                color:
                    isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // 信息行
  Widget _buildInfoRow(bool isCyber, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color:
                  isCyber ? CyberColors.descColor : AppleColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: isCyber ? CyberColors.monoFont : null,
              color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // 区块卡片
  Widget _buildSectionCard({
    required bool isCyber,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return _buildCard(
      isCyber: isCyber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isCyber ? CyberColors.cyan : AppleColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: isCyber ? 15 : 17,
                  fontWeight: FontWeight.w600,
                  color:
                      isCyber
                          ? CyberColors.titleWhite
                          : AppleColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // 基础卡片容器
  Widget _buildCard({required bool isCyber, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppleColors.radiusCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 12), sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 12)),
        child: Container(
          width: double.infinity,
          clipBehavior: isCyber ? Clip.antiAlias : Clip.none,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppleColors.radiusCard),
            color: Colors.transparent,
            border:
                isCyber
                    ? Border.all(color: CyberColors.borderGlow, width: 1)
                    : Border.all(color: AppleColors.cardBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
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

  String _formatTime(int ms) {
    if (ms <= 0) return '0ms';
    if (ms < 1000) return '${ms}ms';
    final seconds = ms ~/ 1000;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainSeconds = seconds % 60;
    if (minutes < 60) return '${minutes}m${remainSeconds}s';
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    return '${hours}h${remainMinutes}m';
  }

  String _formatUptime(int seconds) {
    if (seconds <= 0) return '-';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (days > 0) return '${days}天${hours}小时';
    if (hours > 0) return '${hours}小时${mins}分';
    return '${mins}分';
  }
}

/// 近 7 日趋势折线图（纯 CustomPaint 绘制，避免引入 fl_chart 依赖）
class _TrendChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool isCyber;

  _TrendChartPainter({required this.data, required this.isCyber});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final color = isCyber ? CyberColors.cyan : AppleColors.accent;
    final successColor = isCyber ? CyberColors.neonGreen : AppColors.success;
    final failColor = isCyber ? CyberColors.neonRed : AppColors.danger;
    final gridColor = (isCyber
            ? CyberColors.descColor
            : AppleColors.textSecondary)
        .withOpacity(0.15);
    final textColor =
        isCyber ? CyberColors.descColor : AppleColors.textSecondary;

    // 解析 total 数据
    final values = <double>[];
    final labels = <String>[];
    for (final row in data) {
      final v = (row['total'] as num?)?.toDouble() ?? 0;
      values.add(v);
      labels.add(row['date']?.toString() ?? '');
    }

    if (values.isEmpty) return;

    final maxV = values.reduce(math.max);
    final minV = 0.0;
    // y 轴范围留 10% 顶部空白
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final yMax = maxV + range * 0.1;

    // 布局：左侧 36px 给 y 轴刻度文字，底部 22px 给 x 轴日期
    final chartLeft = 36.0;
    final chartTop = 8.0;
    final chartRight = size.width - 4.0;
    final chartBottom = size.height - 22.0;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    // 绘制网格线（4 条水平线）
    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    final textStyle = TextStyle(
      fontSize: isCyber ? 9 : 10,
      color: textColor,
      fontFamily: isCyber ? CyberColors.monoFont : null,
    );
    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = chartTop + chartHeight * i / gridLines;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      final v = yMax * (1 - i / gridLines);
      final tp = TextPainter(
        text: TextSpan(
          text:
              v >= 1000
                  ? '${(v / 1000).toStringAsFixed(1)}k'
                  : v.toInt().toString(),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 30);
      tp.paint(canvas, Offset(chartLeft - tp.width - 4, y - tp.height / 2));
    }

    if (values.length == 1) {
      // 单点直接画圆点
      final cx = chartLeft + chartWidth / 2;
      final cy = chartTop + chartHeight * (1 - values[0] / yMax);
      canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = color);
    } else {
      // x 步进
      final stepX = chartWidth / (values.length - 1);

      // 折线（总）
      final linePath = Path();
      for (var i = 0; i < values.length; i++) {
        final x = chartLeft + stepX * i;
        final y = chartTop + chartHeight * (1 - values[i] / yMax);
        if (i == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }
      }
      // 区域填充
      final fillPath =
          Path.from(linePath)
            ..lineTo(chartLeft + stepX * (values.length - 1), chartBottom)
            ..lineTo(chartLeft, chartBottom)
            ..close();
      final fillPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
            ).createShader(
              Rect.fromLTWH(chartLeft, chartTop, chartWidth, chartHeight),
            );
      canvas.drawPath(fillPath, fillPaint);
      // 折线
      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      // 成功/失败 虚线（如果数据存在）
      final success = <double>[];
      final fail = <double>[];
      for (final row in data) {
        success.add((row['success'] as num?)?.toDouble() ?? 0);
        fail.add((row['fail'] as num?)?.toDouble() ?? 0);
      }
      void drawDash(List<double> list, Color c) {
        final p = Path();
        for (var i = 0; i < list.length; i++) {
          final x = chartLeft + stepX * i;
          final y = chartTop + chartHeight * (1 - list[i] / yMax);
          if (i == 0) {
            p.moveTo(x, y);
          } else {
            p.lineTo(x, y);
          }
        }
        canvas.drawPath(
          p,
          Paint()
            ..color = c
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }

      drawDash(success, successColor);
      drawDash(fail, failColor);

      // 圆点
      for (var i = 0; i < values.length; i++) {
        final x = chartLeft + stepX * i;
        final y = chartTop + chartHeight * (1 - values[i] / yMax);
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        canvas.drawCircle(
          Offset(x, y),
          2,
          Paint()..color = isCyber ? const Color(0xFF1A1A2E) : Colors.white,
        );
      }

      // x 轴日期
      final dateStyle = TextStyle(
        fontSize: isCyber ? 9 : 10,
        color: textColor,
        fontFamily: isCyber ? CyberColors.monoFont : null,
      );
      // 控制标签密度：超过 7 个则只显示首尾
      final showEvery = values.length > 8 ? (values.length / 6).ceil() : 1;
      for (var i = 0; i < values.length; i++) {
        if (i % showEvery != 0 && i != values.length - 1) continue;
        final x = chartLeft + stepX * i;
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: dateStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 40);
        tp.paint(canvas, Offset(x - tp.width / 2, chartBottom + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) {
    return old.data != data;
  }
}
