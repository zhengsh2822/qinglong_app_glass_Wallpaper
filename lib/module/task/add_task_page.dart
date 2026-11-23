import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:path/path.dart' as p;
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_text_field.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/upload_script_widget.dart';
import 'package:qinglong_app/module/others/scripts/script_upload_page.dart';
import 'package:qinglong_app/module/subscribe/add_subscribe_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/config_detail_page.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  final TaskBean? taskBean;
  final bool hideUploadFile;

  const AddTaskPage({super.key, this.taskBean, required this.hideUploadFile});

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage>
    with LazyLoadState<AddTaskPage> {
  late TaskBean taskBean;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _cronController = TextEditingController();

  /// 附加定时规则输入控制器（青龙 2.24+ 一任务多规则，Issue #3）
  final List<TextEditingController> _extraCronControllers = [];

  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.taskBean != null) {
      taskBean = widget.taskBean!;
      _nameController.text = taskBean.name ?? "";
      _commandController.text = taskBean.command ?? "";
      _cronController.text = taskBean.schedule ?? "";
      // 编辑回填附加规则
      for (final String s in taskBean.extraSchedules ?? const []) {
        _extraCronControllers.add(TextEditingController(text: s));
      }
    } else {
      taskBean = TaskBean();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CommitButton(
            onTap: () {
              submit();
            },
          ),
        ],
        title:
            (taskBean.sId == null || taskBean.sId!.isEmpty) ? "新增任务" : "编辑任务",
      ),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),
                  const TitleWidget("名称", required: true),
                  const SizedBox(height: 10),
                  GlassTextField(
                    focusNode: focusNode,
                    controller: _nameController,
                    hintText: "请输入名称",
                    maxLines: 3,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),
                  const TitleWidget("命令", required: true),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _commandController,
                    hintText: "请输入命令",
                    maxLines: 4,
                    minLines: 1,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),
                  const TitleWidget("定时规则", required: true),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _cronController,
                    hintText: "可选，多个命令用换行分隔",
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      try {
                        var cron = _cronController.text.replaceAll(" ", "_");
                        await launchUrl(
                          Uri.tryParse("https://crontab.guru/#$cron")!,
                        );
                      } catch (e) { /* ignore: failure is non-critical */ }
                    },
                    child: Text(
                      "在线测试",
                      style: TextStyle(
                        fontSize: 12,
                        color: ref.watch(themeProvider).primaryColor,
                      ),
                    ),
                  ),
                  // ── 附加定时规则（动态列表，仿网页版「新增定时规则」）──
                  const SizedBox(height: 20),
                  const TitleWidget("附加定时规则"),
                  const SizedBox(height: 10),
                  ...List.generate(_extraCronControllers.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GlassTextField(
                              controller: _extraCronControllers[i],
                              hintText: "秒(可选) 分 时 天 月 周",
                              minLines: 1,
                              textAlignVertical: TextAlignVertical.center,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.redAccent,
                            tooltip: "删除该规则",
                            onPressed: () {
                              setState(() {
                                _extraCronControllers.removeAt(i).dispose();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _extraCronControllers.add(TextEditingController());
                      });
                    },
                    child: Text(
                      "+ 新增定时规则",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ref.watch(themeProvider).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Visibility(
                    visible: !widget.hideUploadFile,
                    child: UploadScriptWidget(
                      key: fileKey,
                      nameCallBack: (name) async {
                        _nameController.text = name ?? "";
                        if (name == null || name.isEmpty) {
                          _commandController.text = "";
                          _cronController.text = "";
                        } else {
                          String command =
                              "task ${fileKey.currentState?.scriptPath}${(fileKey.currentState != null && fileKey.currentState!.scriptPath.isNotEmpty) ? p.separator : ""}${fileKey.currentState?.getFileName()}";

                          _commandController.text = command;

                          String data =
                              await fileKey.currentState?.file
                                  ?.readAsString() ??
                              "";

                          _cronController.text =
                              ScriptUploadPageState.getCronString(data, name) ??
                              "";
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  GlobalKey<UploadScriptWidgetState> fileKey = GlobalKey();

  void submit() async {
    if (_nameController.text.isEmpty) {
      "任务名称不能为空".toast();
      return;
    }
    if (_commandController.text.isEmpty) {
      "命令不能为空".toast();
      return;
    }
    if (_cronController.text.isEmpty) {
      "定时规则不能为空".toast();
      return;
    }

    // 附加规则轻量校验：非空行须为 5 或 6 段（秒可选）cron 表达式，
    // 空行静默丢弃（网页版 required 逻辑的宽松版）
    for (final TextEditingController c in _extraCronControllers) {
      final String s = c.text.trim();
      if (s.isEmpty) continue;
      final int fields = s.split(RegExp(r"\s+")).length;
      if (fields != 5 && fields != 6) {
        "附加规则格式有误：$s（应为 分 时 天 月 周，秒可选）".toast();
        return;
      }
    }

    commitReal();
  }

  void commitReal() async {
    try {
      hideKeyboardFocus();
      if (fileKey.currentState != null && fileKey.currentState!.file != null) {
        String content = await fileKey.currentState!.file!.readAsString();
        if (!mounted) return;
        HttpResponse<NullResponse> responseS =
            await SingleAccountPageState.ofApi(context).addScript(
              fileKey.currentState?.getFileName() ??
                  _commandController.text.split(" ").last,
              fileKey.currentState?.scriptPath ?? "",
              content,
            );
        if (!responseS.success) {
          responseS.message?.toast();
          return;
        }
      }

      taskBean.name = _nameController.text;
      taskBean.command = _commandController.text.trim();
      taskBean.schedule = _cronController.text.trim();
      // 附加规则：丢弃空行；编辑场景总是全量提交（含空=清空），新增场景
      // 无附加规则时不带字段
      final List<String> extras = _extraCronControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      taskBean.extraSchedules = extras;

      await EasyLoading.show(status: "提交中");
      if (!mounted) return;
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(
        context,
      ).addTask(
        _nameController.text,
        _commandController.text.trim(),
        _cronController.text.trim(),
        id: taskBean.id,
        nId: taskBean.nId,
        extraSchedules: extras,
      );
      await EasyLoading.dismiss();
      if (!mounted) return;
      if (response.success) {
        (widget.taskBean?.sId == null) ? "新增成功" : "修改成功".toast();
        ref
            .read(
              SingleAccountPageState.ofTaskProvider(context)(
                getProviderName(context),
              ),
            )
            .updateBean(context, taskBean);
        Navigator.of(context).pop();
      } else {
        response.message?.toast();
      }
    } catch (e) {
      e.toString().toast();
      EasyLoading.dismiss();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _cronController.dispose();
    for (final TextEditingController c in _extraCronControllers) {
      c.dispose();
    }
    focusNode.dispose();
    super.dispose();
  }

  @override
  void onLazyLoad() {
    if (widget.hideUploadFile) {
      focusNode.requestFocus();
    }
  }
}
