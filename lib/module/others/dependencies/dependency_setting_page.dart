import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/glass_text_field.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 依赖设置页面（青龙面板 v2.21+ 系统设置 → 依赖设置）
///
/// 配置依赖代理 + Node/Python/Linux 镜像源，解决依赖安装慢/失败的问题。
/// 4 个输入框：
/// - 依赖代理（http_proxy/https_proxy）
/// - Node.js 镜像源（pnpm config set registry）
/// - Python 镜像源（pip3 config set global.index-url）
/// - Linux 镜像源（仅 Linux 平台）
///
/// 传空字符串保存表示清除设置。
/// Node/Linux 镜像源更新会触发重装已安装依赖，耗时较长，用 Loading 遮罩提示。
class DependencySettingPage extends ConsumerStatefulWidget {
  const DependencySettingPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DependencySettingPage> createState() =>
      _DependencySettingPageState();
}

class _DependencySettingPageState extends ConsumerState<DependencySettingPage> {
  final _proxyController = TextEditingController();
  final _nodeController = TextEditingController();
  final _pythonController = TextEditingController();
  final _linuxController = TextEditingController();

  /// 服务器端当前值，用于对比是否变化，避免发送无效请求
  String _origProxy = '';
  String _origNode = '';
  String _origPython = '';
  String _origLinux = '';

  bool _loading = true;
  bool _saving = false;
  String? _errorMsg;

  /// 全局字重（build 顶部统一 watch，供卡片标题/保存按钮使用）
  FontWeight _globalFw = FontWeight.w400;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _nodeController.dispose();
    _pythonController.dispose();
    _linuxController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final api = SingleAccountPageState.ofApi(context);
    final response = await api.systemConfig();

    if (!mounted) return;

    if (response.success && response.bean != null) {
      try {
        final decoded = jsonDecode(response.bean!);
        // 青龙 API 返回结构：{code:200, data:{id, type, info:{dependenceProxy, nodeMirror, ...}}}
        // response.bean 是 data 字段的 JSON 字符串，即 {id, type, info:{...}}
        final data = decoded is Map ? decoded['data'] ?? decoded : decoded;
        if (data is Map) {
          // 依赖设置字段在 info 对象下
          final info = data['info'];
          final cfg = info is Map ? info : data;
          _proxyController.text = cfg['dependenceProxy']?.toString() ?? '';
          _nodeController.text = cfg['nodeMirror']?.toString() ?? '';
          _pythonController.text = cfg['pythonMirror']?.toString() ?? '';
          _linuxController.text = cfg['linuxMirror']?.toString() ?? '';
          // 保存原始值，用于保存时对比是否变化
          _origProxy = _proxyController.text;
          _origNode = _nodeController.text;
          _origPython = _pythonController.text;
          _origLinux = _linuxController.text;
        }
        setState(() => _loading = false);
      } catch (e) {
        setState(() {
          _loading = false;
          _errorMsg = '解析配置失败: $e';
        });
      }
    } else {
      setState(() {
        _loading = false;
        _errorMsg = response.message?.isNotEmpty == true
            ? response.message
            : '当前版本不支持依赖设置，请将青龙更新到 v2.21+';
      });
    }
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    setState(() => _saving = true);

    final api = SingleAccountPageState.ofApi(context);

    // 只发送变化的字段，避免发送无效请求（如代理地址为空时服务器 rm 不存在的文件会 500）
    final newProxy = _proxyController.text.trim();
    final newPython = _pythonController.text.trim();
    final newNode = _nodeController.text.trim();
    final newLinux = _linuxController.text.trim();

    final labels = <String>[];
    final fns = <Future<HttpResponse<String>> Function()>[];

    if (newProxy != _origProxy) {
      labels.add('依赖代理');
      fns.add(() => api.updateDependenceProxy(newProxy));
    }
    if (newPython != _origPython) {
      labels.add('Python镜像源');
      fns.add(() => api.updatePythonMirror(newPython));
    }
    if (newNode != _origNode) {
      labels.add('Node镜像源');
      fns.add(() => api.updateNodeMirror(newNode));
    }
    if (newLinux != _origLinux) {
      labels.add('Linux镜像源');
      fns.add(() => api.updateLinuxMirror(newLinux));
    }

    // 无任何变化
    if (labels.isEmpty) {
      setState(() => _saving = false);
      '配置未变化'.toast();
      return;
    }

