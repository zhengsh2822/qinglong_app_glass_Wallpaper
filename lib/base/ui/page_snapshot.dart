import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 路由级整页一次性快照（动画期间非实时模糊兜底）。
///
/// 用途：路由 push/pop 动画期间，把整个页面截成一张静态位图显示，
/// 动画期间 setState 触发的子组件 rebuild 不再走 BackdropFilter/GPU 模糊，
/// 直接走 RawImage 叶子节点 → 整页 paint 链路大幅简化，掉帧场景流畅度提升。
///
/// ## 关键设计：监听自己的 animation.status（不是全局）
/// 每个路由只对自己的动画负责。push/pop B 时，下层路由 A 仍在路由栈
/// 但 A 的 animation 已 completed/未在动画，**不会被错误触发截图**，
/// 避免出现"下层页面突然变模糊再恢复"的视觉问题。
/// 之前用全局计数器会有这个 bug：所有路由的 PageSnapshot 都被 inTransition
/// 触发，下层页面也跟着截图/释放。
///
/// 视觉：动画期间整页静止（已是模糊结果，视觉无感知），动画结束恢复真实渲染。
class PageSnapshot extends StatefulWidget {
  final Widget child;

  /// 当前路由的 Animation（由 WallpaperPageRoute.buildPage 传入）。
  /// 监听这个 animation 的 status 决定截屏时机，不监听全局。
  final Animation<double> animation;

  const PageSnapshot({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  State<PageSnapshot> createState() => _PageSnapshotState();
}

class _PageSnapshotState extends State<PageSnapshot> {
  // 全局唯一 RepaintBoundary key，整页截图定位。
  final GlobalKey _boundaryKey = GlobalKey();
  ui.Image? _snapshot;
  bool _captureInProgress = false;
  bool _inTransition = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    // forward = push 入场，reverse = pop 离场，两种都需要截屏
    final v = status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (v && !_inTransition) {
      _inTransition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
    } else if (!v && _inTransition) {
      // completed/dismissed：动画结束，释放快照
      _inTransition = false;
      if (mounted && _snapshot != null) {
        setState(() {
          _snapshot?.dispose();
          _snapshot = null;
        });
      }
    }
  }

  Future<void> _capture() async {
    if (_captureInProgress || !mounted || !_inTransition) return;
    _captureInProgress = true;
    try {
      // 等一帧确保子 page 已完整渲染（含 BackdropFilter 输出）
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_inTransition || _snapshot != null) return;
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      // 0.3 pixelRatio 降采样（整页截图）
      final image = await boundary.toImage(pixelRatio: 0.3);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _snapshot = image);
    } finally {
      _captureInProgress = false;
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: _snapshot != null
          // 整页静态位图：动画期间所有子 setState 都不再走 paint
          ? RawImage(
              image: _snapshot,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            )
          : widget.child,
    );
  }
}
