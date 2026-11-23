import 'dart:convert';

import 'package:qinglong_app/utils/sp_utils.dart';

/// 会话的一段时间窗口（按块读盘结果）。
class AgentSessionWindow {
  const AgentSessionWindow({
    required this.entries,
    required this.startIndex,
    required this.total,
  });

  /// 已加载的最旧一段（时间正序）
  final List<Map<String, dynamic>> entries;

  /// entries[0] 在整段会话中的绝对下标
  final int startIndex;

  /// 会话总条数
  final int total;

  bool get hasEarlier => startIndex > 0;
}

/// 会话持久化：按块存储（UI 条目 + 模型对话历史），退出重进可恢复。
///
/// v5 分块格式（前缀 `agent_session_v5_<backendId>_<槽位>_<host>`）：
/// - `<p>:meta`  → {version, entryChunk, historyChunk, entryCount, historyCount, savedAt}
/// - `<p>:e:<i>` → 第 i 块 UI 条目（每块 60 条，块内时间正序）
/// - `<p>:h:<i>` → 第 i 块模型历史（每块 40 条）
///
/// 这样首屏只解最后一块，内存只保留窗口；追加新消息只重写末尾块，
/// 7 天保留期的大会话也不会在主线程编解码整段 JSON。
/// v3/v4 数据在旧版本里可能被「第一个已登录账号」共用过、归属不可判定，
/// 升级后首次读取时统一清理，绝不跨账号接管。
class AgentSessionStore {
  AgentSessionStore._();

  /// 会话保留天数，设置页可选 1/3/7 天，过期自动清理。
  static const String keepDaysKey = 'agent_session_keep_days';
  static const int defaultKeepDays = 7;

  /// 分块大小
  static const int entryChunkSize = 60;
  static const int historyChunkSize = 40;

  static int get keepDays {
    final v = SpUtil.getInt(keepDaysKey, defValue: defaultKeepDays);
    return (v == 1 || v == 3 || v == 7) ? v : defaultKeepDays;
  }

  static Future<void> setKeepDays(int days) async {
    if (days == 1 || days == 3 || days == 7) {
      await SpUtil.putInt(keepDaysKey, days);
    }
  }

  static Duration get maxAge => Duration(days: keepDays);

  /// v5 分块前缀。
  ///
  /// 账号隔离：key 同时带槽位与面板主机（同一槽位退出后登录另一台面板
  /// 不会读到上一个账号的会话）。[host] 为空时仅用槽位号。
  ///
  /// v4 及更早的会话在旧版本里可能被「全局第一个账号」共用过，无法判断
  /// 归属；升级到 v5 时统一清理，避免把其他面板的记录带给新账号。
  static String keyFor(String backendId, int accountIndex, {String? host}) {
    final String tag = _accountTag(accountIndex, host);
    return 'agent_session_v5_${backendId}_$tag';
  }

  static String _accountTag(int index, String? host) {
    final String h = _hostTag(host ?? '');
    return h.isEmpty ? '$index' : 'a${index}_$h';
  }

  static String _hostTag(String host) {
    var h = host.trim().toLowerCase();
    if (h.isEmpty) return '';
    h = h.replaceAll(RegExp(r'[^a-z0-9.\-]+'), '-');
    h = h.replaceAll(RegExp(r'-+'), '-');
    h = h.replaceAll(RegExp(r'^-+|-+$'), '');
    if (h.length > 60) h = h.substring(0, 60);
    return h;
  }

  static String _metaKey(String p) => '$p:meta';
  static String _entryChunkKey(String p, int i) => '$p:e:$i';
  static String _historyChunkKey(String p, int i) => '$p:h:$i';

  /// 旧版会话是否已清理（进程内只扫一次）
  static bool _legacyPurged = false;

