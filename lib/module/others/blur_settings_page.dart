import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/services/wallpaper_service.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';

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
  double _bgBlurSigma = 8.0;
  double _cardBlurSigma = 15.0;

  @override
  void initState() {
    super.initState();
    _bgBlurSigma = SpUtil.getDouble(spBgBlurSigma, defValue: 8.0);
    _cardBlurSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 15.0);
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

  void _reset() {
    _saveBgBlur(8.0);
    _saveCardBlur(15.0);
  }

  @override
  Widget build(BuildContext context) {
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
                          fontWeight: FontWeight.w600,
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
                            fontWeight: FontWeight.w600,
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
                          fontWeight: FontWeight.w600,
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
                            fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }
}
