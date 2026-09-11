import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 导航栏「+ ↔ 全选/全不选」切换按钮
///
/// 非编辑态显示加号图标（24px），编辑态切换为「全选 / 全不选」文本（16px）。
/// 内容固定 52 宽且区域内**右对齐**：`+` 右缘贴齐卡片右缘（与左侧"编辑"文字
/// 左缘对齐卡片左缘对称）。图标与文本常驻 Stack 同一右对齐锚点，
/// 用两个 AnimatedOpacity 交叉淡化（260ms）——只有透明度变化，
/// 无 AnimatedSwitcher 新旧 child 宽度跳动 / 重叠脏帧，切换最平滑。
/// 按钮宽度固定，不挤压左侧排序按钮或中间标题。
/// 供 env_page / task_page / dependency_page 共用。
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
        child: SizedBox(
          width: 52,
          height: 24,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              // 文本层：编辑态显示
              AnimatedOpacity(
                opacity: editMode ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                child: IgnorePointer(
                  ignoring: !editMode,
                  child: Text(
                    allChecked ? "全不选" : "全选",
                    style: TextStyle(fontSize: 16, color: color),
                  ),
                ),
              ),
              // 图标层：非编辑态显示
              AnimatedOpacity(
                opacity: editMode ? 0 : 1,
                duration: const Duration(milliseconds: 260),
                child: IgnorePointer(
                  ignoring: editMode,
                  child: Icon(CupertinoIcons.add, size: 24, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
