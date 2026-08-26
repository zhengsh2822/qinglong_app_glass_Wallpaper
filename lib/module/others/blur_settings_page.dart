import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/services/wallpaper_service.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/color_picker_sheet.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';

import '../../base/sp_const.dart';
import '../../utils/sp_utils.dart';

/// 模糊参数调节页
///
/// 背景模糊：控制路由级 WallpaperBackground 的模糊 sigma（纯文字页面生效）
/// 卡片模糊：控制 GlassCard / GlassListItemCard 的模糊 sigma
class BlurSettingsPage extends ConsumerStatefulWidget {
  const BlurSettingsPage({super.key});

  @override
  ConsumerState<BlurSettingsPage> createState() => _BlurSettingsPageState();
}

class _BlurSettingsPageState extends ConsumerState<BlurSettingsPage> {
  double _bgBlurSigma = 6.0;
  double _cardBlurSigma = 4.0;
  double _cardSolidOpacity = 0.45;
  int _cardSolidColor = -1; // -1 = 随主题自动（浅色白 / 深色黑）

  /// 全局字重（build 顶部统一 watch，供各卡片标题/数值使用）
  FontWeight _globalFw = FontWeight.w400;

  @override
  void initState() {
    super.initState();
    _bgBlurSigma = SpUtil.getDouble(spBgBlurSigma, defValue: 6.0);
    _cardBlurSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 4.0);
    _cardSolidOpacity =
        SpUtil.getDouble(spCardSolidOpacity, defValue: 0.45);
    _cardSolidColor = SpUtil.getInt(spCardSolidColor, defValue: -1);
  }

  void _saveBgBlur(double value) {
    _bgBlurSigma = value;
    SpUtil.putDouble(spBgBlurSigma, value);
    // 触发 WallpaperBackground rebuild，让它重新读取 SP 中的背景模糊值
    WallpaperService.instance.notifyListeners();
    setState(() {});
  }

  void _saveCardBlur(double value) {
    _cardBlurSigma = value;
    SpUtil.putDouble(spCardBlurSigma, value);
    // 通知主题重建，让 GlassCard 重新读取 SP
    ref.read(themeProvider).notifyListeners();
    setState(() {});
  }

  void _saveCardSolidOpacity(double value) {
    _cardSolidOpacity = value;
    SpUtil.putDouble(spCardSolidOpacity, value);
    // 通知主题重建，让 OptimizedFrostedGlass 重新读取 SP
    ref.read(themeProvider).notifyListeners();
    setState(() {});
  }

  // 当前生效的纯色底色（自定义颜色或随主题自动白/黑）
  Color get _currentSolidColor {
    final isDark = ref.read(themeProvider).themeMode == modeDark ||
        ref.read(themeProvider).themeMode == modeCyber;
    return _cardSolidColor >= 0
        ? Color(_cardSolidColor)
        : (isDark ? Colors.black : Colors.white);
  }

  void _saveCardSolidColor(Color color) {
    _cardSolidColor = color.value;
    SpUtil.putInt(spCardSolidColor, color.value);
    ref.read(themeProvider).notifyListeners();
    setState(() {});
  }

  void _resetCardSolidColor() {
    _cardSolidColor = -1;
    SpUtil.putInt(spCardSolidColor, -1);
    ref.read(themeProvider).notifyListeners();
    setState(() {});
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ColorPickerSheet(
          initialColor: _currentSolidColor,
          title: "纯色颜色",
          subtitle:
              "卡片模糊关闭时的底色。不同壁纸可自定义颜色适配（也可以搭配不透明度滑块调节）",
          onConfirm: _saveCardSolidColor,
          onReset: _resetCardSolidColor,
        );
      },
    );
  }

  void _reset() {
    _saveBgBlur(6.0);
    _saveCardBlur(4.0);
    _saveCardSolidOpacity(0.45);
    _resetCardSolidColor();
  }

  @override
  Widget build(BuildContext context) {
    _globalFw = FontWeight(ref.watch(textWeightProvider));
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        title: "模糊调节",
        actions: [
          GestureDetector(
            onTap: _reset,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Text(
                  "恢复默认",
                  style: TextStyle(
                    fontSize: 14,
                    color: ref.watch(themeProvider).primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 背景模糊调节卡片
            GlassCard(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.circle_filled,
                        size: 16,
                        color: ref.watch(themeProvider).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "背景模糊",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _globalFw,
                          color: ref.watch(themeProvider).themeColor.titleColor(),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ref.watch(themeProvider).primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _bgBlurSigma.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _globalFw,
                            color: ref.watch(themeProvider).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "控制纯文字页面的背景模糊度（0 = 不模糊，值越大越模糊）",
                    style: TextStyle(
                      fontSize: 12,
                      color: ref.watch(themeProvider).themeColor.descColor(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _bgBlurSigma,
                    min: 0,
                    max: 30,
                    divisions: 60,
                    activeColor: ref.watch(themeProvider).primaryColor,
                    onChanged: _saveBgBlur,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // 卡片模糊调节卡片
            GlassCard(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.square_stack_3d_up,
                        size: 16,
                        color: ref.watch(themeProvider).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "卡片模糊",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _globalFw,
                          color: ref.watch(themeProvider).themeColor.titleColor(),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ref.watch(themeProvider).primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _cardBlurSigma.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _globalFw,
                            color: ref.watch(themeProvider).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "控制所有卡片的毛玻璃模糊度（值越大越模糊，影响滚动性能）",
                    style: TextStyle(
                      fontSize: 12,
                      color: ref.watch(themeProvider).themeColor.descColor(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _cardBlurSigma,
                    min: 0,
                    max: 30,
                    divisions: 60,
                    activeColor: ref.watch(themeProvider).primaryColor,
                    onChanged: _saveCardBlur,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // 卡片纯色调节卡片（卡片模糊=0 时生效）
            GlassCard(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.square_fill,
                        size: 16,
                        color: ref.watch(themeProvider).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "卡片纯色",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _globalFw,
                          color: ref.watch(themeProvider).themeColor.titleColor(),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ref.watch(themeProvider).primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${(_cardSolidOpacity * 100).round()}%",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _globalFw,
                            color: ref.watch(themeProvider).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "关闭卡片模糊（设为 0）时生效：卡片改用纯色背景替代毛玻璃，"
                    "无模糊=零 GPU 离屏开销、滚动更流畅，且内容更清晰可读",
                    style: TextStyle(
                      fontSize: 12,
                      color: ref.watch(themeProvider).themeColor.descColor(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _cardSolidOpacity,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    activeColor: ref.watch(themeProvider).primaryColor,
                    onChanged: _saveCardSolidOpacity,
                  ),
                  const SizedBox(height: 6),
                  // 纯色颜色选择：适配不同壁纸
                  GestureDetector(
                    onTap: _showColorPicker,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          // 当前底色色块预览
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _currentSolidColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor()
                                    .withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _cardSolidColor >= 0
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : Icons.auto_awesome,
                              size: 18,
                              color: _currentSolidColor.computeLuminance() > 0.5
                                  ? Colors.black54
                                  : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "纯色颜色",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _globalFw,
                                    color: ref
                                        .watch(themeProvider)
                                        .themeColor
                                        .titleColor(),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _cardSolidColor >= 0
                                      ? "#${(_cardSolidColor & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}"
                                      : "自动（随主题白/黑）",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ref
                                        .watch(themeProvider)
                                        .themeColor
                                        .descColor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .descColor(),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
