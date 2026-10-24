import 'package:flutter/widgets.dart';

/// 共享容器转场内的通用页面入场效果。
///
/// 账号页这类多区块页面可以用自己的错峰动画；对于登录页等整页内容，
/// 直接使用本组件即可获得统一的「淡入 + 轻微上移」衔接，避免每个页面
/// 重复写 AnimationBuilder。
///
/// [animation] 必须是 [ContainerTransformRoute] 传入的路由动画；
/// 反向播放时自动倒放，页面先退场，容器再收回源卡片。
class SharedPageEntrance extends StatelessWidget {
  const SharedPageEntrance({
    super.key,
    required this.animation,
    required this.child,
    this.start = 0.30,
    this.end = 0.72,
    this.offsetY = 18,
  });

  final Animation<double> animation;
  final Widget child;
  final double start;
  final double end;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final double progress = Interval(
          start,
          end,
          curve: Curves.easeOutCubic,
        ).transform(animation.value);
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
