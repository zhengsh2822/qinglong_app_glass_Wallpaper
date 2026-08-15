import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/services/wallpaper_service.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/codeeditor_theme.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

var themeProvider = ChangeNotifierProvider((ref) => ThemeViewModel());

Color whiteColor = const Color(0xfff1f1f1);

int modeLight = 0;
int modeWhite = 1;
int modeDark = 2;
int modeCyber = 3;

// 主色 - 青色 (#00cccc) - Apple UI Design SKILL 配色
Color _primaryColor = const Color(0xFF00CCCC);

class ThemeViewModel extends ChangeNotifier {
  late ThemeData currentTheme;

  // 仅保留赛博模式：非赛博模式已下线，强制 modeCyber
  int _themeMode = modeCyber;

  Color primaryColor = CyberColors.cyan;

  ThemeColors themeColor = CyberThemeColors();

  // 兼容旧引用：主文字色 / 次要文字色
  // 支持用户自定义颜色（字体大小页面设置），null 时用默认主题色
  Color get customPrimaryTextColor {
    final custom = SpUtil.getInt(spPrimaryTextColor, defValue: -1);
    return custom >= 0 ? Color(custom) : themeColor.titleColor();
  }
  Color get customSecondaryTextColor {
    final custom = SpUtil.getInt(spSecondaryTextColor, defValue: -1);
    return custom >= 0 ? Color(custom) : themeColor.descColor();
  }

  /// 设置自定义主字体颜色（null 表示恢复默认）
  /// 必须调 notifyListeners 让全局 rebuild
  void setCustomPrimaryTextColor(Color? color) {
    SpUtil.putInt(spPrimaryTextColor, color?.value ?? -1);
    notifyListeners();
  }

  /// 设置自定义次字体颜色（null 表示恢复默认）
  void setCustomSecondaryTextColor(Color? color) {
    SpUtil.putInt(spSecondaryTextColor, color?.value ?? -1);
    notifyListeners();
  }

  ThemeViewModel() {
    // 老用户 SP 中可能存储了 modeLight/modeWhite/modeDark，统一迁移为 modeCyber
    final saved = SpUtil.getInt(spThemeStyle, defValue: modeCyber);
    if (saved != modeCyber) {
      SpUtil.putInt(spThemeStyle, modeCyber);
    }
    changeThemeReal(modeCyber, false);
    // 监听壁纸变化：壁纸平均色改变时，文字色需要自动反色刷新
    // 所有 watch themeProvider 的页面会 rebuild 并重新调用 titleColor()
    WallpaperService.instance.addListener(_onWallpaperChanged);
  }

  void _onWallpaperChanged() {
    // 壁纸的平均色/蒙层变化时，通知所有监听 themeProvider 的页面 rebuild
    // CyberThemeColors.titleColor() 等方法会重新读取 WallpaperService 的最新值
    notifyListeners();
  }

  @override
  void dispose() {
    WallpaperService.instance.removeListener(_onWallpaperChanged);
    super.dispose();
  }

  void changeThemeWithSystemStatus([bool must = true]) {
    // 仅赛博模式，系统跟随已下线，空实现保留兼容性
  }

  void changeTheme(int themeMode) {
    // 仅赛博模式，忽略外部传入的其他模式
    if (_themeMode == modeCyber) return;
    changeThemeReal(modeCyber);
  }

  void changeThemeReal(int themeMode, [bool notify = true]) {
    _themeMode = modeCyber;
    SpUtil.putInt(spThemeStyle, modeCyber);
    currentTheme = getCyberTheme();
    themeColor = CyberThemeColors();
    primaryColor = CyberColors.cyan;
    if (Platform.isAndroid) {
      // 沉浸式：状态栏与小白条均透明，壁纸从顶层透出
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    }
    if (notify) {
      notifyListeners();
    }
  }

  get themeMode => _themeMode;

