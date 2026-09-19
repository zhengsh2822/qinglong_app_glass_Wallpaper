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
/// 与 GlassCard 设计风格一致，描边比卡片更细（0.5 vs 1.0）。
/// 聚焦（选中）状态：描边高亮为主题色/青色（1.0 宽），与主题版 TextField
/// 聚焦反馈同步（壁纸版此前无选中状态）。
class GlassTextField extends ConsumerStatefulWidget {
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
  ConsumerState<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends ConsumerState<GlassTextField> {
  // 外部未传 focusNode 时内部自建（复用外部则无需管理生命周期）
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant GlassTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      widget.focusNode?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;
    final bool isCyber = themeMode == modeCyber;
    // 与卡片同色系描边，但宽度更细（0.5 vs 卡片 1.0）
    final borderColor =
        isDark ? CyberColors.borderGlow : AppleColors.cardBorder;
    // 聚焦（选中）高亮色：cyber 青色 / 非 cyber 主题色
    final focusColor = isCyber ? CyberColors.cyan : AppleColors.accent;
    const radius = 24.0;
    final bool focused = _focusNode.hasFocus;

    // 卡片模糊：SP 有设置时覆盖默认 sigma（用户在设置页调节）
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 4);

    return OptimizedFrostedGlass(
      sigma: effectiveSigma,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: focused ? focusColor : borderColor,
            width: focused ? 1 : 0.5,
          ),
        ),
        padding: widget.padding,
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          autofocus: widget.autofocus,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textAlignVertical: widget.textAlignVertical,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          textInputAction: widget.textInputAction,
          style: widget.style,
          inputFormatters: widget.inputFormatters,
          decoration: InputDecoration(
            hintText: widget.hintText,
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
