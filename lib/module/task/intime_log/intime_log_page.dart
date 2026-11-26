
import 'package:qinglong_app/utils/share_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/ui/pauseable_timer_mixin.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/log_text_view.dart';
import 'package:qinglong_app/base/ui/log_scroll_button.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/module/scan_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../../base/commit_button.dart';
import '../../../base/http/api.dart';
import '../../../base/theme.dart';

class InTimeLogPage extends ConsumerStatefulWidget {
  final String cronId;
  final bool needTimer;
  final String title;
  final String? command;

  const InTimeLogPage(
    this.cronId,
    this.needTimer,
    this.title, {
    super.key,
    this.command,
  });

  @override
  ConsumerState<InTimeLogPage> createState() => _InTimeLogPageState();
}

class _InTimeLogPageState extends ConsumerState<InTimeLogPage>
    with LazyLoadState<InTimeLogPage>, PauseableTimerMixin<InTimeLogPage> {
  String? content;

  /// 传给 LogTextView 的渲染内容：超长日志仅渲染尾部（实时页自动滚底，
  /// 完整内容仍可分享），避免 2s 轮询的全量重建成本随日志增长无上限
  String? _renderContent;

  /// 实时页单次渲染的最大字符数（字符数 ≈ 字节数级，中文按 1 字符计）。
  /// 上限过低会让前面内容被丢弃且没有任何提示，
  /// 取 512KB（仍远低于会卡死主线程的量级），
  /// 并在超出时顶部给「查看完整日志」入口。
  static const int _maxRenderChars = 512 * 1024;

  /// 从 [content] 尾部取约 [limit] 字符，并上移到最近的换行，
  /// 避免首行是半截内容（尤其 UTF-8 截断后的乱码）
  static String _tailFromLineStart(String content, int limit) {
    if (content.length <= limit) return content;
    final int start = content.length - limit;
    final int nl = content.indexOf('\n', start);
    if (nl >= 0 && nl + 1 < content.length) return content.substring(nl + 1);
    return content.substring(start);
  }

  bool isRequest = false;
  bool canRequest = true;
  int _emptyCount = 0;

  /// 连续多少次空响应后停止轮询（省电）。默认 3 次；手动「重新加载」后
  /// 放宽到 30 次，给启动慢/装依赖久的脚本留出输出时间。
  int _emptyTolerance = 3;
  bool alwaysAuthScroll = false;

  ScrollController? controller = ScrollController();
  bool showVIPReminder = false;

  getLogData() async {
    if (!canRequest) return;
    if (isRequest) return;
    if (!mounted) return;
    isRequest = true;
    HttpResponse<String> response = await SingleAccountPageState.ofApi(
      context,
    ).inTimeLog(widget.cronId);

    if (!mounted) return;
    isRequest = false;
    if (response.success) {
      if (!mounted) return;
      String? newContent = response.bean;
      if (newContent == null || newContent.isEmpty) {
        _emptyCount++;
        if (_emptyCount >= _emptyTolerance) {
          // 注意：这里停止轮询是"省电"策略，但脚本启动慢、依赖安装久、
          // 面板写盘延迟都可能让日志在几秒内为空 —— 停了之后即使脚本
          // 开始输出也再不会刷新，用户看到的就是"没有日志"。
          // 因此空态页面提供一个「重新加载」按钮（见 _buildEmptyReload）。
          stopPauseableTimer();
          canRequest = false;
          content = "";
          _renderContent = "";
          if (!mounted) return;
          setState(() {});
        }
        return;
      }
      final bool changed = newContent != content;
      if (changed) {
        _emptyCount = 0;
      }
      final String prev = content ?? "";
      content = newContent;

      // 渲染先落地：不等依赖检测/安装（自动安装可能耗时很长，曾把首帧
      // 渲染卡成永久加载），日志内容先展示，依赖处理在后续轮询中继续
      //
      // 上限说明：超长日志只渲染尾部 _maxRenderChars（且无提示的话
      // 用户会以为日志丢了）。截断点上移到最近的换行，避免第一行是
      // 半截内容；顶部另有「查看完整日志」入口可看全文。
      final String newRender =
          (newContent.length > _maxRenderChars)
              ? _tailFromLineStart(newContent, _maxRenderChars)
              : newContent;
      if (newRender != _renderContent) {
        _renderContent = newRender;
        if (!mounted) return;
        setState(() {});
      }

      if (changed) {
        // 依赖检测只跑新增增量：全量正则随日志增长变慢（MB 级日志每 2s 全量
        // 扫描曾把主线程卡到 ANR），且依赖报错只会出现在新增输出里
        final String delta =
            (newContent.length >= prev.length && newContent.endsWith(prev))
                ? newContent.substring(prev.length)
                : newContent;
        List<String> foundDeps = ScanPageState.foundAllReg(delta);
        if (foundDeps.isNotEmpty &&
            widget.command != null &&
            (widget.command!.endsWith(".js") ||
                widget.command!.endsWith(".ts") ||
                widget.command!.endsWith(".py")) &&
            SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal) {
          Api api = Api(SingleAccountPageState.of(context)?.index ?? 0);
          bool isPy = widget.command!.endsWith(".py");
          for (String found in foundDeps) {
            // 同一依赖本次会话只尝试一次：面板安装异步生效，运行中任务会
            // 持续打印同一条缺依赖错误，无去重会陷入 安装→再报错 死循环
            if (!_autoInstallTried.add(found)) continue;
            var result = await ScanPageState.autoInstallFounded(
              api,
              found,
              isPy,
            );
            if (result == true) {
              "已安装依赖 $found".toast();
            }
          }
        }
      }

      if (changed && alwaysAuthScroll) {
        scrollLogToBottom(controller);
      }
    } else {
      if (!hasToastedFailed) {
        hasToastedFailed = true;
        response.message?.toast();
      }
      // 拉取失败时仅在首次落地空态（保留可能已有的内容），避免永久加载
      if (content == null) {
        content = "";
        _renderContent = "";
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  bool hasToastedFailed = false;

  /// 本次会话已尝试自动安装的依赖（面板安装是异步的，任务日志会持续打印
  /// 同一条缺依赖错误——不去重会导致 安装→重启→再报错 的无限循环，
  /// 每 2s 一轮打满主线程直接 ANR 卡死）
  final Set<String> _autoInstallTried = {};

  /// 空日志且轮询已停时的占位：说明 + 重新加载
  ///
  /// 轮询策略是「连续 _emptyTolerance 次拿不到内容就停」，用来省电；
  /// 但脚本启动慢时日志会长时间为空，停了之后本页就永远停在空态。
  Widget _buildEmptyReload(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "暂无日志",
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: ref.watch(themeProvider).primaryColor,
            borderRadius: BorderRadius.circular(999),
            onPressed: () {
              // 重置空计数与容错次数，重新拉起 2s 轮询；放宽容错，
              // 给启动慢/装依赖久的脚本留出输出时间
              _emptyCount = 0;
              _emptyTolerance = 30;
              canRequest = true;
              startPauseableTimer(const Duration(seconds: 2), () => getLogData());
              getLogData();
              if (mounted) setState(() {});
            },
            child: const Text("重新加载", style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// 打开完整日志（不受渲染上限影响），长日志可在此查看全部内容
  void _openFullLog(String full) {
    if (full.isEmpty) {
      "暂无日志".toast();
      return;
    }
    Navigator.of(context).push(
      WallpaperPageRoute(
        builder:
            (_) => Scaffold(
              appBar: QlAppBar(canBack: true, title: "${widget.title} · 完整日志"),
              body: GlassPageBackground(
                child: CupertinoScrollbar(
                  child: LogTextView(
                    content: full,
                    accountIndex:
                        SingleAccountPageState.of(context)?.index ?? 0,
                  ),
                ),
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    cancelPauseableTimer();
    controller?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    return Builder(
      builder: (context) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            mini: true,
            onPressed: () {
              setState(() {
                alwaysAuthScroll = !alwaysAuthScroll;
              });
              // 开启瞬间立即滚底：日志不再变化时（任务已结束）轮询的
              // changed 条件永远不满足，只切标记会表现为「点击开启无效」
              if (alwaysAuthScroll) {
                scrollLogToBottom(controller);
              }
            },
            elevation: 2,
            child: Icon(
              alwaysAuthScroll
                  ? CupertinoIcons.pause_circle
                  : CupertinoIcons.play_circle,
            ),
          ),
          appBar: QlAppBar(
            canBack: true,
            actions: [
              CommitButton(
                title: "分享",
                onTap: () {
                  ShareUtils.share(content ?? "");
                },
              ),
            ],
            title: widget.title,
          ),
          body: GlassPageBackground(
            child:
                (content == null)
                    ? const Center(child: LoadingWidget())
                    : (content!.isEmpty && !canRequest)
                    // 轮询已停且无内容：多半是脚本还没开始写日志，
                    // 给个手动重开的入口，不然这页永远停在"暂无日志"
                    ? _buildEmptyReload(context)
                    : CupertinoScrollbar(
                      child: LogTextView(
                        content: _renderContent ?? content,
                        accountIndex:
                            SingleAccountPageState.of(context)?.index ?? 0,
                        scrollController: controller,
                        // 超过渲染上限时，顶部给「查看完整日志」入口。
                        // 长日志只显示尾部又无提示，用户会以为前面内容丢了
                        truncatedHint:
                            (content?.length ?? 0) > _maxRenderChars
                                ? "仅显示最后 ${(_maxRenderChars / 1024).round()}KB"
                                    "（共 ${((content?.length ?? 0) / 1024).round()}KB），"
                                    "点击查看完整日志"
                                : null,
                        onShowFull: () => _openFullLog(content ?? ""),
                      ),
                    ),
          ),
        );
      },
    );
  }

  @override
  void onLazyLoad() {
    alwaysAuthScroll = SpUtil.getBool(spLogAutoJump2Bottom, defValue: false);
    if (widget.needTimer) {
      // 金标联盟公平调度：使用可暂停的周期 Timer，应用进入后台时自动暂停
      startPauseableTimer(const Duration(seconds: 2), () => getLogData());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        getLogData();
      });
    }
  }
}
