
import 'package:qinglong_app/utils/share_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/log_text_view.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../../base/cupertino_sheet.dart';
import '../../../main.dart';
import '../../home/system_bean.dart';

class InTimeHistoryLogPage extends StatefulWidget {
  final String title;
  final String path;

  const InTimeHistoryLogPage({
    super.key,
    required this.title,
    required this.path,
  });

  @override
  State<InTimeHistoryLogPage> createState() => _InTimeHistoryLogPageState();
}

class _InTimeHistoryLogPageState extends State<InTimeHistoryLogPage>
    with LazyLoadState<InTimeHistoryLogPage> {
  String? content;

  bool isRequest = false;
  bool canRequest = true;

  /// 上次拉取失败的提示；非空时页面显示错误态 + 重试，
  /// 而不是伪装成"暂无日志"（日志文件可能是空的，两者必须区分开）
  String? _loadError;

  getLogData() async {
    HttpResponse<String> response = await SingleAccountPageState.ofApi(
      context,
    ).taskLogDetail(widget.title, widget.path);

    if (response.success) {
      content = response.bean ?? "";
      _loadError = null;
    } else {
      // 失败不再落地空态：保留可能已有的内容，首次失败则展示错误 + 重试。
      // 原实现失败时 content = ""，用户看到的是"暂无日志"，
      // 无法判断是日志真的为空还是请求失败（"有些直接显示没有日志"）。
      _loadError = response.message ?? "日志读取失败";
      _loadError!.toast();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 日志内容区：加载中 / 读取失败（可重试） / 正常内容
  Widget _buildBody(BuildContext context) {
    if (_loadError != null && content == null) {
      // 首次读取就失败：明确告知失败原因 + 重试，别显示成"暂无日志"
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 34,
                color: AppColors.warning,
              ),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(999),
                onPressed: () {
                  setState(() {
                    content = null;
                    _loadError = null;
                  });
                  getLogData();
                },
                child: const Text(
                  "重试",
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (content == null) {
      return const Center(child: LoadingWidget());
    }
    return CupertinoScrollbar(
      child: LogTextView(
        content: content,
        accountIndex: SingleAccountPageState.of(context)?.index ?? 0,
        // 真的读到空文件时才说"暂无日志"，与"读取失败"区分开
        emptyText: "该日志文件为空",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              showMoreOperate(context, [
                CupertinoSheer(
                  title: "分享",
                  onTap: () async {
                    ShareUtils.share(content ?? "");
                  },
                ),
                addDivider(),
                CupertinoSheer(
                  title: "删除",
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    deleteFold(widget.title, widget.path);
                  },
                ),
              ]);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Icon(
                  Icons.more_horiz,
                  size: 26,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ),
            ),
          ),
        ],
        title: widget.title,
      ),
      body: GlassPageBackground(child: _buildBody(context)),
    );
  }

  @override
  void onLazyLoad() {
    getLogData();
  }

  void deleteFold(String title, String path) async {
    SystemBean systemBean;

    try {
      systemBean = getIt<SystemBean>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString(),
      );
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }
    if (!systemBean.isUpperVersion2_14_5()) {
      "该功能仅支持v2.14.5及以上版本".toast();
      return;
    }

    EasyLoading.show(status: "删除中...");
    if (!mounted) return;
    var temp = await SingleAccountPageState.ofApi(
      context,
    ).deleteLog(title, path);
    EasyLoading.dismiss();
    if (!mounted) return;
    if (temp.success) {
      "已删除".toast();
      Navigator.of(context).pop(true);
    } else {
      temp.message?.toast();
    }
  }
}
