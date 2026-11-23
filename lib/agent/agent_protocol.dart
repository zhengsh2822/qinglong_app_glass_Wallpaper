import 'dart:async';

import 'package:dio/dio.dart';

/// Agent 后端档位。
/// 内置档：App 内直接调用 OpenAI 兼容模型，零部署，开源项目默认。
/// 远程档：把消息交给常驻服务（自建端点 / KSU Agent Core）。
enum AgentBackendType { builtin, remote }

extension AgentBackendTypeX on AgentBackendType {
  String get label =>
      this == AgentBackendType.builtin ? 'App 内置（默认）' : '远程服务';

  String get storageValue => name;

  static AgentBackendType from(String? value) =>
      value == 'remote' ? AgentBackendType.remote : AgentBackendType.builtin;
}

/// 统一事件类型。所有后端都按这套协议与 UI 通信：
/// intent -> candidates -> needConfirmation -> confirmed -> executed -> result
enum AgentEventType { message, candidates, needConfirmation, executed, error }

extension AgentEventTypeX on AgentEventType {
  String get storageValue => name;

  static AgentEventType from(String? value) => AgentEventType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AgentEventType.message,
      );
}

/// 模糊搜索得到的候选目标，UI 会渲染成可确认的列表。
class AgentCandidate {
  final String id;
  final String title;
  final String subtitle;

  const AgentCandidate({
    required this.id,
    required this.title,
    this.subtitle = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
      };

  factory AgentCandidate.fromJson(Map<String, dynamic> json) => AgentCandidate(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
      );
}

/// 待人工确认的动作。写操作与歧义目标必须先经过它。
class AgentPendingAction {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String summary;

  const AgentPendingAction({
    required this.id,
    required this.toolName,
    required this.arguments,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolName': toolName,
        'arguments': arguments,
        'summary': summary,
      };

  factory AgentPendingAction.fromJson(Map<String, dynamic> json) =>
      AgentPendingAction(
        id: json['id']?.toString() ?? '',
        toolName: json['toolName']?.toString() ?? '',
        arguments: (json['arguments'] is Map)
            ? Map<String, dynamic>.from(json['arguments'] as Map)
            : <String, dynamic>{},
        summary: json['summary']?.toString() ?? '',
      );
}

/// 后端 -> UI 的事件。远程后端只要输出同一份 JSON 即可复用同一套界面。
class AgentEvent {
  final AgentEventType type;
  final String text;
  final List<AgentCandidate> candidates;
  final AgentPendingAction? pending;
  final Map<String, dynamic>? data;

  const AgentEvent({
    required this.type,
    this.text = '',
    this.candidates = const [],
    this.pending,
    this.data,
  });

  factory AgentEvent.message(String text) =>
      AgentEvent(type: AgentEventType.message, text: text);

  factory AgentEvent.error(String text) =>
      AgentEvent(type: AgentEventType.error, text: text);

  factory AgentEvent.candidates(List<AgentCandidate> items, {String text = ''}) =>
      AgentEvent(type: AgentEventType.candidates, text: text, candidates: items);

  factory AgentEvent.needConfirmation(AgentPendingAction action,
          {String text = ''}) =>
      AgentEvent(
          type: AgentEventType.needConfirmation, text: text, pending: action);

  Map<String, dynamic> toJson() => {
        'type': type.storageValue,
        'text': text,
        'candidates': candidates.map((e) => e.toJson()).toList(),
        if (pending != null) 'pending': pending!.toJson(),
        if (data != null) 'data': data,
      };

  factory AgentEvent.fromJson(Map<String, dynamic> json) => AgentEvent(
        type: AgentEventTypeX.from(json['type']?.toString()),
        text: json['text']?.toString() ?? '',
        candidates: (json['candidates'] is List)
            ? (json['candidates'] as List)
                .whereType<Map>()
                .map((e) => AgentCandidate.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        pending: json['pending'] is Map
            ? AgentPendingAction.fromJson(
                Map<String, dynamic>.from(json['pending'] as Map))
            : null,
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : null,
      );
}

/// 暴露给 LLM 的参数化工具（OpenAI function calling 格式）。
class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final bool requiresConfirmation;
  final bool readOnly;

  const AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.requiresConfirmation,
    required this.readOnly,
  });

  Map<String, dynamic> toOpenAiFunction() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

/// 所有后端共用的接口。大脑可以换，UI / 确认 / 审计只有一套。
abstract class AgentBackend {
  String get label;

  Stream<AgentEvent> send(String text, {String? sessionId});

  Future<AgentEvent> confirm(AgentPendingAction action, bool approved);

  void dispose();
}

// ==================== 共享错误格式化（可复用组件）====================
//
// 内置档、远程档、工具执行都会遇到 DioException，统一在这里转成可行动的
// 中文提示，避免把一整串英文异常糊到聊天气泡里。
// 429 等限流错误不做自动重试，避免加剧限流。

String formatAgentError(Object error, {String prefix = '请求失败'}) =>
    '$prefix：${describeAgentError(error)}';

String describeAgentError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final server = _serverMessage(error.response?.data);

    if (status == 429) {
      return '模型服务返回 429（请求过于频繁或额度不足）。请稍后重试；'
          '若持续出现，检查该 API Key 的额度与速率限制，或换一个模型 / 服务端点。'
          '${_suffix(server)}';
    }
    if (status == 401 || status == 403) {
      return 'API Key 无效或没有权限（HTTP $status）。'
          '请在「AI 设置」检查 Base URL 与 API Key。${_suffix(server)}';
    }
    if (status == 404) {
      return '接口不存在（HTTP 404）。Base URL 通常应以 /v1 结尾，请检查填写。';
    }
    if (status == 400) {
      return '请求被拒绝（HTTP 400）：${server ?? '请检查模型名与参数'}';
    }
    if (status != null && status >= 500) {
      return '模型服务暂时不可用（HTTP $status），请稍后重试。${_suffix(server)}';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接或读取超时。请检查网络、代理与 Base URL。';
      case DioExceptionType.connectionError:
        return '无法连接模型服务。请检查网络、代理与 Base URL 是否可达。';
      case DioExceptionType.badCertificate:
        return '证书校验失败，请检查 HTTPS 配置。';
      case DioExceptionType.cancel:
        return '请求已取消。';
      default:
        if (status != null) {
          return '服务返回异常（HTTP $status）。${_suffix(server)}';
        }
        return '网络请求失败：${error.message ?? error.type.name}';
    }
  }

  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > 160 ? '${text.substring(0, 160)}…' : text;
}

String _suffix(String? server) =>
    (server == null || server.isEmpty) ? '' : '\n服务端提示：$server';

String? _serverMessage(dynamic data) {
  if (data is Map) {
    final err = data['error'];
    if (err is Map && err['message'] != null) {
      return _clip(err['message'].toString());
    }
    if (err is String) return _clip(err);
    if (data['message'] != null) return _clip(data['message'].toString());
  }
  if (data is String && data.trim().isNotEmpty) return _clip(data.trim());
  return null;
}

String _clip(String value) =>
    value.length > 220 ? '${value.substring(0, 220)}…' : value;
