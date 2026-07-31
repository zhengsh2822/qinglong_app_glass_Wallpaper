import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class CyberDialog {
  static const double borderRadius = 18.0;
  static const double blurSigma = 25.0;
  static const double dimOpacity = 0.3;
  static const double barrierDim = 0.65;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
    Duration transitionDuration = const Duration(milliseconds: 400),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 24),
  }) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'CyberDialog',
      barrierColor: Colors.transparent,
      transitionDuration: transitionDuration,
      transitionBuilder: (context, animation, secondaryAnimation, child) => child,
      pageBuilder: (context, animation, secondaryAnimation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return AnimatedBuilder(
          animation: curved,
          builder: (context, _) {
            final t = curved.value;
            final baseSigma = SpUtil.getDouble(spCardBlurSigma, defValue: CyberDialog.blurSigma);
            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.black.withValues(alpha: barrierDim * t),
                      ),
                    ),
                  ),
                  Center(
                    child: Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.92 + 0.08 * t,
                        child: Padding(
                          padding: padding,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              CyberDialog.borderRadius,
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: baseSigma * t,
                                sigmaY: baseSigma * t,
                              ),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  28,
                                  28,
                                  24,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    CyberDialog.borderRadius,
                                  ),
                                  border: Border.all(
                                    color: CyberColors.cyan.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 0.5,
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
      },
    );
  }
}

class CyberInputDecoration {
  static InputDecoration get standard => InputDecoration(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(
        color: CyberColors.cyan.withValues(alpha: 0.5),
        width: 1,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.3),
      fontFamily: CyberColors.monoFont,
      fontSize: 14,
    ),
  );
}

class CyberGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final bool expanded;

  const CyberGhostButton({
    Key? key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.expanded = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color accentColor = danger ? CyberColors.neonRed : CyberColors.cyan;
    final Color bgColor;
    final Color textColor;
    final Border? border;

    if (primary || danger) {
      bgColor = accentColor.withValues(alpha: 0.2);
      textColor = Colors.white;
      border = null;
    } else {
      bgColor = Colors.transparent;
      textColor = Colors.white;
      border = Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1);
    }

    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontFamily: CyberColors.monoFont,
              fontWeight: primary || danger ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );

    return expanded ? Expanded(child: button) : button;
  }
}

Widget _buildCyberButtonRow({
  required String cancelLabel,
  required String confirmLabel,
  required bool danger,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
}) {
  return Row(
    children: [
      CyberGhostButton(
        label: cancelLabel,
        onTap: onCancel,
      ),
      const SizedBox(width: 12),
      CyberGhostButton(
        label: confirmLabel,
        primary: !danger,
        danger: danger,
        onTap: onConfirm,
      ),
    ],
  );
}

