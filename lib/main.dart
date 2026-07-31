import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/services/wallpaper_service.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/animated_indexed_switch.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/wallpaper_background.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/module/home/home_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth_android/local_auth_android.dart';

final getIt = GetIt.instance;
var navigatorState = GlobalKey<NavigatorState>();
bool openAuth = false;
var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SpUtil.getInstance();
  // 壁纸服务：加载用户壁纸配置（与壁纸背景组件配合）
  await WallpaperService.instance.init();
  getIt.registerSingleton<MultiAccountUserInfoViewModel>(
    MultiAccountUserInfoViewModel(),
  );
  MultiAccountUserInfoViewModel.payedVIP(typeSVIP);
  getIt.get<MultiAccountUserInfoViewModel>().initVipState();
  openAuth = SpUtil.getBool(spOpenAuth, defValue: false);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // 安卓小白条 + 状态栏沉浸效果（通用 edgeToEdge 方案，澎湃OS 亦兼容）
  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(ProviderScope(overrides: [themeProvider], child: const QlApp()));
  ErrorWidget.builder = (FlutterErrorDetails flutterErrorDetail) {
    debugPrint('ERRORWIDGET: ${flutterErrorDetail.exceptionAsString()}');
    return Scaffold(
      backgroundColor: Colors.white,
      body: Builder(
        builder: (context) {
          return GestureDetector(
            onDoubleTap: () {
              showCupertinoDialog(
                context: context,
                useRootNavigator: false,
                builder:
                    (childContext) => CupertinoAlertDialog(
                      title: const Text("温馨提示"),
                      content: const Text("确定要还原App所有配置吗,本次操作不可逆?"),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text("取消"),
                          onPressed: () {
                            Navigator.of(childContext).pop();
                          },
                        ),
                        CupertinoDialogAction(
                          child: const Text("确定"),
                          onPressed: () {
                            SpUtil.clear();
                            "已完成,请重启App".toast();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
              );
            },
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("报错了:${flutterErrorDetail.exceptionAsString()}", maxLines: 5),
                    const SizedBox(height: 5),
                    const Text(
                      "请尝试右滑退出页面,或者重启App,如果打开App之后就报错,一直无法进入首页正常操作,请双击这段文字,清空所有本地配置数据(不会删除本地备份的数据文件),恢复App原始状态,注意,此操作不可逆",
                      maxLines: 10,
                      style: TextStyle(color: Color(0xffFB5858)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  };
}

class QlApp extends ConsumerStatefulWidget {
  const QlApp({Key? key}) : super(key: key);

  @override
  ConsumerState<QlApp> createState() => QlAppState();
}

class QlAppState extends ConsumerState<QlApp> with WidgetsBindingObserver {
  double textScaleFactor = 1;
  @override
  void initState() {
    textScaleFactor = SpUtil.getDouble(spTextScaleFactor, defValue: 1.0);
    super.initState();
    if (Platform.isAndroid) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        fetchAll();
      });
    }
  }

  Future<void> fetchAll() async {
    if (Platform.isAndroid) {
      try {
        await FlutterDisplayMode.setHighRefreshRate();
      } catch (e) {
        // ignore
      }
    }
    setState(() {});
  }

  void updateTextScaleFactor(double target) {
    if (textScaleFactor == target) return;
    textScaleFactor = target;
    SpUtil.putDouble(spTextScaleFactor, textScaleFactor);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch<ThemeViewModel>(themeProvider).currentTheme;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "青龙客户端",
      locale: const Locale('zh', 'CN'),
      navigatorKey: navigatorState,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: EasyLoading.init(
        builder: (BuildContext context, Widget? child) {
          EasyLoading.instance.indicatorWidget = const LoadingWidget(
            color: Colors.white,
          );
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(textScaleFactor),
              viewInsets:
                  mediaQuery.viewInsets == EdgeInsets.zero
                      ? mediaQuery.viewInsets
                      : EdgeInsets.zero,
            ),
            child: ScrollConfiguration(
              behavior: const ScrollPhysicsConfig(),
              child: AnimatedTheme(
                data: theme,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
                child: Stack(
                  children: [
                    const Positioned.fill(child: WallpaperBackground()),
                    if (child != null) child,
                  ],
                ),
              ),
            ),
          );
        },
      ),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      theme: theme,
      home: const MultiAccountPage(),
      // home: LoginPage(),
    );
  }
}

class ScrollPhysicsConfig extends ScrollBehavior {
  const ScrollPhysicsConfig();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.android:
        return const BouncingScrollPhysics();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics();
      default:
        return const BouncingScrollPhysics();
    }
  }
}

