import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
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

  bool _loading = true;
  bool _saving = false;
  String? _errorMsg;

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
        final data = decoded is Map ? decoded['data'] ?? decoded : decoded;
        if (data is Map) {
          _proxyController.text = data['dependenceProxy']?.toString() ?? '';
          _nodeController.text = data['nodeMirror']?.toString() ?? '';
          _pythonController.text = data['pythonMirror']?.toString() ?? '';
          _linuxController.text = data['linuxMirror']?.toString() ?? '';
        }
        setState(() => _loading = false);
      } catch (e) {
        setState(() {
          _loading = false;
          _errorMsg = '解析配置失败';
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
    final results = await Future.wait([
      api.updateDependenceProxy(_proxyController.text.trim()),
      api.updateNodeMirror(_nodeController.text.trim()),
      api.updatePythonMirror(_pythonController.text.trim()),
      api.updateLinuxMirror(_linuxController.text.trim()),
    ]);

    if (!mounted) return;

    final allSuccess = results.every((r) => r.success);
    setState(() => _saving = false);

    if (allSuccess) {
      '依赖设置已保存'.toast();
      Navigator.of(context).pop();
    } else {
      // 部分失败：列出失败的项
      final failed = <String>[];
      if (!results[0].success) failed.add('依赖代理');
      if (!results[1].success) failed.add('Node镜像源');
      if (!results[2].success) failed.add('Python镜像源');
      if (!results[3].success) failed.add('Linux镜像源');
      '${failed.join('、')}保存失败'.toast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);

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
      sigma: 15,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
        sigma: 15,
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: _saving ? null : _saveAll,
        child: Center(
          child: Text(
            '保存',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CyberColors.cyan,
            ),
          ),
        ),
      ),
    );
  }
}
