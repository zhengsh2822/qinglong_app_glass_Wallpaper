import 'dart:async';

import 'package:dio/dio.dart';
import 'package:qinglong_app/agent/agent_config.dart';
import 'package:qinglong_app/agent/agent_protocol.dart';

/// 远程档：把消息交给常驻服务，App 只渲染同一套事件协议。
///
/// 统一协议（自建端点 / KSU Agent Core 都按这个实现）：
///   POST {endpoint}/v1/agent/message
///     -> {"text": "...", "sessionId": "..."}
///     <- {"events": [ AgentEvent.toJson(), ... ], "sessionId": "..."}
///   POST {endpoint}/v1/agent/confirm
///     -> {"action": AgentPendingAction.toJson(), "approved": true, "sessionId": "..."}
///     <- {"events": [ AgentEvent.toJson(), ... ]}
///
/// 这样三种常驻后端只需实现两个 HTTP 端点，客户端 UI / 确认 / 审计无需各写一套。
/// QQ 机器人需要 7×24 在线，只有远程档（或 KSU Agent Core）能提供。
class RemoteAgentBackend implements AgentBackend {
  final AgentConfig config;
  late final Dio _dio;
  String _sessionId = '';
  bool _disposed = false;

  RemoteAgentBackend({required this.config}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ));
  }

  @override
  String get label => '远程服务';

  String get _endpoint =>
      config.remoteEndpoint.trim().replaceAll(RegExp(r'/+$'), '');

  Map<String, dynamic> get _headers => <String, dynamic>{
        'Content-Type': 'application/json',
        if (config.remoteToken.trim().isNotEmpty)
          'Authorization': 'Bearer ${config.remoteToken.trim()}',
      };

  @override
  Stream<AgentEvent> send(String text, {String? sessionId}) async* {
    if (_disposed) return;
    if (!config.remoteReady) {
      yield AgentEvent.error('请先在「Agent 设置」填写远程服务地址。');
      return;
    }
    try {
      final response = await _dio.post<dynamic>(
        '$_endpoint/v1/agent/message',
        options: Options(headers: _headers),
        data: <String, dynamic>{
          'text': text,
          'sessionId': sessionId ?? _sessionId,
          // Skill 路由手册开关：null = 跟随服务端默认（开）
          if (config.useSkill != null) 'useSkill': config.useSkill,
        },
      );
      if (_disposed) return;
      final events = _events(response.data);
      if (events.isEmpty) {
        yield AgentEvent.message('远程服务未返回任何事件。');
        return;
      }
      for (final event in events) {
        yield event;
      }
    } catch (e) {
      yield AgentEvent.error(formatAgentError(e, prefix: '远程服务调用失败'));
    }
  }

  @override
  Future<AgentEvent> confirm(
      AgentPendingAction action, bool approved) async {
    if (!config.remoteReady) {
      return AgentEvent.error('远程服务未配置。');
    }
    try {
      final response = await _dio.post<dynamic>(
        '$_endpoint/v1/agent/confirm',
        options: Options(headers: _headers),
        data: <String, dynamic>{
          'action': action.toJson(),
          'approved': approved,
          'sessionId': _sessionId,
        },
      );
      final events = _events(response.data);
      if (events.isEmpty) {
        return AgentEvent.message(approved ? '已提交执行。' : '已取消。');
      }
      return events.first;
    } catch (e) {
      return AgentEvent.error(formatAgentError(e, prefix: '确认请求失败'));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _dio.close(force: true);
  }

  List<AgentEvent> _events(dynamic data) {
    if (data is! Map) return const <AgentEvent>[];
    final root = Map<String, dynamic>.from(data);
    final sid = root['sessionId']?.toString();
    if (sid != null && sid.isNotEmpty) _sessionId = sid;

    final raw = root['events'];
    if (raw is! List) {
      if (root.containsKey('type')) {
        return <AgentEvent>[AgentEvent.fromJson(root)];
      }
      return const <AgentEvent>[];
    }
    return raw
        .whereType<Map>()
        .map((e) => AgentEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
