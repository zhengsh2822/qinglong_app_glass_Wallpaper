import 'package:flutter/material.dart';

/// 退场键盘错峰观察器（并行优化 · B 方案）
///
/// 移动端掉帧主因：输入框聚焦时键盘未收起就退出页面，键盘收起动画（跨进程）
/// 与路由退场动画 + adjustResize 全页重排叠加，帧预算被打满。
///
/// 优化策略：在路由退场/手势返回**开始**的瞬间（而非转场结束后被动收键盘）
/// 立即 unfocus，让键盘收起动画与手势拖动/退场动画时间重叠、被自然吸收，
/// 转场期间主线程只跑干净的路由动画，全程不塌帧（demo「并行优化」方案）。
///
/// 触发覆盖：
/// - **路由动画 reverse**（核心）：对每个 push 的路由监听 route.animation，
///   一旦进入 reverse 即收键盘。iOS 侧滑手势、Android 预测性返回手势、返回键、
///   代码 pop，全部会先让路由动画进入 reverse → 统一在动画刚开始时收键盘。
/// - [didPop]：兜底（理论上动画 reverse 已覆盖，保留双保险）。
///
/// 挂到业务 Navigator（SingleAccountPage 的自建 Navigator）即可全局生效，
/// 覆盖所有带输入框页面（AddEnvPage/AddConfigPage/AddSubscribePage 等）。
class KeyboardDismissNavigatorObserver extends NavigatorObserver {
  /// 已挂监听的路由动画 → 监听回调（动画 dismissed 后移除防泄漏）
  final Map<Animation<double>, VoidCallback> _listeners = {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _watch(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _watch(newRoute);
  }

  void _watch(Route<dynamic> route) {
    // 只有 TransitionRoute 才有 animation（手势返回/反向动画由它驱动）
    if (route is! TransitionRoute) return;
    final anim = (route as TransitionRoute).animation;
    if (anim == null || _listeners.containsKey(anim)) return;
    void listener() {
      if (anim.status == AnimationStatus.reverse) {
        // 路由动画开始反向（手势返回/预测性返回/pop 退场）→ 立即收键盘
        FocusManager.instance.primaryFocus?.unfocus();
      } else if (anim.status == AnimationStatus.dismissed) {
        // 退场动画走完，路由已销毁 → 移除监听防泄漏
        anim.removeListener(listener);
        _listeners.remove(anim);
      }
    }

    _listeners[anim] = listener;
    anim.addListener(listener);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 兜底：pop 调用瞬间收键盘（动画 reverse 路径已提前处理，幂等无害）
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
