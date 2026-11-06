import 'dart:convert';

import 'package:qinglong_app/utils/share_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/log_scroll_button.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/pauseable_timer_mixin.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../../base/commit_button.dart';

class InTimeDepLogPage extends StatefulWidget {
  final String id;
  final bool needTimer;
  final String title;

  const InTimeDepLogPage(this.id, this.needTimer, this.title, {super.key});

  @override
  State<InTimeDepLogPage> createState() => _InTimeDepLogPageState();
}

class _InTimeDepLogPageState extends State<InTimeDepLogPage>
    with
        LazyLoadState<InTimeDepLogPage>,
        PauseableTimerMixin<InTimeDepLogPage> {
  String? content;

  @override
  void initState() {
    super.initState();
    getLogData();
  }

  bool alwaysAuthScroll = false;

  ScrollController? controller = ScrollController();
  bool isRequest = false;
  bool canRequest = true;
  int _emptyCount = 0;

  getLogData() async {
    if (!canRequest) return;
    if (isRequest) return;
    isRequest = true;
    HttpResponse<String> response = await SingleAccountPageState.ofApi(
      context,
    ).inTimeDepLog(widget.id);
    if (response.success) {
      try {
        if (response.bean == null) {
          _emptyCount++;
          if (_emptyCount >= 3) {
            "已删除".toast();
            stopPauseableTimer();
            canRequest = false;
            content = "";
            if (mounted) setState(() {});
          }
          return;
        }
        Map<String, dynamic> data =
            jsonDecode(response.bean ?? "{}") as Map<String, dynamic>;

        List<dynamic> list = data["log"] as List<dynamic>;
        String newContent = list.join("\n");
        if (content != newContent) {
          _emptyCount = 0;
        }
        content = newContent;
        if (alwaysAuthScroll) {
          scrollLogToBottom(controller, animate: false);
        }
      } catch (e) { /* ignore: failure is non-critical */ }
      setState(() {});
    } else {
      // 拉取失败（依赖已删除等）落地空态，避免永久加载；轮询继续后台重试
      content ??= "";
      if (mounted) setState(() {});
    }
    isRequest = false;
  }

  @override
  void dispose() {
    cancelPauseableTimer();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    : CupertinoScrollbar(
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: EdgeInsets.only(
                          left: 15,
                          right: 15,
                          bottom:
                              MediaQuery.of(context).viewPadding.bottom + 20,
                        ),
                        child: Text(
                          content!,
                          style: const TextStyle(fontSize: 12),
                        ),
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
