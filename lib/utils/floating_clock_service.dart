import 'package:flutter/services.dart';

/// 悬浮时钟服务 — 通过 MethodChannel 与 Android 原生 WindowManager 通信
/// 移植自 floating_clock 项目，集成到青龙客户端
class FloatingClockService {
  static const MethodChannel _channel =
      MethodChannel('com.qlapp.qinglong_app/floating_clock');

  /// 检查是否有悬浮窗权限
  static Future<bool> canDrawOverlays() async {
    try {
      final bool result = await _channel.invokeMethod('canDrawOverlays');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// 请求悬浮窗权限（跳转系统设置）
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException {}
  }

  /// 启动悬浮时钟
  static Future<void> startFloating() async {
    try {
      await _channel.invokeMethod('startFloating');
    } on PlatformException {}
  }

  /// 停止悬浮时钟
  static Future<void> stopFloating() async {
    try {
      await _channel.invokeMethod('stopFloating');
    } on PlatformException {}
  }

  /// 切换悬浮时钟：有权限则启动，无权限则请求权限
  /// 返回 true 表示已启动，false 表示需要先授予权限
  static Future<bool> toggleFloating() async {
    final bool hasPermission = await canDrawOverlays();
    if (!hasPermission) {
      await requestOverlayPermission();
      return false;
    }
    try {
      await startFloating();
      return true;
    } catch (e) {
      return false;
    }
  }
}
