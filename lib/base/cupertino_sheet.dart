import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glow_sheet.dart';
import 'package:qinglong_app/base/ui/spring_sheet.dart';

/// 底部操作弹层操作项
///
/// 新设计：文案水平居中（危险项红色系）；
/// [showDivider] 由弹层传入控制项之间分隔线（最后一项不显示）。
class CupertinoSheer extends ConsumerWidget {
  final String title;
  final GestureTapCallback onTap;

  /// 危险项（删除等）：文字红色系
  final bool danger;

  /// 是否在项下方显示分隔线（弹层内部自动控制）
  final bool showDivider;

  const CupertinoSheer({
    Key? key,
    required this.title,
    required this.onTap,
    this.danger = false,
    this.showDivider = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    // 提示色统一走 primaryColor（赛博模式下返回 cyan），参与主题切换颜色过渡
    final Color accent = ref.watch(themeProvider).primaryColor;
    final Color textColor =
        isCyber ? CyberColors.titleWhite : const Color(0xFF1A1A1A);
    final Color dividerColor =
        isCyber ? const Color(0x22FFFFFF) : const Color(0xFFE5E5EA);
    final Color actionColor =
        danger
            ? (isCyber ? CyberColors.neonRed : const Color(0xFFFF3B30))
            : accent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
              onTap();
            },
            child: SizedBox(
              height: 58,
              width: double.infinity,
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: danger ? actionColor : textColor,
                    // 跟随全局字体粗细（四档 400/500/600/700），与列表卡片统一
                    fontWeight: FontWeight(ref.watch(textWeightProvider)),
                  ),
                ),
              ),
            ),
          ),
        ),
        // 分隔线只出现在项之间，最后一项下方不显示；左右对称居中
        if (showDivider)
          Divider(height: 0.5, indent: 60, endIndent: 60, color: dividerColor),
      ],
    );
  }
}

/// 分隔线（兼容旧调用：新弹层会自动在操作项之间加对称分隔线，此函数产物会被弹层过滤）
Widget addDivider() {
  return Consumer(
    builder: (context, ref, _) {
      final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
      if (isCyber) {
        return Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: CyberColors.borderGlow.withValues(alpha: 0.25),
        );
      }
      return const Divider(height: 0.5);
    },
  );
}

void showMoreOperate(BuildContext context, List<Widget> list) {
  final bool isCyber =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeCyber;

  // 统一走弹簧弹层：弹出 / 关闭 / 拖拽松手 / 中途打断
  // 与其它底部弹层共用同一组数值（见 SpringSheetSpec），不再各页各写
  showSpringSheet<void>(
    context: context,
    builder: (ctx) => _buildSheet(ctx, list, isCyber: isCyber),
  );
}

/// 构建底部弹层：主列表 + 独立取消胶囊
Widget _buildSheet(
  BuildContext context,
  List<Widget> list, {
  required bool isCyber,
}) {
  // 过滤出操作项（兼容旧 addDivider() 调用，弹层自动在项之间加对称分隔线）
  final List<CupertinoSheer> items = list.whereType<CupertinoSheer>().toList();
  final Color textColor =
      isCyber ? CyberColors.titleWhite : const Color(0xFF1A1A1A);
  final Color dividerColor =
      isCyber ? const Color(0x22FFFFFF) : const Color(0xFFE5E5EA);
  // 弹层内所有文案跟随全局字体粗细（与 CupertinoSheer 操作项一致）
  final FontWeight globalFw = FontWeight(
    ProviderScope.containerOf(context).read(textWeightProvider),
  );

  return SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主列表
          GlowSheetContainer(
            isCyber: isCyber,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DragHandle(isCyber: isCyber),
                Divider(height: 0.5, color: dividerColor),
                ...items.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final CupertinoSheer item = entry.value;
                  return CupertinoSheer(
                    title: item.title,
                    onTap: item.onTap,
                    danger: item.danger,
                    showDivider: index != items.length - 1,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 取消按钮（独立胶囊，与列表分离）；SpringSheetTrailing 让它比主卡片略滞后
          SpringSheetTrailing(
            child: GlowSheetContainer(
              isCyber: isCyber,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: globalFw,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
