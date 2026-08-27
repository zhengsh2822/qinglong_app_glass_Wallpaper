import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

const double _dialogBlurSigma = 4.0;
const double _dialogBorderRadius = 18.0;
const double _dialogBarrierDim = 0.65;
const Duration _dialogTransitionDuration = Duration(milliseconds: 400);
const double _dialogButtonRadius = 12.0;

class DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final bool isCyber;
  final Color primaryColor;

  const DialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    required this.isCyber,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color btnColor;
    final Color textColor;
    final Color borderColor;

    if (danger) {
      btnColor = const Color(0xFFFF3B30);
      textColor = Colors.white;
      borderColor = const Color(0xFFFF3B30);
    } else if (primary) {
      btnColor = primaryColor;
      textColor = Colors.white;
      borderColor = primaryColor;
    } else {
      btnColor = Colors.transparent;
      textColor = Colors.white;
      borderColor = Colors.white.withValues(alpha: 0.3);
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: primary || danger
                ? btnColor.withValues(alpha: isCyber ? 0.2 : 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(_dialogButtonRadius),
            border: primary || danger
                ? null
                : Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: primary || danger ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogTheme {
  final Color cardBg;
  final Color borderColor;
  final double borderWidth;
  final Color titleColor;
  final Color contentColor;
  final Color primaryAction;
  final Color inputBg;
  final Color inputBorder;
  final Color inputText;
  final Color inputHint;
  final List<BoxShadow>? shadows;

  const _DialogTheme({
    required this.cardBg,
    required this.borderColor,
    required this.borderWidth,
    required this.titleColor,
    required this.contentColor,
    required this.primaryAction,
    required this.inputBg,
    required this.inputBorder,
    required this.inputText,
    required this.inputHint,
    this.shadows,
  });
}

_DialogTheme _resolveDialogTheme(bool isCyber, bool isDark, bool danger) {
  if (isCyber) {
    return _DialogTheme(
      cardBg: Colors.transparent,
      borderColor: CyberColors.cyan.withValues(alpha: 0.2),
      borderWidth: 0.5,
      titleColor: danger ? CyberColors.neonRed : CyberColors.cyan,
      contentColor: CyberColors.titleWhite,
      primaryAction: danger ? CyberColors.neonRed : CyberColors.cyan,
      inputBg: Colors.white.withValues(alpha: 0.05),
      inputBorder: CyberColors.cyan.withValues(alpha: 0.3),
      inputText: CyberColors.titleWhite,
      inputHint: Colors.white.withValues(alpha: 0.3),
      shadows: null,
    );
  } else if (isDark) {
    return _DialogTheme(
      cardBg: Colors.transparent,
      borderColor: Colors.white.withValues(alpha: 0.15),
      borderWidth: 0.5,
      titleColor: danger ? const Color(0xFFFF453A) : AppleColors.textPrimary,
      contentColor: AppleColors.textSecondary,
      primaryAction: danger ? const Color(0xFFFF453A) : AppleColors.accent,
      inputBg: Colors.white.withValues(alpha: 0.05),
      inputBorder: Colors.white.withValues(alpha: 0.15),
      inputText: AppleColors.textPrimary,
      inputHint: AppleColors.textSecondary,
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  } else {
    return _DialogTheme(
      cardBg: Colors.transparent,
      borderColor: Colors.black.withValues(alpha: 0.1),
      borderWidth: 0.5,
      titleColor: danger ? const Color(0xFFFF3B30) : AppleColors.textPrimary,
      contentColor: const Color(0xFF6B7280),
      primaryAction: danger ? const Color(0xFFFF3B30) : AppleColors.accent,
      inputBg: Colors.black.withValues(alpha: 0.03),
      inputBorder: Colors.black.withValues(alpha: 0.1),
      inputText: AppleColors.textPrimary,
      inputHint: const Color(0xFF9CA3AF),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

Widget _buildDialogPage({
  required BuildContext context,
  required Widget child,
  required _DialogTheme theme,
  required Animation<double> animation,
  VoidCallback? onBarrierTap,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return AnimatedBuilder(
    animation: curved,
    builder: (context, _) {
      final t = curved.value;
      final baseSigma = SpUtil.getDouble(spCardBlurSigma, defValue: _dialogBlurSigma);
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onBarrierTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: _dialogBarrierDim * t),
                ),
              ),
            ),
            Center(
              child: Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: OptimizedFrostedGlass(
                        sigma: baseSigma * t,
                        borderRadius:
                            BorderRadius.circular(_dialogBorderRadius),
                        forceOpaqueSolid: true,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardBg,
                            borderRadius: BorderRadius.circular(
                              _dialogBorderRadius,
                            ),
                            border: Border.all(
                              color: theme.borderColor,
                              width: theme.borderWidth,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildDialogButtons({
  required _DialogTheme theme,
  required bool isCyber,
  required String cancelLabel,
  required String confirmLabel,
  required bool danger,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
}) {
  return Row(
    children: [
      DialogButton(
        label: cancelLabel,
        onTap: onCancel,
        isCyber: isCyber,
        primaryColor: theme.primaryAction,
      ),
      const SizedBox(width: 12),
      DialogButton(
        label: confirmLabel,
        onTap: onConfirm,
        primary: !danger,
        danger: danger,
        isCyber: isCyber,
        primaryColor: theme.primaryAction,
      ),
    ],
  );
}

Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  bool danger = false,
}) {
  final isCyber =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeCyber;
  final isDark =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeDark;
  final theme = _resolveDialogTheme(isCyber, isDark, danger);

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'ConfirmDialog',
    barrierColor: Colors.transparent,
    transitionDuration: _dialogTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      // 弹窗标题字重跟随全局粗细调节（弹窗为瞬时场景，打开时读取一次）
      final FontWeight fw = FontWeight(
        ProviderScope.containerOf(context).read(textWeightProvider),
      );
      return _buildDialogPage(
        context: context,
        animation: animation,
        theme: theme,
        onBarrierTap: () => Navigator.of(context).pop(false),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.titleColor,
                  fontSize: 17,
                  fontWeight: fw,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.contentColor,
                  fontSize: 14,
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 24),
              _buildDialogButtons(
                theme: theme,
                isCyber: isCyber,
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                danger: danger,
                onCancel: () => Navigator.of(context).pop(false),
                onConfirm: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  String content = '',
  String hintText = '',
  String initialValue = '',
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  TextInputType? keyboardType,
  bool obscureText = false,
  List<TextInputFormatter>? inputFormatters,
}) {
  final isCyber =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeCyber;
  final isDark =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeDark;
  final theme = _resolveDialogTheme(isCyber, isDark, false);
  final controller = TextEditingController(text: initialValue);

  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'InputDialog',
    barrierColor: Colors.transparent,
    transitionDuration: _dialogTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      // 弹窗标题字重跟随全局粗细调节（弹窗为瞬时场景，打开时读取一次）
      final FontWeight fw = FontWeight(
        ProviderScope.containerOf(context).read(textWeightProvider),
      );
      return _buildDialogPage(
        context: context,
        animation: animation,
        theme: theme,
        onBarrierTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.titleColor,
                  fontSize: 17,
                  fontWeight: fw,
                  letterSpacing: 0.3,
                ),
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.contentColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                inputFormatters: inputFormatters,
                autofocus: true,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.inputText, fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.inputBg,
                  hintText: hintText,
                  hintStyle: TextStyle(color: theme.inputHint, fontSize: 15),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.inputBorder, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: theme.primaryAction,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDialogButtons(
                theme: theme,
                isCyber: isCyber,
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                danger: false,
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: () => Navigator.of(context).pop(controller.text),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<int?> showFrequencyDialog(
  BuildContext context, {
  required String title,
  required int initialValue,
  int minValue = 1,
  int maxValue = 1000,
  String unit = '天',
  /// 可选的异步值加载器。
  ///
  /// 传入时，弹窗会立即显示（先用 [initialValue] 占位），
  /// 加载完成后自动替换输入框的值（若用户尚未手动编辑）。
  /// 这样可以避免"点击后等网络请求才弹窗"的延迟感。
  Future<int?> Function()? valueLoader,
}) {
  final isCyber =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeCyber;
  final isDark =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeDark;
  final theme = _resolveDialogTheme(isCyber, isDark, false);
  final controller = TextEditingController(text: initialValue.toString());

  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'FrequencyDialog',
    barrierColor: Colors.transparent,
    transitionDuration: _dialogTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return _buildDialogPage(
        context: context,
        animation: animation,
        theme: theme,
        onBarrierTap: () => Navigator.of(context).pop(),
        child: _FrequencyDialogContent(
          title: title,
          unit: unit,
          minValue: minValue,
          maxValue: maxValue,
          initialValue: initialValue,
          controller: controller,
          theme: theme,
          isCyber: isCyber,
          valueLoader: valueLoader,
        ),
      );
    },
  );
}

/// 频率输入弹窗内容（支持异步加载当前值）
class _FrequencyDialogContent extends StatefulWidget {
  final String title;
  final String unit;
  final int minValue;
  final int maxValue;
  final int initialValue;
  final TextEditingController controller;
  final _DialogTheme theme;
  final bool isCyber;
  final Future<int?> Function()? valueLoader;

  const _FrequencyDialogContent({
    required this.title,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.initialValue,
    required this.controller,
    required this.theme,
    required this.isCyber,
    required this.valueLoader,
  });

  @override
  State<_FrequencyDialogContent> createState() =>
      _FrequencyDialogContentState();
}

class _FrequencyDialogContentState extends State<_FrequencyDialogContent> {
  bool _loading = true;
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    // 监听用户手动编辑
    widget.controller.addListener(_onUserEdit);
    // 立即触发异步加载（若有 loader）
    if (widget.valueLoader != null) {
      _loadValue();
    } else {
      _loading = false;
    }
  }

  void _onUserEdit() {
    if (widget.controller.text != widget.initialValue.toString() && !_loading) {
      _userEdited = true;
    }
  }

  Future<void> _loadValue() async {
    try {
      final value = await widget.valueLoader!();
      if (!mounted) return;
      // 仅当用户尚未手动编辑时才替换值
      if (!_userEdited && value != null) {
        widget.controller.text = value.toString();
      }
    } catch (_) {
      // 加载失败时保留初始占位值
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUserEdit);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 弹窗标题字重跟随全局粗细调节（弹窗为瞬时场景，build 时读取一次）
    final FontWeight fw = FontWeight(
      ProviderScope.containerOf(context).read(textWeightProvider),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.theme.titleColor,
              fontSize: 17,
              fontWeight: fw,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '每',
                style: TextStyle(
                  color: widget.theme.contentColor,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TextField(
                      controller: widget.controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      // 加载期间禁用输入，避免与加载完成后的值替换冲突
                      enabled: !_loading,
                      style: TextStyle(
                        color: widget.theme.inputText,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: widget.theme.inputBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: widget.theme.inputBorder,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: widget.theme.primaryAction,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    // 加载期间覆盖一个小尺寸 loading 指示器
                    if (_loading)
                      Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.theme.primaryAction,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.unit,
                style: TextStyle(
                  color: widget.theme.contentColor,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDialogButtons(
            theme: widget.theme,
            isCyber: widget.isCyber,
            cancelLabel: '取消',
            confirmLabel: '确定',
            danger: false,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () {
              if (_loading) {
                '请等待加载完成'.toast();
                return;
              }
              final value = int.tryParse(widget.controller.text);
              if (value == null || value > widget.maxValue) {
                '最大可设置${widget.maxValue}${widget.unit}'.toast();
                return;
              }
              if (value < widget.minValue) {
                '最小可设置${widget.minValue}${widget.unit}'.toast();
                return;
              }
              Navigator.of(context).pop(value);
            },
          ),
        ],
      ),
    );
  }
}
