import 'dart:convert';

import 'package:qinglong_app/agent/agent_capability.dart';
import 'package:qinglong_app/agent/agent_protocol.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart' show getIt;

const Map<String, dynamic> _emptySchema = <String, dynamic>{
  'type': 'object',
  'properties': <String, dynamic>{},
  'required': <String>[],
};

Map<String, dynamic> _schema(
  Map<String, dynamic> properties, [
  List<String> required = const <String>[],
]) =>
    <String, dynamic>{
      'type': 'object',
      'properties': properties,
      'required': required,
    };

const Map<String, dynamic> _stringProp = <String, dynamic>{'type': 'string'};
const Map<String, dynamic> _intProp = <String, dynamic>{
  'type': 'integer',
  'minimum': 1,
};

/// 工具注册表：资源级工具，不是脚本级命令。
/// 新上传的脚本只是 crons / scripts 资源里的一条数据，
/// list_tasks(search) + run_task(id) 的通用组合即可覆盖，零新增代码。
/// 「今天运行了哪些任务」这类问题由 dashboard 系列工具提供真实数据，
/// 不需要用户改写问法。
class AgentToolRegistry {
  AgentToolRegistry._();

  static final List<AgentTool> all = <AgentTool>[
    const AgentTool(
      name: 'server_status',
      description: '读取青龙面板系统信息与当前状态。',
      parameters: _emptySchema,
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'list_tasks',
      description: '按任务名称模糊搜索「任务定义」列表。只在需要定位某个脚本/任务、或需要查看任务配置时使用；不要用它回答「今天运行了哪些任务」。',
      parameters: _schema(<String, dynamic>{
        'search': _stringProp,
        'page': _intProp,
        'limit': _intProp,
      }),
      requiresConfirmation: false,
      readOnly: true,
    ),
    const AgentTool(
      name: 'today_runs',
      description: '今日运行次数最多的任务 Top 列表。用户问「今天运行了哪些任务 / 今天跑了什么 / 今日执行概况」时必须优先用它。',
      parameters: _emptySchema,
      requiresConfirmation: false,
      readOnly: true,
    ),
    const AgentTool(
      name: 'today_successes',
      description: '今日成功执行的任务明细。回答「今天哪些任务成功了」时使用。',
      parameters: _emptySchema,
      requiresConfirmation: false,
      readOnly: true,
    ),
    const AgentTool(
      name: 'today_failures',
      description: '今日失败任务明细（按失败次数降序）。回答「今天有哪些任务失败 / 失败的原因」时使用。',
      parameters: _emptySchema,
      requiresConfirmation: false,
      readOnly: true,
    ),
    const AgentTool(
      name: 'runtime_status',
      description: '实时运行态：运行中/排队中的任务、正在运行的实例、24 小时未运行的任务。回答「现在有什么在跑」时使用。',
      parameters: _emptySchema,
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'task_trend',
      description: '近 N 日任务执行趋势。回答「最近几天运行情况」时使用。',
      parameters: _schema(<String, dynamic>{'days': _intProp}),
      requiresConfirmation: false,
      readOnly: true,
    ),
    const AgentTool(
      name: 'label_stats',
      description: '按标签统计的任务执行情况。回答「各标签跑得怎么样」时使用。',
      parameters: _emptySchema,
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'task_instances',
      description: '指定任务的运行实例列表。需要看某个任务今天的执行实例时用。',
      parameters: _schema(<String, dynamic>{'id': _stringProp},
          const <String>['id']),
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'list_envs',
      description: '列出环境变量元数据（值会被脱敏）。',
      parameters: _schema(<String, dynamic>{
        'search': _stringProp,
        'limit': _intProp,
      }),
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'list_scripts',
      description: '列出脚本与目录元数据，不读取正文。',
      parameters: _schema(<String, dynamic>{'limit': _intProp}),
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'task_log',
      description: '读取指定任务的最新运行日志正文（不是日志文件清单，只保留尾部）。'
          '用户问「某任务跑了什么 / 成功还是失败 / 报了什么错」时用它。',
      parameters: _schema(<String, dynamic>{'id': _stringProp},
          const <String>['id']),
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'list_logs',
      description: '列出青龙的日志文件（按时间倒序），用于查找历史某次运行的日志。keyword 可过滤任务名。',
      parameters: _schema(<String, dynamic>{
        'keyword': _stringProp,
        'limit': _intProp,
      }),
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'read_log',
      description: '读取日志正文（保留尾部）。'
          'file 可留空，改传 keyword（任务名）与 date（如 2026-11-13）自动找最新匹配的日志。',
      parameters: _schema(<String, dynamic>{
        'file': _stringProp,
        'keyword': _stringProp,
        'date': _stringProp,
      }),
      requiresConfirmation: false,
      readOnly: true,
    ),
    AgentTool(
      name: 'open_api',
      description: '通用青龙 OpenAPI 请求，仅在现有工具覆盖不到时用'
          '（订阅、应用、依赖、配置、通知日志等）。path 如 crons/views、'
          'subscriptions、apps、envs、configs、scripts、dependencies、'
          'system、dashboard、logs、users，不要带 /open 前缀；写操作会先确认。',
      parameters: _schema(<String, dynamic>{
        'method': _stringProp,
        'path': _stringProp,
        'query': <String, dynamic>{'type': 'object'},
        'body': <String, dynamic>{'type': 'object'},
      }, const <String>['method', 'path']),
      // 实际是否确认由 backend 按 method 判断（GET 直接读）。
      requiresConfirmation: true,
      readOnly: false,
    ),
    AgentTool(
      name: 'run_task',
      description: '运行一个定时任务。调用时必须把任务名称放进 name，便于用户确认；需要用户确认后才会执行。',
      parameters: _schema(
          <String, dynamic>{'id': _intProp, 'name': _stringProp},
          const <String>['id']),
      requiresConfirmation: true,
      readOnly: false,
    ),
    AgentTool(
      name: 'stop_task',
      description: '停止一个定时任务。调用时必须把任务名称放进 name，便于用户确认；需要用户确认后才会执行。',
      parameters: _schema(
          <String, dynamic>{'id': _intProp, 'name': _stringProp},
          const <String>['id']),
      requiresConfirmation: true,
      readOnly: false,
    ),
  ];

