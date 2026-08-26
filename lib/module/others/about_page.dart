import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/utils/share_utils.dart';
import 'package:qinglong_app/base/ui/qlvisible.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage>
    with LazyLoadState<AboutPage> {
  String desc = "";
  String versionCode = "";

  /// 全局字重（build 顶部统一 watch，供标题/按钮使用）
  FontWeight _globalFw = FontWeight.w400;

  @override
  void initState() {
    super.initState();
    getInfo();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    // 标题字重跟随全局粗细调节
    _globalFw = FontWeight(ref.watch(textWeightProvider));
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString(),
      );
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }
    final Widget scaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(canBack: true, title: "关于软件"),
      body: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height / 25),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset("assets/images/ql.png", height: 60),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  "青龙客户端",
                  style: TextStyle(
                    fontWeight: _globalFw,
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Center(
                child: Text(
                  "基于青龙开源项目打造的第三方${getPlatformName()}客户端",
                  style: TextStyle(
                    color: ref.watch(themeProvider).themeColor.descColor(),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SettingsCard(
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                        onTap: _checkGithubUpdate,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 15,
                            right: 15,
                            top: 10,
                            bottom: 10,
                          ),
                          child: Row(
                            children: [
                              Text(
                                "版本",
                                style: TextStyle(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "$desc ($versionCode)",
                                style: TextStyle(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 5),
                              // 小刷新图标提示：点击检测 GitHub 新版安装包
                              Icon(
                                CupertinoIcons.refresh,
                                size: 14,
                                color:
                                    ref
                                        .watch(themeProvider)
                                        .themeColor
                                        .descColor(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(indent: 15, height: 1),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        onTap: () {
                          _checkUpdate();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 15,
                            right: 15,
                            bottom: 10,
                            top: 10,
                          ),
                          child: Row(
                            children: [
                              Text(
                                "青龙服务端",
                                style: TextStyle(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${systemBean.version}",
                                style: TextStyle(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor(),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const SectionHeader(
                title: "主要改进",
                padding: EdgeInsets.symmetric(horizontal: 30),
              ),
              const SizedBox(height: 10),
              SettingsCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 15,
                ),
                child: Text(
                  "基于 ayoulx/qinglong-app 二次开发：\n"
                  "· 全局可更换壁纸系统（渐变/纯色/相册/网络壁纸，支持模糊+蒙层+自动切换）\n"
                  "· 统一毛玻璃效果\n"
                  "· 文字颜色根据壁纸亮度自动反色\n"
                  "· 超长脚本分块懒加载+异步解析（SelectableCodeView，万行脚本秒开）\n"
                  "· 弹窗全透明+高斯模糊统一设计\n"
                  "· 安卓小白条+状态栏沉浸式适配\n"
                  "· 多账号 HTTP 缓存隔离，防止跨账号数据泄漏\n"
                  "· 仪表盘对齐 Web 端（7 日趋势折线图 / Top5 耗时与执行次数 / 标签统计 / 实时运行态含 PID / 系统资源）\n"
                  "· 脚本搜索能力补全（列表常驻过滤 + 查看/编辑页弹出式搜索，支持正则与上下导航）\n"
                  "· 切换底部 Tab 自动收起展开的滑动卡片\n"
                  "· 日志/详情页长按复制启用 iOS 风格文本选择放大镜\n"
                  "· 京东助手独立模块（独立登录 + Cookie 校验 + 弹窗样式统一，基于 yclawn/ql_jd_cookie 二次开发）\n"
                  "· 统一滑动操作与卡片设计规范（搜索框胶囊 24 / 卡片圆角 18）\n",
                  style: TextStyle(
                    color: ref.watch(themeProvider).customPrimaryTextColor,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const SectionHeader(
                title: "反馈",
                padding: EdgeInsets.symmetric(horizontal: 30),
              ),
              const SizedBox(height: 10),
              SettingsCard(
                child: Column(
                  children: [
                    QlVisible(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                          ),
                          onTap: () async {},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 15,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.heart,
                                  color: ref.watch(themeProvider).primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 15),
                                Text(
                                  "在 App Store 评分",
                                  style: TextStyle(
                                    color:
                                        ref
                                            .watch(themeProvider)
                                            .themeColor
                                            .titleColor(),
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  CupertinoIcons.right_chevron,
                                  size: 16,
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      childReplace: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                          ),
                          onTap: () async {
                            try {
                              await launchUrl(
                                Uri.tryParse(
                                  "https://github.com/zhengsh2822/qinglong_app_glass_Wallpaper",
                                )!,
                              );
                            } catch (e) {
                              logger.e(e);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 15,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.cloud_download,
                                  color: ref.watch(themeProvider).primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 15),
                                Text(
                                  "下载地址",
                                  style: TextStyle(
                                    color:
                                        ref
                                            .watch(themeProvider)
                                            .themeColor
                                            .titleColor(),
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                const SizedBox(width: 5),
                                Icon(
                                  CupertinoIcons.right_chevron,
                                  size: 16,
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(indent: 50, height: 1),
                    SettingsTapRow(
                      icon: CupertinoIcons.shield,
                      title: "用户协议",
                      onTap: () {
                        _launchURL("https://newtab.work/PrivacyPolicy.html");
                      },
                    ),
                    const Divider(indent: 50, height: 1),
                    SettingsTapRow(
                      icon: CupertinoIcons.paperplane,
                      title: "App更新通知",
                      onTap: () {
                        _launchURL("https://t.me/qinglongapp");
                      },
                    ),
                    const Divider(indent: 50, height: 1),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        onTap: () {
                          if (Platform.isAndroid) {
                            ShareUtils.shareApp();
                          } else {
                            ShareUtils.shareApp();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 15,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.share,
                                color: ref.watch(themeProvider).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 15),
                              Text(
                                "分享App",
                                style: TextStyle(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                CupertinoIcons.right_chevron,
                                size: 16,
                                color:
                                    ref
                                        .watch(themeProvider)
                                        .themeColor
                                        .descColor(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  "APP不会收集任何关于您的信息,使用前请仔细阅读用户协议",
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
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  void _launchURL(String _url) async {
    try {
      await launchUrl(Uri.tryParse(_url.trimLeft())!);
    } catch (e) {
      logger.e(e);
    }
  }

  void getInfo() async {
    String version = "3.0.0";
    versionCode = "300";
    desc = version;
    setState(() {});
  }

  @override
  void onLazyLoad() {}

  void _checkUpdate() async {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    var response = await SingleAccountPageState.ofApi(context).checkUpdate();
    if (response.success) {
      if (response.bean?.hasNewVersion ?? false) {
        if (isCyber) {
          showCyberConfirmDialog(
            context,
            title: "青龙服务端发现新版本 ${response.bean?.lastVersion}",
            content: "${response.bean?.lastLog}",
            confirmLabel: "知道了",
          );
          return;
        }
        showCupertinoDialog(
          context: context,
          useRootNavigator: false,
          builder:
              (childContext) => CupertinoAlertDialog(
                title: Text("青龙服务端发现新版本 ${response.bean?.lastVersion}"),
                content: Padding(
                  padding: const EdgeInsets.only(left: 5, top: 5),
                  child: Text(
                    "${response.bean?.lastLog}",
                    textAlign: TextAlign.left,
                  ),
                ),
                actions: [
                  CupertinoDialogAction(
                    child: const Text("知道了"),
                    onPressed: () {
                      Navigator.of(childContext).pop();
                    },
                  ),
                ],
              ),
        );
      } else {
        "已经是新版本".toast();
      }
    }
  }

  /// 获取新版安装包信息：GitHub Releases latest 的发布时间与本地已确认时间对比。
  /// 构建版本号固定不变（3.0.0+300），仅靠发布时间判断是否有新安装包；
  /// 仅用户主动点击"版本"行时检测，不主动提醒。
  Future<void> _checkGithubUpdate() async {
    const String releaseUrl =
        'https://github.com/zhengsh2822/qinglong_app_glass_Wallpaper/releases/latest';
    try {
      final resp = await Dio().get(
        'https://api.github.com/repos/zhengsh2822/qinglong_app_glass_Wallpaper/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'qinglong-app',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (resp.statusCode != 200 || resp.data is! Map) {
        "获取更新信息失败".toast();
        return;
      }
      final data = resp.data as Map;
      final publishedAt = DateTime.tryParse(
        data['published_at']?.toString() ?? '',
      );
      if (publishedAt == null) {
        "获取更新信息失败".toast();
        return;
      }
      // 与本地已确认的 release 时间对比：有更新的 release 才提示
      final last = SpUtil.getInt(spGithubLastReleaseTime, defValue: 0);
      if (publishedAt.millisecondsSinceEpoch <= last) {
        "已是最新安装包".toast();
        return;
      }
      final name = (data['name']?.toString().isNotEmpty ?? false)
          ? data['name'].toString()
          : (data['tag_name']?.toString() ?? '新版本');
      final body = (data['body']?.toString() ?? '').trim();
      final local = publishedAt.toLocal();
      final timeStr =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      final content =
          '名称：$name\n发布时间：$timeStr\n${body.length > 200 ? '${body.substring(0, 200)}...' : body}';

      // 确认获取安装包后，记录该 release 时间，下次检测不到更新即不重复提示
      void markAndOpen() {
        SpUtil.putInt(
          spGithubLastReleaseTime,
          publishedAt.millisecondsSinceEpoch,
        );
        launchUrl(Uri.parse(releaseUrl));
      }

      final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
      if (isCyber) {
        showCyberConfirmDialog(
          context,
          title: "发现新版安装包",
          content: content,
          cancelLabel: "稍后",
          confirmLabel: "获取安装包",
        ).then((confirmed) {
          if (confirmed == true) markAndOpen();
        });
        return;
      }
      showCupertinoDialog(
        context: context,
        useRootNavigator: false,
        builder: (childContext) => CupertinoAlertDialog(
          title: const Text("发现新版安装包"),
          content: Text(content, textAlign: TextAlign.left),
          actions: [
            CupertinoDialogAction(
              child: const Text("稍后"),
              onPressed: () => Navigator.pop(childContext),
            ),
            CupertinoDialogAction(
              child: const Text("获取安装包"),
              onPressed: () {
                Navigator.pop(childContext);
                markAndOpen();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      "网络异常，无法获取更新信息".toast();
    }
  }
}

String getPlatformName() {
  if (Platform.isAndroid) {
    return "Android";
  }
  return "iOS";
}
