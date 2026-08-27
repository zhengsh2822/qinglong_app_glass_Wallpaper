import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/lazy_first_screen.dart';

class InAppPurchasePage extends ConsumerStatefulWidget {
  final bool fromDirectly;

  const InAppPurchasePage({Key? key, this.fromDirectly = false})
    : super(key: key);

  @override
  ConsumerState<InAppPurchasePage> createState() => _InAppPurchasePageState();
}

class _InAppPurchasePageState extends ConsumerState<InAppPurchasePage> {
  @override
  Widget build(BuildContext context) {
    return LazyFirstScreen(
      placeholder: const FirstScreenSkeleton(title: "APP功能介绍"),
      // 动画期间显示骨架（~400ms），动画结束后挂载真实内容（含实时毛玻璃）。
      // 仅作用于本路由，下层路由不受影响。
      child: Scaffold(
        appBar: QlAppBar(title: "APP功能介绍", canBack: true),
      body: SingleChildScrollView(
        primary: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection("新增功能与设计", [
                "全局可更换壁纸：渐变/纯色/相册/网络四类型，模糊/蒙层可调，支持自动切换壁纸池",
                "底部液态玻璃导航栏：实时采样流光玻璃，双击导航栏/状态栏回页面顶部",
                "统一毛玻璃设计：卡片/弹窗/顶部导航风格一致，支持卡片纯色模式（可自定义颜色）",
                "文字颜色随壁纸亮度自动反色，保证可读性",
                "全局字体调节：字号 + 字重四档（400/500/600/700）全页面统一跟随",
                "超长脚本分块懒加载，10000+ 行秒开不卡顿",
                "定时任务卡片新设计：状态竖条/胶囊标签/一键运行停止按钮",
                "安卓沉浸式适配：小白条+状态栏透明，兼容澎湃 OS",
                "仪表盘对齐 Web 端：7 日趋势折线图、耗时/次数 Top5、实时运行态、系统资源",
                "新版安装包主动提醒：序号+时间双判断，同一版本只提醒一次",
                "脚本搜索（正则高亮）、京东助手、悬浮时钟、iOS 风格文本选择放大镜",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("性能与功耗优化", [
                "Flutter 3.44.4 + Dart 3.12 + Impeller 渲染引擎，性能大幅提升",
                "卡片纯色模式可关闭模糊，显著降低 GPU 压力",
                "定时任务列表虚拟滚动，大量任务不卡顿",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("高级功能", [
                "多账号同时登录，不限账号个数",
                "Face ID / 指纹解锁 APP",
                "环境变量/配置/订阅实时备份，最高 100 天历史",
                "剪切板识别自动填入、远程上传文件",
                "字体设置（字号/字重）、拖拽排序、批量操作",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("基础功能", [
                "定时任务（运行/禁用/删除/日志）、环境变量、配置文件、脚本、依赖管理、订阅管理、实时日志、通知设置、仪表盘、应用设置",
              ], isAdvance: false),
              const SizedBox(height: 15),
              _buildSection("已移除的不兼容功能与依赖", [
                "App 内消息推送、iOS 桌面快捷方式/换图标、file_picker、move_to_background、cached_network_image、json_table 等不兼容依赖（升级 Flutter 3.44.4 所致）",
              ], isAdvance: false),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  "本应用不会收集任何关于您的信息，使用前请仔细阅读用户协议",
                  style: TextStyle(
                    color: ref.watch(themeProvider).themeColor.descColor(),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<String> items, {
    bool isAdvance = false,
  }) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ref.watch(themeProvider).themeColor.titleColor(),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: BasicFuncWidget(title: item, advance: isAdvance),
            ),
          ),
        ],
      ),
    );
  }
}

class BasicFuncWidget extends ConsumerWidget {
  final String title;
  final bool advance;

  const BasicFuncWidget({Key? key, required this.title, this.advance = false})
    : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Image.asset(
            advance ? "assets/images/icon_b.png" : "assets/images/icon_a.png",
            fit: BoxFit.cover,
            width: 13,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: ref.watch(themeProvider).themeColor.descColor(),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
