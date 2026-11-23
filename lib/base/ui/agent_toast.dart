import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 轻量浮动提示：不拦截点击、自动消失、可手动关闭。
///
/// 比 SnackBar 更适合「已保存」这类反馈：
/// - `IgnorePointer` 确保不挡住输入框/按钮的点击；
/// - 2 秒自动消失，也可点一下或调 [hide] 提前关闭；
/// - 浮在输入区上方，带圆角与淡入淡出，视觉更轻。
class AgentToast {
  AgentToast._();

  static OverlayEntry? _entry;
  static VoidCallback? _dismiss;

  static bool get isShowing => _entry != null;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_outline,
    Duration duration = const Duration(seconds: 2),
  }) {
    hide();
    if (!context.mounted) return;

    late final AnimationController controller;
    controller = AnimationController(
      vsync: _Ticker(),
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 150),
    );

    void remove() {
      if (_entry == null) return;
      final entry = _entry;
      _entry = null;
      _dismiss = null;
      controller.reverse().whenComplete(() {
        entry?.remove();
        controller.dispose();
      });
    }

    _dismiss = remove;

    final entry = OverlayEntry(
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Positioned(
          left: 24,
          right: 24,
          // 浮在输入区上方，不贴底、不遮挡输入框
          bottom: bottom + 84,
          child: IgnorePointer(
            // 关键：完全不拦截点击，输入框/按钮照常可点
            child: FadeTransition(
              opacity: CurvedAnimation(parent: controller, curve: Curves.easeOut),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: remove,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(icon,
                              size: 16, color: Colors.white.withValues(alpha: 0.9)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              message,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    Overlay.of(context).insert(entry);
    controller.forward();

    Future<void>.delayed(duration, remove);
  }

  /// 提前关闭（输入框获取焦点、点击任意处等场景）。
  static void hide() => _dismiss?.call();
}

/// 极简 ticker，仅用于 Overlay 内的淡入淡出动画。
class _Ticker implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
