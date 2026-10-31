import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/button.dart';
import 'package:qinglong_app/module/others/update/upgrade_status_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 面板安全升级页（仅青龙 2.24.0+ 开放入口）
///
/// 驱动面板 2.24.0 任务化升级流程（避免旧 ql update 流程"git 拉完依赖没装完
/// 导致面板起不来"的事故）：
/// 1. PUT /system/update 启动下载暂存任务（校验过的平台升级包，失败可回退）；
/// 2. GET /system/update-status 轮询（活跃期 2s），阶段：下载 → 解压 → 校验 →
///    依赖 → 预启动验证 → 就绪；
/// 3. status=ready 后由用户确认 → PUT /system/reload {type:'system'} 应用更新；
/// 4. 继续轮询到 completed（期间面板会重启，连接失败属预期，持续容忍重试）。
class PanelUpgradePage extends ConsumerStatefulWidget {
  final String? targetVersion;

  const PanelUpgradePage({Key? key, this.targetVersion}) : super(key: key);

  @override
  ConsumerState<PanelUpgradePage> createState() => _PanelUpgradePageState();
}

class _PanelUpgradePageState extends ConsumerState<PanelUpgradePage> {
  static const Duration _pollInterval = Duration(seconds: 2);

  /// 重启窗口期最大容忍时长：apply 后面板 HTTP 会下线，超时仍未恢复判失败
  static const Duration _restartTolerance = Duration(minutes: 5);

  UpgradeStatusBean? _status;
  String? _errorMessage;

  /// 阶段一（下载暂存）是否已发起
  bool _started = false;

  /// 用户已确认重启应用更新（阶段二）
  bool _applyRequested = false;

