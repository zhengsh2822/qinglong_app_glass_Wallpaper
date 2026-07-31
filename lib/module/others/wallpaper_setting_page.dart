import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/services/wallpaper_service.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 壁纸设置页
///
/// 配置 [WallpaperService] 中的壁纸类型、预设、模糊度、蒙层等。
/// 通过 [AnimatedBuilder] 监听 [WallpaperService.instance]（单例 ChangeNotifier），
/// 配置变更后立即重建 UI。
class WallpaperSettingPage extends ConsumerStatefulWidget {
  const WallpaperSettingPage({super.key});

  @override
  ConsumerState<WallpaperSettingPage> createState() =>
      _WallpaperSettingPageState();
}

class _WallpaperSettingPageState extends ConsumerState<WallpaperSettingPage> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const QlAppBar(title: '壁纸设置'),
      body: AnimatedBuilder(
        animation: WallpaperService.instance,
        builder: (context, _) {
          final cfg = WallpaperService.instance.config;
          // 同步 URL 输入框（仅在未编辑时回填当前网络 URL）
          if (_urlController.text.isEmpty &&
              cfg.type == WallpaperType.network &&
              cfg.networkUrl != null) {
            _urlController.text = cfg.networkUrl!;
          }
          return ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: MediaQuery.of(context).padding.bottom + 50,
            ),
            children: [
              _buildTypeSection(cfg),
              if (cfg.type == WallpaperType.gradient)
                _buildGradientSection(cfg),
              if (cfg.type == WallpaperType.solid)
                _buildSolidColorSection(cfg),
              if (cfg.type == WallpaperType.local) _buildLocalSection(cfg),
              if (cfg.type == WallpaperType.network) _buildNetworkSection(cfg),
              _buildBlurSection(cfg),
              _buildDimSection(cfg),
              _buildResetButton(),
            ],
          );
        },
      ),
    );
  }

  // —— 壁纸类型选择 ——
  Widget _buildTypeSection(WallpaperConfig cfg) {
    final types = <(WallpaperType, String, IconData)>[
      (WallpaperType.gradient, '渐变', CupertinoIcons.paintbrush),
      (WallpaperType.solid, '纯色', CupertinoIcons.circle_fill),
      (WallpaperType.local, '本地相册', CupertinoIcons.photo),
      (WallpaperType.network, '网络图片', CupertinoIcons.globe),
    ];
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
            child: Text(
              '壁纸类型',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
          ),
          for (final (type, label, icon) in types)
            SettingsTapRow(
              icon: icon,
              title: label,
              showChevron: false,
              trailing: cfg.type == type
                  ? Icon(
                      CupertinoIcons.check_mark,
                      size: 18,
                      color: ref.watch(themeProvider).primaryColor,
                    )
                  : null,
              onTap: () => WallpaperService.instance.setType(type),
            ),
        ],
      ),
    );
  }

  // —— 预设渐变 ——
  Widget _buildGradientSection(WallpaperConfig cfg) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SettingsCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预设渐变',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (int i = 0; i < PresetGradients.all.length; i++)
                  _buildGradientCell(i, cfg.gradientIndex == i),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientCell(int index, bool selected) {
    final gradient = PresetGradients.all[index];
    return GestureDetector(
      onTap: () => WallpaperService.instance.setGradientPreset(index),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? ref.watch(themeProvider).primaryColor
                : Colors.transparent,
            width: 2.5,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? const Icon(
                CupertinoIcons.check_mark,
                color: Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  // —— 预设纯色 ——
  Widget _buildSolidColorSection(WallpaperConfig cfg) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SettingsCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预设纯色',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in PresetSolidColors.all)
                  _buildSolidColorCell(
                    color,
                    cfg.solidColor == color.toARGB32(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolidColorCell(Color color, bool selected) {
    return GestureDetector(
      onTap: () => WallpaperService.instance.setSolidColor(color),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? ref.watch(themeProvider).primaryColor
                : AppleColors.cardBorder,
            width: 2.5,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? const Icon(
                CupertinoIcons.check_mark,
                color: Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  // —— 本地相册 ——
  Widget _buildLocalSection(WallpaperConfig cfg) {
    final file = WallpaperService.instance.localImageFile;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsTapRow(
              icon: CupertinoIcons.photo_on_rectangle,
              title: '从相册选择',
              onTap: () async {
                final path =
                    await WallpaperService.instance.pickFromGallery();
                if (path == null) {
                  '未选择图片'.toast();
                } else {
                  '已设置壁纸'.toast();
                }
              },
            ),
            if (file != null) ...[
              const Divider(indent: 55, height: 1),
              Padding(
                padding: const EdgeInsets.all(15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    file,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // —— 网络图片 ——
  Widget _buildNetworkSection(WallpaperConfig cfg) {
    final svc = WallpaperService.instance;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SettingsCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '网络图片 URL',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _urlController,
                    placeholder: 'https://...',
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    style: TextStyle(
                      color: ref.watch(themeProvider).themeColor.titleColor(),
                      fontSize: 14,
                    ),
                    decoration: BoxDecoration(
                      color: ref
                          .watch(themeProvider)
                          .themeColor
                          .settingBgColor(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: svc.isDownloading
                      ? null
                      : () {
                          final url = _urlController.text.trim();
                          if (!isHttpUrl(url)) {
                            '请输入合法的图片 URL'.toast();
                            return;
                          }
                          WallpaperService.instance.setNetworkUrl(url);
                          '已设置网络壁纸'.toast();
                        },
                  child: svc.isDownloading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text('确认'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '预设网络壁纸源',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPresetNetworkChip(
                  label: 'Bing 每日',
                  onTap: () => WallpaperService.instance
                      .setNetworkUrl(NetworkWallpaperSources.bingDaily().first),
                ),
                for (int i = 0; i < 4; i++)
                  _buildPresetNetworkChip(
                    label: 'picsum ${i + 1}',
                    onTap: () => WallpaperService.instance.setNetworkUrl(
                      NetworkWallpaperSources.picsum(seed: 1000 + i),
                    ),
                  ),
              ],
            ),
            if (cfg.networkUrl != null && !svc.isDownloading) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  cfg.networkUrl!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: AppleColors.bgTertiary,
                    alignment: Alignment.center,
                    child: Text(
                      '图片加载失败',
                      style: TextStyle(
                        color: ref.watch(themeProvider).themeColor.descColor(),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetNetworkChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ref.watch(themeProvider).primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                ref.watch(themeProvider).primaryColor.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: ref.watch(themeProvider).primaryColor,
          ),
        ),
      ),
    );
  }

  // —— 模糊度 ——
  Widget _buildBlurSection(WallpaperConfig cfg) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SettingsCard(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.drop,
                  size: 20,
                  color: ref.watch(themeProvider).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  '背景模糊',
                  style: TextStyle(
                    fontSize: 16,
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                  ),
                ),
                const Spacer(),
                Text(
                  cfg.blurSigma.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 14,
                    color: ref.watch(themeProvider).themeColor.descColor(),
                  ),
                ),
              ],
            ),
            Slider(
              min: 0,
              max: 50,
              divisions: 50,
              value: cfg.blurSigma.clamp(0.0, 50.0),
              activeColor: ref.watch(themeProvider).primaryColor,
              onChanged: (v) => WallpaperService.instance.setBlurSigma(v),
            ),
          ],
        ),
      ),
    );
  }

  // —— 蒙层不透明度 ——
  Widget _buildDimSection(WallpaperConfig cfg) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SettingsCard(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.moon,
                  size: 20,
                  color: ref.watch(themeProvider).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  '黑色蒙层',
                  style: TextStyle(
                    fontSize: 16,
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                  ),
                ),
                const Spacer(),
                Text(
                  cfg.dimOpacity.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 14,
                    color: ref.watch(themeProvider).themeColor.descColor(),
                  ),
                ),
              ],
            ),
            Slider(
              min: 0,
              max: 1,
              divisions: 100,
              value: cfg.dimOpacity.clamp(0.0, 1.0),
              activeColor: ref.watch(themeProvider).primaryColor,
              onChanged: (v) => WallpaperService.instance.setDimOpacity(v),
            ),
          ],
        ),
      ),
    );
  }

  // —— 重置 ——
  Widget _buildResetButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 24, 15, 0),
      child: GlassCard(
        sigma: 12,
        onTap: () async {
          await WallpaperService.instance.reset();
          _urlController.clear();
          '已恢复默认壁纸'.toast();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            '恢复默认壁纸',
            style: TextStyle(
              fontSize: 16,
              color: ref.watch(themeProvider).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
