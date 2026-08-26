import 'package:flutter/foundation.dart';

/// 全局"App 首次启动"标志。
///
/// App cold start 后 isFirstLaunch = true。LazyFirstScreen 在首次创建时检测此标志：
/// - true：跳过骨架动画，直接显示 child（避免和 child 自身的网络 loading 动画叠加），
///   同时调用 [markNotFirstLaunch] 消耗此标志
/// - false：启用骨架模拟加载动画
///
/// 典型场景：
/// - 用户 cold start App → 主页可见 → 首次点"订阅管理"（push 路由）：
///   LazyFirstScreen 检测 true → 跳过骨架，订阅管理页面**自身的网络 loading 动画**
///   正常显示（不会和模拟骨架叠加），更真实
/// - 后续再点"订阅管理"：isFirstLaunch=false → 启用模拟骨架动画
///
/// 注：仅 LazyFirstScreen 消耗此标志，其他用途（如 splash 引导）请另设标志。
class AppFirstLaunchState {
  AppFirstLaunchState._();

  /// App 启动后初始为 true。LazyFirstScreen 首次创建时读取并消耗。
  static final ValueNotifier<bool> isFirstLaunch = ValueNotifier<bool>(true);

  /// 标记首次启动已被消耗（LazyFirstScreen 检测到 true 后调用）
  static void markNotFirstLaunch() {
    if (isFirstLaunch.value) {
      isFirstLaunch.value = false;
    }
  }
}