class MultiAccountPage extends ConsumerStatefulWidget {
  const MultiAccountPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MultiAccountPage> createState() => MultiAccountPageState();
}

class MultiAccountPageState extends ConsumerState<MultiAccountPage>
    with WidgetsBindingObserver {
  int _index = 0;

  /// 当前激活账号索引，供 Http.exitLogin 判断是否在后台账号
  static int currentAccountIndex = 0;

  List<Widget> list = [];

  get index => _index;

  bool authenticated = false;

  void updateIndex(int index) {
    if (_index == index) return;
    _index = index;
    currentAccountIndex = index;
    setState(() {});

    // 切换到新账号后，检查该账号是否有待处理的登录失败弹窗
    // 用 postFrameCallback 确保切换动画完成后再弹窗
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final http = getIt<Http>(instanceName: index.toString());
      if (http.pendingExitLogin) {
        http.pendingExitLogin = false;
        http.exitLogin();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const String actionRunAll = "runAllTask";
  static const String actionEditConfig = "editConfig";
  static String _action = "";

  static String useAction() {
    return _action;
  }

  static void clearAction() {
    _action = "";
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    if (SpUtil.getBool(spSingleInstance, defValue: false)) {
      list = [const RepaintBoundary(child: SingleAccountPage(index: 0))];
    } else {
      list = List<Widget>.generate(MultiAccountUserInfoViewModel.maxAccount, (
        i,
      ) {
        return RepaintBoundary(child: SingleAccountPage(index: i));
      });
    }
    if (!openAuth) {
      authenticated = true;
    }
    super.initState();
    currentAccountIndex = 0;
    WidgetsBinding.instance.addObserver(this);

    var platformDispatcher = WidgetsBinding.instance.platformDispatcher;
    platformDispatcher.onPlatformBrightnessChanged = () {
      ref.read(themeProvider.notifier).changeThemeWithSystemStatus(false);
    };

    initAuth();
  }

  final LocalAuthentication auth = LocalAuthentication();

  void authMe() {
    auth
        .authenticate(
          localizedReason: "请验证你的身份",
          authMessages: [
            const AndroidAuthMessages(
              signInTitle: '请验证你的身份',
              cancelButton: '取消',
            ),
          ],
        )
        .then((value) {
          authenticated = value;
          setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        var key = getIt.get<GlobalKey<NavigatorState>>(
          instanceName: _index.toString(),
        );
        if (key.currentState != null && key.currentState!.canPop()) {
          key.currentState!.pop();
        } else {
          SystemNavigator.pop();
        }
      },
      child:
          !authenticated
              ? authWidget()
              : (list.length == 1
                  ? list.first
                  : IndexedStack(index: _index, children: list)),
    );
  }

  Widget authWidget() {
    return Center(
      child: GestureDetector(
        onTap: () {
          authMe();
        },
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            ref.watch(themeProvider).primaryColor,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            faceID ? "assets/images/faceid.png" : "assets/images/figure.png",
            width: 50,
            height: 50,
          ),
        ),
      ),
    );
  }

  bool faceID = false;

  void initAuth() async {
    if (!openAuth) return;
    final isAvailable = await auth.canCheckBiometrics;
    final isDeviceSupported = await auth.isDeviceSupported();
    if (isAvailable && isDeviceSupported) {
      final List<BiometricType> availableBiometrics =
          await auth.getAvailableBiometrics();
      if (availableBiometrics.contains(BiometricType.face)) {
        faceID = true;
      } else {
        faceID = false;
      }
      setState(() {});

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        authMe();
      });
    } else {
      authenticated = true;
      setState(() {});
    }
  }
}
