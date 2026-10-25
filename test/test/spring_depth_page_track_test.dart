import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/ui/spring_depth_page_track.dart';

Widget _page(String text) => SizedBox.expand(
      child: Center(child: Text(text, textDirection: TextDirection.ltr)),
    );

Future<void> _pump(WidgetTester tester, ValueNotifier<double> position,
    {required int current}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SpringDepthPageTrack(
        position: position,
        current: current,
        children: [_page('A'), _page('B'), _page('C')],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('初始只挂载当前页（与 PageView 惰性构建一致）', (tester) async {
    final position = ValueNotifier<double>(0);
    await _pump(tester, position, current: 0);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsNothing);
  });

  testWidgets('切页后新页挂载且旧页常驻（状态不丢）', (tester) async {
    final position = ValueNotifier<double>(0);
    await _pump(tester, position, current: 0);
    // 模拟胶囊弹簧已带页面到 tab1
    position.value = 1;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SpringDepthPageTrack(
          position: position,
          current: 1,
          children: [_page('A'), _page('B'), _page('C')],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('A'), findsOneWidget); // 已访问页常驻
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsNothing); // 未访问页不构建
  });

  testWidgets('连续位置驱动页面位移（S1 纯盖上：无缩放无变暗）', (tester) async {
    final position = ValueNotifier<double>(0);
    await _pump(tester, position, current: 0);

    // 先让 B 成为目标（挂载），再把位置摆到中途 0.5（A→B 飞行中）
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SpringDepthPageTrack(
          position: position,
          current: 1,
          children: [_page('A'), _page('B'), _page('C')],
        ),
      ),
    );
    position.value = 1;
    await tester.pump();
    position.value = 0.5;
    await tester.pump();
    await tester.pump();

    final width = tester.getSize(find.byType(SpringDepthPageTrack)).width;

    // 进入页 B：轨道位移 0.5W
    final bTranslate = tester.widget<Transform>(
      find.ancestor(
        of: find.text('B'),
        matching: find.byType(Transform),
      ).first,
    );
    expect(bTranslate.transform.entry(0, 3), closeTo(0.5 * width, 0.01));

    // 离开页 A：轨道位移 -0.5W
    final aTranslate = tester.widget<Transform>(
      find.ancestor(
        of: find.text('A'),
        matching: find.byType(Transform),
      ).first,
    );
    expect(aTranslate.transform.entry(0, 3), closeTo(-0.5 * width, 0.01));

    // S1：所有页面都是纯位移（无缩放分量），也无变暗蒙层
    for (final t in ['A', 'B']) {
      final transforms = tester.widgetList<Transform>(
        find.ancestor(of: find.text(t), matching: find.byType(Transform)),
      );
      for (final tr in transforms) {
        expect(tr.transform.entry(0, 0), closeTo(1.0, 0.0001),
            reason: '$t 不应有缩放');
      }
    }
    expect(find.byType(ColoredBox), findsNothing, reason: 'S1 无变暗蒙层');
  });
}