  ThemeData getWhiteTheme() {
    return ThemeData.light().copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      splashColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        secondary: _primaryColor,
        primary: _primaryColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusSmall),
        ),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: const Color(0xFFE5E5EA),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA)),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(
          fontSize: 17,
          color: AppleColors.textTertiary,
        ),
        labelStyle: TextStyle(color: _primaryColor, fontSize: 15),
        isDense: true,
        // Apple 胶囊形输入框：圆角24，水平16/垂直12
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleColors.spaceMd,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _primaryColor, width: 2),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: AppleColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: TextStyle(color: _primaryColor),
        iconTheme: IconThemeData(color: _primaryColor),
        actionsIconTheme: IconThemeData(color: _primaryColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: AppleColors.textSecondary,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: _primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusButton),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          side: BorderSide(color: _primaryColor, width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: _primaryColor),
      tabBarTheme: TabBarTheme(
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        labelColor: _primaryColor,
        unselectedLabelColor: AppleColors.textSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      hintColor: AppleColors.textTertiary,
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.black;
        }),
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return Colors.transparent;
        }),
      ),
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: Colors.transparent,
      ),
    );
  }

  ThemeData getLightTheme() {
    return ThemeData.light().copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      splashColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        secondary: _primaryColor,
        primary: _primaryColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusSmall),
        ),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: const Color(0xFFE5E5EA),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA)),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(
          fontSize: 17,
          color: AppleColors.textTertiary,
        ),
        labelStyle: TextStyle(color: _primaryColor, fontSize: 15),
        isDense: true,
        // Apple 胶囊形输入框：圆角24，水平16/垂直12
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleColors.spaceMd,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _primaryColor, width: 2),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: TextStyle(color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: AppleColors.textSecondary,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: _primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusButton),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          side: BorderSide(color: _primaryColor, width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: _primaryColor),
      tabBarTheme: TabBarTheme(
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        labelColor: _primaryColor,
        unselectedLabelColor: AppleColors.textSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      hintColor: AppleColors.textTertiary,
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.black;
        }),
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return Colors.transparent;
        }),
      ),
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: Colors.transparent,
      ),
    );
  }

  ThemeData getDartTheme() {
    return ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: Colors.transparent,
      dividerColor: const Color(0xff444444),
      canvasColor: const Color(0xff1a1a1a),
      dividerTheme: const DividerThemeData(color: Color(0xff444444)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData().copyWith(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      brightness: Brightness.dark,
      primaryColor: const Color(0xffffffff),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: Color(0xffffffff),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: TextStyle(color: _primaryColor),
        iconTheme: IconThemeData(color: _primaryColor),
        actionsIconTheme: IconThemeData(color: _primaryColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      hintColor: const Color(0xffBBBBBB),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xffBBBBBB)),
        labelStyle: TextStyle(color: _primaryColor, fontSize: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff999999), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff999999), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff999999), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelStyle: TextStyle(fontSize: 14),
        unselectedLabelStyle: TextStyle(fontSize: 14),
        labelColor: Color(0xffffffff),
        unselectedLabelColor: Color(0xff999999),
      ),
      colorScheme: ColorScheme.dark(
        secondary: _primaryColor,
        primary: _primaryColor,
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
      ),
      cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xffffffff),
        scaffoldBackgroundColor: Colors.transparent,
      ),
    );
  }

  /// 赛博终端主题
  ThemeData getCyberTheme() {
    return ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: Colors.transparent,
      dividerColor: CyberColors.borderGlow,
      canvasColor: Colors.transparent,
      dividerTheme: const DividerThemeData(color: CyberColors.borderGlow),
      floatingActionButtonTheme: const FloatingActionButtonThemeData().copyWith(
        backgroundColor: CyberColors.cyan,
        foregroundColor: CyberColors.bg,
      ),
      brightness: Brightness.dark,
      primaryColor: CyberColors.cyan,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: CyberColors.titleWhite,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
        toolbarTextStyle: TextStyle(color: CyberColors.cyan),
        iconTheme: IconThemeData(color: CyberColors.cyan),
        actionsIconTheme: IconThemeData(color: CyberColors.cyan),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: CyberColors.cyan,
        unselectedItemColor: CyberColors.idleGray,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      hintColor: CyberColors.descColor,
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(fontSize: 14, color: CyberColors.descColor),
        labelStyle: const TextStyle(color: CyberColors.cyan, fontSize: 14),
        isDense: true,
        // 圆柱形输入框：水平 padding 加大，圆角24（胶囊形）
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.cyan, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.idleGray, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.idleGray, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.idleGray, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelStyle: TextStyle(fontSize: 14),
        unselectedLabelStyle: TextStyle(fontSize: 14),
        labelColor: CyberColors.cyan,
        unselectedLabelColor: CyberColors.idleGray,
      ),
      colorScheme: const ColorScheme.dark(
        secondary: CyberColors.cyan,
        primary: CyberColors.cyan,
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return CyberColors.bg;
          }
          return CyberColors.cyan;
        }),
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return CyberColors.cyan;
          }
          return Colors.transparent;
        }),
      ),
      cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CyberColors.cyan,
        scaffoldBackgroundColor: Colors.transparent,
      ),
    );
  }
}

