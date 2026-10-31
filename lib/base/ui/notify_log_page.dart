import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/content_entrance.dart';
import 'package:qinglong_app/base/ui/empty_widget.dart';
import 'package:qinglong_app/base/ui/enable_widget.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/others/notify_log/notify_log_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';

/// 通知审计日志（青龙 2.24.0 新增，对齐网页版「系统设置 → 通知日志」）
///
/// 展示每次通知推送的来源（系统/脚本）、标题、内容、推送渠道与发送结果。
/// 数据来自 GET /system/notify-log，仅记录面板升级到 2.24.0 之后发送的通知。
class NotifyLogPage extends ConsumerStatefulWidget {
  const NotifyLogPage({super.key});

  @override
  _NotifyLogPageState createState() => _NotifyLogPageState();
}

class _NotifyLogPageState extends ConsumerState<NotifyLogPage>
    with LazyLoadState<NotifyLogPage> {
  List<NotifyLogBean> list = [];

  /// 首次加载是否完成：未完成前显示加载态，完成后空数据显示空态（防永远转圈）
  bool _loaded = false;

  /// 内容较长时默认折叠，点击展开/收起
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          Navigator.of(context).pop();
        },
        title: "通知日志",
      ),
      body:
          !_loaded
              ? const Center(child: LoadingWidget())
              : list.isEmpty
              ? const EmptyWidget()
              // 数据到位后内容柔和进场（首次挂载播放一次）：淡入 + 轻微上移
              : ContentEntrance(
                child: ListView.separated(
                  primary: true,
                  itemBuilder: (context, index) {
                    NotifyLogBean item = list[index];
                    bool expanded = _expanded.contains(index);
                    bool isScript = item.source == 'script';

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (expanded) {
                            _expanded.remove(index);
                          } else {
                            _expanded.add(index);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints.loose(
                                    Size.fromWidth(
                                      MediaQuery.of(context).size.width / 1.8,
                                    ),
                                  ),
                                  child: Text(
                                    isScript
                                        ? "脚本通知${item.scriptName == null ? '' : ' · ${item.scriptName}'}${item.taskId == null ? '' : ' (#${item.taskId})'}"
                                        : "系统通知",
                                    style: TextStyle(
                                      color:
                                          ref
                                              .watch(themeProvider)
                                              .themeColor
                                              .titleColor(),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: StatusWidget(
                                    title: item.status == 1 ? "失败" : "成功",
                                    color:
                                        item.status == 1
                                            ? const Color(0xffFB5858)
                                            : ref
                                                .watch(themeProvider)
                                                .primaryColor,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  Utils.formatMessageTime(item.timestamp ?? 0),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        ref
                                            .watch(themeProvider)
                                            .themeColor
                                            .descColor(),
                                  ),
                                ),
                              ],
                            ),
                            if (item.notifyType != null &&
                                item.notifyType!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "推送渠道：${item.notifyType}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            if (item.title != null && item.title!.isNotEmpty)
                              Text(
                                item.title!,
                                style: TextStyle(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .titleColor(),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (item.content != null &&
                                item.content!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SelectableText(
                                item.content!,
                                selectionControls:
                                    cupertinoTextSelectionControls,
                                selectionWidthStyle: BoxWidthStyle.max,
                                selectionHeightStyle: BoxHeightStyle.max,
                                maxLines: expanded ? null : 3,
                                style: TextStyle(
                                  color:
                                      ref
                                          .watch(themeProvider)
                                          .themeColor
                                          .descColor(),
                                  fontSize: 13,
                                ),
                              ),
                              if (!_isShortContent(item.content)) ...[
                                const SizedBox(height: 2),
                                Text(
                                  expanded ? "收起" : "展开全文",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        ref.watch(themeProvider).primaryColor,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  itemCount: list.length,
                  separatorBuilder: (BuildContext context, int index) {
                    return const Divider(indent: 15, height: 1);
                  },
                ),
              ),
    );
  }

  bool _isShortContent(String? content) {
    return content == null || content.length <= 60;
  }

  Future<void> loadData() async {
    HttpResponse<List<NotifyLogBean>> response =
        await SingleAccountPageState.ofApi(context).notifyLog();

    // 无论成功失败都结束加载态：失败/无数据以空态呈现，避免页面永远转圈
    _loaded = true;
    if (response.success) {
      if (response.bean == null || response.bean!.isEmpty) {
        "暂无数据".toast();
      }
      list.clear();
      list.addAll(response.bean ?? []);
    } else {
      response.message?.toast();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void onLazyLoad() {
    loadData();
  }
}
