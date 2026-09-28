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

/// 客户端 IP 与代理链路（青龙 2.22 新增）
///
/// 对应 Web 面板「系统设置 - 客户端 IP / 可信代理 / 登录 IP 黑名单」：
/// GET/PUT /system/client-ip/config   可信代理解析配置（trustProxy/source/editable）
/// GET     /system/client-ip/diagnose 访问链路诊断（remoteAddress/forwardedFor/expressIps/clientIp/hops）
/// GET/PUT/DELETE /user/ip-blacklist  登录 IP 黑名单（body: {ip}）
class ClientIpPage extends ConsumerStatefulWidget {
  const ClientIpPage({Key? key}) : super(key: key);

  @override
  ClientIpPageState createState() => ClientIpPageState();
}

class ClientIpPageState extends ConsumerState<ClientIpPage> {
  /// 全局字重（build 顶部统一 watch，供 helper 方法使用）
  FontWeight _globalFw = FontWeight.w400;
  bool _loading = true;
  String? _errorMsg;

  // 可信代理配置
  final TextEditingController _trustProxyController = TextEditingController();
  String _source = 'default';
  bool _editable = true;

  // 链路诊断结果
  Map<String, dynamic>? _diagnose;
  bool _diagnosing = false;

  // 登录 IP 黑名单
  final TextEditingController _newIpController = TextEditingController();
  List<String> _blacklist = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _trustProxyController.dispose();
    _newIpController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = SingleAccountPageState.ofApi(context);
    final results = await Future.wait([
      api.clientIpConfig(),
      api.ipBlacklist(),
    ]);
    if (!mounted) return;

    final configRes = results[0];
    final blacklistRes = results[1];
    final config = _parseObject(configRes.bean);

