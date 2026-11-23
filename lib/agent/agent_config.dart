import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:qinglong_app/agent/agent_protocol.dart';
import 'package:qinglong_app/utils/crypto_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// Agent 配置。非敏感项存 SharedPreferences；模型 API Key 经项目现成的
/// CryptoUtils(AES-256-GCM + PBKDF2) 加密后再落盘，避免明文凭据。
///
/// [temperature] 为 null 时请求体不带该参数 —— 小米 MiMo 等思考模式模型
/// 不支持自定义 temperature，强行传 0.2 会被部分端点拒绝（400）。
///
/// 说明：设备口令本身也存本地，因此这是「本地混淆级」保护，不是 Keystore 级。
/// 若后续引入 flutter_secure_storage，只需替换 AgentConfigStore 的存取实现。
class AgentConfig {
  final AgentBackendType backendType;
  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModel;
  final double? temperature;
  final String remoteEndpoint;
  final String remoteToken;
  final Set<String> scopes;

  /// 是否启用 Skill 路由手册（服务端注入官方 openapi.md 路由表）。
  /// null = 跟随服务端默认（开）；true/false = 请求级强制覆盖。
  final bool? useSkill;

  /// 模型 API 协议三选一：openai_chat（默认）/ anthropic / openai_responses。
  final String llmProtocol;

  /// App 本地 MCP Server：开关、端口、监听范围与 Manual 选中的客户端格式。
  final bool mcpEnabled;
  final int mcpPort;

  /// true = 监听 0.0.0.0（PC 端客户端可用手机 IP 连入）；
  /// false = 仅 127.0.0.1（只有机内客户端能连）。
  final bool mcpLan;

  /// Manual 模式下选中的客户端格式 id，见 mcp_client_formats.dart。
  final String mcpClient;

  const AgentConfig({
    this.backendType = AgentBackendType.builtin,
    this.llmBaseUrl = '',
    this.llmApiKey = '',
    this.llmModel = '',
    this.temperature,
    this.remoteEndpoint = '',
    this.remoteToken = '',
    this.scopes = defaultScopes,
    this.useSkill,
    this.llmProtocol = 'openai_chat',
    this.mcpEnabled = false,
    this.mcpPort = 9127,
    this.mcpLan = false,
    this.mcpClient = 'cursor',
  });

  /// 只读优先。dashboard 系列用于回答「今天运行了哪些任务」这类问题。
  static const Set<String> defaultScopes = <String>{
    'crons:read',
    'envs:read',
    'scripts:read',
    'logs:read',
    'dependencies:read',
    'system:read',
    'dashboard:read',
  };

  bool get builtinReady =>
      llmBaseUrl.trim().isNotEmpty &&
      llmApiKey.trim().isNotEmpty &&
      llmModel.trim().isNotEmpty;

  bool get remoteReady => remoteEndpoint.trim().isNotEmpty;

  AgentConfig copyWith({
    AgentBackendType? backendType,
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModel,
    double? temperature,
    String? remoteEndpoint,
    String? remoteToken,
    Set<String>? scopes,
    bool? useSkill,
    String? llmProtocol,
    bool? mcpEnabled,
    int? mcpPort,
    bool? mcpLan,
    String? mcpClient,
  }) => AgentConfig(
    backendType: backendType ?? this.backendType,
    llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
    llmApiKey: llmApiKey ?? this.llmApiKey,
    llmModel: llmModel ?? this.llmModel,
    temperature: temperature ?? this.temperature,
    remoteEndpoint: remoteEndpoint ?? this.remoteEndpoint,
    remoteToken: remoteToken ?? this.remoteToken,
    scopes: scopes ?? this.scopes,
    useSkill: useSkill ?? this.useSkill,
    llmProtocol: llmProtocol ?? this.llmProtocol,
    mcpEnabled: mcpEnabled ?? this.mcpEnabled,
    mcpPort: mcpPort ?? this.mcpPort,
    mcpLan: mcpLan ?? this.mcpLan,
    mcpClient: mcpClient ?? this.mcpClient,
  );
}

class AgentConfigStore {
  AgentConfigStore._();

  static const String _kBackend = 'agent_backend_v1';
  static const String _kLlmBaseUrl = 'agent_llm_base_url_v1';
  static const String _kLlmApiKey = 'agent_llm_api_key_v1';
  static const String _kLlmModel = 'agent_llm_model_v1';
  static const String _kLlmTemperature = 'agent_llm_temperature_v1';
  static const String _kRemoteEndpoint = 'agent_remote_endpoint_v1';
  static const String _kRemoteToken = 'agent_remote_token_v1';
  static const String _kScopes = 'agent_scopes_v1';
  static const String _kDeviceSecret = 'agent_device_secret_v1';
  static const String _kUseSkill = 'agent_use_skill_v1';
  static const String _kLlmProtocol = 'agent_llm_protocol_v1';
  static const String _kMcpEnabled = 'agent_mcp_enabled_v1';
  static const String _kMcpPort = 'agent_mcp_port_v1';
  static const String _kMcpLan = 'agent_mcp_lan_v1';
  static const String _kMcpClient = 'agent_mcp_client_v1';

