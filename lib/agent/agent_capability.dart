import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart' show getIt;

/// 一次轻量探测的结果。
class AgentCapability {
  final bool online;
  final String message;

  const AgentCapability({required this.online, this.message = ''});
}

/// 公共能力探测与 scope 判定。
///
/// 所有 Agent 后端共用这一份；仪表盘等模块也可以复用 scopeAllows / detect，
/// 避免「老版本自动隐藏卡片」这类降级逻辑散落在多个页面。
/// 工具表来自项目已有的 Url getter（自动在 /open/* 与 /api/* 间切换），
/// 不依赖设备上有 ql CLI，也不假设青龙版本或网络拓扑。
class AgentCapabilityService {
  AgentCapabilityService._();

  /// 工具 -> 所需最小 scope。写工具用资源级 scope，只读工具用 :read。
  static const Map<String, String> toolScopes = <String, String>{
    'server_status': 'system:read',
    'list_tasks': 'crons:read',
    'run_task': 'crons',
    'stop_task': 'crons',
    'list_envs': 'envs:read',
    'list_scripts': 'scripts:read',
    'task_log': 'logs:read',
    'list_logs': 'logs:read',
    'read_log': 'logs:read',
    'today_runs': 'dashboard:read',
    'today_successes': 'dashboard:read',
    'today_failures': 'dashboard:read',
    'runtime_status': 'dashboard:read',
    'task_trend': 'dashboard:read',
    'label_stats': 'dashboard:read',
    'task_instances': 'crons:read',
  };

  /// 依赖青龙 2.22+ dashboard 接口的工具；老版本面板会自动隐藏。
  static const Set<String> dashboardTools = <String>{
    'today_runs',
    'today_successes',
    'today_failures',
    'runtime_status',
    'task_trend',
    'label_stats',
  };

  /// 找到当前已登录的账号索引。getIt 里每个账号以 "0"、"1"... 注册。
  static int resolveAccountIndex() {
    for (var i = 0; i < 5; i++) {
      final name = i.toString();
      if (!getIt.isRegistered<UserInfoViewModel>(instanceName: name)) continue;
      final vm = getIt<UserInfoViewModel>(instanceName: name);
      if ((vm.token ?? '').isNotEmpty) return i;
    }
    return 0;
  }

  /// 资源级 scope 可以覆盖 :read；:read 不能覆盖写工具。
  static bool scopeAllows(String toolName, Set<String> scopes) {
    // open_api 跨资源，具体权限由青龙侧应用 token 决定，不在这里卡单一 scope。
    if (toolName == 'open_api') return true;
    final required = toolScopes[toolName];
    if (required == null) return false;
    if (scopes.contains(required)) return true;
    final base = required.split(':').first;
    if (base == required) return false;
    return scopes.contains(base);
  }

  /// 只读探测：拉一条任务即可判断当前账号与服务端是否可用。
  /// 不写任何数据、不假设公网/域名/版本。
  static Future<AgentCapability> detect(int index) async {
    try {
      final name = index.toString();
      if (!getIt.isRegistered<Http>(instanceName: name)) {
        return const AgentCapability(
            online: false, message: '当前账号网络实例未就绪');
      }
      final http = getIt<Http>(instanceName: name);
      final result = await http.get<String>(
        Url(index).tasks,
        const <String, String?>{'page': '1', 'size': '1'},
      );
      return AgentCapability(
        online: result.success,
        message: result.success
            ? '青龙接口可用'
            : (result.message ?? '接口返回不可用'),
      );
    } catch (e) {
      return AgentCapability(online: false, message: '$e');
    }
  }

  /// 探测 dashboard 系列接口是否可用（青龙 2.21 及更早版本没有）。
  /// 只读 GET，404/410/403 一律视为不支持，相关工具自动隐藏。
  static Future<bool> detectDashboard(int index) async {
    try {
      final name = index.toString();
      if (!getIt.isRegistered<Http>(instanceName: name)) return false;
      final http = getIt<Http>(instanceName: name);
      final result = await http.get<String>(
        Url(index).dashboardTopCount,
        const <String, String?>{},
      );
      if (!result.success) {
        final code = result.code;
        if (code == 403 || code == 404 || code == 410) return false;
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
