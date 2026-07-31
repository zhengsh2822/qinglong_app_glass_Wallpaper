import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';

/// 滑动按钮数据模型
class CyberSlideActionData {
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const CyberSlideActionData({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// 赛博风滑动操作按钮组
///
/// 圆角拼接逻辑：
/// - 外层 [ClipRRect] 统一裁剪 BorderRadius.circular(12)，确保整体为完整圆角矩形
/// - 内部每个按钮按位置自动处理首尾圆角：
///   - 第1个按钮：左侧上下圆角（topLeft + bottomLeft）
///   - 中间按钮：全部直角（Radius.circular(0)）
///   - 最后1个按钮：右侧上下圆角（topRight + bottomRight）
/// - 按钮之间紧密贴合，无缝拼接
///
/// 使用方式：作为 Slidable 的 endActionPane 返回值
ActionPane taskSlideActions({
  required VoidCallback onEdit,
  required VoidCallback onPin,
  required VoidCallback onDisable,
  required VoidCallback onDelete,
  IconData pinIcon = CupertinoIcons.pin,
  IconData disableIcon = CupertinoIcons.eye_slash,
  String pinLabel = '置顶',
  String disableLabel = '禁用',
}) {
  return CyberSlideActions.buildActionPane(
    actions: [
      CyberSlideActionData(
        backgroundColor: const Color(0xFF00F0FF),
        foregroundColor: Colors.black,
        icon: CupertinoIcons.pencil_outline,
        label: '编辑',
        onPressed: onEdit,
      ),
      CyberSlideActionData(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        icon: pinIcon,
        label: pinLabel,
        onPressed: onPin,
      ),
      CyberSlideActionData(
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        icon: disableIcon,
        label: disableLabel,
        onPressed: onDisable,
      ),
      CyberSlideActionData(
        backgroundColor: const Color(0xFFFF3D00),
        foregroundColor: Colors.white,
        icon: CupertinoIcons.delete,
        label: '删除',
        onPressed: onDelete,
      ),
    ],
  );
}

/// 独立组件 CyberSlideActions
///
/// 接收按钮数据列表，自动处理首尾圆角拼接。
/// 结构：ActionPane → [ClipRRect(12)] → Row → Expanded × N → _CyberSlideButton
class CyberSlideActions extends StatelessWidget {
  final List<CyberSlideActionData> actions;
  final double borderRadius;
  final double extentRatio;

  const CyberSlideActions({
    Key? key,
    required this.actions,
    this.borderRadius = 12.0,
    this.extentRatio = 0.7,
  }) : super(key: key);

  /// 构造 ActionPane，供需要直接返回 ActionPane 的场景使用
  static ActionPane buildActionPane({
    required List<CyberSlideActionData> actions,
    double borderRadius = 12.0,
    double extentRatio = 0.7,
  }) {
    return ActionPane(
      motion: const ScrollMotion(),
      extentRatio: extentRatio,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Row(
            children: List.generate(actions.length, (i) {
              return Expanded(
                child: _CyberSlideButton(
                  data: actions[i],
                  borderRadius: borderRadius,
                  isFirst: i == 0,
                  isLast: i == actions.length - 1,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildActionPane(
      actions: actions,
      borderRadius: borderRadius,
      extentRatio: extentRatio,
    );
  }
}

/// 赛博风单个滑动按钮
///
/// 圆角处理：
/// - [isFirst] && [isLast]（仅1个按钮）：四角全圆
/// - [isFirst]：左侧上下圆角
/// - [isLast]：右侧上下圆角
/// - 中间：全直角
class _CyberSlideButton extends StatelessWidget {
  final CyberSlideActionData data;
  final double borderRadius;
  final bool isFirst;
  final bool isLast;

  const _CyberSlideButton({
    required this.data,
    required this.borderRadius,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    // 【首尾圆角拼接】按位置计算 BorderRadius
    BorderRadius radius;
    if (isFirst && isLast) {
      radius = BorderRadius.circular(borderRadius);
    } else if (isFirst) {
      radius = BorderRadius.only(
        topLeft: Radius.circular(borderRadius),
        bottomLeft: Radius.circular(borderRadius),
      );
    } else if (isLast) {
      radius = BorderRadius.only(
        topRight: Radius.circular(borderRadius),
        bottomRight: Radius.circular(borderRadius),
      );
    } else {
      radius = BorderRadius.zero;
    }

    return CustomSlidableAction(
      onPressed: (_) => data.onPressed(),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: data.backgroundColor,
          borderRadius: radius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, size: 22, color: data.foregroundColor),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: TextStyle(
                color: data.foregroundColor,
                fontSize: 10,
                fontFamily: CyberColors.monoFont,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
