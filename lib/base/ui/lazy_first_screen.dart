import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_first_launch_state.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';

/// 分两阶段加载：动画期间渲染简化的第一屏骨架（占位），动画完成后切换为真实内容。
///
/// 用途：解决"进入含大量 GlassCard 的二级页面（订阅管理/依赖管理/App功能介绍）
/// 进退动画掉帧"问题。push 动画期间不挂载真实列表/卡片，paint 链路过重
/// 仍会触发 BackdropFilter 重算。改为：
/// - 阶段 1（forward 动画期间）：渲染骨架占位（极轻量），避开真实内容 paint
/// - 阶段 2（forward 完成后）：挂载真实 child，正常渲染（含实时毛玻璃）
/// - reverse 期间：保持显示真实 child（让用户看到完整页面反向滑出，无视觉跳变）
///
/// **App 首次启动特判**：cold start 后的第一个 push 路由会绕过骨架动画，
/// 直接显示 child 自身的网络 loading（更真实，避免叠加）。后续 push 全部启用骨架。
/// 详见 [AppFirstLaunchState]。
///
/// 仅在三个掉帧页面（订阅管理/依赖管理/App功能介绍）使用，其他页面不受影响。
class LazyFirstScreen extends StatefulWidget {
  final Widget child;

  /// 阶段 1 渲染的占位（建议使用 [FirstScreenSkeleton] 通用骨架）。
  final Widget placeholder;

  const LazyFirstScreen({
    super.key,
    required this.child,
    required this.placeholder,
  });

  @override
  State<LazyFirstScreen> createState() => _LazyFirstScreenState();
}

class _LazyFirstScreenState extends State<LazyFirstScreen> {
  Animation<double>? _anim;
  bool _listenerAttached = false;
  bool _showReal = false;

  /// 是否绕过骨架（直接显示 child）。App 首次启动后的第一个 push
  /// 页面会绕过骨架，避免和页面自身的网络 loading 动画叠加。
  /// 后续 push 全部启用骨架模拟加载动画。
  bool _bypassSkeleton = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听当前 ModalRoute 的 animation 状态。
    // 只对当前路由的动画负责——下层路由不会被错误触发。
    if (!_listenerAttached) {
      final route = ModalRoute.of(context);
      if (route != null) {
        _anim = route.animation;
        _anim!.addStatusListener(_onStatus);
        _listenerAttached = true;
        // App cold start 后的首次 push：跳过骨架动画，避免和 child 自身的
        // 网络 loading 动画叠加，更真实。同时消耗"首次"标志。
        if (AppFirstLaunchState.isFirstLaunch.value) {
          _bypassSkeleton = true;
          _showReal = true;
          AppFirstLaunchState.markNotFirstLaunch();
        } else {
          // 立即按当前状态初始化（处理 animation 直接是 completed 的边界情况）
          _onStatus(_anim!.status);
        }
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.forward) {
      // push 入场开始：显示占位
      if (_showReal) {
        setState(() => _showReal = false);
      }
    } else if (status == AnimationStatus.completed) {
      // push 入场完成：显示真实内容
      if (!_showReal) {
        setState(() => _showReal = true);
      }
    }
    // reverse 期间保持 _showReal = true：pop 时用户已看到完整内容，
    // 让真实页面反向滑出（无视觉跳变），dismissed 时组件 dispose
  }

  @override
  void dispose() {
    if (_listenerAttached) {
      _anim?.removeStatusListener(_onStatus);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 首次启动后的第一个 push：直接显示 child，绕开骨架动画
    if (_bypassSkeleton) return widget.child;
    return _showReal ? widget.child : widget.placeholder;
  }
}

/// 通用第一屏骨架占位（与真实 loading 视觉一致：AppBar + 居中 LoadingWidget）。
///
/// 设计：
/// - AppBar 真实渲染（标题+返回按钮即时可见，和真实 loading 期间一致）
/// - body 居中显示 [LoadingWidget]（staggeredDotsWave 小竖条波动动画）
///   视觉上和"页面自身网络请求 loading"完全一致 —— 用户分不清"动画期间"和
///   "数据加载中"，最自然的过渡
/// - 依靠路由级 WallpaperBackground 的 cacheBlur 提供模糊背景（和真实 loading 一样）
/// - LoadingWidget 自带 RepaintBoundary 隔离无限循环动画，不触发父级重绘
/// - 极轻量：单个动画 widget + AppBar，paint 几乎无开销
class FirstScreenSkeleton extends StatelessWidget {
  final String title;

  const FirstScreenSkeleton({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(title: title, canBack: true),
      body: RepaintBoundary(
        child: const Center(child: LoadingWidget()),
      ),
    );
  }
}
