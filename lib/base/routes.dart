import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/module/config/config_detail_page.dart';
import 'package:qinglong_app/module/config/config_edit_page.dart';
import 'package:qinglong_app/module/dashboard/dashboard_page.dart';
import 'package:qinglong_app/module/env/add_env_page.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/env/env_detail_page.dart';
import 'package:qinglong_app/module/home/home_page.dart';
import 'package:qinglong_app/module/icloud/icloud_file_page.dart';
import 'package:qinglong_app/module/icloud/icloud_page.dart';
import 'package:qinglong_app/module/login/login_page.dart';
import 'package:qinglong_app/module/others/about_page.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:qinglong_app/module/others/dependencies/add_dependency_page.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_page.dart';
import 'package:qinglong_app/module/others/login_log/login_log_page.dart';
import 'package:qinglong_app/module/others/scripts/script_add_page.dart';
import 'package:qinglong_app/module/others/scripts/script_detail_page.dart';
import 'package:qinglong_app/module/others/scripts/script_edit_page.dart';
import 'package:qinglong_app/module/others/scripts/script_page.dart';
import 'package:qinglong_app/module/others/task_log/task_log_page.dart';
import 'package:qinglong_app/module/others/jdck/jdck_page.dart';
import 'package:qinglong_app/module/others/update_password_page.dart';
import 'package:qinglong_app/module/others/wallpaper_setting_page.dart';
import 'package:qinglong_app/module/setting_page.dart';
import 'package:qinglong_app/module/subscribe/subscribe_detail_page.dart';
import 'package:qinglong_app/module/subscribe/subscribe_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/module/task/task_detail/task_detail_page.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/base/app_colors.dart';

class Routes {
  static const String routeHomePage = "/home/homepage";
  static const String routeLogin = "/login";
  static const String routeSubscribeList = "/task/subscribeList";
  static const String routeTaskDetail = "/task/detail";
  static const String routeSubscribeDetail = "/task/subscribeDetail";
  static const String routeEnvDetail = "/env/detail";
  static const String routeAddDependency = "/task/dependency";
  static const String routeAddEnv = "/env/add";
  static const String routeConfigEdit = "/config/edit";
  static const String routeConfigDetail = "/config/detail";
  static const String routeLoginLog = "/log/login";
  static const String routeTaskLog = "/log/task";
  static const String routeScript = "/script";
  static const String routeScriptDetail = "/script/detail";
  static const String routeScriptUpdate = "/script/update";
  static const String routeScriptAdd = "/script/add";
  static const String routeDependency = "/Dependency";
  static const String routeSetting = "/setting";
  static const String routeUpdatePassword = "/updatePassword";
  static const String routeAbout = "/about";
  static const String routeTheme = "/theme";
  static const String routeICloud = "/icloud";
  static const String routeDashboard = "/dashboard";
  static const String routeJdck = "/jdck";

  static const String routeIcloudFile = "/icloudfile";

  static const String routeWallpaperSetting = "/wallpaper_setting";

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case routeHomePage:
        return WallpaperPageRoute(builder: (context) => const HomePage());
      case routeLogin:
        return WallpaperPageRoute(
          builder:
              (context) => LoginPage(
                fromAddNewAccount: (settings.arguments as bool?) ?? false,
              ),
        );
      case routeICloud:
        return WallpaperPageRoute(builder: (context) => const IcloudPage());
      case routeSubscribeList:
        return WallpaperPageRoute(builder: (context) => const SubscribePage());
      case routeDashboard:
        return WallpaperPageRoute(builder: (context) => const DashboardPage());
      case routeSetting:
        return WallpaperPageRoute(builder: (context) => const SettingPage());
      case routeIcloudFile:
        return WallpaperPageRoute(builder: (context) => const IcloudFilePage());

      case routeAddDependency:
        return WallpaperPageRoute(
          builder: (context) => const AddDependencyPage(),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeAddEnv:
        if (settings.arguments != null) {
          return WallpaperPageRoute(
            builder:
                (context) => AddEnvPage(envBean: settings.arguments as EnvBean),
          );
        } else {
          return WallpaperPageRoute(builder: (context) => const AddEnvPage());
        }
      case routeConfigEdit:
        return WallpaperPageRoute(
          builder:
              (context) => ConfigEditPage(
                (settings.arguments as Map)["title"],
                (settings.arguments as Map)["content"],
              ),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeConfigDetail:
        return WallpaperPageRoute(
          builder:
              (context) => ConfigDetailPage(
                bean: (settings.arguments as Map)["bean"],
                content: (settings.arguments as Map)["content"],
              ),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeLoginLog:
        return WallpaperPageRoute(
          builder: (context) => const LoginLogPage(),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeTaskLog:
        if (settings.arguments != null) {
          return WallpaperPageRoute(
            builder:
                (context) => TaskLogPage(
                  searchText: (settings.arguments as Map)["search"],
                ),
            blurSigma: 6,
            blurTintColor: CyberColors.bg.withOpacity(0.50),
          );
        } else {
          return WallpaperPageRoute(
            builder: (context) => TaskLogPage(),
            blurSigma: 6,
            blurTintColor: CyberColors.bg.withOpacity(0.50),
          );
        }
      case routeScript:
        return WallpaperPageRoute(
          builder: (context) => const ScriptPage(),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeDependency:
        return WallpaperPageRoute(builder: (context) => const DependencyPage());
      case routeScriptDetail:
        return WallpaperPageRoute(
          builder:
              (context) => ScriptDetailPage(
                title: (settings.arguments as Map)["title"],
                path: (settings.arguments as Map)["path"],
              ),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeTaskDetail:
        return WallpaperPageRoute(
          builder: (context) => TaskDetailPage(settings.arguments as TaskBean),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeSubscribeDetail:
        return WallpaperPageRoute(
          builder:
              (context) => SubscribeDetailPage(
                settings.arguments as Map<String, dynamic>,
              ),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeEnvDetail:
        return WallpaperPageRoute(
          builder: (context) => EnvDetailPage(settings.arguments as EnvBean),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeUpdatePassword:
        return WallpaperPageRoute(
          builder: (context) => const UpdatePasswordPage(),
        );
      case routeAbout:
        return WallpaperPageRoute(
          builder: (context) => const AboutPage(),
        );
      case routeScriptUpdate:
        return WallpaperPageRoute(
          builder:
              (context) => ScriptEditPage(
                (settings.arguments as Map)["title"],
                (settings.arguments as Map)["path"],
                (settings.arguments as Map)["content"],
              ),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeScriptAdd:
        return WallpaperPageRoute(
          builder:
              (context) => ScriptAddPage(
                (settings.arguments as Map)["title"],
                (settings.arguments as Map)["path"],
              ),
          blurSigma: 6,
          blurTintColor: CyberColors.bg.withOpacity(0.50),
        );
      case routeJdck:
        return WallpaperPageRoute(builder: (context) => const JdckPage());
      case routeWallpaperSetting:
        return WallpaperPageRoute(
          builder: (context) => const WallpaperSettingPage(),
        );
    }

    return null;
  }
}
