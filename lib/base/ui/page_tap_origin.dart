import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qinglong_app/utils/ql_debug_log.dart';

/// 最后一次点击的来源（点 + 命中的卡片矩形）。
class TapOriginData {
  const TapOriginData({this.point, this.rect});

  final Offset? point;
  final Rect? rect;
}

/// 全局点击来源缓存。
///
/// 页面 push 前由 [PageTapScope] 记录；WallpaperPageRoute 构造时读取。
/// 超过 1.5 秒视为过期（程序化跳转 / 网络回调），使用屏幕中心兜底。
class PageTapOrigin {
  static Offset? _point;
  static Rect? _rect;
  static DateTime? _time;

  static void record(Offset point, Rect? rect) {
    _point = point;
    _rect = rect;
    _time = DateTime.now();
  }

  static TapOriginData? get lastFresh {
    final DateTime? time = _time;
    if (time == null) return null;
    if (DateTime.now().difference(time) > const Duration(milliseconds: 1500)) {
      return null;
    }
    return TapOriginData(point: _point, rect: _rect);
  }
}

/// 根部监听点击，并用命中测试推断「被点的视觉卡片」矩形。
///
/// 识别优先级（命中路径叶子在前，`??=` 保留最深的一个）：
/// 1. [RenderClipRRect]：GlassCard/OptimizedFrostedGlass 的毛玻璃裁切边，
///    即卡片真实外框（含 padding、不含 margin）；
/// 2. 带圆角的 [RenderDecoratedBox]：卡片内衬/圆角行，与卡片外框同界；
/// 3. 兜底：尺寸像卡片/行的最小面积矩形；
/// 4. 都没有（点在空白处）→ 返回 null，路由回退到点击点 64x64 圆角源。
///
/// 尺寸门槛用于排除头像/图标等小圆角裁切与整页容器：
/// 宽 ≥45% 屏宽且 ≤98.5%，高 ≥48 且 ≤55% 屏高。
class PageTapScope extends StatelessWidget {
  const PageTapScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int viewId = View.of(context).viewId;
    final Size screen = MediaQuery.sizeOf(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        Rect? detected;
        try {
          detected = _detectCardRect(event.position, viewId, screen);
        } catch (error, stack) {
          QlDebugLog.write('QLLOG TapScope detect ERROR: $error\n$stack');
        }
        QlDebugLog.write(
          'QLLOG TapScope down pos=${event.position} rect=$detected',
        );
        PageTapOrigin.record(event.position, detected);
      },
      child: child,
    );
  }

  static Rect? _detectCardRect(Offset position, int viewId, Size screen) {
    final HitTestResult result = HitTestResult();
    RendererBinding.instance.hitTestInView(result, position, viewId);

    final double minW = screen.width * 0.45;
    final double maxW = screen.width * 0.985;
    final double maxH = screen.height * 0.55;
    const double minH = 48;

    bool cardLike(Size size) {
      return size.width >= minW &&
          size.width <= maxW &&
          size.height >= minH &&
          size.height <= maxH;
    }

    Rect? clipCard;
    Rect? decoratedCard;
    Rect? anyBox;

    for (final HitTestEntry entry in result.path) {
      final target = entry.target;
      if (target is! RenderBox || !target.attached || !target.hasSize) {
        continue;
      }
      final Size size = target.size;
      if (size.width <= 0 || size.height <= 0) continue;

      if (target is RenderClipRRect &&
          target.borderRadius != BorderRadius.zero &&
          cardLike(size)) {
        clipCard ??= target.localToGlobal(Offset.zero) & size;
        continue;
      }

      if (target is RenderDecoratedBox) {
        final Decoration decoration = target.decoration;
        final BorderRadiusGeometry? radius =
            decoration is BoxDecoration ? decoration.borderRadius : null;
        if (radius != null && cardLike(size)) {
          decoratedCard ??= target.localToGlobal(Offset.zero) & size;
          continue;
        }
      }

      // 兜底候选：排除整页容器后取最宽矩形（整行/整条区域优先——行内的
      // 两行文本等窄盒子不应成为展开来源）；同宽取面积最小（最内层）。
      if (size.width >= 120 && size.width <= maxW && size.height <= maxH) {
        final Rect rect = target.localToGlobal(Offset.zero) & size;
        if (rect.height >= 40) {
          if (anyBox == null ||
              rect.width > anyBox.width + 0.5 ||
              ((rect.width - anyBox.width).abs() <= 0.5 &&
                  rect.width * rect.height < anyBox.width * anyBox.height)) {
            anyBox = rect;
          }
        }
      }
    }

    return clipCard ?? decoratedCard ?? anyBox;
  }
}