  /// 按 scopes 过滤；[disabled] 用于老版本青龙自动隐藏不支持的 dashboard 工具。
  static List<AgentTool> available(
    Set<String> scopes, {
    Set<String> disabled = const <String>{},
  }) =>
      all
          .where((tool) =>
              !disabled.contains(tool.name) &&
              AgentCapabilityService.scopeAllows(tool.name, scopes))
          .toList(growable: false);

  static AgentTool? byName(String name) {
    for (final tool in all) {
      if (tool.name == name) return tool;
    }
    return null;
  }

  static bool isReadOnly(String name) => byName(name)?.readOnly ?? true;

  static bool requiresConfirmation(String name) =>
      byName(name)?.requiresConfirmation ?? true;
}

/// 参数化执行器：只走项目已有的 Http + Url，不拼 shell、不发起任意 HTTP。
class QingLongToolExecutor {
  final int index;
  final Set<String> scopes;

  const QingLongToolExecutor(
    this.index, {
    this.scopes = const <String>{
      'crons:read',
      'envs:read',
      'scripts:read',
      'logs:read',
      'system:read',
      'dashboard:read',
    },
  });

  Future<String> execute(String name, Map<String, dynamic> args) async {
    final tool = AgentToolRegistry.byName(name);
    if (tool == null) return '未知工具：$name';
    if (!AgentCapabilityService.scopeAllows(name, scopes)) {
      return '当前应用未授权该操作所需的 scope，请在「AI 设置 → 应用授权 scopes」补充权限。';
    }

    try {
      final http = getIt<Http>(instanceName: index.toString());
      final url = Url(index);
      late HttpResponse<String> result;

      switch (name) {
        case 'server_status':
          // Url.system 是静态 getter（/api/system）；应用授权登录需走 /open/system。
          final accountName = index.toString();
          final useOpen =
              getIt.isRegistered<UserInfoViewModel>(instanceName: accountName) &&
                  getIt<UserInfoViewModel>(instanceName: accountName)
                      .useSecretLogined;
          result = await http.get<String>(
            useOpen ? '/open/system' : Url.system,
            const <String, String?>{},
          );
          break;
        case 'list_tasks':
          result = await http.get<String>(url.tasks, _query(<String, dynamic>{
            'searchValue': args['search'],
            'page': args['page'] ?? 1,
            'size': args['limit'] ?? 20,
          }));
          break;
        case 'today_runs':
          result = await http.get<String>(
              url.dashboardTopCount, const <String, String?>{});
          break;
        case 'today_successes':
          result = await http.get<String>(
              url.dashboardSuccesses, const <String, String?>{});
          break;
        case 'today_failures':
          result = await http.get<String>(
              url.dashboardFailures, const <String, String?>{});
          break;
        case 'runtime_status':
          result = await http.get<String>(
              url.dashboardRuntime, const <String, String?>{});
          break;
        case 'task_trend':
          result = await http.get<String>(
            url.dashboardTrend,
            <String, String?>{'days': (args['days'] ?? 7).toString()},
          );
          break;
        case 'label_stats':
          result = await http.get<String>(
              url.dashboardLabels, const <String, String?>{});
          break;
        case 'task_instances':
          result = await http.get<String>(
              url.cronInstances(args['id']), const <String, String?>{});
          break;
        case 'list_envs':
          result = await http.get<String>(url.envs, _query(<String, dynamic>{
            'searchValue': args['search'],
            'limit': args['limit'] ?? 20,
          }));
          break;
        case 'list_scripts':
          result = await http.get<String>(
              url.scripts, _query(<String, dynamic>{'limit': args['limit'] ?? 20}));
          break;
        case 'task_log': {
          // 读「某个任务的运行日志」要走 /open/crons/:id/log；
          // url.taskLog 是日志文件清单（/open/logs），只会返回目录列表。
          final resp = await http.get<String>(
              url.cronLogs(args['id']), const <String, String?>{});
          if (!resp.success) {
            result = resp;
            break;
          }
          // 日志结论在末尾，保留尾部而不是开头。
          return sanitizeToolOutput(resp.bean ?? '',
              maxChars: 6000, keepTail: true);
        }
        case 'list_logs': {
          final resp =
              await http.get<String>(url.taskLog, const <String, String?>{});
          if (!resp.success) {
            result = resp;
            break;
          }
          return formatLogList(resp.bean ?? '', args);
        }
        case 'read_log': {
          var file = (args['file']?.toString() ?? '').trim();
          final keyword = (args['keyword']?.toString() ?? '').trim();
          final date = (args['date']?.toString() ?? '').trim();
          if (file.isEmpty) {
            if (keyword.isEmpty) return 'file 与 keyword 至少给一个';
            final listResp =
                await http.get<String>(url.taskLog, const <String, String?>{});
            if (!listResp.success) {
              result = listResp;
              break;
            }
            file = findLogKey(listResp.bean ?? '', keyword, date);
            if (file.isEmpty) {
              return '没有找到匹配的日志文件，请换一个 keyword 或 date（如 2026-11-13）。';
            }
          }
          final slash = file.lastIndexOf('/');
          final dir = slash >= 0 ? file.substring(0, slash) : '';
          final name = slash >= 0 ? file.substring(slash + 1) : file;
          final resp = await http.get<String>(
            '${url.taskLogDetail}detail',
            <String, String?>{'path': dir, 'file': name},
          );
          if (!resp.success) {
            result = resp;
            break;
          }
          return sanitizeToolOutput(resp.bean ?? '',
              maxChars: 6000, keepTail: true);
        }
        case 'open_api': {
          final method = (args['method']?.toString() ?? '').toUpperCase();
          var path = (args['path']?.toString() ?? '').trim();
          path = path.replaceFirst(RegExp(r'^/+'), '');
          if (path.startsWith('open/')) path = path.substring(5);
          if (path.isEmpty) return 'path 不能为空';
          final root = path.split('/').first;
          const allowed = <String>{
            'crons',
            'subscriptions',
            'apps',
            'envs',
            'configs',
            'scripts',
            'dependencies',
            'system',
            'dashboard',
            'logs',
            'users',
            'auth',
          };
          if (!allowed.contains(root)) return 'path 不在白名单：$root';
          final query = <String, String?>{};
          final rawQuery = args['query'];
          if (rawQuery is Map) {
            rawQuery.forEach((k, v) {
              if (v != null) query[k.toString()] = v.toString();
            });
          }
          final body = args['body'];
          final endpoint = '/open/$path';
          switch (method) {
            case 'GET':
              result = await http.get<String>(endpoint, query);
              break;
            case 'POST':
              result = await http.post<String>(endpoint, body);
              break;
            case 'PUT':
              result = await http.put<String>(endpoint, body);
              break;
            case 'DELETE':
              result = await http.delete<String>(endpoint, body);
              break;
            default:
              return '不支持的 method：$method（仅 GET/POST/PUT/DELETE）';
          }
          break;
        }
        case 'run_task': {
          final runResp =
              await http.put<String>(url.runTasks, <dynamic>[args['id']]);
          if (!runResp.success) {
            result = runResp;
            break;
          }
          // 青龙 run 接口只返回 accepted、响应体常为空；补读任务日志，
          // 让模型能总结真实执行结果，而不是「返回体为空」。
          var logText = '';
          for (var attempt = 0; attempt < 2; attempt++) {
            await Future<void>.delayed(
                Duration(seconds: attempt == 0 ? 4 : 3));
            final logResp = await http.get<String>(
                url.cronLogs(args['id']), const <String, String?>{});
            final body = logResp.bean ?? '';
            if (logResp.success && body.trim().isNotEmpty) {
              logText = sanitizeToolOutput(body, maxChars: 2000);
              break;
            }
          }
          return logText.isEmpty
              ? '任务已提交运行（accepted），但暂时读不到日志；请稍后再查任务日志。'
              : '任务已提交运行（accepted）。最新日志：\n$logText';
        }
        case 'stop_task':
          result = await http.put<String>(url.stopTasks, <dynamic>[args['id']]);
          break;
        default:
          return '工具尚未实现：$name';
      }

      if (!result.success) {
        return '调用失败(code=${result.code})：${result.message ?? ''}';
      }
      return sanitizeToolOutput(result.bean ?? '{}');
    } catch (e) {
      return formatAgentError(e, prefix: '工具调用');
    }
  }

