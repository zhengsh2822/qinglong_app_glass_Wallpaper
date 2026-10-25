import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/ui/elastic_reorder_list.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  List<int> items = <int>[0, 1, 2, 3, 4];
  int? oldIndex;
  int? newIndex;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: ElasticReorderList<int>(
            items: items,
            itemKey: (int i) => ValueKey<int>(i),
            itemBuilder: (BuildContext c, int i, int index) {
              return Container(
                height: 100,
                alignment: Alignment.center,
                color: Colors.primaries[i % Colors.primaries.length],
                child: Text('item-$i'),
              );
            },
            onReorder: (int o, int n) {
              setState(() {
                oldIndex = o;
                newIndex = n;
                int target = n;
                if (target > o) target -= 1;
                final int item = items.removeAt(o);
                items.insert(target, item);
              });
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _drag(
  WidgetTester tester,
  Offset start,
  double dy, {
  int steps = 10,
}) async {
  final TestGesture g = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 400));
  for (int i = 0; i < steps; i++) {
    await g.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('向下拖 3 格：onReorder 索引符合框架约定且顺序生效', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pump();
    final _HarnessState state = tester.state(find.byType(_Harness));

    final Offset start = tester.getCenter(find.text('item-1'));
    await _drag(tester, start, 300);

    expect(state.oldIndex, 1);
    expect(state.newIndex, 4); // finalPos 3 → newIndex = 3 + 1
    expect(state.items, <int>[0, 2, 3, 1, 4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖到列表最底部：能插到最后一位（边界修复）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pump();
    final _HarnessState state = tester.state(find.byType(_Harness));

    final Offset start = tester.getCenter(find.text('item-0'));
    await _drag(tester, start, 600);

    expect(state.oldIndex, 0);
    expect(state.newIndex, 5); // finalPos 4 → newIndex = 5
    expect(state.items, <int>[1, 2, 3, 4, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖到列表最顶部：能插到第一位', (WidgetTester tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pump();
    final _HarnessState state = tester.state(find.byType(_Harness));

    final Offset start = tester.getCenter(find.text('item-4'));
    await _drag(tester, start, -600);

    expect(state.oldIndex, 4);
    expect(state.newIndex, 0);
    expect(state.items, <int>[4, 0, 1, 2, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未越过阈值松手：不触发重排', (WidgetTester tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pump();
    final _HarnessState state = tester.state(find.byType(_Harness));

    final Offset start = tester.getCenter(find.text('item-2'));
    await _drag(tester, start, 20);

    expect(state.oldIndex, isNull);
    expect(state.items, <int>[0, 1, 2, 3, 4]);
    expect(tester.takeException(), isNull);
  });
}