Future<bool?> showEditTaskDialog(
  BuildContext context, {
  String? initialName,
  String? initialCommand,
  String? initialCron,
}) {
  final nameController = TextEditingController(text: initialName ?? '');
  final commandController = TextEditingController(text: initialCommand ?? '');
  final cronController = TextEditingController(text: initialCron ?? '');
  final formKey = GlobalKey<FormState>();

  return CyberDialog.show<bool>(
    context: context,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      child: Form(
        key: formKey,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                initialName == null ? '新增任务' : '编辑任务',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CyberColors.cyan,
                  fontSize: 17,
                  fontFamily: CyberColors.monoFont,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('名称', style: _labelStyle),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: nameController,
                style: _inputStyle,
                decoration: CyberInputDecoration.standard.copyWith(
                  hintText: '请输入名称',
                ),
                validator: (v) => (v == null || v.isEmpty) ? '名称不能为空' : null,
              ),
              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('命令', style: _labelStyle),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: commandController,
                style: _inputStyle,
                maxLines: 3,
                decoration: CyberInputDecoration.standard.copyWith(
                  hintText: '请输入命令',
                ),
                validator: (v) => (v == null || v.isEmpty) ? '命令不能为空' : null,
              ),
              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('定时规则', style: _labelStyle),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: cronController,
                style: _inputStyle,
                decoration: CyberInputDecoration.standard.copyWith(
                  hintText: '秒(可选) 分 时 天 月 周',
                ),
                validator: (v) => (v == null || v.isEmpty) ? '定时规则不能为空' : null,
              ),
              const SizedBox(height: 24),

              _buildCyberButtonRow(
                cancelLabel: '取消',
                confirmLabel: '保存',
                danger: false,
                onCancel: () => Navigator.of(context).pop(false),
                onConfirm: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const TextStyle _labelStyle = TextStyle(
  color: Colors.white70,
  fontSize: 12,
  fontFamily: CyberColors.monoFont,
);

final TextStyle _inputStyle = TextStyle(
  color: CyberColors.titleWhite,
  fontSize: 14,
  fontFamily: CyberColors.monoFont,
);

Future<bool?> showCyberConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  bool danger = false,
}) {
  return CyberDialog.show<bool>(
    context: context,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: danger ? CyberColors.neonRed : CyberColors.cyan,
                fontSize: 17,
                fontFamily: CyberColors.monoFont,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CyberColors.titleWhite,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildCyberButtonRow(
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              danger: danger,
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> showEditScriptDialog(
  BuildContext context, {
  required String title,
  required String initialContent,
}) {
  final contentController = TextEditingController(text: initialContent);

  return CyberDialog.show<String>(
    context: context,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.9,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '编辑 $title',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CyberColors.cyan,
                fontSize: 17,
                fontFamily: CyberColors.monoFont,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: TextField(
                    controller: contentController,
                    maxLines: null,
                    style: TextStyle(
                      color: CyberColors.titleWhite,
                      fontSize: 13,
                      fontFamily: CyberColors.monoFont,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildCyberButtonRow(
              cancelLabel: '取消',
              confirmLabel: '保存',
              danger: false,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () => Navigator.of(context).pop(contentController.text),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> showCyberInputDialog(
  BuildContext context, {
  required String title,
  String hintText = '',
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  TextInputType? keyboardType,
  bool obscureText = false,
}) {
  final controller = TextEditingController();

  return CyberDialog.show<String>(
    context: context,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CyberColors.cyan,
                fontSize: 17,
                fontFamily: CyberColors.monoFont,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CyberColors.titleWhite,
                fontSize: 14,
                fontFamily: CyberColors.monoFont,
              ),
              decoration: CyberInputDecoration.standard.copyWith(
                hintText: hintText,
              ),
            ),
            const SizedBox(height: 24),
            _buildCyberButtonRow(
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              danger: false,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> showCyberFrequencyDialog(
  BuildContext context, {
  required String title,
  required int initialValue,
  int minValue = 1,
  int maxValue = 100,
  String unit = '天',
}) {
  final controller = TextEditingController(text: initialValue.toString());

  return CyberDialog.show<int>(
    context: context,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CyberColors.cyan,
                fontSize: 17,
                fontFamily: CyberColors.monoFont,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '每',
                  style: TextStyle(
                    color: CyberColors.titleWhite,
                    fontSize: 15,
                    fontFamily: CyberColors.monoFont,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: CyberColors.titleWhite,
                      fontSize: 15,
                      fontFamily: CyberColors.monoFont,
                    ),
                    decoration: CyberInputDecoration.standard.copyWith(
                      hintText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  unit,
                  style: TextStyle(
                    color: CyberColors.titleWhite,
                    fontSize: 15,
                    fontFamily: CyberColors.monoFont,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildCyberButtonRow(
              cancelLabel: '取消',
              confirmLabel: '确定',
              danger: false,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () {
                final value = int.tryParse(controller.text);
                if (value == null || value > maxValue) {
                  '最大可设置$maxValue$unit'.toast();
                  return;
                }
                if (value < minValue) {
                  '最小可设置$minValue$unit'.toast();
                  return;
                }
                Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
