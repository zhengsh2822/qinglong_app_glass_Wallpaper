import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:qinglong_app/agent/agent_capability.dart';
import 'package:qinglong_app/agent/agent_config.dart';
import 'package:qinglong_app/agent/agent_protocol.dart';
import 'package:qinglong_app/agent/agent_tools.dart';

/// App 本地 MCP Server：把青龙工具按 Model Context Protocol 暴露出去，
/// 让 Cursor / Claude Code / Cherry Studio 等 MCP 客户端直连手机 App 调用青龙能力。
///
/// 与 Core 的 /mcp 端点同协议，但是**客户端独立暴露服务**，可配置开关、端口
/// 与监听范围（仅本机 / 局域网）。
///
/// 传输：Streamable HTTP —— 只做 POST 单次 JSON-RPC 请求/响应，不开 SSE 长连接。
/// 规范允许这种无状态形态：客户端探测 GET 流时返回 405，客户端会降级为纯 POST。
class AgentMCPServer {
  AgentMCPServer._();

  static final AgentMCPServer instance = AgentMCPServer._();

  HttpServer? _server;
  QingLongToolExecutor? _executor;
  Set<String> _scopes = const <String>{};
  bool _lan = false;

  bool get running => _server != null;

  /// 当前是否监听全部网卡（局域网可访问）
  bool get lan => _lan;

  int _port = 9127;
  int get port => _port;

  /// 启动本地 MCP 服务。返回实际监听端口（被占用时自增重试）。
  ///
  /// [lan] 为 true 时绑定 0.0.0.0，PC 端客户端才能用手机 IP 连进来；
  /// 默认只绑 127.0.0.1，避免同网段任意设备调用青龙 API。
  Future<int> start({
    required int port,
    required QingLongToolExecutor executor,
    Set<String> scopes = const <String>{},
    bool lan = false,
  }) async {
    await stop();
    _executor = executor;
    _scopes = scopes;

    final bindAddr =
        lan ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;
    var p = port;
    for (var i = 0; i < 5; i++) {
      try {
        _server = await HttpServer.bind(bindAddr, p);
        _port = p;
        _lan = lan;
        break;
      } catch (_) {
        p++;
      }
    }
    if (_server == null) {
      throw StateError('端口 $port 不可用');
    }

    _server!.listen(_handleRequest, onError: (_) {}, cancelOnError: false);
    return _port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _lan = false;
  }

  /// App 启动时恢复监听。
  ///
  /// 开关与端口是持久化的，但 HttpServer 不跨进程存活；不在这里恢复，
  /// 会出现「设置页显示已启用、端口其实没开」的假状态。
  static Future<void> restore() async {
    try {
      final config = await AgentConfigStore.load();
      if (!config.mcpEnabled || instance.running) return;
      final index = AgentCapabilityService.resolveAccountIndex();
      await instance.start(
        port: config.mcpPort,
        executor: QingLongToolExecutor(index, scopes: config.scopes),
        scopes: config.scopes,
        lan: config.mcpLan,
      );
    } catch (_) {
      // 端口占用等异常不阻断 App 启动
    }
  }

