import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 整页切换 · 弹簧轨道（S1 · 纯盖上，demos/nav_tab_spring_demo 验收选型）
///
/// 页面位移完全跟随 [position]（底部导航胶囊 / 顶部分段胶囊的 travel 弹簧
/// 连续位置，胶囊是唯一物理源）——页面与滑块同一物理，天然像素级同步：
/// 点击、连点打断（胶囊弹簧保留速度）、长按拖拽跟手，全部一致。
///
/// 视觉规则（S1 · 纯盖上，用户选型 2026-10-25）：进入页（[current]）全尺寸
/// 盖在最上层，离开页**原样**沉底被盖——零缩放、零变暗、零投影，
/// 层次感只来自运动遮挡。曾试验过 缩小/变暗/渐隐 均被否（浅色主题显灰带）。
class SpringDepthPageTrack extends StatefulWidget {
  const SpringDepthPageTrack({
    super.key,
    required this.position,
    required this.current,
    required this.children,
  });

  /// 连续页位置（0..n-1），来自胶囊/滑块的 travel 弹簧
  final ValueListenable<double> position;

  /// 当前提交的目标页索引（决定层级、变暗豁免与 TickerMode）
  final int current;

  final List<Widget> children;

  @override
  State<SpringDepthPageTrack> createState() => _SpringDepthPageTrackState();
}

class _SpringDepthPageTrackState extends State<SpringDepthPageTrack> {
  /// 惰性挂载：与 PageView 行为对齐（首次成为目标才构建），
  /// 挂载后常驻（Stack 天然保活，滚动位置不丢）
  final Set<int> _mountedPages = {};

  @override
  void initState() {
    super.initState();
    _mountedPages.add(widget.current.clamp(0, widget.children.length - 1));
  }

  @override
  void didUpdateWidget(covariant SpringDepthPageTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current != oldWidget.current) {
      _mountedPages.add(widget.current.clamp(0, widget.children.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.children.isNotEmpty);
    final int current = widget.current.clamp(0, widget.children.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        return ListenableBuilder(
          listenable: widget.position,
          builder: (context, _) {
            final double x = widget.position.value;
            final List<Widget> slots = <Widget>[];
            for (int i = 0; i < widget.children.length; i++) {
              if (i != current) {
                slots.add(_slot(i, x, w, false));
              }
            }
            // 目标页放最后 → Stack 画在最上层（进入页永远盖住离开页）
            slots.add(_slot(current, x, w, true));
            return Stack(children: slots);
          },
        );
      },
    );
  }

  Widget _slot(int i, double x, double w, bool isTarget) {
    final double d = (i - x).toDouble();
    Widget page = _mountedPages.contains(i)
        ? TickerMode(
            enabled: isTarget,
            child: RepaintBoundary(child: widget.children[i]),
          )
        : const SizedBox.expand();

    // 离开页原样沉底被盖（S1 零修饰）；大半出屏后不再接收点击
    if (!isTarget && d.abs() > 0.5) {
      page = IgnorePointer(child: page);
    }

    return Positioned.fill(
      key: ValueKey<int>(i),
      child: Transform.translate(offset: Offset(d * w, 0), child: page),
    );
  }
}
