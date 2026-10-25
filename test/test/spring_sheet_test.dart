import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/ui/spring_sheet.dart';

class _Host extends StatelessWidget {
  const _Host();

  Future<void> _open(BuildContext context) {
    return showSpringSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  height: 240,
                  width: double.infinity,
                  color: const Color(0xFFF7F7F7),
                  alignment: Alignment.center,
                  child: const Text('主卡片'),
                ),
                const SizedBox(height: 10),
                SpringSheetTrailing(
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    color: const Color(0xFFF7F7F7),
                    alignment: Alignment.center,
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            // 触发项放在顶部，避免被底部弹层遮挡（真实页面里触发项也在内容区上方）
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: GestureDetector(
                  onTap: () => _open(context),
                  child: const SizedBox(
                    width: 200,
                    height: 60,
                    child: ColoredBox(
                      color: Colors.blue,
                      child: Center(child: Text('触发项')),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// 内容可滚动的弹层宿主（验证"列表滚到边界后越界量交给弹层"）
class _ListHost extends StatelessWidget {
  const _ListHost(this.controller);

  final ScrollController controller;

  Future<void> _open(BuildContext context) {
    return showSpringSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          key: const ValueKey<String>('list-sheet'),
          height: 300,
          color: const Color(0xFFF7F7F7),
          child: ListView.builder(
            controller: controller,
            itemCount: 30,
            itemExtent: 60,
            itemBuilder: (BuildContext c, int i) => Center(child: Text('item $i')),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: GestureDetector(
                  onTap: () => _open(context),
                  child: const SizedBox(
                    width: 200,
                    height: 60,
                    child: ColoredBox(
                      color: Colors.blue,
                      child: Center(child: Text('触发项')),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  testWidgets('弹出后主卡片与取消胶囊都在，且主卡片先到位', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);

    expect(find.text('主卡片'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    // 弹簧到位后不应残留错层位移
    final Offset mainPos = tester.getCenter(find.text('主卡片'));
    final Offset cancelPos = tester.getCenter(find.text('取消'));
    expect(mainPos.dx, closeTo(cancelPos.dx, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('点遮罩关闭', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);
    expect(find.text('主卡片'), findsOneWidget);

    await tester.tapAt(const Offset(200, 80));
    await _pumpFrames(tester, 80);
    expect(find.text('主卡片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('打开途中再点触发项：立即反向关闭', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 6);
    expect(find.text('主卡片'), findsOneWidget);

    // 动画进行中遮罩不拦截，触发项可再次点击
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 90);
    expect(find.text('主卡片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('下拉超过阈值：松手关闭', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);

    await tester.drag(find.text('主卡片'), const Offset(0, 220));
    await _pumpFrames(tester, 90);
    expect(find.text('主卡片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('小幅下拉松手：弹回原位', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);

    await tester.drag(find.text('主卡片'), const Offset(0, 40));
    await _pumpFrames(tester, 90);
    expect(find.text('主卡片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('按住卡片上沿外的遮罩上拉：弹层同样跟手', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);
    final double before = tester.getTopLeft(find.text('主卡片')).dy;

    // 从弹层上方（卡片上沿外的遮罩区）起手，模拟"按住顶部横条"手指略微偏上
    final TestGesture gesture =
        await tester.startGesture(const Offset(700, 200));
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final double during = tester.getTopLeft(find.text('主卡片')).dy;
    expect(during, lessThan(before - 6));

    await gesture.up();
    await _pumpFrames(tester, 90);
    expect(tester.getTopLeft(find.text('主卡片')).dy, closeTo(before, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('按住顶部横条（先按住再拖）上拉：弹层跟手', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);

    final Offset sheetTopLeft = tester.getTopLeft(find.text('主卡片'));
    final double before = sheetTopLeft.dy;

    // 在卡片顶部横条带内先按住 400ms，再上拉。
    // 必须用「手指连续小步移动」模拟真机：真机每次 move 只有几像素，
    // 若橡皮筋对已压缩的 y 反复压缩，会随步长变小而收敛到 1%（几乎不动）。
    final TestGesture gesture =
        await tester.startGesture(sheetTopLeft + const Offset(40, 18));
    await tester.pump(const Duration(milliseconds: 400));
    for (int i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(0, -2.5));
      await tester.pump(const Duration(milliseconds: 10));
    }
    final double during = tester.getTopLeft(find.text('主卡片')).dy;
    expect(during, lessThan(before - 20));

    await gesture.up();
    await _pumpFrames(tester, 90);
    expect(tester.getTopLeft(find.text('主卡片')).dy, closeTo(before, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('列表滚到底后继续上拉：弹层橡皮筋上移，松手弹回', (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(_ListHost(controller));
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);

    const ValueKey<String> sheetKey = ValueKey<String>('list-sheet');
    final double before = tester.getTopLeft(find.byKey(sheetKey)).dy;

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.byKey(sheetKey)));
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final double during = tester.getTopLeft(find.byKey(sheetKey)).dy;
    // 上拉越界 → 弹层整体上移（橡皮筋）
    expect(during, lessThan(before - 8));

    await gesture.up();
    await _pumpFrames(tester, 90);
    final double after = tester.getTopLeft(find.byKey(sheetKey)).dy;
    expect(after, closeTo(before, 2));
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('列表在顶部继续下拉：弹层跟手下移并关闭', (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(_ListHost(controller));
    await tester.tap(find.text('触发项'));
    await _pumpFrames(tester, 60);

    const ValueKey<String> sheetKey = ValueKey<String>('list-sheet');
    final double before = tester.getTopLeft(find.byKey(sheetKey)).dy;

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.byKey(sheetKey)));
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 28));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final double during = tester.getTopLeft(find.byKey(sheetKey)).dy;
    expect(during, greaterThan(before + 4));

    await gesture.up();
    await _pumpFrames(tester, 90);
    expect(find.byKey(sheetKey), findsNothing);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