    setState(() {
      _loading = false;
      if (config != null) {
        _trustProxyController.text = config['trustProxy']?.toString() ?? '';
        _source = config['source']?.toString() ?? 'default';
        _editable = config['editable'] != false;
      }
      _blacklist = _parseStringList(blacklistRes.bean);
      if (config == null && !blacklistRes.success) {
        _errorMsg =
            (configRes.message ?? '').isNotEmpty
                ? configRes.message
                : '当前版本不支持该功能，请将青龙更新到 2.22 及以上';
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

  List<String> _parseStringList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      dynamic data = decoded;
      if (decoded is Map<String, dynamic>) data = decoded['data'];
      if (data is List) {
        return data.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveProxy() async {
    final String value = _trustProxyController.text.trim();
    if (value.isEmpty) {
      "请填写 trust proxy 配置".toast();
      return;
    }
    EasyLoading.show(status: "保存中");
    final res = await SingleAccountPageState.ofApi(
      context,
    ).updateClientIpConfig(value);
    await EasyLoading.dismiss();
    if (res.success) {
      "保存成功".toast();
      await _loadData();
    } else {
      (res.message ?? "保存失败").toast();
    }
  }

  Future<void> _runDiagnose() async {
    setState(() => _diagnosing = true);
    final res = await SingleAccountPageState.ofApi(context).clientIpDiagnose();
    if (!mounted) return;
    setState(() {
      _diagnosing = false;
      if (res.success) {
        _diagnose = _parseObject(res.bean);
      }
    });
    if (!res.success) {
      (res.message ?? "诊断失败").toast();
    }
  }

  Future<void> _addIp() async {
    final String ip = _newIpController.text.trim();
    if (ip.isEmpty) {
      "请填写 IP 地址".toast();
      return;
    }
    EasyLoading.show(status: "提交中");
    final res = await SingleAccountPageState.ofApi(context).addIpBlacklist(ip);
    await EasyLoading.dismiss();
    if (res.success) {
      _newIpController.clear();
      "已加入 IP 黑名单".toast();
      await _loadData();
    } else {
      (res.message ?? "添加失败").toast();
    }
  }

  Future<void> _removeIp(String ip) async {
    EasyLoading.show(status: "提交中");
    final res = await SingleAccountPageState.ofApi(context).removeIpBlacklist(ip);
    await EasyLoading.dismiss();
    if (res.success) {
      "已移出 IP 黑名单".toast();
      await _loadData();
    } else {
      (res.message ?? "移除失败").toast();
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
      body = RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: AppleColors.spaceMd,
            right: AppleColors.spaceMd,
            top: AppleColors.spaceMd,
            bottom: MediaQuery.of(context).viewPadding.bottom + 30,
          ),
          children: [
            if (_errorMsg != null) _buildErrorCard(isCyber),
            _buildProxyCard(isCyber),
            const SizedBox(height: AppleColors.spaceMd),
            _buildDiagnoseCard(isCyber),
            const SizedBox(height: AppleColors.spaceMd),
            _buildBlacklistCard(isCyber),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(title: 'IP 设置', canBack: true),
      body: GlassPageBackground(child: body),
    );
  }

  Widget _buildErrorCard(bool isCyber) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppleColors.spaceMd),
      child: GlassCard(
        sigma: 10,
        padding: const EdgeInsets.all(14),
        child: Text(
          _errorMsg ?? '',
          style: TextStyle(
            fontSize: 13,
            color: ref.watch(themeProvider).themeColor.descColor(),
          ),
        ),
      ),
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

  // 可信代理解析配置
  Widget _buildProxyCard(bool isCyber) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    final String sourceText = _source == 'environment'
        ? '环境变量 QL_TRUST_PROXY'
        : (_source == 'system' ? '系统设置' : '默认值 loopback');

    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('可信代理解析', isCyber),
          const SizedBox(height: 6),
          Text(
            '影响面板如何识别客户端真实 IP，取值同 Express trust proxy：'
            'true/false、代理层数（≤20）、loopback、具体 IP 段或预设名',
            style: TextStyle(fontSize: 12, color: desc),
          ),
          const SizedBox(height: 12),
          if (_editable)
            GlassTextField(
              controller: _trustProxyController,
              hintText: 'loopback',
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _trustProxyController.text,
                style: TextStyle(
                  fontSize: 14,
                  color: ref.watch(themeProvider).themeColor.titleColor(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _editable
                ? '生效来源：$sourceText（可在下方修改）'
                : '生效来源：$sourceText，已锁定不可修改',
            style: TextStyle(
              fontSize: 12,
              color: _editable ? desc : AppColors.warning,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color:
                  _editable
                      ? ref.watch(themeProvider).primaryColor.withValues(
                        alpha: 0.15,
                      )
                      : desc.withValues(alpha: 0.12),
              onPressed: _editable ? _saveProxy : null,
              child: Text(
                '保存',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      _editable
                          ? ref.watch(themeProvider).primaryColor
                          : desc,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 访问链路诊断
  Widget _buildDiagnoseCard(bool isCyber) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    final Map<String, dynamic>? d = _diagnose;
    final List hops = (d?['hops'] as List?) ?? const [];
    final List forwarded = (d?['forwardedFor'] as List?) ?? const [];
    final List expressIps = (d?['expressIps'] as List?) ?? const [];

    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('访问链路诊断', isCyber),
          const SizedBox(height: 6),
          Text(
            '查看面板实际识别到的客户端 IP 与经过的代理跳数',
            style: TextStyle(fontSize: 12, color: desc),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: ref.watch(themeProvider).primaryColor.withValues(
                alpha: 0.15,
              ),
              onPressed: _diagnosing ? null : _runDiagnose,
              child: Text(
                _diagnosing ? '诊断中…' : '开始诊断',
                style: TextStyle(
                  fontSize: 13,
                  color: ref.watch(themeProvider).primaryColor,
                ),
              ),
            ),
          ),
          if (d != null) ...[
            const SizedBox(height: 12),
            _buildInfoLine('识别 IP', d['clientIp']?.toString() ?? '-'),
            const SizedBox(height: 4),
            _buildInfoLine('直连地址', d['remoteAddress']?.toString() ?? '-'),
            const SizedBox(height: 4),
            _buildInfoLine(
              'X-Forwarded-For',
              forwarded.isEmpty ? '-' : forwarded.join(', '),
            ),
            const SizedBox(height: 4),
            _buildInfoLine(
              'Express req.ips',
              expressIps.isEmpty ? '-' : expressIps.join(', '),
            ),
            if (hops.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '链路跳数',
                style: TextStyle(fontSize: 12, color: desc),
              ),
              const SizedBox(height: 6),
              ...hops.map((item) {
                final m = item as Map<String, dynamic>;
                final String status = m['status']?.toString() ?? '';
                final String statusText = status == 'trusted'
                    ? '可信代理'
                    : (status == 'client' ? '判定为客户端' : '未检查');
                final Color c = status == 'client'
                    ? CyberColors.neonGreen
                    : desc;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Text(
                          '第${m['hop'] ?? 0}跳',
                          style: TextStyle(fontSize: 12, color: desc),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          m['ip']?.toString() ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .titleColor(),
                          ),
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(fontSize: 11, color: c),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  // 登录 IP 黑名单
  Widget _buildBlacklistCard(bool isCyber) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();

    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('登录 IP 黑名单', isCyber),
          const SizedBox(height: 6),
          Text(
            '黑名单中的 IP 将无法登录面板（仅支持单个 IPv4/IPv6，不支持网段）',
            style: TextStyle(fontSize: 12, color: desc),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassTextField(
                  controller: _newIpController,
                  hintText: '例如 192.168.1.100',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                color: ref.watch(themeProvider).primaryColor.withValues(
                  alpha: 0.15,
                ),
                onPressed: _addIp,
                child: Text(
                  '添加',
                  style: TextStyle(
                    fontSize: 13,
                    color: ref.watch(themeProvider).primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_blacklist.isEmpty)
            Text(
              '暂无黑名单 IP',
              style: TextStyle(fontSize: 13, color: desc),
            )
          else
            ..._blacklist.map((ip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              ref.watch(themeProvider).themeColor.titleColor(),
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _removeIp(ip),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.minus_circle,
                            size: 14,
                            color: CyberColors.neonRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '移除',
                            style: TextStyle(
                              fontSize: 12,
                              color: CyberColors.neonRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    final Color desc = ref.watch(themeProvider).themeColor.descColor();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: desc),
          ),
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
}