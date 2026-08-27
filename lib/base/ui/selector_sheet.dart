import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/glow_sheet.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 通用底部弹窗选择器（可复用组件）
///
/// 用于替代原生 DropdownButtonFormField 等"顶部下拉"控件，
/// 从底部弹出（showModalBottomSheet），风格对齐：
/// - 选择通知方式弹窗（push_setting_page）
/// - 脚本目录选择弹窗（upload_script_widget）
///
/// 设计规范（对齐项目毛玻璃弹窗语言）：
/// - 顶部 40x4 圆角拖拽条
/// - 标题栏 + 右上角关闭按钮
/// - 弹窗容器：OptimizedFrostedGlass + forceOpaqueSolid（100% 纯色，不跟随
///   卡片纯色调节），cyber 青色发光边框 / 其他浅灰边框
/// - 选项列表最大高度 = 屏幕高 * 0.55，超出可滚动
/// - 选中项：主色文字 + 右侧对勾 + 行背景微色
/// - 标题与列表项字重跟随全局粗细调节（spTextFontWeight）
class SelectorOption<T> {
  final T value;
  final String label;
  final String? subtitle;

  const SelectorOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

/// 显示通用底部弹窗选择器
///
/// 弹出后用户选择一个 [SelectorOption.value]，通过 [onSelected] 回调。
/// 如果用户点击空白/关闭按钮，弹窗关闭但 [onSelected] 不会触发。
Future<void> showSelectorSheet<T>({
  required BuildContext context,
  required String title,
  required List<SelectorOption<T>> options,
  required T? selectedValue,
  required ValueChanged<T> onSelected,
}) async {
  // 同步读取主题状态（在弹窗弹出前一次性读取，避免异步内 ref 失效）
  final container = ProviderScope.containerOf(context);
  final themeModel = container.read(themeProvider);
  final bool isCyber = themeModel.themeMode == modeCyber;
  // 弹窗字重跟随全局粗细调节（弹窗为瞬时场景，打开时读取一次）
  final FontWeight fw = FontWeight(container.read(textWeightProvider));
  final Color accent = isCyber ? CyberColors.cyan : AppleColors.accent;
  final Color dividerColor =
      isCyber ? const Color(0x22FFFFFF) : const Color(0xFFE5E5EA);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlowSheetContainer(
          isCyber: isCyber,
          child: OptimizedFrostedGlass(
            sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
            borderRadius: BorderRadius.circular(18),
            forceOpaqueSolid: true,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: isCyber
                          ? CyberColors.cyan.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: fw,
                            color: isCyber ? CyberColors.cyan : AppleColors.textPrimary,
                            fontFamily: 'MiSans',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 22,
                          color: isCyber
                              ? CyberColors.titleWhite.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 0.5, color: dividerColor),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final selected = option.value == selectedValue;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelected(option.value);
                        },
                        child: Container(
                          color: selected
                              ? accent.withValues(alpha: 0.08)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: fw,
                                        color: selected
                                            ? accent
                                            : (isCyber
                                                ? CyberColors.titleWhite
                                                : AppleColors.textPrimary),
                                        fontFamily: 'MiSans',
                                      ),
                                    ),
                                    if (option.subtitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        option.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isCyber
                                              ? CyberColors.descColor
                                              : AppleColors.textSecondary,
                                          fontFamily: 'MiSans',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  CupertinoIcons.checkmark_alt,
                                  size: 18,
                                  color: accent,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    },
  );
}

/// 弹窗选择器触发卡片
///
/// 整张卡显示当前选中值的文字，点击后弹出 [showSelectorSheet] 让用户重新选择。
/// 圆角与其他卡片一致（18），与下拉框外观区分。
class SelectorFieldCard extends ConsumerWidget {
  final String hintText;
  final String currentValue;
  final String emptyHint;
  final VoidCallback onTap;

  const SelectorFieldCard({
    super.key,
    required this.hintText,
    required this.currentValue,
    required this.emptyHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    // 字重跟随全局粗细调节
    final FontWeight fw = FontWeight(ref.read(textWeightProvider));
    final String displayText = currentValue.isEmpty ? emptyHint : currentValue;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: fw,
                  // 选择器当前显示值：非空时跟随主字体色，空值占位跟随次字体色
                  color: currentValue.isEmpty
                      ? ref.watch(themeProvider).themeColor.descColor()
                      : ref.watch(themeProvider).themeColor.titleColor(),
                  fontFamily: 'MiSans',
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: isCyber ? CyberColors.cyan : null,
            ),
          ],
        ),
      ),
    );
  }
}