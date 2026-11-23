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

  // 必须第一个执行：清理只在进程内发生一次
  test('v3/v4 旧共用会话在首次读取时被清理', () async {
    const String v3 = 'agent_session_v3_legacy_0';
    const String v4 = 'agent_session_v4_legacy_0:meta';
    const String v4Chunk = 'agent_session_v4_legacy_0:e:0';
    await SpUtil.putString(v3, '{"entries":[]}');
    await SpUtil.putString(v4, '{"version":4}');
    await SpUtil.putString(v4Chunk, '[]');

    // 任意 v5 key 首次读盘会触发一次性清理
    final AgentSessionWindow win = await AgentSessionStore.loadRecent(
      AgentSessionStore.keyFor('legacy', 0),
    );
    expect(win.total, 0);
    expect(SpUtil.getString(v3), isEmpty);
    expect(SpUtil.getString(v4), isEmpty);
    expect(SpUtil.getString(v4Chunk), isEmpty);
  });

  test('v5 key 含槽位与面板 host', () {
    expect(AgentSessionStore.keyFor('builtin', 0), 'agent_session_v5_builtin_0');
    expect(
      AgentSessionStore.keyFor('builtin', 2, host: 'Panel.Example.com:5700'),
      'agent_session_v5_builtin_a2_panel.example.com-5700',
    );
    // 同槽位不同面板必须落到不同 key（不串记录）
    expect(
      AgentSessionStore.keyFor('builtin', 1, host: 'a.example.com'),
      isNot(AgentSessionStore.keyFor('builtin', 1, host: 'b.example.com')),
    );
  });

  test('分块追加 + 最近窗口 + 向上分页', () async {
    final String key = AgentSessionStore.keyFor('chunk', 0);
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
    final String key = AgentSessionStore.keyFor('history', 0);
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
    final String key = AgentSessionStore.keyFor('clear', 0);
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

  test('同槽位不同面板互不可见', () async {
    final String a = AgentSessionStore.keyFor('iso', 1, host: 'a.example.com');
    final String b = AgentSessionStore.keyFor('iso', 1, host: 'b.example.com');
    await AgentSessionStore.appendEntries(
      a,
      List<Map<String, dynamic>>.generate(3, _entry),
      atIndex: 0,
    );
    expect((await AgentSessionStore.loadRecent(a)).total, 3);
    expect((await AgentSessionStore.loadRecent(b)).total, 0);
    expect(SpUtil.getString('$b:meta'), isEmpty);
  });
}
