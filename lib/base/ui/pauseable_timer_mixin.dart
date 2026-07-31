import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:qinglong_app/base/app_lifecycle_provider.dart';

/// 金标联盟公平调度：可暂停的周期任务 Mixin
///
/// 为带有 [Timer.periodic] 轮询的页面提供前后台感知能力：
/// - 应用进入后台时自动暂停周期 Timer
/// - 应用回到前台时自动恢复周期 Timer（仅当业务未主动停止时）
///
/// 使用方式：
/// ```dart
/// class _MyPageState extends State<MyPage>
///     with PauseableTimerMixin<MyPage> {
///   @override
///   void onLazyLoad() {
///     startPauseableTimer(Duration(seconds: 2), () => loadData());
///   }
///
///   // 业务主动停止（如连续 N 次数据为空后不再轮询）
///   void stopOnError() {
///     stopPauseableTimer();
///   }
///
///   @override
///   void dispose() {
///     cancelPauseableTimer();
///     super.dispose();
///   }
/// }
/// ```
///
/// 注意：必须调用 [cancelPauseableTimer] 释放资源，否则订阅会泄漏。
mixin PauseableTimerMixin<T extends StatefulWidget> on State<T> {
  Timer? _pauseableTimer;
  StreamSubscription<AppLifecycleState>? _lifecycleSub;
  Duration? _timerDuration;
  void Function()? _timerCallback;
  // 业务是否主动停止（区分"前后台暂停"和"业务停止"）
  bool _stoppedByBusiness = false;

  /// 启动可暂停的周期 Timer
  ///
  /// 应用在前台时，按 [duration] 周期调用 [callback]。
  /// 应用进入后台时，自动取消 Timer；回到前台时，自动恢复。
  void startPauseableTimer(Duration duration, VoidCallback callback) {
    _timerDuration = duration;
    _timerCallback = callback;
    _stoppedByBusiness = false;
    _pauseableTimer?.cancel();
    _pauseableTimer = Timer.periodic(duration, (_) => callback());
    // 立即触发一次，与原 intime_log 行为保持一致
    callback();
    // 订阅前后台状态（避免重复订阅）
    _lifecycleSub ??= AppLifecycleProvider.instance.stream.listen((state) {
      if (state == AppLifecycleState.background) {
        // 进入后台：暂停周期任务
        _pauseableTimer?.cancel();
        _pauseableTimer = null;
      } else if (state == AppLifecycleState.foreground) {
        // 回到前台：恢复周期任务
        // 仅当业务未主动停止、且 timer 当前不存在时才恢复
        if (!_stoppedByBusiness &&
            _pauseableTimer == null &&
            _timerDuration != null &&
            _timerCallback != null) {
          _pauseableTimer =
              Timer.periodic(_timerDuration!, (_) => _timerCallback!());
        }
      }
    });
  }

  /// 业务主动停止周期 Timer
  ///
  /// 与前后台暂停不同：业务停止后，应用回到前台也不会自动恢复。
  /// 适用于"连续 N 次数据为空后不再轮询"等场景。
  void stopPauseableTimer() {
    _stoppedByBusiness = true;
    _pauseableTimer?.cancel();
    _pauseableTimer = null;
  }

  /// 取消可暂停的周期 Timer 并释放所有资源
  ///
  /// 必须在 State.dispose 中调用。
  void cancelPauseableTimer() {
    _pauseableTimer?.cancel();
    _pauseableTimer = null;
    _lifecycleSub?.cancel();
    _lifecycleSub = null;
    _timerDuration = null;
    _timerCallback = null;
  }
}