  /// 清理 v3/v4 会话：旧版按「第一个已登录账号」共用存储，归属不可判定，
  /// 保留会把其他面板的记录带到新账号，直接丢弃最安全。
  static Future<void> _purgeLegacyOnce() async {
    if (_legacyPurged) return;
    _legacyPurged = true;
    final Set<String>? keys = SpUtil.getKeys();
    if (keys == null) return;
    for (final String k in keys.toList()) {
      if (k.startsWith('agent_session_v3_') ||
          k.startsWith('agent_session_v4_')) {
        await SpUtil.remove(k);
      }
    }
  }

  /// 读取最近 [limit] 条（只解最后 1~2 块）。
  static Future<AgentSessionWindow> loadRecent(
    String key, {
    int limit = 40,
  }) async {
    await _purgeLegacyOnce();
    final Map<String, dynamic>? meta = _readMeta(key);
    if (meta == null) {
      return const AgentSessionWindow(
        entries: <Map<String, dynamic>>[],
        startIndex: 0,
        total: 0,
      );
    }
    final int total = (meta['entryCount'] as num?)?.toInt() ?? 0;
    final int? savedAt = (meta['savedAt'] as num?)?.toInt();
    if (savedAt != null &&
        DateTime.now().millisecondsSinceEpoch - savedAt >
            maxAge.inMilliseconds) {
      await clear(key);
      return const AgentSessionWindow(
        entries: <Map<String, dynamic>>[],
        startIndex: 0,
        total: 0,
      );
    }
    if (total <= 0) {
      return const AgentSessionWindow(
        entries: <Map<String, dynamic>>[],
        startIndex: 0,
        total: 0,
      );
    }
    final int start = total - limit < 0 ? 0 : total - limit;
    final int firstChunk = start ~/ entryChunkSize;
    final int lastChunk = (total - 1) ~/ entryChunkSize;
    final List<Map<String, dynamic>> all = <Map<String, dynamic>>[];
    for (int c = firstChunk; c <= lastChunk; c++) {
      all.addAll(_readChunk(_entryChunkKey(key, c)));
    }
    final int skip = start - firstChunk * entryChunkSize;
    final List<Map<String, dynamic>> win =
        skip > 0 && all.length > skip
            ? all.sublist(skip)
            : (skip > 0 ? <Map<String, dynamic>>[] : all);
    return AgentSessionWindow(entries: win, startIndex: start, total: total);
  }

  /// 读取 [beforeIndex] 之前的一段更早记录。
  static Future<List<Map<String, dynamic>>> loadEarlier(
    String key, {
    required int beforeIndex,
    int count = 40,
  }) async {
    if (beforeIndex <= 0) return <Map<String, dynamic>>[];
    final int start = beforeIndex - count < 0 ? 0 : beforeIndex - count;
    final int firstChunk = start ~/ entryChunkSize;
    final int lastChunk = (beforeIndex - 1) ~/ entryChunkSize;
    final List<Map<String, dynamic>> all = <Map<String, dynamic>>[];
    for (int c = firstChunk; c <= lastChunk; c++) {
      all.addAll(_readChunk(_entryChunkKey(key, c)));
    }
    final int base = firstChunk * entryChunkSize;
    final int from = start - base;
    final int to = beforeIndex - base;
    if (from < 0 || from >= all.length) return <Map<String, dynamic>>[];
    return all.sublist(from, to > all.length ? all.length : to);
  }

