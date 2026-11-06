
import 'package:qinglong_app/utils/share_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/log_scroll_button.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/pauseable_timer_mixin.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../../base/commit_button.dart';

class InTimeSubscribeLogPage extends StatefulWidget {
  final int cronId;
  final bool needTimer;
  final String title;

  const InTimeSubscribeLogPage(
    this.cronId,
    this.needTimer,
    this.title, {
    super.key,
  });

  @override
  State<InTimeSubscribeLogPage> createState() => _InTimeSubscribeLogPageState();
}

class _InTimeSubscribeLogPageState extends State<InTimeSubscribeLogPage>
    with
        LazyLoadState<InTimeSubscribeLogPage>,
        PauseableTimerMixin<InTimeSubscribeLogPage> {
  String? content;

  ScrollController? controller = ScrollController();

  @override
  void initState() {
    super.initState();
    getLogData();
  }

  bool alwaysAuthScroll = false;

  bool isRequest = false;
  bool canRequest = true;
  int _emptyCount = 0;

  getLogData() async {
    if (!canRequest) return;
    if (isRequest) return;
    isRequest = true;
    HttpResponse<String> response = await SingleAccountPageState.ofApi(
      context,
    ).inTimeSubscribeLog(widget.cronId);
    if (response.success) {
      String? newContent = response.bean;
      if (newContent == null || newContent.isEmpty) {
        _emptyCount++;
        if (_emptyCount >= 3) {
          stopPauseableTimer();
          canRequest = false;
        }
        isRequest = false;
        return;
      }
      if (content != newContent) {
        _emptyCount = 0;
      }
      content = newContent;
      if (alwaysAuthScroll) {
        scrollLogToBottom(controller, animate: false);
      }
      setState(() {});
    } else {
      // 拉取失败（订阅已删除等）落地空态，避免永久加载
      (response.message ?? "").toast();
      content = "";
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
              // 开启瞬间立即滚底，与实时日志页行为一致
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
                        primary: true,
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
