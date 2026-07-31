import 'package:flutter/material.dart';
import 'package:qinglong_app/base/services/wallpaper_service.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class AppColors {
  static const Color danger = Color(0xffEA4D3E);
  static const Color warning = Color(0xffF19A39);
  static const Color success = Color(0xff5D5E70);
  static const Color purple = Color(0xffA356D6);
  static const Color greyText = Color(0xff999999);
  static const Color greyBg = Color(0xffF7F7F7);
  static const Color divider = Color(0xffE0E0E0);
  static const Color dividerDark = Color(0xff444444);
}

/// 赛博终端配色方案
class CyberColors {
  /// 深空黑底色
  static const Color bg = Color(0xFF0A0A0F);

  /// 卡片半透明背景（不带模糊，纯纯色保证列表滚动性能）
  static const Color cardBg = Color(0xFF12121A);

  /// 赛博青色 - 主色
  static const Color cyan = Color(0xFF00F0FF);

  /// 荧光绿 - 成功状态
  static const Color neonGreen = Color(0xFF00FF94);

  /// 警告红 - 失败状态
  static const Color neonRed = Color(0xFFFF3B5C);

  /// 警告黄 - 暂停/停止状态
  static const Color neonYellow = Color(0xFFFFB800);

  /// 待机灰
  static const Color idleGray = Color(0xFF4A4A5E);

  /// 网格线颜色
  static const Color gridLine = Color(0x14FFFFFF);

  /// 边框微光
  static const Color borderGlow = Color(0x3300F0FF);

  /// 主字体颜色（标题/任务名）
  /// 优先读 SP[spPrimaryTextColor] 自定义颜色，未设置（-1）回退壁纸反色
  static Color get titleWhite {
    final custom = SpUtil.getInt(spPrimaryTextColor, defValue: -1);
    if (custom >= 0) return Color(custom);
    return WallpaperService.instance.contrastTextColor;
  }

  /// 次字体颜色（时间/描述/命令）
  /// 优先读 SP[spSecondaryTextColor] 自定义颜色，未设置（-1）回退壁纸反色
  static Color get descColor {
    final custom = SpUtil.getInt(spSecondaryTextColor, defValue: -1);
    if (custom >= 0) return Color(custom);
    return WallpaperService.instance.contrastDescTextColor;
  }

  /// 等宽字体族（使用系统monospace字体，无需额外依赖）
  static const String monoFont = 'monospace';
}

/// Apple UI Design 配色与样式常量
/// 主色 #00cccc，遵循 iOS HIG 标准色板
class AppleColors {
  // ===== 间距 =====
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;

  // ===== 圆角 =====
  static const double radiusSmall = 8.0;

  /// 胶囊形输入框圆角
  static const double radiusInput = 24.0;
  static const double radiusButton = 12.0;
  static const double radiusCard = 18.0;

  // ===== 背景色 =====
  /// 主背景（页面 scaffold）
  static const Color bgPrimary = Color(0xFFF9F9F9);

  /// 卡片/内容背景
  static const Color bgSecondary = Color(0xFFFFFFFF);

  /// 三级背景（分段控件等）
  static const Color bgTertiary = Color(0xFFF2F2F7);

  // ===== 文字色 =====
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0x993C3C43);
  static const Color textTertiary = Color(0x4D3C3C43);

  // ===== 主色 =====
  static const Color accent = Color(0xFF00CCCC);

  // ===== 卡片装饰 =====
  static const Color cardBorder = Color(0xFFE5E5EA);
  static const Color cardShadow = Color(0x1A000000);

  /// 卡片纯色背景
  static const Color cardBgSolid = Color(0xFFFFFFFF);

  /// 玻璃效果边框
  static const Color glassBorder = Color(0xFFE5E5EA);

  /// 提示文字颜色
  static const Color textHint = Color(0x993C3C43);
}