  bool _busy = false;
  Timer? _timer;
  DateTime? _firstErrorAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _beginDownload();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _beginDownload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final response =
          await SingleAccountPageState.ofApi(context).startPanelUpdate();
      if (!mounted) return;
      if (response.success) {
        _started = true;
        if (response.bean != null) {
          _status = response.bean;
        }
        _startPolling();
      } else {
        // 已有任务在跑（重复进入/网页端同时操作）：直接接管轮询
        if ((response.message ?? "").contains("已有更新")) {
          _started = true;
          _startPolling();
        } else {
          _errorMessage = response.message ?? "启动升级任务失败";
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (!mounted) return;
    final response =
        await SingleAccountPageState.ofApi(context).panelUpdateStatus();

    if (!mounted) return;

    if (response.success && response.bean != null) {
      _firstErrorAt = null;
      setState(() {
        _status = response.bean;
        if (response.bean!.isCompleted) {
          _timer?.cancel();
        }
        if (response.bean!.isFailed) {
          _timer?.cancel();
          _errorMessage = response.bean!.error;
        }
      });
      return;
    }

    // 面板重启窗口期：HTTP 短暂不可达属预期，持续轮询直到超容忍时长
    if (_applyRequested) {
      final DateTime first = _firstErrorAt ??= DateTime.now();
      if (DateTime.now().difference(first) > _restartTolerance) {
        _timer?.cancel();
        setState(() {
          _errorMessage = "面板重启后长时间无法连接，请上机检查面板状态";
        });
      }
      return;
    }

    // 下载阶段连续失败：提示并保留重试入口
    final DateTime first = _firstErrorAt ??= DateTime.now();
    if (DateTime.now().difference(first) > const Duration(seconds: 30)) {
      _timer?.cancel();
      setState(() {
        _errorMessage = "连接面板失败，请检查网络后面重试";
      });
    }
  }

  Future<void> _applyUpdate() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _applyRequested = true;
      _firstErrorAt = null;
      _errorMessage = null;
    });
    try {
      final response = await SingleAccountPageState.ofApi(
        context,
      ).reloadSystem('system');
      if (!mounted) return;
      if (!response.success && !(response.message ?? "").contains("已有更新")) {
        // 应用失败但任务可能已被网页端拉起，回到轮询继续观察
        "重启请求失败：${response.message ?? '未知错误'}，继续观察任务状态".toast();
        setState(() => _applyRequested = false);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _startPolling();
    }
  }

  String get _phaseLabel {
    final UpgradeStatusBean? s = _status;
    if (s == null) return "正在连接面板...";
    switch (s.status) {
      case 'ready':
        return "更新已就绪，等待重启面板";
      case 'completed':
        return "升级成功";
      case 'failed':
        return "更新失败";
      case 'starting':
      case 'running':
      case 'restarting':
        if (_applyRequested) return "正在重启面板并应用更新";
        switch (s.phase) {
          case 'downloading':
            return "下载更新中...";
          case 'extracting':
            return "正在解压更新包";
          case 'verifying':
            return "正在校验更新包";
          case 'dependencies':
            return "正在准备依赖";
          case 'prestarting':
            return "正在预启动验证";
          case 'repairing':
            return "正在修复运行依赖";
          default:
            return "正在准备更新";
        }
      default:
        return "等待任务开始";
    }
  }

  String get _versionHeaderText {
    final String current = "当前面板";
    final String? target = _status?.version ?? widget.targetVersion;
    if (target == null || target.isEmpty) return "面板版本更新";
    return "$current → 新版本 $target";
  }

  String get _logTail {
    final String log = _status?.log ?? "";
    if (log.isEmpty) return "";
    return log.length > 2000 ? log.substring(log.length - 2000) : log;
  }

  @override
  Widget build(BuildContext context) {
    final bool failed = _errorMessage != null && (_status?.isFailed ?? false);
    final bool completed = _status?.isCompleted ?? false;
    final bool ready = _status?.isReady ?? false;

    return Scaffold(
      appBar: QlAppBar(
        // 任务在面板侧独立执行，离开页面不影响升级；仅活跃期引导用户留在本页观察
        canBack:
            !_started ||
            (_status?.isFailed ?? false) ||
            (_status?.isCompleted ?? false) ||
            ((_status?.isReady ?? false) && !_applyRequested),
        backCall: () {
          Navigator.of(context).pop();
        },
        title: "面板安全升级",
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _versionHeaderText,
              style: TextStyle(
                color: ref.watch(themeProvider).themeColor.titleColor(),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_busy && _status == null) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    _phaseLabel,
                    style: TextStyle(
                      color:
                          failed
                              ? const Color(0xffFB5858)
                              : ref.watch(themeProvider).primaryColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildProgress(),
            const SizedBox(height: 14),
            _buildHint(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xffFB5858), fontSize: 14),
              ),
            ],
            if (_logTail.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                "任务日志（尾部）",
                style: TextStyle(
                  color: ref.watch(themeProvider).themeColor.descColor(),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ref
                      .watch(themeProvider)
                      .themeColor
                      .titleColor()
                      .withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    _logTail,
                    selectionControls: cupertinoTextSelectionControls,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: ref.watch(themeProvider).themeColor.descColor(),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            _buildActions(failed: failed, completed: completed, ready: ready),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final UpgradeStatusBean? s = _status;
    final num? percent = s?.percent;
    if (s == null || s.isCompleted) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: percent == null ? null : (percent.toDouble() / 100).clamp(0, 1),
        minHeight: 6,
        backgroundColor: ref
            .watch(themeProvider)
            .themeColor
            .titleColor()
            .withOpacity(0.10),
        valueColor: AlwaysStoppedAnimation<Color>(
          ref.watch(themeProvider).primaryColor,
        ),
      ),
    );
  }

  Widget _buildHint() {
    final UpgradeStatusBean? s = _status;
    final bool completed = _status?.isCompleted ?? false;
    if (completed) {
      return Text(
        "面板已升级并重启完成，环境变量、任务、脚本等数据不受影响。",
        style: TextStyle(
          color: ref.watch(themeProvider).themeColor.descColor(),
          fontSize: 13,
        ),
      );
    }
    if (_applyRequested) {
      return Text(
        "面板正在重启，期间将短暂无法访问，请保持本页打开，请勿重启面板进程或断电。",
        style: TextStyle(
          color: ref.watch(themeProvider).themeColor.descColor(),
          fontSize: 13,
        ),
      );
    }
    if (s?.isActive ?? false) {
      return Text(
        "升级包会先完整校验并准备依赖后才重启面板，请勿在此期间重启面板进程或断电。",
        style: TextStyle(
          color: ref.watch(themeProvider).themeColor.descColor(),
          fontSize: 13,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActions({
    required bool failed,
    required bool completed,
    required bool ready,
  }) {
    if (completed) {
      return ButtonWidget(
        title: "完成",
        onTap: () {
          Navigator.of(context).pop();
        },
      );
    }
    if (failed) {
      return Column(
        children: [
          ButtonWidget(
            title: "重新下载更新",
            onTap: () {
              setState(() {
                _status = null;
                _applyRequested = false;
                _firstErrorAt = null;
                _errorMessage = null;
              });
              _beginDownload();
            },
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "关闭",
                style: TextStyle(
                  color: ref.watch(themeProvider).themeColor.descColor(),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (ready && !_applyRequested) {
      return Column(
        children: [
          ButtonWidget(title: "立即重启面板应用更新", onTap: _applyUpdate),
          const SizedBox(height: 10),
          Text(
            "重启后面板将短暂无法访问，任务会自动完成剩余步骤",
            style: TextStyle(
              color: ref.watch(themeProvider).themeColor.descColor(),
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    if (_status == null && _errorMessage != null) {
      return ButtonWidget(
        title: "重试",
        onTap: () {
          setState(() {
            _errorMessage = null;
            _firstErrorAt = null;
          });
          _beginDownload();
        },
      );
    }
    return const SizedBox.shrink();
  }
}
