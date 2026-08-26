import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// 液态玻璃胶囊形状工具 —— 苹果（浅色）/ 赛博两套视觉。
///
/// 对齐 demos/liquid_glass_easy/example/lib/tab_bar_page.dart 的
/// `_glassShape` / `_cyberShape`，供底部导航（home_page）与顶部 tab
/// （glass_segmented_tab）复用，避免两处重复定义。

/// 苹果风格胶囊：半透明毛玻璃 + 柔和光学边框（浅色主题 / 非赛博）。
/// 对齐官方 LiquidGlassNavBarMotionPill 默认（borderSolidity 0.5、lightIntensity
/// 1.3）：rim 高光变细（≈1px 细线），不再因 borderSolidity 0.95 全实而显粗。
LiquidGlassShape glassShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.4, // 配合 _fullBorderWidth 收紧补偿，rim 高光约 1px 细线
      lightIntensity: 1.3,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.4,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    );

/// 赛博风格胶囊：深色底 + 光学边框。外圈高光用默认白色 lightColor（不带青色），
/// 深色背景上更清晰；青色仅作为胶囊内部 tint / 文字高亮。
LiquidGlassShape cyberShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.5, // 配合 _fullBorderWidth 收紧补偿，rim 高光约 1px 细线
      lightIntensity: 1.0,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.2,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    );