abstract class ThemeColors {
  Color settingBgColor();

  Color bg2Color();

  Color blackAndWhite();

  Color codeBgColor();

  Color pinedAndWhite();

  Color settingBordorColor();

  Color titleColor();

  Color title2Color();

  Color hintColor();

  Color descColor();

  Color filterColor();

  Color tabBarColor();

  Color pinColor();

  Color searchBgColor();

  Color buttonBgColor();

  Color segmentedUnCheckBg();

  Color otherFuncBg();

  Map<String, TextStyle> codeEditorTheme();

  List<Color> appBarBg();
}

class LightThemeColors extends ThemeColors {
  @override
  Color titleColor() => AppleColors.textPrimary;

  @override
  Color pinColor() => Colors.transparent;

  @override
  Map<String, TextStyle> codeEditorTheme() => qinglongLightTheme;

  @override
  Color descColor() => const Color(0xFF666666);

  @override
  Color settingBgColor() => Colors.transparent;

  @override
  Color buttonBgColor() => _primaryColor;

  @override
  Color settingBordorColor() => Colors.transparent;

  @override
  Color tabBarColor() => Colors.transparent;

  @override
  List<Color> appBarBg() => [Colors.transparent, Colors.transparent];

  @override
  Color blackAndWhite() => Colors.white;

  @override
  Color filterColor() => AppleColors.textSecondary;

  @override
  Color title2Color() => AppleColors.textPrimary;

  @override
  Color hintColor() => AppleColors.textTertiary;

  @override
  Color bg2Color() => Colors.transparent;

  @override
  Color segmentedUnCheckBg() => AppleColors.bgTertiary;

  @override
  Color pinedAndWhite() => Colors.white;

  @override
  Color searchBgColor() => Colors.white.withOpacity(0.6);

  @override
  Color otherFuncBg() => Colors.transparent;

  @override
  Color codeBgColor() => AppleColors.bgPrimary;
}

class WhiteThemeColors extends ThemeColors {
  @override
  Color titleColor() => AppleColors.textPrimary;

  @override
  Color codeBgColor() => AppleColors.bgPrimary;

  @override
  Color pinColor() => AppleColors.bgPrimary;

  @override
  Color searchBgColor() => Colors.white.withOpacity(0.6);

  @override
  Color otherFuncBg() => Colors.transparent;

  @override
  Map<String, TextStyle> codeEditorTheme() => qinglongLightTheme;

  @override
  Color descColor() => const Color(0xFF666666);

  @override
  Color pinedAndWhite() => Colors.white;

  @override
  Color settingBgColor() => Colors.transparent;

  @override
  Color buttonBgColor() => _primaryColor;

  @override
  Color settingBordorColor() => Colors.transparent;

  @override
  Color tabBarColor() => Colors.transparent;

  @override
  List<Color> appBarBg() => [Colors.transparent, Colors.transparent];

  @override
  Color blackAndWhite() => Colors.white;

  @override
  Color filterColor() => AppleColors.textSecondary;

  @override
  Color title2Color() => AppleColors.textPrimary;

  @override
  Color hintColor() => AppleColors.textTertiary;

  @override
  Color bg2Color() => Colors.transparent;

  @override
  Color segmentedUnCheckBg() => AppleColors.bgTertiary;
}

class DartThemeColors extends ThemeColors {
  @override
  Color hintColor() {
    return const Color(0xffBBBBBB);
  }

