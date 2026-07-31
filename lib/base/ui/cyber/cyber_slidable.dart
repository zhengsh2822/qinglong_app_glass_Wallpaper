import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';

/// 滑动操作按钮数据模型
class CyberSlideAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CyberSlideAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// 全局通用滑动操作组件
///
/// 赛博模式：独立圆角胶囊按钮 + 外发光 + 按钮间距
/// 按钮宽度：每个占屏幕宽度 18%（4个=72%、3个=54%、2个=36%）
class CyberSlidable extends StatelessWidget {
  final Widget child;
  final List<CyberSlideAction> startActions;
  final List<CyberSlideAction> endActions;
  final Key? slidableKey;
  final bool enabled;
  final double borderRadius;

  const CyberSlidable({
    super.key,
    required this.child,
    this.startActions = const [],
    this.endActions = const [],
    this.slidableKey,
    this.enabled = true,
    this.borderRadius = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: slidableKey,
      enabled: enabled,
      startActionPane: _buildPane(context, startActions),
      endActionPane: _buildPane(context, endActions),
      child: child,
    );
  }

  ActionPane? _buildPane(BuildContext context, List<CyberSlideAction> actions) {
    if (actions.isEmpty) return null;

    final extentRatio = (actions.length * 0.18).clamp(0.2, 0.9);
    const buttonRadius = 12.0;
    const buttonSpacing = 4.0;
    const verticalPadding = 4.0;

    return ActionPane(
      motion: const ScrollMotion(),
      extentRatio: extentRatio,
      children:
          actions
              .map(
                (action) => CustomSlidableAction(
                  onPressed: (ctx) {
                    Slidable.of(ctx)?.close();
                    action.onTap();
                  },
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: buttonSpacing / 2,
                    vertical: verticalPadding,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: action.color,
                      borderRadius: BorderRadius.circular(buttonRadius),
                      border: Border.all(
                        color: action.color.withValues(alpha: 0.7),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: action.color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Slidable.of(context)?.close();
                          action.onTap();
                        },
                        borderRadius: BorderRadius.circular(buttonRadius),
                        child: Center(
                          child: Icon(
                            action.icon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}
