import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/agent/agent_session_store.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _entry(int i) => <String, dynamic>{'text': 'm$i'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  test('分块追加 + 最近窗口 + 向上分页', () async {
    const String key = 'agent_session_v4_test_0';
    final List<Map<String, dynamic>> all = List<Map<String, dynamic>>.generate(
      130,
      _entry,
    );
    // 模拟逐批落盘（每 7 条一次，跨越 60 的块边界）
    for (int i = 0; i < all.length; i += 7) {
      final int end = i + 7 > all.length ? all.length : i + 7;
      await AgentSessionStore.appendEntries(
        key,
        all.sublist(i, end),
        atIndex: i,
      );
    }

    final AgentSessionWindow win = await AgentSessionStore.loadRecent(
      key,
      limit: 40,
    );
    expect(win.total, 130);
    expect(win.startIndex, 90);
    expect(win.entries.length, 40);
    expect(win.entries.first['text'], 'm90');
    expect(win.entries.last['text'], 'm129');

    final List<Map<String, dynamic>> p1 =
        await AgentSessionStore.loadEarlier(
          key,
          beforeIndex: win.startIndex,
          count: 40,
        );
    expect(p1.length, 40);
    expect(p1.first['text'], 'm50');
    expect(p1.last['text'], 'm89');

    final List<Map<String, dynamic>> p2 =
        await AgentSessionStore.loadEarlier(key, beforeIndex: 50, count: 40);
    expect(p2.length, 40);
    expect(p2.first['text'], 'm10');

    final List<Map<String, dynamic>> p3 =
        await AgentSessionStore.loadEarlier(key, beforeIndex: 10, count: 40);
    expect(p3.length, 10);
    expect(p3.first['text'], 'm0');

    expect((await AgentSessionStore.loadEarlier(key, beforeIndex: 0)).length, 0);
  });

  test('历史分块保存 / 读取（只重写末尾块）', () async {
    const String key = 'agent_session_v4_test_1';
    final List<Map<String, dynamic>> history =
        List<Map<String, dynamic>>.generate(
          95,
          (i) => <String, dynamic>{'role': i.isEven ? 'user' : 'assistant'},
        );
    await AgentSessionStore.appendEntries(
      key,
      <Map<String, dynamic>>[_entry(0)],
      atIndex: 0,
    );
    await AgentSessionStore.saveHistory(key, history);
    final loaded = await AgentSessionStore.loadHistory(key);
    expect(loaded.length, 95);
    expect(loaded.first['role'], 'user');

    // 追加 10 条后再次保存
    final List<Map<String, dynamic>> next = <Map<String, dynamic>>[
      ...history,
      ...List<Map<String, dynamic>>.generate(
        10,
        (i) => <String, dynamic>{'role': 'tool', 'i': i},
      ),
    ];
    await AgentSessionStore.saveHistory(key, next);
    expect((await AgentSessionStore.loadHistory(key)).length, 105);
  });

  test('清空后计数归零', () async {
    const String key = 'agent_session_v4_test_2';
    await AgentSessionStore.appendEntries(
      key,
      List<Map<String, dynamic>>.generate(75, _entry),
      atIndex: 0,
    );
    await AgentSessionStore.clear(key);
    final AgentSessionWindow win = await AgentSessionStore.loadRecent(
      key,
      limit: 40,
    );
    expect(win.total, 0);
    expect(win.entries, isEmpty);
  });

  test('v3 单 key 自动迁移到 v4 分块', () async {
    const String key = 'agent_session_v4_test_3';
    const String legacy = 'agent_session_v3_test_3';
    await SpUtil.putString(
      legacy,
      jsonEncode(<String, dynamic>{
        'entries': List<Map<String, dynamic>>.generate(70, _entry),
        'history': List<Map<String, dynamic>>.generate(
          45,
          (i) => <String, dynamic>{'role': 'user', 'i': i},
        ),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );

    final AgentSessionWindow win = await AgentSessionStore.loadRecent(
      key,
      limit: 40,
    );
    expect(win.total, 70);
    expect(win.entries.length, 40);
    expect(win.entries.last['text'], 'm69');
    expect((await AgentSessionStore.loadHistory(key)).length, 45);

    // 迁移后旧 key 应被删除
    expect(SpUtil.getString(legacy), isEmpty);
    // 向上翻页仍可用
    final earlier = await AgentSessionStore.loadEarlier(
      key,
      beforeIndex: win.startIndex,
      count: 40,
    );
    expect(earlier.length, 30);
    expect(earlier.first['text'], 'm0');
  });
}
