import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/hsl_color_picker.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../base/sp_const.dart';
import '../../utils/sp_utils.dart';

class TextSizePage extends ConsumerStatefulWidget {
  const TextSizePage({super.key});

  @override
  ConsumerState<TextSizePage> createState() => _TextSizePageState();
}

class _TextSizePageState extends ConsumerState<TextSizePage> {
  double textScaleFactor = 1.0;
  Color? _primaryTextColor;
  Color? _secondaryTextColor;

  @override
  void initState() {
    textScaleFactor = SpUtil.getDouble(spTextScaleFactor, defValue: 1.0);
    _loadCustomColors();
    super.initState();
  }

  void _loadCustomColors() {
    final p = SpUtil.getInt(spPrimaryTextColor, defValue: -1);
    final s = SpUtil.getInt(spSecondaryTextColor, defValue: -1);
    _primaryTextColor = p >= 0 ? Color(p) : null;
    _secondaryTextColor = s >= 0 ? Color(s) : null;
  }

  void _savePrimaryColor(Color? color) {
    _primaryTextColor = color;
    // 调 ThemeViewModel 方法，内部会 notifyListeners 让全局 rebuild
    ref.read(themeProvider).setCustomPrimaryTextColor(color);
    setState(() {});
  }

  void _saveSecondaryColor(Color? color) {
    _secondaryTextColor = color;
    ref.read(themeProvider).setCustomSecondaryTextColor(color);
    setState(() {});
  }

  void _resetColors() {
    _savePrimaryColor(null);
    _saveSecondaryColor(null);
  }

  void _showColorPicker(bool isPrimary) {
    final theme = ref.read(themeProvider);
    final Color defaultColor =
        isPrimary
            ? theme.themeColor.titleColor()
            : theme.themeColor.descColor();
    final Color initialColor =
        (isPrimary ? _primaryTextColor : _secondaryTextColor) ?? defaultColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _ColorPickerSheet(
          initialColor: initialColor,
          isPrimary: isPrimary,
          onConfirm: (color) {
            if (isPrimary) {
              _savePrimaryColor(color);
            } else {
              _saveSecondaryColor(color);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    return MediaQuery(
      data: MediaQueryData.fromView(View.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: QlAppBar(
          canBack: true,
          title: "字体设置",
          actions: [
            CupertinoButton(
              onPressed: _resetColors,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Text(
                  "重置",
                  style: TextStyle(fontSize: 16, color: theme.primaryColor),
                ),
              ),
            ),
            CommitButton(
              onTap: () {
                context
                    .findAncestorStateOfType<QlAppState>()
                    ?.updateTextScaleFactor(textScaleFactor);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          primary: true,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 卡片1：预览（3 行内容 + 右上角时间）
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
                child: MediaQuery(
                  data: MediaQueryData.fromView(
                    View.of(context),
                  ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "测试任务",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                color: theme.customPrimaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "10 1-23/3 * * *",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.customSecondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "task test/test.js",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.customSecondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "6/12 12:00",
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.customSecondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 卡片2：字体设置调整
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("A", style: TextStyle(fontSize: 12)),
                        const Text("A", style: TextStyle(fontSize: 22)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlider(
                        key: const Key('slider'),
                        value: textScaleFactor,
                        max: 1.4,
                        min: 0.6,
                        onChanged: (double value) {
                          textScaleFactor = value;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: CupertinoButton(
                        onPressed: () {
                          textScaleFactor = 1;
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        child: Text(
                          "标准",
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 卡片3：字体颜色自定义（标题 + 说明 + 2 行颜色）
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "字体颜色",
                      style: TextStyle(
                        fontSize: 17,
                        color: theme.customPrimaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "主字体用于标题/任务名，次字体用于时间/描述/命令",
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.customSecondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildColorRow(
                      title: "主字体颜色",
                      color: _primaryTextColor ?? theme.themeColor.titleColor(),
                      onTap: () => _showColorPicker(true),
                    ),
                    const Divider(height: 1, color: Color(0x33FFFFFF)),
                    _buildColorRow(
                      title: "次字体颜色",
                      color:
                          _secondaryTextColor ?? theme.themeColor.descColor(),
                      onTap: () => _showColorPicker(false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorRow({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = ref.watch(themeProvider);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.customPrimaryTextColor,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33FFFFFF), width: 1),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: theme.customSecondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// 颜色选择器底部弹窗（独立 StatefulWidget，currentColor 持久化）
class _ColorPickerSheet extends ConsumerStatefulWidget {
  final Color initialColor;
  final bool isPrimary;
  final ValueChanged<Color> onConfirm;

  const _ColorPickerSheet({
    required this.initialColor,
    required this.isPrimary,
    required this.onConfirm,
  });

  @override
  ConsumerState<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<_ColorPickerSheet> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    return GlassCard(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      sigma: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "选择颜色",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.customPrimaryTextColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.customPrimaryTextColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: theme.customPrimaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "主字体用于标题/任务名，次字体用于时间/描述/命令",
            style: TextStyle(
              fontSize: 13,
              color: theme.customSecondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          _ColorPreviewBlock(color: _currentColor),
          const SizedBox(height: 20),
          HslColorPicker(
            color: _currentColor,
            onChanged: (c) {
              setState(() => _currentColor = c);
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "取消",
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.customPrimaryTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CupertinoButton(
                  color: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () {
                    widget.onConfirm(_currentColor);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "确认",
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 颜色选择器顶部预览块（色块 + 十六进制色值）
class _ColorPreviewBlock extends StatelessWidget {
  final Color color;
  const _ColorPreviewBlock({required this.color});

  @override
  Widget build(BuildContext context) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '#${hex.substring(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
