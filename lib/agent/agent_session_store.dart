import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
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
/// v4 分块格式（前缀 `agent_session_v4_<backendId>_<accountIndex>`）：
/// - `<p>:meta`  → {version, entryChunk, historyChunk, entryCount, historyCount, savedAt}
/// - `<p>:e:<i>` → 第 i 块 UI 条目（每块 60 条，块内时间正序）
/// - `<p>:h:<i>` → 第 i 块模型历史（每块 40 条）
///
/// 这样首屏只解最后一块，内存只保留窗口；追加新消息只重写末尾块，
/// 7 天保留期的大会话也不会在主线程编解码整段 JSON。
/// 旧 v3 单 key 数据会在首次读取时自动迁移并删除。
class AgentSessionStore {
  AgentSessionStore._();

  /// 会话保留天数，设置页可选 1/3/7 天，过期自动清理。
  static const String keepDaysKey = 'agent_session_keep_days';
  static const int defaultKeepDays = 7;

  /// 分块大小
  static const int entryChunkSize = 60;
  static const int historyChunkSize = 40;

  /// 会话 JSON 超过该阈值时用后台 isolate 解码
  static const int _isolateThreshold = 64 * 1024;

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

  /// v4 分块前缀
  static String keyFor(String backendId, int accountIndex) =>
      'agent_session_v4_${backendId}_$accountIndex';

  static String _metaKey(String p) => '$p:meta';
  static String _entryChunkKey(String p, int i) => '$p:e:$i';
  static String _historyChunkKey(String p, int i) => '$p:h:$i';

  /// v3 单 key（仅用于迁移）
  static String _legacyKeyOf(String key) => key.startsWith('agent_session_v4_')
      ? key.replaceFirst('agent_session_v4_', 'agent_session_v3_')
      : '';

  /// 读取最近 [limit] 条（只解最后 1~2 块）。
  static Future<AgentSessionWindow> loadRecent(
    String key, {
    int limit = 40,
  }) async {
    await _migrateIfNeeded(key);
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
    await _migrateIfNeeded(key);
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
    final String legacy = _legacyKeyOf(key);
    if (legacy.isNotEmpty) await SpUtil.remove(legacy);
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
      'version': 4,
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

  /// v3 → v4 迁移（只在 v4 meta 不存在且旧 key 有数据时执行一次）
  static Future<void> _migrateIfNeeded(String key) async {
    if (_readMeta(key) != null) return;
    final String legacy = _legacyKeyOf(key);
    if (legacy.isEmpty) return;
    final String raw = SpUtil.getString(legacy);
    if (raw.isEmpty) return;
    try {
      final dynamic decoded =
          raw.length > _isolateThreshold
              ? await compute(_decodeJson, raw)
              : jsonDecode(raw);
      if (decoded is! Map) {
        await SpUtil.remove(legacy);
        return;
      }
      final int savedAt =
          (decoded['savedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      if (DateTime.now().millisecondsSinceEpoch - savedAt >
          maxAge.inMilliseconds) {
        await SpUtil.remove(legacy);
        return;
      }
      final List<Map<String, dynamic>> entries = _listOfMaps(
        decoded['entries'],
      );
      final List<Map<String, dynamic>> history = _listOfMaps(
        decoded['history'],
      );
      for (int i = 0; i < entries.length; i += entryChunkSize) {
        final int end =
            i + entryChunkSize > entries.length
                ? entries.length
                : i + entryChunkSize;
        await SpUtil.putString(
          _entryChunkKey(key, i ~/ entryChunkSize),
          jsonEncode(entries.sublist(i, end)),
        );
      }
      for (int i = 0; i < history.length; i += historyChunkSize) {
        final int end =
            i + historyChunkSize > history.length
                ? history.length
                : i + historyChunkSize;
        await SpUtil.putString(
          _historyChunkKey(key, i ~/ historyChunkSize),
          jsonEncode(history.sublist(i, end)),
        );
      }
      await SpUtil.putString(
        _metaKey(key),
        jsonEncode(<String, dynamic>{
          'version': 4,
          'entryChunk': entryChunkSize,
          'historyChunk': historyChunkSize,
          'entryCount': entries.length,
          'historyCount': history.length,
          'savedAt': savedAt,
        }),
      );
      await SpUtil.remove(legacy);
    } catch (_) {
      // 迁移失败保留旧数据，不阻断使用
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

/// 后台 isolate 解码入口（compute 只接受顶层 / 静态函数）
Map<String, dynamic> _decodeJson(String raw) {
  final dynamic decoded = jsonDecode(raw);
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return <String, dynamic>{};
}
