import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/color_picker_sheet.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
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
  /// 全局字体粗细（四档 400/500/600/700），默认 400
  int fontWeight = 400;
  Color? _primaryTextColor;
  Color? _secondaryTextColor;

  @override
  void initState() {
    textScaleFactor = SpUtil.getDouble(spTextScaleFactor, defValue: 1.0);
    fontWeight = SpUtil.getInt(spTextFontWeight, defValue: 400);
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

  /// 重置字体设置：字体大小回标准 + 粗细回标准 + 主/次字体颜色恢复默认（立即保存全局生效）
  void _resetFontSettings() {
    textScaleFactor = 1;
    fontWeight = 400;
    _savePrimaryColor(null);
    _saveSecondaryColor(null);
    final app = context.findAncestorStateOfType<QlAppState>();
    app?.updateTextScaleFactor(1);
    app?.updateTextFontWeight(400);
  }

  /// 当前粗细档位文案（四档）
  String get _fontWeightLabel {
    return switch (fontWeight) {
      500 => "常规 (w500)",
      600 => "中等 (w600)",
      700 => "粗体 (w700)",
      _ => "标准 (w400)",
    };
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
        return ColorPickerSheet(
          initialColor: initialColor,
          title: "选择颜色",
          subtitle: "主字体用于标题/任务名，次字体用于时间/描述/命令",
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
              onPressed: _resetFontSettings,
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
                final app = context.findAncestorStateOfType<QlAppState>();
                app?.updateTextScaleFactor(textScaleFactor);
                app?.updateTextFontWeight(fontWeight);
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
                                fontWeight: FontWeight(fontWeight),
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
                                fontWeight: FontWeight(fontWeight),
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
                                fontWeight: FontWeight(fontWeight),
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

              // 卡片2.5：字体粗细调整（四档：w400/w500/w600/w700，与字体大小滑块同风格）
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
                      children: const [
                        Text("细", style: TextStyle(fontSize: 14)),
                        Text("粗", style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlider(
                        key: const Key('weight_slider'),
                        value: ((fontWeight - 400) / 100).toDouble(),
                        max: 3,
                        min: 0,
                        divisions: 3,
                        onChanged: (double value) {
                          fontWeight = 400 + (value.round() * 100);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _fontWeightLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
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
