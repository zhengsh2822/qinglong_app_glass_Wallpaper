import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/container_transform_route.dart';
import 'package:qinglong_app/base/ui/wallpaper_background.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';

/// 顶部标题 / 空白区域 → 账号页的统一共享转场。
///
/// 这些区域没有卡片材质：容器以标题矩形为起点，展开后由壁纸版整页背景接管。
/// 圆角使用 app 统一标准 [AppleColors.radiusCard]，与账号卡片/添加账号卡一致。
Future<void> pushAccountPageFromTitle({
  required BuildContext context,
  required Rect sourceRect,
  required Widget sourceChild,
}) {
  return Navigator.of(context).push(
    ContainerTransformRoute(
      sourceRect: sourceRect,
      sourceChild: sourceChild,
      background: const WallpaperBackground(cacheBlur: true),
      sourceRadius: AppleColors.radiusCard,
      sourceBlurSigma: 0,
      sourceHighlightOpacity: 0,
      sourceBorderColor: Colors.transparent,
      pageBackground: const Color(0xFF080A0D),
      pageBuilder:
          (context, animation) => ChangeAccountPage(animation: animation),
    ),
  );
}
