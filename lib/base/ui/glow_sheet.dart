import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';

/// 高光内发光底部弹层容器（壁纸版，与 CapsuleGlowCard 同设计语言）
///
/// 用于底部弹层（选择器 / 操作菜单等）与居中弹窗：
/// - 深色模式（cyber/dark）：青色发光边框 + 青色顶部高光 + 青色内发光
///   + 青色外发光（弹层已由 forceOpaqueSolid 提供 100% 纯色底，此处只叠加装饰）
/// - 浅色模式（兜底）：白色边框 + 浅灰顶部高光 + 白色内发光 + 外阴影
class GlowSheetContainer extends StatelessWidget {
  final bool isCyber;
  final Widget child;
  final double radius;

  const GlowSheetContainer({
    super.key,
    required this.isCyber,
    required this.child,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final Border border;
    final List<BoxShadow> glow;

    if (isCyber) {
      border = Border.all(
        color: CyberColors.cyan.withValues(alpha: 0.25),
        width: 1,
      );
      glow = [
        // 顶部青色高光（内发光）
        BoxShadow(
          color: CyberColors.cyan.withValues(alpha: 0.16),
          blurRadius: 2.5,
          spreadRadius: 0.2,
          offset: const Offset(0, -1),
        ),
        // 底部青色内发光
        BoxShadow(
          color: CyberColors.cyan.withValues(alpha: 0.08),
          blurRadius: 8,
          spreadRadius: 0.4,
          offset: const Offset(0, 2),
        ),
        // 青色外发光
        BoxShadow(
          color: CyberColors.cyan.withValues(alpha: 0.05),
          blurRadius: 14,
          spreadRadius: 0.5,
        ),
      ];
    } else {
      border = Border.all(color: Colors.white, width: 1);
      glow = [
        // 顶部浅灰高光（内发光）
        BoxShadow(
          color: const Color(0xFFF2F2F4).withValues(alpha: 0.20),
          blurRadius: 2.5,
          spreadRadius: 0.2,
          offset: const Offset(0, -1),
        ),
        // 底部纯白内发光
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.16),
          blurRadius: 8,
          spreadRadius: 0.4,
          offset: const Offset(0, 2),
        ),
        // 外阴影（底部弹层阴影向上）
        BoxShadow(
          color: const Color(0x0F000000),
          blurRadius: 12,
          offset: const Offset(0, -4),
        ),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: glow,
      ),
      child: child,
    );
  }
}

/// 顶部圆角拖拽条（底部弹层通用）
class DragHandle extends StatelessWidget {
  final bool isCyber;

  const DragHandle({super.key, required this.isCyber});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: isCyber
            ? CyberColors.cyan.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}