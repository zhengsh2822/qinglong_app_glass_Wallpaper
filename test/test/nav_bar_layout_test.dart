import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/ui/sort_nav_button.dart';
import 'package:qinglong_app/base/ui/sort_triangle.dart';
import 'package:qinglong_app/base/ui/add_select_all_button.dart';

/// 环境变量导航栏对称 + 标题完整性回归测试：
/// 在最小主流屏宽（截图为 1080px/3dpr = 360 逻辑宽）断言：
///  1. 标题「环境变量」完整显示（渲染宽度 == 完整文本宽度，无省略号）
///  2. 名称→标题 与 标题→排序 缝隙对称（|diff| < 1）
///  3. 标题居中（offCenter < 1）
/// 参数（与 env_page.dart 一致）：G1=31(编辑→名称) G2=4(actions首) G3=10(排序→加号)，
/// titleSpacing=4（与 QlAppBar 一致）。
void main() {
  testWidgets('env nav bar: full title + symmetric gaps', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0; // 逻辑宽 360
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          appBarTheme: const AppBarTheme(),
          useMaterial3: false,
        ),
        home: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            centerTitle: true,
            titleSpacing: 4,
            leadingWidth: 141,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  color: Colors.transparent,
                  padding: const EdgeInsets.only(left: 16),
                  onPressed: () {},
                  child: const Center(
                    child: Text('编辑', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 31),
                SortNavButton(
                  key: const Key('nameBtn'),
                  label: '名称',
                  state: SortState.none,
                  activeColor: Colors.cyanAccent,
                  inactiveColor: Colors.grey,
                  onTap: () {},
                ),
              ],
            ),
            title: const Text(
              '环境变量',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            actions: [
              const SizedBox(width: 4),
              SortNavButton(
                key: const Key('sortBtn'),
                label: '排序',
                state: SortState.none,
                activeColor: Colors.cyanAccent,
                inactiveColor: Colors.grey,
                onTap: () {},
              ),
              const SizedBox(width: 10),
              AddSelectAllNavButton(
                editMode: false,
                allChecked: false,
                onPressed: () {},
                color: Colors.cyanAccent,
                padding: const EdgeInsets.only(right: 16),
              ),
            ],
          ),
          body: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    Rect box(String key) {
      final r = tester.renderObject(find.byKey(Key(key))) as RenderBox;
      return r.localToGlobal(Offset.zero) & r.size;
    }

    final name = box('nameBtn');
    final sort = box('sortBtn');
    final tf = find.text('环境变量');
    final trender = tester.renderObject(tf) as RenderBox;
    final t = trender.localToGlobal(Offset.zero) & trender.size;

    final tp = TextPainter(
      text: const TextSpan(
        text: '环境变量',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fullWidth = tp.width;

    // 1. 标题完整（无省略号）
    expect(t.width, greaterThanOrEqualTo(fullWidth - 0.5),
        reason: '标题被截断：渲染宽 ${t.width.toStringAsFixed(1)} vs 完整 $fullWidth');

    // 2. 两侧缝隙对称
    final left = t.left - name.right;
    final right = sort.left - t.right;
    expect((right - left).abs(), lessThan(1.0),
        reason: '缝隙不对称 left=$left right=$right');

    // 3. 标题居中
    final center = (t.left + t.right) / 2;
    expect((center - 180).abs(), lessThan(1.0),
        reason: '标题未居中 center=$center');

    // ignore: avoid_print
    print(
      'OK: title完整=${t.width.toStringAsFixed(1)}px | '
      'left=${left.toStringAsFixed(1)} right=${right.toStringAsFixed(1)} | '
      'diff=${(right - left).toStringAsFixed(1)} | center=${center.toStringAsFixed(1)}',
    );
  });
}