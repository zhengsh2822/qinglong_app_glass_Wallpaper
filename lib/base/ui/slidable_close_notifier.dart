import 'package:flutter/foundation.dart';

/// 全局 Slidable 关闭通知器
/// 当底部导航栏切换 tab 时触发，各页面监听后关闭所有打开的 Slidable 卡片
class SlidableCloseNotifier {
  static final ValueNotifier<int> _notifier = ValueNotifier<int>(0);

  static ValueListenable<int> get listenable => _notifier;

  /// 触发关闭信号（tab 切换时调用）
  static void notify() {
    _notifier.value++;
  }

  /// 获取当前信号值（用于生成 Key）
  static int get value => _notifier.value;
}
