import 'package:flutter/material.dart';

import '../theme.dart';
import 'sort_triangle.dart';

/// 排序激活纯色：跟随导航栏按钮文字色（iconTheme）
/// 白导航栏=青 #00CCCC / 黑导航栏=荧光青 #00F0FF / 青导航栏=白
Color sortActiveColor(BuildContext context) =>
    Theme.of(context).appBarTheme.iconTheme?.color ?? const Color(0xFF00CCCC);

/// 排序默认描边灰：按主题模式（浅色=青底白半透明 / 白色=浅灰 / 赛博=深灰）
Color sortInactiveColor(int themeMode) {
  if (themeMode == modeCyber || themeMode == modeDark) {
    return const Color(0xFF4A4A5E);
  }
  if (themeMode == modeWhite) return const Color(0xFFC7C7CC);
  return Colors.white.withValues(alpha: 0.65);
}

/// 顶部导航栏排序入口按钮（文字 + 三态三角）
///
/// 排版：`名称 ▴▾`（按钮文字 + SortTriangle）。三角三态随 [state] 变化，
/// [activeColor] 为激活纯色（通常传导航栏按钮文字色），[inactiveColor] 为默认描边灰。
class SortNavButton extends StatelessWidget {
  final String label;
  final SortState state;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final double fontSize;

  const SortNavButton({
    super.key,
    required this.label,
    required this.state,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: activeColor,
                ),
              ),
              const SizedBox(width: 3),
              SortTriangle(
                state: state,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
