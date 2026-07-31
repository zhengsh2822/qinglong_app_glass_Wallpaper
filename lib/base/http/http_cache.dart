/// HTTP 响应缓存
///
/// 设计要点:
/// 1. 每个账号独立实例(_instances 按 index 隔离),避免跨账号数据泄漏
/// 2. 内部维护两套索引:
///    - `_cache`: key -> _CacheEntry,用于点查
///    - `_prefixIndex`: prefix -> Set<key>,用于按前缀批量失效,避免 O(n) 遍历
/// 3. 分级 TTL: 不同资源类型使用不同过期时长,避免短 TTL 频繁回源
class HttpCache {
  static final Map<int, HttpCache> _instances = {};

  factory HttpCache(int index) {
    return _instances.putIfAbsent(index, () => HttpCache._());
  }

  HttpCache._();

  final Map<String, _CacheEntry> _cache = {};

  /// 前缀索引:资源前缀(如 /api/scripts) -> 该前缀下所有缓存 key
  /// 用于 O(1) 找到某类资源的全部 key,失效时直接遍历该 Set 即可
  final Map<String, Set<String>> _prefixIndex = {};

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > entry.ttl) {
      _removeEntry(key);
      return null;
    }
    return entry.data as T?;
  }

  void set<T>(String key, T data, {Duration ttl = const Duration(seconds: 30)}) {
    // 如果之前已存在,先清理旧的前缀索引引用,防止悬挂 key
    if (_cache.containsKey(key)) {
      _removeFromPrefixIndex(key);
    }
    _cache[key] = _CacheEntry(data, ttl);
    _addToPrefixIndex(key);
  }

  void invalidate(String key) {
    _removeEntry(key);
  }

  /// 按前缀批量失效:通过前缀索引直接拿到该前缀下所有 key,无需遍历整个 _cache
  void invalidatePrefix(String prefix) {
    final keys = _prefixIndex[prefix];
    if (keys == null || keys.isEmpty) return;
    // 复制一份再删,避免并发修改
    for (final key in keys.toList()) {
      _cache.remove(key);
    }
    _prefixIndex.remove(prefix);
    // 注意:被删除的 key 可能也属于其他前缀集合,但通常一个 key 只属于一个前缀组
    // 这里不强制清理跨前缀引用,因为 invalidatePrefix 一般用于清空某类资源
  }

  void invalidateAll() {
    _cache.clear();
    _prefixIndex.clear();
  }

  static void clearAccount(int index) {
    _instances.remove(index);
  }

  static void clearAll() {
    _instances.clear();
  }

  /// 将 key 挂到对应资源前缀的索引集合下
  void _addToPrefixIndex(String key) {
    final prefix = _extractPrefix(key);
    if (prefix == null) return;
    (_prefixIndex[prefix] ??= <String>{}).add(key);
  }

  void _removeFromPrefixIndex(String key) {
    final prefix = _extractPrefix(key);
    if (prefix == null) return;
    _prefixIndex[prefix]?.remove(key);
    if (_prefixIndex[prefix]?.isEmpty == true) {
      _prefixIndex.remove(prefix);
    }
  }

  void _removeEntry(String key) {
    _cache.remove(key);
    _removeFromPrefixIndex(key);
  }

  /// 从 URI key 中提取资源前缀,用于归入前缀索引
  /// 例如:/api/scripts/detail?file=a.js -> /api/scripts
  ///      /open/crons/123/log -> /open/crons
  ///      /api/crons?searchValue= -> /api/crons
  static String? _extractPrefix(String key) {
    String path = key.split('?').first;
    // 去除前导斜杠后分段
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    // 形如 api/scripts、open/crons:取前两段
    // 形如 api/crons/123/log:也归一到 api/crons
    // 形如 open/auth/token:归一到 open/auth
    if (segments[0] == 'api' || segments[0] == 'open') {
      return '/${segments[0]}/${segments[1]}';
    }
    return null;
  }
}

class _CacheEntry {
  final dynamic data;
  final Duration ttl;
  final DateTime timestamp = DateTime.now();
  _CacheEntry(this.data, this.ttl);
}

/// 分级 TTL 预设:不同资源类型使用不同缓存时长
class CacheTtl {
  CacheTtl._();

  /// 脚本列表 / 脚本详情:内容变更不频繁,5 分钟
  static const Duration scripts = Duration(minutes: 5);

  /// 日志列表(目录树):变更不频繁,2 分钟
  static const Duration logs = Duration(minutes: 2);

  /// 配置 / 配置文件:变更较少,3 分钟
  static const Duration configs = Duration(minutes: 3);

  /// 环境变量:变更较少,3 分钟
  static const Duration envs = Duration(minutes: 3);

  /// 依赖列表:变更较少,3 分钟
  static const Duration dependencies = Duration(minutes: 3);

  /// 订阅列表:变更较少,3 分钟
  static const Duration subscriptions = Duration(minutes: 3);

  /// 任务列表:可变,1 分钟
  static const Duration tasks = Duration(minutes: 1);

  /// 系统信息 / 用户信息:变更少,1 分钟
  static const Duration system = Duration(minutes: 1);

  /// Dashboard 趋势 / Top 等聚合数据:1 分钟
  static const Duration dashboard = Duration(minutes: 1);

  /// 默认 TTL:30 秒(原行为)
  static const Duration defaultTtl = Duration(seconds: 30);

  /// 根据请求 URI 推断合适的 TTL
  static Duration forUri(String uri) {
    final path = uri.split('?').first;
    if (path.contains('/scripts')) return scripts;
    if (path.contains('/logs')) return logs;
    if (path.contains('/configs')) return configs;
    if (path.contains('/envs')) return envs;
    if (path.contains('/dependencies')) return dependencies;
    if (path.contains('/subscriptions')) return subscriptions;
    if (path.contains('/crons') || path.contains('/tasks')) return tasks;
    if (path.contains('/dashboard')) return dashboard;
    if (path.contains('/system') || path.contains('/user')) return system;
    return defaultTtl;
  }
}
