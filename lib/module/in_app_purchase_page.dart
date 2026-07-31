import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';

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
    return Scaffold(
      appBar: QlAppBar(title: "APP功能介绍", canBack: true),
      body: SingleChildScrollView(
        primary: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection("新增功能与设计", [
                "全局可更换壁纸系统：支持渐变/纯色/相册/网络壁纸四种类型，可调模糊度与蒙层不透明度，支持自动切换壁纸池",
                "统一毛玻璃效果：全项目卡片风格一致，支持路由级壁纸模糊",
                "文字颜色自适应壁纸亮度：根据壁纸平均色+蒙层计算实际亮度，自动切换深色/浅色文字",
                "超长脚本分块懒加载+异步解析：SelectableCodeView 支持 10000+ 行脚本秒开，分块高亮不卡顿",
                "安卓沉浸式适配：小白条+状态栏透明，兼容澎湃 OS",
                "多账号 HTTP 缓存隔离，防止跨账号数据泄漏",
                "仪表盘对齐 Web 端：新增 7 日趋势自绘折线图（无 fl_chart 依赖）、今日耗时 Top5、执行次数 Top5、标签统计、实时运行态（含 PID）、系统资源，老版本服务端自动隐藏不支持的卡片",
                "脚本搜索能力补全：列表页常驻胶囊搜索栏（300ms 防抖递归过滤）；查看/编辑页弹出式搜索卡片，支持 /re/flags 正则语法、上下导航、200ms 防抖、CodeMirror 高亮匹配",
                "切换底部导航 Tab 自动收起展开的滑动卡片（SlidableCloseNotifier + ValueKey 重建）",
                "日志/任务详情/环境变量详情/订阅详情/代码高亮等可复制区域启用 iOS 风格文本选择放大镜",
                "京东助手独立模块：独立青龙面板登录、自动获取 clientId/clientSecret、Cookie 上传前校验、账号与配置备份恢复",
                "统一设计规范：胶囊输入框（圆角 24）、卡片 18px 圆角、Tab 悬浮胶囊样式",
                "HTTP 容错：ResponseType.plain + 手动 jsonDecode，过滤底层库 JSON 错误",
                "悬浮时钟功能",
                "Flutter 3.29.3 + Dart 3.7.2 全面升级，性能大幅提升",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("性能与功耗优化", [
                "Dio 5.x HTTP 客户端，IOHttpClientAdapter 兼容性更好",
                "Flutter Impeller 渲染引擎（OpenGLES），GPU 渲染更高效",
                "定时任务列表支持虚拟滚动，大量任务不卡顿",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("高级功能", [
                "多账号同时登录，不限账号个数",
                "Face ID / 指纹解锁 APP",
                "环境变量、配置文件、订阅管理等文件实时备份",
                "最高可查看历史 100 天的备份文件",
                "支持剪切板识别，自动填入配置文件",
                "支持修改 APP 内字体设置",
                "支持远程上传文件",
                "账号历史记录保存无上限",
                "轻触任意页面标题，即可打开多账号切换页面",
                "环境变量拖拽排序 + 自定义位置",
                "定时任务、依赖管理批量操作",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("基础功能", [
                "对定时任务进行各项操作（运行、禁用、删除、日志等）",
                "管理环境变量：增删改、排序、批量操作",
                "查看、编辑配置文件（CodeMirror 编辑器）",
                "查看、编辑脚本文件",
                "操作服务器依赖管理",
                "查看任务日志（支持实时日志、历史日志）",
                "查看登录记录",
                "订阅管理（查看、添加、删除订阅）",
                "应用设置（主题切换、字体设置、日志自动滚动等）",
                "通知设置（推送通知配置）",
                "仪表盘（青龙版本、任务概览、近 7 日趋势折线图、今日耗时/执行次数 Top5、标签统计、实时运行态、系统资源）",
              ], isAdvance: false),
              const SizedBox(height: 15),
              _buildSection("已移除的不兼容功能与依赖", [
                "App 内消息推送功能",
                "iOS 专属：QuickActions 桌面快捷方式、动态更换 APP 图标",
                "file_picker 文件选择器（iCloud 备份、脚本上传、配置导入）",
                "move_to_background 后台运行",
                "cached_network_image 网络图片缓存",
                "json_table JSON 表格渲染、extended_text 增强文本",
                "launch_review 应用商店评分跳转、package_info_plus 版本号读取",
                "pretty_dio_logger / dio_log HTTP 日志打印",
                "convex_bottom_bar 凸起导航栏（改为自定义导航栏）",
                "Lottie 扫描动画（无效文件，改用 CupertinoIcons 图标）",
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
