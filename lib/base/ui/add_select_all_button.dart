import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 导航栏「+ ↔ 全选/全不选」切换按钮
///
/// 非编辑态显示加号图标（24px），编辑态切换为「全选 / 全不选」文本（16px）。
/// 内容固定 52 宽居中，切换用 AnimatedSwitcher 原地淡出淡入（260ms）：
/// 旧内容淡出、新内容淡入，位置不变；按钮宽度不变，避免挤压左侧排序按钮
/// 或中间标题跳位。供 env_page / task_page / dependency_page 共用。
class AddSelectAllNavButton extends StatelessWidget {
  final bool editMode;

  /// 当前列表是否已全部选中（true 显示「全不选」）
  final bool allChecked;

  final VoidCallback onPressed;

  /// 图标 / 文字颜色（跟随导航栏按钮色）
  final Color color;

  /// 外边距（右缘对齐卡片宽度由各页面传入）
  final EdgeInsetsGeometry padding;

  const AddSelectAllNavButton({
    super.key,
    required this.editMode,
    required this.allChecked,
    required this.onPressed,
    required this.color,
    this.padding = const EdgeInsets.only(right: 16),
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      color: Colors.transparent,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Padding(
        padding: padding,
        child: Center(
          child: SizedBox(
            width: 52,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child:
                    editMode
                        ? Text(
                          allChecked ? "全不选" : "全选",
                          key: ValueKey('select-all-$allChecked'),
                          style: TextStyle(fontSize: 16, color: color),
                        )
                        : Icon(
                          CupertinoIcons.add,
                          key: const ValueKey('add'),
                          size: 24,
                          color: color,
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
