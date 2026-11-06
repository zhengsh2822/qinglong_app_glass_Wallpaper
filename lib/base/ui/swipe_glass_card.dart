import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/app_corner.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slidable.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 单条滑动操作（语义化描述，由 [SwipeGlassCard] 决定赛博/普通样式）
class SwipeActionSpec {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// 赛博模式背景色（同时作为普通模式默认色）
  final Color color;

  /// 普通模式背景色（null 时使用 [color]）
  final Color? normalColor;

  /// 普通模式标签（null 时使用 [label]）
  final String? normalLabel;

  /// 普通模式图标（null 时使用 [icon]）
  final IconData? normalIcon;

  /// 普通模式是否显示文字（账号卡片删除按钮只显示图标）
  final bool showNormalLabel;

  const SwipeActionSpec({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
    this.normalColor,
    this.normalLabel,
    this.normalIcon,
    this.showNormalLabel = true,
  });
}

/// 统一「毛玻璃卡片 + 滑动操作」组件。
///
/// 固定层级（解决"按钮跑到卡片外"的根因）：
/// ```text
/// Container(margin)
///  └ OptimizedFrostedGlass（静态毛玻璃外壳）
///     └ Container（静态描边/置顶描边）
///        └ ClipRRect（同时裁剪内容与 ActionPane）
///           └ CyberSlidable / Slidable（只滑内容）
///              └ child（纯内容，不能再自带毛玻璃/描边）
/// ```
///
/// 赛博主题使用 [CyberSlidable] 的独立胶囊按钮；普通主题使用
/// [AppSlideButton] 等分按钮。调用方只提供内容与动作数据，不再各页
/// 手写外壳/圆角/裁剪，避免再次出现"修一页漏五页"。
class SwipeGlassCard extends ConsumerWidget {
  final Widget child;
  final List<SwipeActionSpec> startActions;
  final List<SwipeActionSpec> endActions;
  final Key? slidableKey;
  final bool enabled;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double sigma;

  /// 强制模式；null 时跟随主题（赛博主题走 CyberSlidable）
  final bool? isCyber;

  /// 是否置顶；配合 [highlightPinned] 使用
  final bool isPinned;

  /// 置顶时描边高亮（定时任务页专属）
  final bool highlightPinned;

  /// 普通模式 extentRatio 覆盖；null 时按按钮数自动计算
  final double? normalExtentRatio;

  /// 普通模式按钮圆角
  final double normalButtonRadius;

  /// 圆角曲线类型（默认连续曲率 G2）
  final AppCornerStyle cornerStyle;

  const SwipeGlassCard({
    super.key,
    required this.child,
    this.startActions = const [],
    this.endActions = const [],
    this.slidableKey,
    this.enabled = true,
    this.margin = const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
    this.radius = AppleColors.radiusCard,
    this.sigma = 4,
    this.isCyber,
    this.isPinned = false,
    this.highlightPinned = false,
    this.normalExtentRatio,
    this.normalButtonRadius = 10,
    this.cornerStyle = AppCornerStyle.continuous,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool cyber =
        isCyber ?? (ref.watch(themeProvider).themeMode == modeCyber);
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final double effectiveSigma = SpUtil.getDouble(
      spCardBlurSigma,
      defValue: sigma,
    );
    final bool pinnedHighlight = highlightPinned && isPinned;
    final ShapeBorder shape = appCornerBorder(
      borderRadius: borderRadius,
      style: cornerStyle,
      side: BorderSide(
        color:
            pinnedHighlight
                ? CyberColors.cyan.withValues(alpha: 0.85)
                : CyberColors.cardStroke,
        width: pinnedHighlight ? 1.2 : 1,
      ),
    );

    final Widget slidable =
        cyber
            ? CyberSlidable(
              slidableKey: slidableKey,
              enabled: enabled,
              borderRadius: radius,
              startActions: _toCyberActions(startActions),
              endActions: _toCyberActions(endActions),
              child: child,
            )
            : Slidable(
              key: slidableKey,
              enabled: enabled,
              startActionPane: _buildNormalPane(context, startActions),
              endActionPane: _buildNormalPane(context, endActions),
              child: child,
            );

    return Container(
      margin: margin,
      child: OptimizedFrostedGlass(
        sigma: effectiveSigma,
        // 与「我的」页 GlassCard 一致：全透明仅保留模糊，
        // 不再叠加默认 15% 白膜，避免列表卡片比其它卡片偏白
        tintColor: Colors.transparent,
        borderRadius: borderRadius,
        cornerStyle: cornerStyle,
        child: Container(
          decoration: ShapeDecoration(shape: shape),
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: appCornerBorder(radius: radius - 1, style: cornerStyle),
            ),
            child: slidable,
          ),
        ),
      ),
    );
  }

  List<CyberSlideAction> _toCyberActions(List<SwipeActionSpec> actions) {
    return actions
        .map(
          (a) => CyberSlideAction(
            label: a.label,
            icon: a.icon,
            color: a.color,
            onTap: a.onTap,
          ),
        )
        .toList();
  }

  ActionPane? _buildNormalPane(
    BuildContext context,
    List<SwipeActionSpec> actions,
  ) {
    if (actions.isEmpty) return null;
    final double extentRatio =
        normalExtentRatio ?? (actions.length * 0.18).clamp(0.2, 0.9);
    return ActionPane(
      motion: const ScrollMotion(),
      extentRatio: extentRatio,
      children:
          actions
              .map(
                (a) => AppSlideButton(
                  context: context,
                  color: a.normalColor ?? a.color,
                  icon: a.normalIcon ?? a.icon,
                  onTap: a.onTap,
                  label: a.showNormalLabel ? (a.normalLabel ?? a.label) : null,
                  cyberMode: false,
                  width: double.infinity,
                  cornerRadius: normalButtonRadius,
                ),
              )
              .toList(),
    );
  }
}
