import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glow_card.dart';

/// 设置页通用可复用组件集合
///
/// 统一项目中重复出现的设置页 UI 模式：
/// - [SettingsCard] 设置分组卡片容器（高光内发光毛玻璃）
/// - [SettingsSwitchRow] 带开关的设置行
/// - [SettingsTapRow] 带尾部内容的可点击设置行
/// - [SectionHeader] 分区标题
/// - [settingsDivider] 设置行间分隔线

/// 设置分组卡片容器（高光内发光毛玻璃）
///
/// 使用 [CapsuleGlowCard] 实现毛玻璃模糊（壁纸透出）+ 高光内发光效果
/// （对齐主题版新高光卡片设计）。默认 margin 为 `EdgeInsets.symmetric(horizontal: 15)`，
/// 圆角 18 与全项目卡片统一。
class SettingsCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const SettingsCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CapsuleGlowCard(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 15),
      padding: padding,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: child,
    );
  }
}

/// 分区标题
///
/// 统一 `descColor()` + `fontSize: 12` 样式。
/// 默认 padding 为 `EdgeInsets.only(left: 30)`。
class SectionHeader extends ConsumerWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(left: 30),
      child: Text(
        title,
        style: TextStyle(
          color: ref.watch(themeProvider).themeColor.descColor(),
          fontSize: 12,
        ),
      ),
    );
  }
}

/// 设置行间分隔线
///
/// 统一 `Divider(indent: 55, height: 1)` 样式。
const Widget settingsDivider = Divider(indent: 55, height: 1);

/// 带开关的设置行
///
/// 统一 `[Icon(20)] + Text(16) + Transform.scale(0.9) + CupertinoSwitch` 样式。
/// [icon] 为 null 时不显示图标（适用于 icloud_page 等无图标场景）。
/// 自动使用 `primaryColor` 作为图标和开关颜色。
class SettingsSwitchRow extends ConsumerWidget {
  final IconData? icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// 标题右侧的自定义 widget（如帮助按钮）
  final Widget? trailing;

  const SettingsSwitchRow({
    super.key,
    this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: ref.watch(themeProvider).primaryColor,
              size: 20,
            ),
            const SizedBox(width: 15),
          ],
          Text(
            title,
            style: TextStyle(
              color: ref.watch(themeProvider).themeColor.titleColor(),
              fontSize: 16,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 5),
            trailing!,
          ],
          const Spacer(),
          Transform.scale(
            scale: 0.9,
            child: CupertinoSwitch(
              activeColor: ref.watch(themeProvider).primaryColor,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 带尾部内容的可点击设置行
///
/// 统一 `[Icon(20)] + Text(16) + trailing` 样式。
/// [icon] 为 null 时不显示图标。
/// [trailing] 默认为右箭头，可自定义为任意 widget（如版本号文本）。
class SettingsTapRow extends ConsumerWidget {
  final IconData? icon;
  final String title;
  final VoidCallback? onTap;

  /// 尾部 widget，默认为右箭头
  final Widget? trailing;

  /// 是否显示默认右箭头（trailing 为 null 时生效）
  final bool showChevron;

  /// 行内边距
  final EdgeInsetsGeometry padding;

  const SettingsTapRow({
    super.key,
    this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && showChevron) {
      effectiveTrailing = Icon(
        CupertinoIcons.right_chevron,
        size: 16,
        color: ref.watch(themeProvider).themeColor.descColor(),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: ref.watch(themeProvider).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 15),
            ],
            Text(
              title,
              style: TextStyle(
                color: ref.watch(themeProvider).themeColor.titleColor(),
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (effectiveTrailing != null) ...[
              const SizedBox(width: 5),
              effectiveTrailing!,
            ],
          ],
        ),
      ),
    );
  }
}