  static final Map<String, String> _memoryKeys = <String, String>{};

  static bool? _decodeBool(String v) =>
      v == '1' ? true : (v == '0' ? false : null);

  static Future<AgentConfig> load() async {
    return AgentConfig(
      backendType: AgentBackendTypeX.from(SpUtil.getString(_kBackend)),
      llmBaseUrl: SpUtil.getString(_kLlmBaseUrl),
      llmApiKey: await _readSecret(_kLlmApiKey),
      llmModel: SpUtil.getString(_kLlmModel),
      temperature: double.tryParse(SpUtil.getString(_kLlmTemperature)),
      remoteEndpoint: SpUtil.getString(_kRemoteEndpoint),
      remoteToken: await _readSecret(_kRemoteToken),
      scopes: _decodeScopes(SpUtil.getString(_kScopes)),
      useSkill: _decodeBool(SpUtil.getString(_kUseSkill)),
      llmProtocol: SpUtil.getString(_kLlmProtocol, defValue: 'openai_chat'),
      mcpEnabled: SpUtil.getBool(_kMcpEnabled),
      mcpPort: int.tryParse(SpUtil.getString(_kMcpPort)) ?? 9127,
      mcpLan: SpUtil.getBool(_kMcpLan),
      mcpClient: SpUtil.getString(_kMcpClient, defValue: 'cursor'),
    );
  }

  static Future<void> save(AgentConfig config) async {
    await SpUtil.putString(_kBackend, config.backendType.storageValue);
    await SpUtil.putString(_kLlmBaseUrl, config.llmBaseUrl.trim());
    await SpUtil.putString(_kLlmModel, config.llmModel.trim());
    await SpUtil.putString(
      _kLlmTemperature,
      config.temperature == null ? '' : config.temperature.toString(),
    );
    await SpUtil.putString(_kRemoteEndpoint, config.remoteEndpoint.trim());
    await SpUtil.putString(_kScopes, _encodeScopes(config.scopes));
    await SpUtil.putString(
      _kUseSkill,
      config.useSkill == null ? '' : (config.useSkill! ? '1' : '0'),
    );
    await SpUtil.putString(_kLlmProtocol, config.llmProtocol);
    await SpUtil.putBool(_kMcpEnabled, config.mcpEnabled);
    await SpUtil.putString(_kMcpPort, config.mcpPort.toString());
    await SpUtil.putBool(_kMcpLan, config.mcpLan);
    await SpUtil.putString(_kMcpClient, config.mcpClient);
    await _writeSecret(_kLlmApiKey, config.llmApiKey.trim());
    await _writeSecret(_kRemoteToken, config.remoteToken.trim());
  }

  static Set<String> _decodeScopes(String raw) {
    if (raw.trim().isEmpty) return AgentConfig.defaultScopes;
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static String _encodeScopes(Set<String> scopes) =>
      (scopes.toList()..sort()).join(',');

  /// 供会话持久化等模块复用的设备口令（单一来源，避免重复实现加密）。
  static Future<String> deviceSecret() async {
    String value = SpUtil.getString(_kDeviceSecret);
    if (value.isEmpty) {
      final random = Random.secure();
      value =
          List<String>.generate(
            32,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
      await SpUtil.putString(_kDeviceSecret, value);
    }
    return value;
  }

  static Future<void> _writeSecret(String key, String plain) async {
    if (plain.isEmpty) {
      _memoryKeys.remove(key);
      await SpUtil.remove(key);
      return;
    }
    try {
      final passphrase = await deviceSecret();
      final bytes = await CryptoUtils.encryptBytes(
        Uint8List.fromList(utf8.encode(plain)),
        passphrase,
      );
      await SpUtil.putString(key, base64Encode(bytes));
      _memoryKeys.remove(key);
    } catch (_) {
      // 加密不可用时仅保留在内存，绝不回退成明文落盘。
      _memoryKeys[key] = plain;
      await SpUtil.remove(key);
    }
  }

  static Future<String> _readSecret(String key) async {
    final inMemory = _memoryKeys[key];
    if (inMemory != null) return inMemory;
    final stored = SpUtil.getString(key);
    if (stored.isEmpty) return '';
    try {
      final passphrase = await deviceSecret();
      final bytes = await CryptoUtils.decryptBytes(
        Uint8List.fromList(base64Decode(stored)),
        passphrase,
      );
      return utf8.decode(bytes);
    } catch (_) {
      return '';
    }
  }
}
