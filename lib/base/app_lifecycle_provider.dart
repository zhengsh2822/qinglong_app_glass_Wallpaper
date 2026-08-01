import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_app/base/http/http_cache.dart';

/// 应用前后台生命周期状态
enum AppLifecycleState {
  /// 应用在前台
  foreground,
  /// 应用在后台
  background,
}

/// 金标联盟公平运行内存机制：内存事件类型
enum MemoryEvent {
  /// 系统内存压力（onTrimMemory 回调）
  pressure,
  /// 金标联盟内存预警（itgsa.intent.action.TRIM）
  trim,
  /// 金标联盟应用查杀（itgsa.intent.action.KILL）
  kill,
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
  StreamController<MemoryEvent>? _memoryController;
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

  /// 内存事件流
  ///
  /// 金标联盟公平运行内存机制：
  /// - [MemoryEvent.pressure]：系统内存压力（onTrimMemory），应释放缓存
  /// - [MemoryEvent.trim]：金标联盟内存预警（itgsa.intent.action.TRIM），应释放图片/HTTP 缓存
  /// - [MemoryEvent.kill]：金标联盟应用查杀（itgsa.intent.action.KILL），应立即释放所有资源
  ///
  /// 订阅后本 Provider 会自动执行默认的内存清理（清空图片缓存和 HTTP 缓存），
  /// 订阅者可额外响应（如清空业务缓存、保存未提交数据等）。
  Stream<MemoryEvent> get memoryEventStream {
    _ensureInitialized();
    return _memoryController!.stream;
  }

  void _ensureInitialized() {
    if (_controller != null) return;
    _controller = StreamController<AppLifecycleState>.broadcast();
    _memoryController = StreamController<MemoryEvent>.broadcast();
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
                _handleMemoryEvent(MemoryEvent.pressure);
                break;
              case 'memory_trim':
                _handleMemoryEvent(MemoryEvent.trim);
                break;
              case 'memory_kill':
                _handleMemoryEvent(MemoryEvent.kill);
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

  /// 处理内存事件：执行默认清理 + 推送给订阅者
  void _handleMemoryEvent(MemoryEvent event) {
    // 1. 默认清理：清空图片缓存和 HTTP 缓存
    _performDefaultCleanup(event);
    // 2. 推送给订阅者，让业务方额外响应
    _memoryController?.add(event);
  }

  /// 默认内存清理：根据事件类型释放对应资源
  ///
  /// - pressure/trim：清空图片缓存 + HTTP 缓存（可快速恢复，降低内存占用）
  /// - kill：清空所有缓存 + 立即释放图片缓存（应用即将被杀，尽力释放）
  void _performDefaultCleanup(MemoryEvent event) {
    try {
      // 清空 Flutter 图片缓存（ImageCache 内部持有已解码图片，占用大量内存）
      PaintingBinding.instance.imageCache.clear();
      // 清空 HTTP 响应缓存（每个账号一份，全部清空）
      HttpCache.clearAll();
      switch (event) {
        case MemoryEvent.kill:
          // 应用查杀：强制立即释放图片缓存（evict 已解码的图片）
          PaintingBinding.instance.imageCache.clearLiveImages();
          break;
        case MemoryEvent.pressure:
        case MemoryEvent.trim:
          // 内存压力/预警：清空缓存即可，无需额外操作
          break;
      }
    } catch (_) {
      // 清理过程中任何异常都忽略，避免影响订阅者
    }
  }

  /// 释放资源（仅在应用退出时调用，通常不需要手动调用）
  void dispose() {
    _platformSub?.cancel();
    _platformSub = null;
    _controller?.close();
    _controller = null;
    _memoryController?.close();
    _memoryController = null;
  }
}