    final results = <HttpResponse<String>>[];
    final detailLines = <String>[];

    for (int i = 0; i < fns.length; i++) {
      final label = labels[i];
      detailLines.add('▶ $label');
      try {
        final r = await fns[i]();
        results.add(r);
        if (r.success) {
          detailLines.add('  ✓ 成功');
        } else {
          final raw = r.message?.isNotEmpty == true ? r.message : 'code=${r.code}';
          detailLines.add('  ✗ 失败: $raw');
        }
      } catch (e, st) {
        detailLines.add('  ✗ 异常: $e');
        results.add(HttpResponse<String>(success: false, code: -9999, message: e.toString()));
      }
      detailLines.add('');
    }

    if (!mounted) return;

    final allSuccess = results.every((r) => r.success);
    setState(() => _saving = false);

    if (allSuccess) {
      // 更新原始值，避免重复保存
      _origProxy = newProxy;
      _origNode = newNode;
      _origPython = newPython;
      _origLinux = newLinux;

      final hasMirror = newNode.isNotEmpty || newLinux.isNotEmpty;
      if (hasMirror) {
        '依赖设置已保存，镜像源更新后将在后台重装依赖'.toast();
      } else {
        '依赖设置已保存'.toast();
      }
    } else {
      final detail = detailLines.join('\n');
      debugPrint('[DependencySetting] 保存失败:\n$detail');
      await Clipboard.setData(ClipboardData(text: detail));
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: CyberColors.bg,
          title: Text('保存失败', style: TextStyle(color: CyberColors.titleWhite)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                detail,
                style: TextStyle(color: CyberColors.descColor, fontSize: 12, fontFamily: 'MiSans'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('关闭', style: TextStyle(color: CyberColors.cyan)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    // 卡片标题/按钮字重跟随全局粗细调节
    _globalFw = FontWeight(ref.watch(textWeightProvider));

    Widget body;
    if (_loading) {
      body = Center(
        child: LoadingWidget(
          color: CyberColors.cyan,
          size: 30,
        ),
      );
    } else if (_errorMsg != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CyberColors.descColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                color: CyberColors.cyan.withOpacity(0.15),
                onPressed: _loadConfig,
                child: Text(
                  '重试',
                  style: TextStyle(color: CyberColors.cyan, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppleColors.spaceMd,
          right: AppleColors.spaceMd,
          top: AppleColors.spaceMd,
          bottom: MediaQuery.of(context).viewPadding.bottom + 30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: '依赖代理',
              subtitle: 'http_proxy / https_proxy，用于代理安装依赖',
              hint: '例如 http://127.0.0.1:7890',
              controller: _proxyController,
            ),
            const SizedBox(height: AppleColors.spaceMd),
            _buildSection(
              title: 'Node.js 镜像源',
              subtitle: 'pnpm config set registry，更新后会重装已安装的 nodejs 依赖',
              hint: '例如 https://registry.npmmirror.com',
              controller: _nodeController,
            ),
            const SizedBox(height: AppleColors.spaceMd),
            _buildSection(
              title: 'Python 镜像源',
              subtitle: 'pip3 config set global.index-url',
              hint: '例如 https://mirrors.aliyun.com/pypi/simple/',
              controller: _pythonController,
            ),
            const SizedBox(height: AppleColors.spaceMd),
            _buildSection(
              title: 'Linux 镜像源',
              subtitle: '仅 Linux 平台生效',
              hint: '例如 https://mirrors.aliyun.com',
              controller: _linuxController,
            ),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: QlAppBar(
            title: '依赖设置',
            canBack: true,
          ),
          body: body,
        ),
        if (_saving)
          Positioned.fill(
            child: AbsorbPointer(
              child: Center(
                child: LoadingWidget(
                  color: CyberColors.cyan,
                  size: 30,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required String hint,
    required TextEditingController controller,
  }) {
    return GlassCard(
      sigma: 10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: _globalFw,
              color: CyberColors.titleWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: CyberColors.descColor,
            ),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: controller,
            hintText: hint,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              color: CyberColors.titleWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        sigma: 10,
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: _saving ? null : _saveAll,
        child: Center(
          child: Text(
            '保存',
            style: TextStyle(
              fontSize: 16,
              fontWeight: _globalFw,
              color: CyberColors.cyan,
            ),
          ),
        ),
      ),
    );
  }
}
