import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/module/appkey/appkey_page.dart';
import 'package:qinglong_app/module/appkey/appkey_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../base/commit_button.dart';
import '../../base/ql_app_bar.dart';
import '../../base/single_account_page.dart';
import '../../base/theme.dart';
import '../../base/ui/glass_card.dart';
import '../../base/ui/glass_text_field.dart';
import '../../base/ui/tag_chip.dart';
import '../subscribe/add_subscribe_page.dart';



class AddAppKeyPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> bean;

  const AddAppKeyPage({
    Key? key,
    required this.bean,
  }) : super(key: key);

  @override
  ConsumerState<AddAppKeyPage> createState() => _AddAppKeyPageState();
}

class _AddAppKeyPageState extends ConsumerState<AddAppKeyPage> {
  final TextEditingController _nameController = TextEditingController();

  List<String> selectedPermissions = ["定时任务"];

  @override
  void initState() {
    if (widget.bean.isNotEmpty) {
      _nameController.text = widget.bean["name"] ?? "";

      selectedPermissions.clear();
      selectedPermissions
          .addAll(AppKeyViewModel.getScopeNames(widget.bean["scopes"]));
    }

    super.initState();
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
              commit();
            },
          ),
        ],
        title: "新增应用",
      ),
      body: GlassPageBackground(
        child: SingleChildScrollView(
        primary: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  Row(
                    children: [
                      const TitleWidget(
                        "权限",
                        required: true,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => onTextFieldTap(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ref.watch(themeProvider).primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.add,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 2),
                              Text(
                                "添加权限",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  GestureDetector(
                    onTap: () {
                      onTextFieldTap();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: selectedPermissions.isEmpty
                        ? Text(
                            "请选择",
                            style: TextStyle(
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .descColor(),
                              fontSize: 16,
                            ),
                          )
                        : Material(
                            color: Colors.transparent,
                            child: Wrap(
                              runSpacing: 5,
                              spacing: 5,
                              children: selectedPermissions
                                  .map((e) => TagChip(label: e))
                                  .toList(),
                            ),
                          ),
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

  void onTextFieldTap() {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    // 临时副本，确定后才回写
    final List<String> tmpSelected = List.from(selectedPermissions);
    final allPermissions = [
      "定时任务",
      "环境变量",
      "配置文件",
      "脚本管理",
      "任务日志",
      "依赖管理",
      "订阅管理",
      "系统信息",
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OptimizedFrostedGlass(
                sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
                borderRadius: BorderRadius.circular(18),
                forceOpaqueSolid: true,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: CyberColors.cyan.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 顶部拖拽指示器（grabber）— 配合 showModalBottomSheet 的 enableDrag 使用
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        decoration: BoxDecoration(
                          color: CyberColors.cyan.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "请选择你需要的权限",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: CyberColors.cyan,
                                fontFamily: 'MiSans',
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 22,
                                color: CyberColors.titleWhite.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 0.5,
                        color: CyberColors.cyan.withValues(alpha: 0.2),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: allPermissions.length,
                          itemBuilder: (context, index) {
                            final name = allPermissions[index];
                            final selected = tmpSelected.contains(name);
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setModalState(() {
                                  if (selected) {
                                    tmpSelected.remove(name);
                                  } else {
                                    tmpSelected.add(name);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: selected
                                              ? CyberColors.cyan
                                              : CyberColors.titleWhite,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          fontFamily: 'MiSans',
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        CupertinoIcons.checkmark_alt,
                                        size: 18,
                                        color: CyberColors.cyan,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Divider(
                        height: 0.5,
                        color: CyberColors.cyan.withValues(alpha: 0.2),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            color: ref.watch(themeProvider).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            child: const Text(
                              "确定",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () {
                              selectedPermissions
                                ..clear()
                                ..addAll(tmpSelected);
                              setState(() {});
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void commit() async {
    if (_nameController.text.isEmpty) {
      "请输入名称".toast();
      return;
    }

    if (selectedPermissions.isEmpty) {
      "请选择权限".toast();
      return;
    }

    EasyLoading.show(status: "提交中");

    HttpResponse<NullResponse> response;

    Map<String, dynamic> data = {
      "name": _nameController.getTextOrDefault(),
      "scopes": AppKeyViewModel.getScopeKeys(selectedPermissions),
    };
    if (widget.bean.containsKey("_id") || widget.bean.containsKey("id")) {
      if (widget.bean.containsKey("_id")) {
        data["_id"] = widget.bean["_id"];
      } else {
        data["id"] = widget.bean["id"];
      }

      response = await SingleAccountPageState.ofApi(context).updateAppKey(data);
    } else {
      response = await SingleAccountPageState.ofApi(context).addAppKey(data);
    }
    EasyLoading.dismiss();

    if (response.success) {
      Navigator.of(context).pop(true);
    } else {
      response.message?.toast();
    }
  }
}
