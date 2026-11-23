import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/agent/agent_config.dart';
import 'package:qinglong_app/agent/agent_mcp_server.dart';
import 'package:qinglong_app/agent/agent_protocol.dart';
import 'package:qinglong_app/agent/agent_session_store.dart';
import 'package:qinglong_app/agent/agent_tools.dart';
import 'package:qinglong_app/agent/mcp_client_formats.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/ui/agent_toast.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/selector_card.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/scope_picker.dart';
import 'package:qinglong_app/main.dart';

/// Agent 设置：四档后端在客户端里收敛为「内置 / 远程」两个入口。
/// 远程入口服务于自建 HTTP 端点与 KSU Agent Core，
/// 二者只要实现同一份 /v1/agent 事件协议即可。
/// 取色、字重、沉浸与键盘处理全部按项目统一方案，不另起一套。
class AgentSettingsPage extends ConsumerStatefulWidget {
  /// 与 AgentPage 一致的账号槽位：MCP 绑定、会话清理都按它执行。
  final int? accountIndex;

  const AgentSettingsPage({super.key, this.accountIndex});

  @override
  ConsumerState<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends ConsumerState<AgentSettingsPage>
    with WidgetsBindingObserver {
  final TextEditingController _baseUrl = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _temperature = TextEditingController();
  final TextEditingController _remoteEndpoint = TextEditingController();
  final TextEditingController _remoteToken = TextEditingController();

  AgentBackendType _backend = AgentBackendType.builtin;
  Set<String> _scopes = Set<String>.from(AgentConfig.defaultScopes);
  int _keepDays = 7;
  bool _useSkill = true;
  String _llmProtocol = 'openai_chat';
  bool _mcpEnabled = false;
  int _mcpPort = 9127;
  bool _mcpLan = false;
  String _mcpClient = 'cursor';
  String _localIp = '127.0.0.1';
  String _mcpStyle = 'manual';
  bool _loading = true;
  bool _saving = false;

  final TextEditingController _mcpPortCtrl = TextEditingController(
    text: '9127',
  );

  double _lastKeyboard = 0;

  /// 当前账号槽位，保留给「清空会话」「MCP 绑定」等账号级操作
  int _accountIndex = 0;
  bool _slotResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_slotResolved) return;
    _slotResolved = true;
    _accountIndex =
        widget.accountIndex ??
        SingleAccountPageState.of(context)?.index ??
        MultiAccountPageState.currentAccountIndex;
    _load();
  }

  @override
  void didChangeMetrics() {
    final bottom = View.maybeOf(context)?.viewInsets.bottom ?? 0;
    if (bottom == _lastKeyboard) return;
    _lastKeyboard = bottom;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _temperature.dispose();
    _remoteEndpoint.dispose();
    _remoteToken.dispose();
    _mcpPortCtrl.dispose();
    super.dispose();
  }

  /// 取本机局域网 IP，Manual 模式下给 PC 端客户端拼地址用。
  Future<void> _refreshLocalIp() async {
    final ip = await AgentMCPServer.localAddress();
    if (!mounted) return;
    setState(() => _localIp = ip);
  }

  Future<void> _load() async {
    final config = await AgentConfigStore.load();
    if (!mounted) return;
    setState(() {
      _backend = config.backendType;
      _baseUrl.text = config.llmBaseUrl;
      _apiKey.text = config.llmApiKey;
      _model.text = config.llmModel;
      _temperature.text =
          config.temperature == null ? '' : config.temperature.toString();
      _remoteEndpoint.text = config.remoteEndpoint;
      _remoteToken.text = config.remoteToken;
      _scopes = Set<String>.from(config.scopes);
      _keepDays = AgentSessionStore.keepDays;
      _useSkill = config.useSkill ?? true;
      _llmProtocol = config.llmProtocol;
      _mcpEnabled = config.mcpEnabled;
      _mcpPort = config.mcpPort;
      _mcpLan = config.mcpLan;
      _mcpClient = config.mcpClient;
      _mcpPortCtrl.text = config.mcpPort.toString();
      _loading = false;
    });
    _refreshLocalIp();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    _mcpPort = int.tryParse(_mcpPortCtrl.text.trim()) ?? _mcpPort;
    final parsedTemperature = double.tryParse(_temperature.text.trim());
    await AgentConfigStore.save(
      AgentConfig(
        backendType: _backend,
        llmBaseUrl: _baseUrl.text,
        llmApiKey: _apiKey.text,
        llmModel: _model.text,
        temperature: parsedTemperature,
        remoteEndpoint: _remoteEndpoint.text,
        remoteToken: _remoteToken.text,
        scopes: _scopes.isEmpty ? AgentConfig.defaultScopes : _scopes,
        useSkill: _useSkill,
        llmProtocol: _llmProtocol,
        mcpEnabled: _mcpEnabled,
        mcpPort: _mcpPort,
        mcpLan: _mcpLan,
        mcpClient: _mcpClient,
      ),
    );
    await AgentSessionStore.setKeepDays(_keepDays);
    // MCP Server 随开关启停：启用则起本地 HTTP 服务，关闭则停
    if (_mcpEnabled) {
      try {
        await AgentMCPServer.instance.start(
          port: _mcpPort,
          executor: QingLongToolExecutor(_accountIndex, scopes: _scopes),
          scopes: _scopes,
          lan: _mcpLan,
          accountIndex: _accountIndex,
        );
        _mcpPort = AgentMCPServer.instance.port;
      } catch (_) {
        // 端口占用等异常不阻断保存
      }
    } else {
      await AgentMCPServer.instance.stop();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    AgentToast.show(context, '已保存');
    Navigator.of(context).pop();
  }

  /// 按监听范围拼端点：局域网模式用本机 IP，PC 端客户端才连得上；
  /// 仅本机模式用 127.0.0.1，只对机内客户端有效。
  String get _mcpUrl {
    final host = _mcpLan ? _localIp : '127.0.0.1';
    return 'http://$host:$_mcpPort/mcp';
  }

  /// 当前档位下的配置片段：两个命令快捷档 + Manual 的客户端格式表。
  String get _mcpSnippet {
    switch (_mcpStyle) {
      case 'claude':
        return 'claude mcp add --transport http qinglong_app "$_mcpUrl"';
      case 'codex':
        return 'codex mcp add qinglong_app --url "$_mcpUrl"';
      default:
        return mcpClientFormatOf(_mcpClient).build(_mcpUrl);
    }
  }

  String get _mcpTarget {
    switch (_mcpStyle) {
      case 'claude':
        return '终端执行；也可写入项目 .mcp.json 的 mcpServers';
      case 'codex':
        return '终端执行；或写入 ~/.codex/config.toml';
      default:
        return mcpClientFormatOf(_mcpClient).target;
    }
  }

  String get _mcpStyleLabel {
    switch (_mcpStyle) {
      case 'claude':
        return 'Claude Code 命令';
      case 'codex':
        return 'Codex 命令';
      default:
        return mcpClientFormatOf(_mcpClient).name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(themeProvider);
    final titleColor = model.themeColor.titleColor();
    final descColor = model.themeColor.descColor();
    final accent = model.primaryColor;
    // 真实监听状态：开关只是意图，进程重启后未恢复时会不一样
    final bool mcpRunning = AgentMCPServer.instance.running;
    final navBottom = MediaQuery.of(context).viewPadding.bottom;
    // MediaQueryData.fromView 会做 devicePixelRatio 转换；直接读 View.viewInsets
    // 拿到的是物理像素，会让底部留白变成三倍。
    final keyboard =
        MediaQueryData.fromView(View.of(context)).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(title: 'AI 设置'),
      body: GlassPageBackground(child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + navBottom),
                  children: <Widget>[
                    _sectionTitle('后端档位', titleColor),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: SelectorCard(
                        title: _backend.label,
                        subtitle: '选择对话后端',
                        items: <SelectorCardItem>[
                          for (final t in AgentBackendType.values)
                            SelectorCardItem(
                              title: t.label,
                              selected: _backend == t,
                              onTap: () => setState(() => _backend = t),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _hintCard(
                      '默认档零部署：填一个 OpenAI 兼容地址、API Key 和模型名，'
                      '打开 App 即可用对话管理青龙，不需要 root、模块或外部服务。',
                      descColor,
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('模型（内置档）', titleColor),
                    _sectionTitle('API 协议', titleColor),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: SelectorCard(
                        title:
                            const <String, String>{
                              'openai_chat': 'OpenAI Chat Completions',
                              'anthropic': 'Anthropic Messages',
                              'openai_responses': 'OpenAI Responses',
                            }[_llmProtocol] ??
                            'OpenAI Chat Completions',
                        subtitle: '模型 API 协议',
                        items: <SelectorCardItem>[
                          for (final e
                              in const <String, String>{
                                'openai_chat': 'OpenAI Chat Completions',
                                'anthropic': 'Anthropic Messages',
                                'openai_responses': 'OpenAI Responses',
                              }.entries)
                            SelectorCardItem(
                              title: e.value,
                              selected: _llmProtocol == e.key,
                              onTap: () => setState(() => _llmProtocol = e.key),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _baseUrl,
                      'Base URL',
                      'https://your-api-host/v1',
                      titleColor,
                      descColor,
                    ),
                    _field(
                      _apiKey,
                      'API Key',
                      'API Key',
                      titleColor,
                      descColor,
                      obscure: true,
                    ),
                    _field(_model, '模型名', '模型名', titleColor, descColor),
                    _field(
                      _temperature,
                      'temperature（留空则不传）',
                      'MiMo 思考模式等不支持自定义值，留空即可',
                      titleColor,
                      descColor,
                      number: true,
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('远程服务（自建 / KSU Core）', titleColor),
                    _field(
                      _remoteEndpoint,
                      '服务地址',
                      'http://127.0.0.1:18789',
                      titleColor,
                      descColor,
                    ),
                    _field(
                      _remoteToken,
                      '访问令牌（可选）',
                      '',
                      titleColor,
                      descColor,
                      obscure: true,
                    ),
                    const SizedBox(height: 8),
                    _hintCard(
                      '远程服务需实现 POST /v1/agent/message 与 /v1/agent/confirm，'
                      '并返回统一事件 JSON。QQ 机器人与 7×24 无人值守必须依赖常驻后端，'
                      '仅靠 App 内置档无法在 App 未打开时接收 QQ 消息。',
                      descColor,
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('应用授权 scopes', titleColor),
                    ScopePicker(
                      selected: _scopes,
                      onChanged: (next) => setState(() => _scopes = next),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '当前已选 ${_scopes.length} 项：${(_scopes.toList()..sort()).join(', ')}',
                      style: TextStyle(fontSize: 11, color: descColor),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('MCP Server', titleColor),
                    SwitchListTile(
                      value: _mcpEnabled,
                      onChanged: (v) => setState(() => _mcpEnabled = v),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '启用 MCP 服务器',
                        style: TextStyle(color: titleColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        '把青龙工具以 MCP 协议暴露给 Cursor / Claude Code / '
                        'Cherry Studio 等客户端，可选命令或多种配置文件格式。',
                        style: TextStyle(color: descColor, fontSize: 11),
                      ),
                    ),
                    if (_mcpEnabled) ...<Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: mcpRunning ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mcpRunning ? '运行中' : '未启动',
                            style: TextStyle(
                              color: mcpRunning ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '端口:',
                            style: TextStyle(color: descColor, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 78,
                            child: TextField(
                              controller: _mcpPortCtrl,
                              keyboardType: TextInputType.number,
                              onSubmitted:
                                  (v) => setState(
                                    () =>
                                        _mcpPort =
                                            int.tryParse(v.trim()) ?? _mcpPort,
                                  ),
                              style: TextStyle(color: titleColor, fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        value: _mcpLan,
                        onChanged: (v) {
                          setState(() => _mcpLan = v);
                          if (v) _refreshLocalIp();
                        },
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '允许局域网访问',
                          style: TextStyle(color: titleColor, fontSize: 14),
                        ),
                        subtitle: Text(
                          _mcpLan
                              ? '同网段设备用 $_localIp:$_mcpPort 接入，'
                                  'CORS 已放开，注意 scopes 授权范围。'
                              : '仅 127.0.0.1 可连。PC 上的 Cursor / Claude Code '
                                  '需开启此项才能连入手机。',
                          style: TextStyle(color: descColor, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('MCP 配置', titleColor),
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: SelectorCard(
                          title: _mcpStyleLabel,
                          subtitle: '选择配置片段格式',
                          items: <SelectorCardItem>[
                            SelectorCardItem(
                              title: 'Claude Code 命令',
                              subtitle: 'Shell · claude mcp add',
                              selected: _mcpStyle == 'claude',
                              onTap: () => setState(() => _mcpStyle = 'claude'),
                            ),
                            SelectorCardItem(
                              title: 'Codex 命令',
                              subtitle: 'Shell · codex mcp add',
                              selected: _mcpStyle == 'codex',
                              onTap: () => setState(() => _mcpStyle = 'codex'),
                            ),
                            SelectorCardItem(
                              title: 'Manual（多客户端）',
                              subtitle:
                                  'Cursor / Copilot / Gemini CLI / 通义灵码 等',
                              selected: _mcpStyle == 'manual',
                              onTap: () => setState(() => _mcpStyle = 'manual'),
                            ),
                          ],
                        ),
                      ),
                      if (_mcpStyle == 'manual') ...<Widget>[
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: SelectorCard(
                            title: mcpClientFormatOf(_mcpClient).name,
                            subtitle:
                                '选择要接入的客户端 · '
                                '${mcpClientFormatOf(_mcpClient).snippetType}',
                            items:
                                mcpClientFormats
                                    .map<SelectorCardItem>(
                                      (f) => SelectorCardItem(
                                        title: f.name,
                                        subtitle:
                                            '${f.snippetType} · ${f.target}',
                                        selected: f.id == _mcpClient,
                                        onTap:
                                            () => setState(
                                              () => _mcpClient = f.id,
                                            ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        decoration: BoxDecoration(
                          color: descColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    _mcpSnippet,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 11.5,
                                      height: 1.45,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.copy, size: 18, color: accent),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _mcpSnippet),
                                );
                                AgentToast.show(context, '已复制');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_mcpTarget。Core 的 MCP 端点为 http://127.0.0.1:18790/mcp。',
                        style: TextStyle(color: descColor, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle('Skill 路由手册', titleColor),
                    SwitchListTile(
                      value: _useSkill,
                      onChanged: (v) => setState(() => _useSkill = v),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '启用官方路由手册',
                        style: TextStyle(color: titleColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        '服务端注入 openapi.md 路由表，AI 按表选 path，不靠猜、省 token。'
                        '关闭后退回纯工具描述模式。',
                        style: TextStyle(color: descColor, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('对话记录保留', titleColor),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: SelectorCard(
                        title: '$_keepDays 天',
                        subtitle: '超期会话在下次进入 AI 助手时自动清理',
                        items:
                            const <int>[1, 3, 7]
                                .map<SelectorCardItem>(
                                  (d) => SelectorCardItem(
                                    title: '$d 天',
                                    subtitle:
                                        d == 1
                                            ? '只保留最近 24 小时'
                                            : (d == 3
                                                ? '保留最近 3 天'
                                                : '保留最近 7 天'),
                                    selected: _keepDays == d,
                                    onTap: () => setState(() => _keepDays = d),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      onPressed: _saving ? null : _save,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_saving ? '保存中…' : '保存'),
                      ),
                    ),
                  ],
                ),
      ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight(ref.watch(textWeightProvider)),
        color: color,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    Color titleColor,
    Color descColor, {
    bool obscure = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: number ? TextInputType.number : null,
      style: TextStyle(color: titleColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontSize: 12, color: descColor),
        hintStyle: TextStyle(fontSize: 12, color: descColor),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Widget _hintCard(String text, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color)),
  );
}
