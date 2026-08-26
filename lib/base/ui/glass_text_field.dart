import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 胶囊形毛玻璃输入框
///
/// 统一封装：ClipRRect(borderRadius 24) + BackdropFilter(sigma 12) + 描边
/// 与 GlassCard 设计风格一致，描边比卡片更细（0.5 vs 1.0）
class GlassTextField extends ConsumerWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextAlignVertical? textAlignVertical;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final EdgeInsets padding;
  final List<TextInputFormatter>? inputFormatters;

  const GlassTextField({
    Key? key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.maxLines,
    this.minLines,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.textAlignVertical,
    this.onChanged,
    this.onEditingComplete,
    this.textInputAction,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.inputFormatters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;
    // 与卡片同色系描边，但宽度更细（0.5 vs 卡片 1.0）
    final borderColor = isDark ? CyberColors.borderGlow : AppleColors.cardBorder;
    const radius = 24.0;

    // 卡片模糊：SP 有设置时覆盖默认 sigma（用户在设置页调节）
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 4);

    // 统一毛玻璃封装：sigma<=0 时自动退化为纯色（无 BackdropFilter）
    return OptimizedFrostedGlass(
      sigma: effectiveSigma,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: padding,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          minLines: minLines,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textAlignVertical: textAlignVertical,
          onChanged: onChanged,
          onEditingComplete: onEditingComplete,
          textInputAction: textInputAction,
          style: style,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
