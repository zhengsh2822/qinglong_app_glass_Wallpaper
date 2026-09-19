import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/module/appkey/appkey_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../base/commit_button.dart';
import '../../base/ql_app_bar.dart';
import '../../base/single_account_page.dart';
import '../../base/ui/glass_card.dart';
import '../../base/ui/glass_text_field.dart';
import '../../base/ui/selectable_chip.dart';
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
  final TextEditingController _customScopeController = TextEditingController();

  /// 全部可选权限（与青龙面板 scopes 对应）
  static const List<String> _allPermissions = [
    '定时任务',
    '环境变量',
    '配置文件',
    '脚本管理',
    '任务日志',
    '依赖管理',
    '订阅管理',
    '系统信息',
  ];

  List<String> selectedPermissions = ["定时任务"];

  /// 自定义 scope key（青龙新增权限时手动输入，无需等 App 更新）
  final List<String> _customScopes = [];

  @override
  void initState() {
    if (widget.bean.isNotEmpty) {
      _nameController.text = widget.bean["name"] ?? "";

      selectedPermissions.clear();
      // 预设权限→中文名，青龙新增的自定义 key→原样返回
      final names = AppKeyViewModel.getScopeNames(widget.bean["scopes"]);
      for (final n in names) {
        if (_allPermissions.contains(n)) {
          selectedPermissions.add(n);
        } else if (n.isNotEmpty) {
          _customScopes.add(n);
        }
      }
    }

    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customScopeController.dispose();
    super.dispose();
  }

  /// 添加自定义 scope key
  void _addCustomScope() {
    final text = _customScopeController.text.trim();
    if (text.isEmpty) return;
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(text)) {
      "scope key 只能包含字母、数字、下划线".toast();
      return;
    }
    setState(() {
      if (!_customScopes.contains(text)) {
        _customScopes.add(text);
      }
    });
    _customScopeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final bool isCyber = theme.themeMode == modeCyber;
    final Color accentColor = theme.primaryColor;
    final Color titleColor =
        isCyber ? CyberColors.titleWhite : AppleColors.textPrimary;

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
      // 与主题版一致：无卡片平铺，字段宽度 = 屏宽-32（左右留白16），
      // 与内容/标签数量无关，天然固定宽度（杜绝自适应宽窄不一）
      body: GlassPageBackground(
        child: SingleChildScrollView(
          primary: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    const TitleWidget(
                      "权限",
                      required: true,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    // 权限平铺多选（SelectableChip 点击切换选中），与主题版一致
                    Wrap(
                      runSpacing: 8,
                      spacing: 8,
                      children: _allPermissions.map((e) {
                        final selected = selectedPermissions.contains(e);
                        return SelectableChip(
                          label: e,
                          selected: selected,
                          onToggle: (value) {
                            setState(() {
                              if (value) {
                                selectedPermissions.add(e);
                              } else {
                                selectedPermissions.remove(e);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    const TitleWidget(
                      "自定义权限",
                      required: false,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    // 青龙新增权限时手动输入 scope key，无需等 App 更新
                    Row(
                      children: [
                        Expanded(
                          child: GlassTextField(
                            controller: _customScopeController,
                            hintText: "青龙新增的 scope key，如 subscriptions",
                            textInputAction: TextInputAction.done,
                            onEditingComplete: _addCustomScope,
                            // 单行输入：禁止换行导致输入框变高，与右侧「添加」按钮对齐
                            maxLines: 1,
                            minLines: 1,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addCustomScope,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              "添加",
                              style: TextStyle(fontSize: 13, color: accentColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_customScopes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _customScopes.map((s) {
                          // 可删除的自定义 scope 标签（点击删除）
                          return GestureDetector(
                            onTap: () {
                              setState(() => _customScopes.remove(s));
                            },
                            child: Container(
                              padding: const EdgeInsets.only(
                                left: 10,
                                right: 6,
                                top: 4,
                                bottom: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 14,
                                    color: accentColor,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void commit() async {
    if (_nameController.text.isEmpty) {
      "请输入名称".toast();
      return;
    }

    if (selectedPermissions.isEmpty && _customScopes.isEmpty) {
      "请选择权限".toast();
      return;
    }

    EasyLoading.show(status: "提交中");

    HttpResponse<NullResponse> response;

    // 预设权限（中文名→key）+ 自定义 scope key（青龙新增权限直接输入）
    List<String> scopes = [
      ...AppKeyViewModel.getScopeKeys(selectedPermissions),
      ..._customScopes,
    ];

    Map<String, dynamic> data = {
      "name": _nameController.getTextOrDefault(),
      "scopes": scopes,
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
