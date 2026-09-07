import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/button.dart';
import 'package:qinglong_app/base/ui/glass_text_field.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/selection_follow_text_field.dart';
import 'package:qinglong_app/module/config/config_viewmodel.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/env/env_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../config/config_detail_page.dart';
import '../subscribe/add_subscribe_page.dart';

class AddEnvPage extends ConsumerStatefulWidget {
  final EnvBean? envBean;

  /// 是否为复制模式：预填原变量字段，但新建不带 id 的 EnvBean（走"新增"而非"编辑"）
  final bool isCopy;

  const AddEnvPage({Key? key, this.envBean, this.isCopy = false})
      : super(key: key);

  @override
  ConsumerState<AddEnvPage> createState() => _AddEnvPageState();
}

class _AddEnvPageState extends ConsumerState<AddEnvPage>
    with LazyLoadState<AddEnvPage> {
  late EnvBean envBean;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.isCopy) {
      // 复制模式：新建空 EnvBean（不带 id/sId，保证走新增），仅预填原变量字段
      // name 自动加 _copy 后缀：青龙后端 name+value 为联合唯一索引（compositeIndex），
      // 若 name/value 完全相同会违反唯一约束导致创建失败，改名后才能保存副本
      envBean = EnvBean();
      final String? rawName = widget.envBean?.name;
      _nameController.text =
          (rawName == null || rawName.isEmpty) ? "" : "${rawName}_copy";
      _valueController.text = widget.envBean?.value ?? "";
      _remarkController.text = widget.envBean?.remarks ?? "";
    } else if (widget.envBean != null) {
      envBean = widget.envBean!;
      _nameController.text = envBean.name ?? "";
      _valueController.text = envBean.value ?? "";
      _remarkController.text = envBean.remarks ?? "";
    } else {
      envBean = EnvBean();
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
        title: envBean.name == null ? "新增环境变量" : "编辑环境变量",
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height - kToolbarHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    const TitleWidget(
                      "名称",
                      required: true,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    GlassTextField(
                      focusNode: (envBean.sId == null || envBean.sId!.isEmpty) ? focusNode : null,
                      controller: _nameController,
                      hintText: "请输入名称",
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    const TitleWidget(
                      "值",
                      required: true,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    SelectionFollowTextField(
                      debugLabel: 'AddEnvPage:值',
                      focusNode: (envBean.sId == null || envBean.sId!.isEmpty) ? null : focusNode,
                      controller: _valueController,
                      maxLines: 8,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: "请输入值",
                      ),
                      autofocus: false,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    const TitleWidget(
                      "备注",
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    GlassTextField(
                      maxLines: 3,
                      minLines: 1,
                      controller: _remarkController,
                      hintText: "请输入备注",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void submit() async {
    try {
      if (_nameController.text.isEmpty) {
        "名称不能为空".toast();
        return;
      }
      if (_valueController.text.isEmpty) {
        "值不能为空".toast();
        return;
      }
      hideKeyboardFocus();

      envBean.name = _nameController.text;
      envBean.value = _valueController.text;
      envBean.remarks = _remarkController.text;

      await EasyLoading.show(status: " 提交中");
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(context).addEnv(
        _nameController.text,
        _valueController.text,
        _remarkController.text,
        id: envBean.id,
        nId: envBean.nId,
      );
      await EasyLoading.show(status: " 提交中");
      if (envBean.sId != null && envBean.sId!.isNotEmpty) {
        await SingleAccountPageState.ofApi(context).enableEnv(
          [envBean.sId!],
        );
      }
      await EasyLoading.dismiss();
      if (response.success) {
        (envBean.sId == null || envBean.sId!.isEmpty) ? "新增成功" : "修改成功${envBean.status == 1?",并自动启用":""}".toast();
        Navigator.of(context).pop();
      } else {
        (response.message ?? "").toast();
      }
    } catch (e) {
      EasyLoading.dismiss();
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void onLazyLoad() {
    focusNode.requestFocus();
  }
}