  /// 按任务名/日期找最新的日志文件 key。
  static String findLogKey(String raw, String keyword, String date) {
    try {
      final decoded = jsonDecode(raw);
      final keys = <String>[];
      if (decoded is Map && decoded['data'] is List) {
        for (final dir in decoded['data'] as List) {
          if (dir is! Map) continue;
          final children = dir['children'];
          if (children is! List) continue;
          for (final file in children) {
            if (file is! Map) continue;
            final key = file['key']?.toString() ?? '';
            if (key.isEmpty) continue;
            if (keyword.isNotEmpty && !key.contains(keyword)) continue;
            if (date.isNotEmpty && !key.contains(date)) continue;
            keys.add(key);
          }
        }
      }
      if (keys.isEmpty) return '';
      keys.sort((a, b) => b.compareTo(a));
      return keys.first;
    } catch (_) {
      return '';
    }
  }

  /// 把 /open/logs 的目录树压成扁平文件列表（按时间倒序）。
  static String formatLogList(String raw, Map<String, dynamic> args) {
    try {
      final decoded = jsonDecode(raw);
      final items = <Map<String, dynamic>>[];
      if (decoded is Map && decoded['data'] is List) {
        for (final dir in decoded['data'] as List) {
          if (dir is! Map) continue;
          final children = dir['children'];
          if (children is! List) continue;
          for (final file in children) {
            if (file is Map) items.add(Map<String, dynamic>.from(file));
          }
        }
      }
      final keyword = args['keyword']?.toString() ?? '';
      var list = items
          .where((e) =>
              keyword.isEmpty ||
              (e['key']?.toString() ?? '').contains(keyword))
          .toList()
        ..sort((a, b) =>
            (b['key']?.toString() ?? '').compareTo(a['key']?.toString() ?? ''));
      final limit = args['limit'] is int
          ? args['limit'] as int
          : int.tryParse(args['limit']?.toString() ?? '') ?? 40;
      final total = list.length;
      if (list.length > limit) list = list.sublist(0, limit);
      final buffer = StringBuffer(
          '共 $total 个日志文件（按时间倒序，展示 ${list.length} 条）：\n');
      for (final item in list) {
        buffer.writeln('${item['key']}  (${item['size'] ?? 0} 字节)');
      }
      return buffer.toString();
    } catch (_) {
      return '日志列表解析失败';
    }
  }

  static Map<String, String?> _query(Map<String, dynamic> args) {
    final out = <String, String?>{};
    args.forEach((key, value) {
      if (value != null) out[key] = value.toString();
    });
    return out;
  }
}

/// 共享脱敏规则：所有后端与工具结果都经过它，日志/脚本内容按不可信数据处理。
/// 默认上限收紧到 3000 字符，避免全量任务列表淹没模型上下文导致反复调工具。
String sanitizeToolOutput(String raw,
    {int maxChars = 3000, bool keepTail = false}) {
  var text = raw;
  text = text.replaceAllMapped(
    RegExp(
      r'"(value|token|client_secret|password|secret|cookie|pt_key|pt_pin|authorization)"\s*:\s*"[^"]*"',
      caseSensitive: false,
    ),
    (match) => '"${match.group(1)}":"***"',
  );
  if (text.length > maxChars) {
    text = keepTail
        ? '…(前面内容已省略)\n${text.substring(text.length - maxChars)}'
        : '${text.substring(0, maxChars)}\n…(内容已截断，仅展示前 $maxChars 字符)';
  }
  return text;
}