  /// 追加写入新条目（只重写受影响的末尾块）。
  /// [atIndex] 为本批条目在整段会话中的绝对起始下标。
  static Future<void> appendEntries(
    String key,
    List<Map<String, dynamic>> entries, {
    required int atIndex,
  }) async {
    if (entries.isEmpty) return;
    final Map<String, dynamic> meta =
        _readMeta(key) ?? <String, dynamic>{};
    int i = 0;
    while (i < entries.length) {
      final int abs = atIndex + i;
      final int chunk = abs ~/ entryChunkSize;
      final int offset = abs % entryChunkSize;
      final List<Map<String, dynamic>> merged =
          offset == 0
              ? <Map<String, dynamic>>[]
              : _readChunk(_entryChunkKey(key, chunk));
      while (i < entries.length && merged.length < entryChunkSize) {
        merged.add(entries[i]);
        i++;
      }
      await SpUtil.putString(
        _entryChunkKey(key, chunk),
        jsonEncode(merged),
      );
    }
    await _writeMeta(
      key,
      meta,
      entryCount: atIndex + entries.length,
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 读取全部模型历史（用于内置后端恢复上下文）。
  static Future<List<Map<String, dynamic>>> loadHistory(String key) async {
    await _purgeLegacyOnce();
    final Map<String, dynamic>? meta = _readMeta(key);
    final int count = (meta?['historyCount'] as num?)?.toInt() ?? 0;
    if (count <= 0) return <Map<String, dynamic>>[];
    final int chunks = (count + historyChunkSize - 1) ~/ historyChunkSize;
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (int c = 0; c < chunks; c++) {
      out.addAll(_readChunk(_historyChunkKey(key, c)));
    }
    return out.length > count ? out.sublist(0, count) : out;
  }

  /// 保存模型历史（只重写末尾发生变化的块）。
  static Future<void> saveHistory(
    String key,
    List<Map<String, dynamic>> history,
  ) async {
    final Map<String, dynamic> meta =
        _readMeta(key) ?? <String, dynamic>{};
    if (history.isEmpty) {
      await _writeMeta(
        key,
        meta,
        historyCount: 0,
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );
      return;
    }
    final int prev = (meta['historyCount'] as num?)?.toInt() ?? 0;
    final int chunkSize =
        (meta['historyChunk'] as num?)?.toInt() ?? historyChunkSize;
    // 最后一块可能被追加过：从上一块边界开始重写，保证块内内容完整
    int abs = prev > 0 ? ((prev - 1) ~/ chunkSize) * chunkSize : 0;
    while (abs < history.length) {
      final int end =
          abs + chunkSize > history.length ? history.length : abs + chunkSize;
      await SpUtil.putString(
        _historyChunkKey(key, abs ~/ chunkSize),
        jsonEncode(history.sublist(abs, end)),
      );
      abs = end;
    }
    await _writeMeta(
      key,
      meta,
      historyCount: history.length,
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> clear(String key) async {
    final Map<String, dynamic>? meta = _readMeta(key);
    final int eCount = (meta?['entryCount'] as num?)?.toInt() ?? 0;
    final int hCount = (meta?['historyCount'] as num?)?.toInt() ?? 0;
    final int eChunks = (eCount + entryChunkSize - 1) ~/ entryChunkSize;
    final int hChunks = (hCount + historyChunkSize - 1) ~/ historyChunkSize;
    for (int c = 0; c < eChunks; c++) {
      await SpUtil.remove(_entryChunkKey(key, c));
    }
    for (int c = 0; c < hChunks; c++) {
      await SpUtil.remove(_historyChunkKey(key, c));
    }
    await SpUtil.remove(_metaKey(key));
  }

  // ── 内部 ──

  static Map<String, dynamic>? _readMeta(String p) {
    final String raw = SpUtil.getString(_metaKey(p));
    if (raw.isEmpty) return null;
    try {
      final dynamic d = jsonDecode(raw);
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeMeta(
    String key,
    Map<String, dynamic> meta, {
    int? entryCount,
    int? historyCount,
    int? savedAt,
  }) async {
    final Map<String, dynamic> next = <String, dynamic>{
      'version': 5,
      'entryChunk': (meta['entryChunk'] as num?)?.toInt() ?? entryChunkSize,
      'historyChunk':
          (meta['historyChunk'] as num?)?.toInt() ?? historyChunkSize,
      'entryCount':
          entryCount ?? (meta['entryCount'] as num?)?.toInt() ?? 0,
      'historyCount':
          historyCount ?? (meta['historyCount'] as num?)?.toInt() ?? 0,
      'savedAt':
          savedAt ??
          (meta['savedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    };
    await SpUtil.putString(_metaKey(key), jsonEncode(next));
  }

  static List<Map<String, dynamic>> _readChunk(String k) {
    final String raw = SpUtil.getString(k);
    if (raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final dynamic d = jsonDecode(raw);
      return _listOfMaps(d);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
