import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

/// 卡内展开选择器的选项数据
class SelectorCardItem {
  const SelectorCardItem({
    required this.title,
    this.subtitle,
    this.selected = false,
    required this.onTap,
  });

  final String title;
  final String? subtitle;

  /// 选中态：行尾青色对勾（赛博 cyan / 浅色 primary）
  final bool selected;

  /// 选项点击（选择/跳转由调用方决定；collapseOnSelect=true 时组件自动收起）
  final VoidCallback onTap;
}

/// 卡内展开选择器（B 方案，demos/selector_arch_demo 选型）
///
/// 自研高度动画（AnimatedSize）+ 标题行箭头旋转，零 M3 组件皮肤依赖——
/// ExpansionTile 的主题派生黑条从机制上不存在。背景保持透明，由外层
/// 高光卡壳（OtherPageCard/CapsuleGlowCard）提供底色与圆角。
///
/// 使用方：
/// - push_setting_page 通知方式（选中即收起）
/// - task_log_page 任务日志文件夹（点文件跳转、不收起）
/// - upload_script_widget 脚本目录（选中即收起）
class SelectorCard extends ConsumerStatefulWidget {
  const SelectorCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.initiallyExpanded = false,
    this.collapseOnSelect = true,
  });

  /// 标题行主文本（当前值 / 文件夹名）
  final String title;

  /// 标题行副标题（可空）
  final String? subtitle;

  final List<SelectorCardItem> items;

  /// 初始是否展开
  final bool initiallyExpanded;

  /// 点击选项后是否自动收起（跳转类选项传 false）
  final bool collapseOnSelect;

  @override
  ConsumerState<SelectorCard> createState() => _SelectorCardState();
}

class _SelectorCardState extends ConsumerState<SelectorCard> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    // 字重跟随全局四档调节（400/500/600/700）
    final FontWeight fw = FontWeight(ref.watch(textWeightProvider));

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：当前值 + 副标题 + 旋转箭头
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: fw,
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .titleColor(),
                          ),
                        ),
                        if (widget.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: isCyber ? CyberColors.cyan : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 选项列表：AnimatedSize 无痕展开/收起
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child:
                _expanded
                ? Column(
                    children:
                        widget.items
                            .map(
                              (item) => InkWell(
                                onTap: () {
                                  item.onTap();
                                  if (widget.collapseOnSelect) {
                                    setState(() => _expanded = false);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Color(0xFFEFEFF1),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: fw,
                                                color: ref
                                                    .watch(themeProvider)
                                                    .themeColor
                                                    .titleColor(),
                                              ),
                                            ),
                                            if (item.subtitle != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  item.subtitle!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: ref
                                                        .watch(themeProvider)
                                                        .themeColor
                                                        .descColor(),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (item.selected)
                                        Icon(
                                          CupertinoIcons.checkmark_alt_circle,
                                          size: 20,
                                          color:
                                              isCyber
                                                  ? CyberColors.cyan
                                                  : ref
                                                      .watch(themeProvider)
                                                      .primaryColor,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