  @override
  Color title2Color() {
    return const Color(0xffffffff);
  }

  @override
  Color filterColor() {
    return const Color(0xffffffff);
  }

  @override
  Color pinedAndWhite() {
    return pinColor();
  }

  @override
  Color blackAndWhite() {
    return const Color(0xff111111);
  }

  @override
  Color titleColor() {
    return Colors.white;
  }

  @override
  Color pinColor() {
    return const Color(0xff202020);
  }

  @override
  Map<String, TextStyle> codeEditorTheme() {
    return qinglongDarkTheme;
  }

  @override
  Color descColor() {
    return const Color(0xFF666666);
  }

  // 透明化以适配毛玻璃壁纸背景
  @override
  Color settingBgColor() => Colors.transparent;

  @override
  Color buttonBgColor() => _primaryColor;

  @override
  Color settingBordorColor() => Colors.transparent;

  @override
  Color tabBarColor() => Colors.transparent;

  @override
  List<Color> appBarBg() => [Colors.transparent, Colors.transparent];

  @override
  Color searchBgColor() => Colors.transparent;

  @override
  Color bg2Color() => Colors.transparent;

  @override
  Color otherFuncBg() => Colors.transparent;

  @override
  Color segmentedUnCheckBg() => const Color(0xff333333);

  @override
  Color codeBgColor() => const Color(0xff000000);
}

/// 赛博终端配色
///
/// 文字色会根据壁纸亮度自动反色：亮背景用深色文字，暗背景用浅色文字。
/// 由 [WallpaperService] 计算壁纸平均色和蒙层后的实际亮度决定。
///
/// 字体颜色分为两种样式（可在字体设置页自定义）：
/// - 主字体样式（标题/任务名）：[titleColor] 优先读 SP[spPrimaryTextColor]
/// - 次字体样式（时间/描述/命令）：[title2Color]/[descColor]/[hintColor]
///   优先读 SP[spSecondaryTextColor]
/// 未设置（-1）时回退到壁纸反色。
class CyberThemeColors extends ThemeColors {
  @override
  Color titleColor() {
    final custom = SpUtil.getInt(spPrimaryTextColor, defValue: -1);
    if (custom >= 0) return Color(custom);
    return WallpaperService.instance.contrastTextColor;
  }

  @override
  Color title2Color() {
    final custom = SpUtil.getInt(spSecondaryTextColor, defValue: -1);
    if (custom >= 0) return Color(custom);
    return WallpaperService.instance.contrastSubTextColor;
  }

  @override
  Color descColor() {
    final custom = SpUtil.getInt(spSecondaryTextColor, defValue: -1);
    if (custom >= 0) return Color(custom);
    return WallpaperService.instance.contrastDescTextColor;
  }

  @override
  Color hintColor() {
    final custom = SpUtil.getInt(spSecondaryTextColor, defValue: -1);
    if (custom >= 0) return Color(custom);
    return WallpaperService.instance.contrastHintTextColor;
  }

  // 透明化以适配毛玻璃壁纸背景
  @override
  Color settingBgColor() => Colors.transparent;

  @override
  Color bg2Color() => Colors.transparent;

  @override
  Color blackAndWhite() =>
      WallpaperService.instance.isLightBackground
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFE0E0FF);

  @override
  Color codeBgColor() => const Color(0xFF000000);

  @override
  Color pinedAndWhite() => const Color(0xFF1A1A2E);

  @override
  Color settingBordorColor() => CyberColors.borderGlow;

  @override
  Color filterColor() => CyberColors.cyan;

  @override
  Color tabBarColor() => Colors.transparent;

  @override
  Color pinColor() => const Color(0xFF1A1A2E);

  @override
  Color searchBgColor() => Colors.transparent;

  @override
  Color buttonBgColor() => CyberColors.cyan;

  @override
  Color segmentedUnCheckBg() => const Color(0xFF1A1A2E);

  @override
  Color otherFuncBg() => Colors.transparent;

  @override
  Map<String, TextStyle> codeEditorTheme() => qinglongDarkTheme;

  @override
  List<Color> appBarBg() => [Colors.transparent, Colors.transparent];
}
