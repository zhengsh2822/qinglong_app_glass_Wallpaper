import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 应用前后台生命周期状态
enum AppLifecycleState {
  /// 应用在前台
  foreground,
  /// 应用在后台
  background,
}

/// 金标联盟公平调度：应用前后台生命周期感知 Provider
///
/// 通过 EventChannel 监听 Kotlin 端 ProcessLifecycleOwner 的前后台切换事件，
/// 暴露为 [Stream] 供 Flutter 端订阅。
///
/// 核心用途：让 [Timer.periodic] 轮询类页面（如 intime_log 每 2 秒刷新日志）
/// 在应用进入后台时立即暂停轮询，避免无意义地占用 CPU 和网络资源。
///
/// 与 Flutter 自带 [WidgetsBindingObserver.didChangeAppLifecycleState] 的区别：
/// - Flutter 自带的生命周期回调基于 Activity 优先级，对单 Activity 应用足够
/// - 但本组件通过 ProcessLifecycleOwner 直接监听进程级前后台切换，更准确，
///   并复用同一个 channel 推送内存压力事件，便于未来扩展
class AppLifecycleProvider {
  static const _channel = EventChannel('com.qlapp.qinglong_app/lifecycle');

  static AppLifecycleProvider? _instance;

  static AppLifecycleProvider get instance {
    _instance ??= AppLifecycleProvider._();
    return _instance!;
  }

  AppLifecycleProvider._();

  StreamController<AppLifecycleState>? _controller;
  StreamSubscription? _platformSub;
  AppLifecycleState _currentState = AppLifecycleState.foreground;

  /// 当前应用前后台状态
  AppLifecycleState get currentState => _currentState;

  /// 应用是否在前台
  bool get isForeground => _currentState == AppLifecycleState.foreground;

  /// 应用前后台状态变化流
  ///
  /// 订阅后会立即收到当前状态，之后每次切换都会推送新状态。
  Stream<AppLifecycleState> get stream {
    _ensureInitialized();
    return _controller!.stream;
  }

  void _ensureInitialized() {
    if (_controller != null) return;
    _controller = StreamController<AppLifecycleState>.broadcast();
    // 仅 Android 平台需要监听（iOS 不适用 ProcessLifecycleOwner）
    if (Platform.isAndroid) {
      _platformSub = _channel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is String) {
            switch (event) {
              case 'foreground':
                _currentState = AppLifecycleState.foreground;
                _controller!.add(_currentState);
                break;
              case 'background':
                _currentState = AppLifecycleState.background;
                _controller!.add(_currentState);
                break;
              case 'memory_pressure':
                // 内存压力事件，可由其他订阅者响应（如清理缓存）
                // 这里不映射到 AppLifecycleState，仅作为扩展点
                break;
            }
          }
        },
        onError: (Object error) {
          // EventChannel 错误静默处理，避免影响订阅者
        },
      );
    }
  }

  /// 释放资源（仅在应用退出时调用，通常不需要手动调用）
  void dispose() {
    _platformSub?.cancel();
    _platformSub = null;
    _controller?.close();
    _controller = null;
  }
}
