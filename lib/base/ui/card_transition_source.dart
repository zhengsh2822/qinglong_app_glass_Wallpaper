import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 卡片共享转场源（demo PageTransitionSource 的主项目版）。
///
/// 包住真实可见卡片（含玻璃材质与描边）：
/// 1. 点击时捕获卡片全局矩形（GlobalKey，精确到视觉卡片外框）；
/// 2. 隐藏真实卡片，同时以卡片内容（不含玻璃材质）作为源内容
///    push [WallpaperPageRoute]——容器首帧与卡片像素一致，从卡片
///    连续展开成整页，而不是在卡片上方盖一层深色面板；
/// 3. 返回时容器收回卡片矩形，源内容淡回，路由移除后恢复真实卡片。
///
/// 注意：卡片内部的 InkWell 需保留编辑模式等本地点击分支
/// （命中测试叶子优先，内层有 onTap 时内层赢出手势仲裁），
/// 非编辑模式下内层 onTap 置 null，点击即由本组件接管。
class CardTransitionSource extends StatefulWidget {
  const CardTransitionSource({
    super.key,
    required this.child,
    required this.sourceBuilder,
    required this.pageBuilder,
    this.blurSigma,
    this.blurTintColor,
    this.onResult,
  });

  /// 真实可见卡片（含玻璃材质与描边）；转场展开期间被隐藏。
  final Widget child;

  /// 卡片内容（不含玻璃材质与描边），容器内首帧绘制；
  /// 布局必须与卡片内部一致，否则首帧会跳变。
  final WidgetBuilder sourceBuilder;

  /// 目标页面。
  final WidgetBuilder pageBuilder;

  /// 目标页壁纸模糊覆盖（与该入口原 push 参数一致；null 用全局默认）。
  final double? blurSigma;
  final Color? blurTintColor;

  /// 路由 pop 结果回调（详情页删除成功 pop(true) 刷新列表等）。
  final void Function(Object?)? onResult;

  @override
  State<CardTransitionSource> createState() => _CardTransitionSourceState();
}

class _CardTransitionSourceState extends State<CardTransitionSource> {
  final GlobalKey _key = GlobalKey();
  bool _opening = false;

  void _open() {
    if (_opening) return;

    final RenderBox? box =
        _key.currentContext?.findRenderObject() as RenderBox?;
    final Rect? rect =
        (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero) & box.size
            : null;

    // 卡片内容快照：隐藏真实卡片前构建，与卡片内部布局保持一致。
    final Widget sourceChild = widget.sourceBuilder(context);

    HapticFeedback.lightImpact();
    setState(() => _opening = true);

    Navigator.of(context)
        .push(
          WallpaperPageRoute(
            builder: (context) => widget.pageBuilder(context),
            blurSigma: widget.blurSigma,
            blurTintColor: widget.blurTintColor,
            // 布局未完成时退化为普通容器转场（无精确来源，不画源内容）
            sourceRect: rect,
            sourceChild: rect == null ? null : sourceChild,
            sourceRadius: 18,
            sourceBlurSigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
            sourceHighlightOpacity: 0.06,
            sourceBorderColor: CyberColors.cardStroke,
          ),
        )
        .then((value) {
          widget.onResult?.call(value);
        })
        .whenComplete(() {
          if (mounted) {
            setState(() => _opening = false);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: IgnorePointer(
        ignoring: _opening,
        child: Opacity(opacity: _opening ? 0 : 1, child: widget.child),
      ),
    );
  }
}
