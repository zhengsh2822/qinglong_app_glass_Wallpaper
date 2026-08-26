import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

/// 通用滑动操作按钮 — 圆角 + 主题自适应
///
/// 风格：
/// - 赛博模式：圆角矩形 + 同色外发光（cyberMode = true）
/// - 普通模式：圆角矩形 + 无外发光（cyberMode = false）
///
/// 不用 SlidableAction，因为：
/// 1. SlidableAction 没有 boxShadow 外发光
/// 2. SlidableAction 不支持自定义 Padding/外发光
/// 3. SlidableAction 会让所有按钮在 ActionPane 内等分，按钮多时会被压缩
class AppSlideButton extends StatelessWidget {
  final BuildContext context;
  final Color color;
  final IconData icon;
  final String? label; // 非赛博模式可选 label
  final VoidCallback onTap;
  final double iconSize;
  final double cornerRadius;
  final double width; // 按钮固定宽度（默认 60）；double.infinity = 等分模式
  final double outerGap; // 按钮与按钮之间外间距
  final double innerGap; // 按钮圆角矩形上下左右内间距
  final double glowBlur;
  final double glowOpacity;
  final bool cyberMode; // 赛博模式开关

  const AppSlideButton({
    Key? key,
    required this.context,
    required this.color,
    required this.icon,
    required this.onTap,
    this.label,
    this.iconSize = 22,
    this.cornerRadius = 10,
    this.width = 60,
    // 外间距/内间距 ≥ 外发光半径（glowBlur 默认 5），
    // 避免发光超出 Slidable 裁剪区域（ClipRect(_SlidableClipper)）被硬切
    this.outerGap = 5,
    this.innerGap = 5,
    this.glowBlur = 5,
    this.glowOpacity = 0.5,
    this.cyberMode = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext buildContext) {
    final inner = Padding(
      // 按钮之间留出缝隙（horizontal），上下各留 4px 与卡片等高
      padding: EdgeInsets.symmetric(horizontal: outerGap, vertical: innerGap),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(cornerRadius),
          // 赛博模式才有边框和外发光
          border:
              cyberMode
                  ? Border.all(color: color.withOpacity(0.7), width: 0.5)
                  : null,
          boxShadow:
              cyberMode
                  ? [
                    BoxShadow(
                      color: color.withOpacity(glowOpacity),
                      blurRadius: glowBlur,
                      spreadRadius: 0,
                    ),
                  ]
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // 关闭 Slidable
              Slidable.of(context)?.close();
              onTap();
            },
            borderRadius: BorderRadius.circular(cornerRadius),
            child: Center(
              child:
                  label == null
                      ? Icon(icon, color: Colors.white, size: iconSize)
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: Colors.white, size: iconSize),
                          if (label != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              label!,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
    // 固定宽度（默认值）
    if (width != double.infinity) {
      return SizedBox(width: width, child: inner);
    }
    // 等分模式：用 Expanded 让按钮撑满父容器（ActionPane 的 Row）
    return Expanded(child: inner);
  }
}

/// 保留旧名以兼容现有调用
class CyberSlideButton extends AppSlideButton {
  const CyberSlideButton({
    Key? key,
    required BuildContext context,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 22,
    double cornerRadius = 10,
    double width = 60,
    double outerGap = 5,
    double innerGap = 5,
    double glowBlur = 5,
    double glowOpacity = 0.5,
  }) : super(
         key: key,
         context: context,
         color: color,
         icon: icon,
         onTap: onTap,
         iconSize: iconSize,
         cornerRadius: cornerRadius,
         width: width,
         outerGap: outerGap,
         innerGap: innerGap,
         glowBlur: glowBlur,
         glowOpacity: glowOpacity,
         cyberMode: true,
       );
}

/// 编辑模式功能按钮（赛博模式：胶囊形外发光 + 主题色；普通模式：图标+文字）
///
/// 风格：
/// - 赛博模式：胶囊形容器 + 同色外发光（折射光效果）
/// - 普通模式：图标+文字的扁平按钮
class EditModeButton extends ConsumerWidget {
  final String title;
  final GestureTapCallback onTap;
  final IconData icon;
  final Color? color; // 按钮主色（赛博模式用做外发光，非赛博模式用做图标颜色）

  const EditModeButton(
    this.title, {
    Key? key,
    required this.icon,
    required this.onTap,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final accent = color ?? ref.watch(themeProvider).primaryColor;

    if (isCyber) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.6),
                  width: 0.5,
                ),
                // 折射光：与同色外发光（blur 5 ≤ 外边距 6，避免被裁剪硬切）
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 5,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 非赛博模式：保持原来的扁平风格
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 15),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: ref.watch(themeProvider).themeColor.titleColor(),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: ref.watch(themeProvider).customPrimaryTextColor,
              ),
            ),
          ],
        ),
        onPressed: onTap,
      ),
    );
  }
}