  /// 取本机局域网 IPv4，供 PC 端 MCP 客户端填写；取不到时回退 127.0.0.1。
  static Future<String> localAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final itf in interfaces) {
        for (final addr in itf.addresses) {
          if (addr.isLoopback) continue;
          // 169.254.x.x 是链路本地地址，跨设备不可用
          if (addr.address.startsWith('169.254.')) continue;
          return addr.address;
        }
      }
    } catch (_) {
      // 无网络或权限不足时静默回退
    }
    return '127.0.0.1';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final res = req.response;
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Accept, Mcp-Session-Id, MCP-Protocol-Version',
    );
    res.headers.set(
      'Access-Control-Allow-Methods',
      'POST, GET, DELETE, OPTIONS',
    );

    // CORS 预检
    if (req.method == 'OPTIONS') {
      res.statusCode = HttpStatus.noContent;
      await res.close();
      return;
    }

    // 会话终止：本服务无状态，直接确认
    if (req.method == 'DELETE') {
      res.statusCode = HttpStatus.ok;
      await res.close();
      return;
    }

    // GET 是客户端探测 SSE 长连接。本服务只做请求-响应，
    // 回 405 + Allow 让客户端按规范降级为 POST。
    if (req.method != 'POST') {
      res.statusCode = HttpStatus.methodNotAllowed;
      res.headers.set('Allow', 'POST, OPTIONS, DELETE');
      await res.close();
      return;
    }

    try {
      final raw = await utf8.decoder.bind(req).join();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final id = data['id'];
      final method = data['method']?.toString() ?? '';
      final params =
          data['params'] is Map
              ? Map<String, dynamic>.from(data['params'] as Map)
              : <String, dynamic>{};

      // 通知（notifications/initialized 等）无 id：按规范回 202 空体。
      // 返回 JSON-RPC 响应会让严格客户端判定握手失败。
      if (!data.containsKey('id') || method.startsWith('notifications/')) {
        res.statusCode = HttpStatus.accepted;
        await res.close();
        return;
      }

      final result = await _dispatch(method, params);
      if (result == null) {
        res.headers.contentType = ContentType.json;
        res.write(
          jsonEncode(<String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'error': <String, dynamic>{
              'code': -32601,
              'message': 'method not found: $method',
            },
          }),
        );
        await res.close();
        return;
      }

      res.headers.contentType = ContentType.json;
      res.write(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': id,
          'result': result,
        }),
      );
      await res.close();
    } catch (e) {
      res.statusCode = HttpStatus.badRequest;
      res.write(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': 0,
          'error': <String, dynamic>{
            'code': -32700,
            'message': 'parse error: $e',
          },
        }),
      );
      await res.close();
    }
  }

  Future<Map<String, dynamic>?> _dispatch(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'initialize':
        // 回显客户端请求的版本：新旧客户端都能继续握手，
        // 固定写死某一版会让另一侧判定版本不兼容。
        final asked = params['protocolVersion']?.toString() ?? '';
        return <String, dynamic>{
          'protocolVersion': asked.isNotEmpty ? asked : '2025-06-18',
          'capabilities': <String, dynamic>{
            'tools': <String, dynamic>{'listChanged': false},
          },
          'serverInfo': <String, dynamic>{
            'name': 'qinglong-app-mcp',
            'version': '1.0.0',
          },
          'instructions': '青龙面板工具集。调用 tools/list 查看可用能力。',
        };

      // 部分客户端握手后会 ping 保活
      case 'ping':
        return <String, dynamic>{};

      case 'tools/list':
        return <String, dynamic>{
          'tools':
              AgentToolRegistry.available(
                _scopes,
                disabled: const <String>{},
              ).map(_toMCPTool).toList(),
        };

      case 'tools/call':
        final name = params['name']?.toString() ?? '';
        final args =
            params['arguments'] is Map
                ? Map<String, dynamic>.from(params['arguments'] as Map)
                : <String, dynamic>{};
        final executor = _executor;
        if (executor == null) {
          return <String, dynamic>{
            'content': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'text', 'text': '服务未就绪'},
            ],
            'isError': true,
          };
        }
        var isError = false;
        String text;
        try {
          text = await executor.execute(name, args);
        } catch (e) {
          text = '执行失败：$e';
          isError = true;
        }
        return <String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': text},
          ],
          if (isError) 'isError': true,
        };

      // 客户端会主动探测这三类能力。返回空列表比 -32601 更友好，
      // 避免有的客户端把「未实现」当成服务端异常而中断连接。
      case 'resources/list':
        return <String, dynamic>{'resources': <dynamic>[]};
      case 'resources/templates/list':
        return <String, dynamic>{'resourceTemplates': <dynamic>[]};
      case 'prompts/list':
        return <String, dynamic>{'prompts': <dynamic>[]};
      case 'logging/setLevel':
        return <String, dynamic>{};

      default:
        return null;
    }
  }

  static Map<String, dynamic> _toMCPTool(AgentTool t) => <String, dynamic>{
    'name': t.name,
    'description': t.description,
    'inputSchema': <String, dynamic>{
      'type': 'object',
      'properties': t.parameters['properties'] ?? <String, dynamic>{},
      'required': t.parameters['required'] ?? <String>[],
    },
  };
}
