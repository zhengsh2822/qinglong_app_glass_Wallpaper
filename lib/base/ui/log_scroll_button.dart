import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

/// 日志页共用：滚动到底部（下一帧执行，controller 未挂载时静默跳过）
///
/// [animate]=true 平滑滚动（实时日志轮询新增内容时），
/// [animate]=false 直接跳转（依赖/订阅日志页每轮轮询原行为）。
void scrollLogToBottom(ScrollController? controller, {bool animate = true}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (controller?.hasClients ?? false) {
      if (animate) {
        controller!.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.linear,
        );
      } else {
        controller!.jumpTo(controller.position.maxScrollExtent);
      }
    }
  });
}

/// 日志详情页"滚动日志"开关按钮
///
/// 设计语言与定时任务卡片"运行/停止"胶囊按钮保持一致：
///  - 胶囊形 + 主题色边框/内发光
///  - 滚动中：暂停图标（主色）；未滚动：播放图标（主色）
class LogScrollButton extends ConsumerWidget {
  /// 当前是否开启自动滚动
  final bool active;

  /// 点击回调（切换自动滚动状态）
  final VoidCallback onTap;

  const LogScrollButton({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final Color accent =
        isCyber ? CyberColors.cyan : ref.watch(themeProvider).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: 0.3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? CupertinoIcons.pause_circle : CupertinoIcons.play_circle,
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 4),
            Text(
              active ? '暂停滚动' : '滚动日志',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
