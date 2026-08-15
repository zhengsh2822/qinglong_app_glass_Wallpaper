import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 京东助手页面
/// 集成自 jdck_flutter 项目，适配青龙客户端主题系统
/// 功能：WebView登录京东、获取Cookie、上传至青龙面板环境变量、账号管理、备份恢复
class JdckPage extends ConsumerStatefulWidget {
  const JdckPage({Key? key}) : super(key: key);

  @override
  ConsumerState<JdckPage> createState() => _JdckPageState();
}

class _JdckPageState extends ConsumerState<JdckPage> {
  static const String _jdUrl = 'https://home.m.jd.com/myJd/home.action';
  static const MethodChannel _cookieChannel = MethodChannel(
    'com.qlapp.qinglong_app/cookies',
  );
  static const EventChannel _smsChannel = EventChannel(
    'com.qlapp.qinglong_app/sms',
  );

  // SharedPreferences keys — 按账号索引隔离，每个账号独立存储
  // 历史数据（无后缀的 key）不再读取，首次写入即建立按账号独立的数据
  int _accountIndex = 0;

  String get _spPhoneStr => 'jdck_phoneStr_$_accountIndex';
  String get _spSelectedPhone => 'jdck_selectedPhone_$_accountIndex';
  String get _spPasswordHidden => 'jdck_passwordHidden_$_accountIndex';
  String get _spSmsEnabled => 'jdck_smsEnabled_$_accountIndex';
  String get _spQlAddress => 'jdck_ql_address_$_accountIndex';
  String get _spQlClientId => 'jdck_ql_client_id_$_accountIndex';
  String get _spQlClientSecret => 'jdck_ql_client_secret_$_accountIndex';
  String get _spQlToken => 'jdck_ql_token_$_accountIndex';

  late WebViewController _webViewController;
  bool _webViewReady = false;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editPasswordController = TextEditingController();
  final TextEditingController _qlAddressController = TextEditingController();
  final TextEditingController _qlClientIdController = TextEditingController();
  final TextEditingController _qlClientSecretController =
      TextEditingController();
  final TextEditingController _restoreController = TextEditingController();
  final GlobalKey _selectorKey = GlobalKey();

  SharedPreferences? _prefs;
  Set<String> _phoneSet = {};
  String? _selectedPhone;
  String? _cookie;
  bool _isLoading = true;
  bool _smsEnabled = false;
  bool _passwordHidden = true;

  // 青龙面板独立登录状态
  String? _qlToken;
  bool _qlLoggedIn = false;
  bool _qlChecking = false;

  StreamSubscription<dynamic>? _smsSubscription;

  /// 路由转场动画监听 — 等动画结束后再初始化 WebView，避免进入页面时掉帧
  bool _routeListenerAdded = false;
  Animation<double>? _routeAnimation;

  /// 账号选择器显示标志 — 跟随页面 lifecycle，tabbar 切换时自动隐藏
  bool _showPhoneList = false;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  @override
  void initState() {
    super.initState();
    // 仅加载本地配置（轻量），不阻塞转场动画
    // WebView 延迟到转场动画完成后初始化，避免进入页面时掉帧
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadConfig();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 获取当前账号索引，用于按账号隔离京东助手数据
    _accountIndex = SingleAccountPageState.of(context)?.index ?? 0;
    if (_webViewReady || _routeListenerAdded) return;
    _routeListenerAdded = true;
    _routeAnimation = ModalRoute.of(context)?.animation;
    if (_routeAnimation == null || _routeAnimation!.isCompleted) {
      // 无转场动画或动画已结束，直接初始化
      _initWebViewDeferred();
    } else {
      // 等待转场动画完成后初始化 WebView，避免动画掉帧
      _routeAnimation!.addStatusListener(_onRouteAnimationComplete);
    }
  }

  void _onRouteAnimationComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationComplete);
      _initWebViewDeferred();
    }
  }

  void _initWebViewDeferred() {
    if (!mounted || _webViewReady) return;
    _initWebView();
    setState(() => _webViewReady = true);
  }

  void _initWebView() {
    final cookieManager = WebViewCookieManager();
    cookieManager.clearCookies();
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                if (mounted) setState(() => _isLoading = true);
              },
              onPageFinished: (url) {
                if (mounted) setState(() => _isLoading = false);
                _getCookies(url);
              },
            ),
          )
          ..loadRequest(Uri.parse(_jdUrl));
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await _getPrefs();
      final phoneStr = prefs.getString(_spPhoneStr);
      if (phoneStr != null && phoneStr.isNotEmpty && mounted) {
        setState(() {
          _phoneSet = phoneStr.split('\n').toSet();
          _selectedPhone = prefs.getString(_spSelectedPhone);
          _passwordHidden = prefs.getBool(_spPasswordHidden) ?? true;
          if (_selectedPhone != null && !_phoneSet.contains(_selectedPhone)) {
            _selectedPhone = null;
          }
          if (_selectedPhone == null && _phoneSet.isNotEmpty) {
            _selectedPhone = _phoneSet.first;
          }
        });
      }
      _smsEnabled = prefs.getBool(_spSmsEnabled) ?? false;

      // 加载青龙面板登录配置
      _qlAddressController.text =
          prefs.getString(_spQlAddress) ??
          (SingleAccountPageState.ofUserInfo(context).host ?? '');
      _qlClientIdController.text = prefs.getString(_spQlClientId) ?? '';
      _qlClientSecretController.text = prefs.getString(_spQlClientSecret) ?? '';
      _qlToken = prefs.getString(_spQlToken);

      // 如果有token，尝试验证
      if (_qlToken != null && _qlToken!.isNotEmpty) {
        _checkQlLogin();
      }

      // 自动获取AppKey中的clientId/clientSecret（如果未配置）
      if (_qlClientIdController.text.isEmpty) {
        _autoFetchAppKey();
      }

      await _applySmsListening();
    } catch (e) {
      debugPrint('Load config error: $e');
    }
  }

  /// 自动从应用管理中获取clientId和clientSecret
  Future<void> _autoFetchAppKey() async {
    try {
      final api = SingleAccountPageState.ofApi(context);
      final response = await api.appKeys();
      if (!response.success || response.bean == null) return;

      final List<dynamic> tempList = jsonDecode(response.bean ?? '[]');
      if (tempList.isEmpty) return;

      // 优先选择有envs权限的应用
      Map<String, dynamic>? bestApp;
      for (final item in tempList) {
        final app = item as Map<String, dynamic>;
        final scopes = app['scopes'] as List<dynamic>?;
        if (scopes != null && scopes.contains('envs')) {
          bestApp = app;
          break;
        }
      }
      // 如果没有envs权限的，取第一个
      bestApp ??= tempList.first as Map<String, dynamic>;

      final clientId = bestApp['client_id']?.toString() ?? '';
      final clientSecret = bestApp['client_secret']?.toString() ?? '';

      if (clientId.isNotEmpty && mounted) {
        setState(() {
          _qlClientIdController.text = clientId;
          _qlClientSecretController.text = clientSecret;
        });
        final prefs = await _getPrefs();
        await prefs.setString(_spQlClientId, clientId);
        await prefs.setString(_spQlClientSecret, clientSecret);
      }
    } catch (e) {
      debugPrint('Auto fetch AppKey error: $e');
    }
  }

  /// 验证青龙token是否有效
  Future<void> _checkQlLogin() async {
    if (_qlToken == null || _qlToken!.isEmpty) return;
    setState(() => _qlChecking = true);
    try {
      final address = _normalizeAddress(_qlAddressController.text);
      final response = await _dio.get(
        '$address/open/envs?searchValue=',
        options: Options(headers: {'Authorization': 'Bearer $_qlToken'}),
      );
      if (response.statusCode == 200) {
        final res = response.data;
        if (res is Map && res['code'] == 200) {
          if (mounted) setState(() => _qlLoggedIn = true);
          return;
        }
      }
      // token无效
      if (mounted) {
        setState(() {
          _qlLoggedIn = false;
          _qlToken = null;
        });
        '青龙token已失效，请重新登录'.toast();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qlLoggedIn = false;
          _qlToken = null;
        });
        '青龙token验证失败'.toast();
      }
    } finally {
      if (mounted) setState(() => _qlChecking = false);
    }
  }

  /// 登录青龙面板（通过clientId/clientSecret获取token）
  Future<void> _loginQinglong() async {
    final address = _qlAddressController.text.trim();
    final clientId = _qlClientIdController.text.trim();
    final clientSecret = _qlClientSecretController.text.trim();

    if (address.isEmpty) {
      '请输入青龙面板地址'.toast();
      return;
    }
    if (clientId.isEmpty || clientSecret.isEmpty) {
      '请输入Client ID和Client Secret'.toast();
      return;
    }

    setState(() => _qlChecking = true);
    try {
      final normalizedAddr = _normalizeAddress(address);
      final encodedClientId = Uri.encodeComponent(clientId);
      final encodedClientSecret = Uri.encodeComponent(clientSecret);
      final response = await _dio.get(
        '$normalizedAddr/open/auth/token?client_id=$encodedClientId&client_secret=$encodedClientSecret',
      );

      if (response.statusCode != 200) {
        throw Exception('服务器${response.statusCode}错误');
      }

      final res = response.data;
      if (res is! Map || res['code'] != 200) {
        throw Exception(res is Map ? res['message'] : '登录失败');
      }

      final token = res['data']?['token'];
      if (token == null || token.toString().isEmpty) {
        throw Exception('获取token失败');
      }

      // 保存配置
      final prefs = await _getPrefs();
      await prefs.setString(_spQlAddress, address);
      await prefs.setString(_spQlClientId, clientId);
      await prefs.setString(_spQlClientSecret, clientSecret);
      await prefs.setString(_spQlToken, token);

      if (mounted) {
        setState(() {
          _qlToken = token;
          _qlLoggedIn = true;
        });
        '青龙面板登录成功'.toast();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) '登录失败: $e'.toast();
    } finally {
      if (mounted) setState(() => _qlChecking = false);
    }
  }

  /// 退出青龙面板登录
  Future<void> _logoutQinglong() async {
    final prefs = await _getPrefs();
    await prefs.remove(_spQlToken);
    if (mounted) {
      setState(() {
        _qlToken = null;
        _qlLoggedIn = false;
      });
      '已退出青龙面板登录'.toast();
    }
  }

  String _normalizeAddress(String addr) {
    var a = addr.trim();
    if (a.endsWith('/')) a = a.substring(0, a.length - 1);
    return a;
  }

  void _injectSmsCode(String code) {
    var js = "var code='$code';";
    js += "if(document.getElementById('authcode')){";
    js += "document.getElementById('authcode').value=code;";
    js +=
        "var evt=new InputEvent('input',{inputType:'insertText',data:code,dataTransfer:null,isComposing:false});";
    js += "document.getElementById('authcode').dispatchEvent(evt);";
    js += "}";
    _webViewController.runJavaScript(js);
    '已填入验证码: $code'.toast();
  }

  Future<void> _applySmsListening() async {
    if (_smsEnabled) {
      _smsSubscription ??= _smsChannel.receiveBroadcastStream().listen((event) {
        if (event is String && mounted) {
          _injectSmsCode(event);
        }
      });
    } else {
      await _smsSubscription?.cancel();
      _smsSubscription = null;
    }
  }

  Future<void> _getCookies(String url) async {
    try {
      final String? cookies = await _cookieChannel.invokeMethod('getCookies', {
        'url': 'https://home.m.jd.com',
      });
      if (cookies != null && cookies.isNotEmpty && mounted) {
        setState(() => _cookie = cookies);
      }
    } catch (e) {
      debugPrint('Get cookies error: $e');
    }
  }

  Future<void> _savePhones() async {
    final prefs = await _getPrefs();
    await prefs.setString(_spPhoneStr, _phoneSet.join('\n'));
    if (_selectedPhone != null) {
      await prefs.setString(_spSelectedPhone, _selectedPhone!);
    } else {
      await prefs.remove(_spSelectedPhone);
    }
  }

  static String _escapeJs(String s) =>
      s.replaceAll("\\", "\\\\").replaceAll("'", "\\'");

  void _inputPhone() {
    if (_selectedPhone == null) {
      '请先选择账号'.toast();
      return;
    }
    final info = _selectedPhone!.split(' ');
    final phone = info[0];
    var js = "var account='${_escapeJs(phone)}';";
    js += "document.getElementsByClassName('policy_tip-checkbox')[0].click();";
    js +=
        "var evt=new InputEvent('input',{inputType:'insertText',data:account,dataTransfer:null,isComposing:false});";
    js += "document.getElementById('username').value=account;";
    js += "document.getElementById('username').dispatchEvent(evt);";
    if (RegExp(r'^1\d{10}$').hasMatch(phone)) {
      js +=
          "document.getElementsByClassName('acc-input mobile J_ping')[0].value=account;";
      js +=
          "document.getElementsByClassName('acc-input mobile J_ping')[0].dispatchEvent(evt);";
    }
    if (info.length > 1) {
      final pwd = info[1];
      js += "var password='${_escapeJs(pwd)}';";
      js +=
          "var evt2=new InputEvent('input',{inputType:'insertText',data:password,dataTransfer:null,isComposing:false});";
      js += "document.getElementById('pwd').value=password;";
      js += "document.getElementById('pwd').dispatchEvent(evt2);";
      js += "document.querySelector('#app>div>a').click()";
    }
    _webViewController.runJavaScript(js);
  }

  /// 获取Cookie并上传至青龙面板
  /// 校验流程：1.检查Cookie是否存在 2.检查pt_key/pt_pin 3.检查青龙登录状态 4.上传
  void _getCookie() {
    // 校验1：Cookie是否存在
    if (_cookie == null || _cookie!.isEmpty) {
      '未获取到Cookie，请先登录京东'.toast();
      return;
    }
    final map = _formatCookies(_cookie!);
    final ptKey = map['pt_key'];
    final ptPin = map['pt_pin'];

    // 校验2：pt_key和pt_pin必须同时存在
    if (ptKey == null || ptKey.isEmpty || ptPin == null || ptPin.isEmpty) {
      'Cookie无效，缺少pt_key或pt_pin，请先登录京东'.toast();
      return;
    }

    // 校验3：检查青龙面板登录状态
    if (!_qlLoggedIn || _qlToken == null || _qlToken!.isEmpty) {
      '请先登录青龙面板'.toast();
      _showQlLoginDialog();
      return;
    }

    final cookie = 'pt_key=$ptKey;pt_pin=$ptPin;';
    Clipboard.setData(ClipboardData(text: cookie));
    '获取成功，已复制到剪切板，正在上传至青龙面板'.toast();
    _updateCookie(cookie);
  }

  Map<String, String> _formatCookies(String cookieString) {
    Map<String, String> cookieMap = {};
    if (cookieString.isNotEmpty) {
      final cookies = cookieString.split(';');
      for (final parameter in cookies) {
        final eqIndex = parameter.indexOf('=');
        if (eqIndex > -1) {
          final k = parameter.substring(0, eqIndex).trim();
          final v = parameter.substring(eqIndex + 1).trim();
          if (v.isNotEmpty) {
            cookieMap[k] = v;
          }
        }
      }
    }
    return cookieMap;
  }

  /// 上传Cookie至青龙面板环境变量
  /// 使用独立登录的token调用/open/envs接口
  Future<void> _updateCookie(String cookie) async {
    try {
      final address = _normalizeAddress(_qlAddressController.text);
      final headers = {
        'Authorization': 'Bearer $_qlToken',
        'Content-Type': 'application/json',
      };

      // 获取现有环境变量列表
      final listResponse = await _dio.get(
        '$address/open/envs?searchValue=JD_COOKIE',
        options: Options(headers: headers),
      );

      if (listResponse.statusCode != 200) {
        throw Exception('获取环境变量失败，服务器${listResponse.statusCode}错误');
      }

      final listRes = listResponse.data;
      if (listRes is! Map || listRes['code'] != 200) {
        throw Exception(listRes is Map ? listRes['message'] : '获取环境变量失败');
      }

      // 解析环境变量列表
      final List rawList;
      if (listRes['data'] is List) {
        rawList = listRes['data'] as List;
      } else {
        rawList = [];
      }

      final ptPin = _formatCookies(cookie)['pt_pin'];
      Map<String, dynamic>? targetEnv;
      for (final e in rawList) {
        final env = e as Map<String, dynamic>;
        if ((env['value'] ?? '').toString().contains('pt_pin=$ptPin')) {
          targetEnv = env;
          break;
        }
      }

      final remarks = _selectedPhone?.split(' ')[0] ?? '';
      final Map<String, dynamic> envData = {
        'name': 'JD_COOKIE',
        'value': cookie,
        'remarks': remarks,
      };

      late final Response saveResponse;

      if (targetEnv != null) {
        // 更新已有环境变量
        final envId = targetEnv['_id'] ?? targetEnv['id'];
        envData['id'] =
            envId is int ? envId : int.tryParse(envId.toString()) ?? envId;
        saveResponse = await _dio.put(
          '$address/open/envs',
          options: Options(headers: headers),
          data: jsonEncode(envData),
        );
      } else {
        // 新增环境变量
        saveResponse = await _dio.post(
          '$address/open/envs',
          options: Options(headers: headers),
          data: jsonEncode([envData]),
        );
      }

      if (saveResponse.statusCode != 200) {
        throw Exception('上传失败，服务器${saveResponse.statusCode}错误');
      }

      final saveRes = saveResponse.data;
      if (saveRes is! Map || saveRes['code'] != 200) {
        throw Exception(saveRes is Map ? saveRes['message'] : '上传失败');
      }

      // 如果是更新，尝试启用环境变量
      if (targetEnv != null) {
        final envId = targetEnv['_id'] ?? targetEnv['id'];
        final idValue = envId is int ? envId : int.tryParse(envId.toString());
        if (idValue != null) {
          try {
            await _dio.put(
              '$address/open/envs/enable',
              options: Options(headers: headers),
              data: jsonEncode([idValue]),
            );
          } catch (e) {
            debugPrint('Enable env error: $e');
          }
        }
      }

      // 只有上传成功才显示成功提示
      if (mounted) {
        '更新Cookie成功'.toast();
      }
    } catch (e) {
      if (mounted) {
        '上传Cookie失败: $e'.toast();
      }
    }
  }

  Future<void> _resetWebView() async {
    await _webViewController.clearCache();
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();
    setState(() {
      _cookie = null;
      _isLoading = true;
    });
    await _webViewController.loadRequest(Uri.parse(_jdUrl));
  }

  Future<void> _toggleSms() async {
    if (!_smsEnabled) {
      final status = await Permission.sms.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.sms.request();
        if (!result.isGranted) {
          if (mounted) '需要短信权限才能自动填入验证码'.toast();
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() => _smsEnabled = !_smsEnabled);
    final prefs = await _getPrefs();
    await prefs.setBool(_spSmsEnabled, _smsEnabled);
    await _applySmsListening();
    if (mounted) {
      _smsEnabled ? '短信识别已开启'.toast() : '短信识别已关闭'.toast();
    }
  }

  // ==================== Apple UI 模糊弹窗 ====================

  /// 显示Apple UI风格模糊弹窗（非赛博模式）
  Future<T?> _showBlurDialog<T>({
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) {
    final isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final isDark = ref.read(themeProvider).themeMode == modeDark;

    // 弹窗卡片采用 frosted glass 效果（半透明 + 高斯模糊）
    // - 赛博模式：黑色 0.5 半透明 + 青色边框 + 青色阴影
    // - 暗黑主题：深色 0.5 半透明
    // - 白色主题：白色 0.5 半透明
    final Color cardBg;
    final Color borderColor;
    final Color shadowColor;
    if (isCyber) {
      cardBg = const Color(0x80000000);
      borderColor = CyberColors.cyan.withValues(alpha: 0.3);
      shadowColor = CyberColors.cyan.withValues(alpha: 0.08);
    } else if (isDark) {
      cardBg = const Color(0x801C1C1E);
      borderColor = const Color(0x33FFFFFF);
      shadowColor = const Color(0x1F000000);
    } else {
      cardBg = const Color(0x80FFFFFF);
      borderColor = const Color(0x1A000000);
      shadowColor = const Color(0x1F000000);
    }

    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'BlurDialog',
      // barrierColor 设为透明，遮罩改由 pageBuilder 内的 Stack 全屏 BackdropFilter 实现
      // 这样可以同时覆盖 WebView 等原生视图（Flutter barrier 对原生层无效）
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      // 过渡动画在 pageBuilder 内用 AnimatedBuilder 实现，让 BackdropFilter 的 sigma
      // 跟随动画同步展开（BackdropFilter 不受 Opacity 影响，必须手动绑定 sigma）
      transitionBuilder:
          (context, animation, secondaryAnimation, child) => child,
      pageBuilder: (context, animation, secondaryAnimation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        // 内容只创建一次，避免 AnimatedBuilder 重建导致输入框失焦
        final content = builder(context);
        return AnimatedBuilder(
          animation: curved,
          builder: (context, _) {
            final t = curved.value;
            final maskBaseSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 5.0);
            final cardBaseSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 10.0);
            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // 全屏蒙版 — sigma 和暗色透明度跟随动画同步从 0 展开
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: maskBaseSigma * t,
                          sigmaY: maskBaseSigma * t,
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.5 * t),
                        ),
                      ),
                    ),
                  ),
                  // 弹窗卡片 — scale + fade + BackdropFilter 同步展开
                  Center(
                    child: Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.92 + 0.08 * t,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: cardBaseSigma * t,
                                  sigmaY: cardBaseSigma * t,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    28,
                                    28,
                                    24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: SingleChildScrollView(child: content),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _dialogTextColor() {
    final isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final isDark = ref.read(themeProvider).themeMode == modeDark;
    if (isCyber) return CyberColors.titleWhite;
    if (isDark) return Colors.white;
    return AppleColors.textPrimary;
  }

  Color _dialogSubTextColor() {
    final isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final isDark = ref.read(themeProvider).themeMode == modeDark;
    if (isCyber) return const Color(0xFFB8BFC9);
    if (isDark) return const Color(0xFFAEAEB2);
    return AppleColors.textSecondary;
  }

  Color _dialogPrimaryColor() {
    final isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return isCyber ? CyberColors.cyan : ref.read(themeProvider).primaryColor;
  }

  // ==================== 弹窗：青龙面板登录 ====================

  void _showQlLoginDialog() {
    final textColor = _dialogTextColor();
    final subTextColor = _dialogSubTextColor();
    final primaryColor = _dialogPrimaryColor();

    _showBlurDialog(
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud, color: primaryColor, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '青龙面板登录',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (_qlLoggedIn)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '已登录',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF34C759),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '通过Client ID和Client Secret登录青龙面板开放API，用于上传Cookie至环境变量。可在应用管理中自动获取。',
                      style: TextStyle(
                        fontSize: 13,
                        color: subTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDialogTextField(
                      controller: _qlAddressController,
                      label: '面板地址',
                      hint: 'http://ip:5700',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: _qlClientIdController,
                      label: 'Client ID',
                      hint: '应用ID',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: _qlClientSecretController,
                      label: 'Client Secret',
                      hint: '应用密钥',
                      obscureText: true,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 16),
                    // 自动获取按钮
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await _autoFetchAppKey();
                          if (mounted) setDialogState(() {});
                          if (_qlClientIdController.text.isNotEmpty) {
                            '已自动获取Client ID'.toast();
                          } else {
                            '未找到应用，请先在应用管理中创建'.toast();
                          }
                        },
                        icon: Icon(
                          Icons.auto_fix_high,
                          size: 18,
                          color: primaryColor,
                        ),
                        label: Text(
                          '自动获取',
                          style: TextStyle(color: primaryColor, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                color: subTextColor.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _qlChecking ? null : _loginQinglong,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor:
                                  isDarkModeForDialog()
                                      ? Colors.white
                                      : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                _qlChecking
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text('登录'),
                          ),
                        ),
                      ],
                    ),
                    if (_qlLoggedIn) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _logoutQinglong();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Text('退出登录'),
                      ),
                    ],
                  ],
                ),
          ),
    );
  }

  bool isDarkModeForDialog() {
    final mode = ref.read(themeProvider).themeMode;
    return mode == modeCyber || mode == modeDark;
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color textColor,
    required Color subTextColor,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    // 标签/提示三模式分离：
    // 赛博模式用浅灰色（黑底卡片上清晰）
    // 非赛博模式用深灰色（白底卡片上清晰）
    final bool isCyberField = ref.read(themeProvider).themeMode == modeCyber;
    final labelColor =
        isCyberField ? const Color(0xFFB8BFC9) : const Color(0xFF555555);
    final hintColor =
        isCyberField ? const Color(0xFFA8AFB9) : const Color(0xFF888888);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          color: labelColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(color: hintColor, fontSize: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: labelColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _dialogPrimaryColor(), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  // ==================== 弹窗：添加账号 ====================

  void _showAddPhoneDialog() {
    _phoneController.clear();
    _passwordController.clear();
    bool localHidden = _passwordHidden;
    final textColor = _dialogTextColor();
    final subTextColor = _dialogSubTextColor();
    final primaryColor = _dialogPrimaryColor();

    _showBlurDialog(
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 标题
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        '添加账号',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDialogTextField(
                      controller: _phoneController,
                      label: '手机号',
                      hint: '请输入手机号',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 18),
                    _buildDialogTextField(
                      controller: _passwordController,
                      label: '密码（选填）',
                      hint: '请输入密码',
                      obscureText: localHidden,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      suffixIcon: IconButton(
                        icon: Icon(
                          localHidden ? Icons.visibility_off : Icons.visibility,
                          color: subTextColor,
                          size: 20,
                        ),
                        onPressed:
                            () => setDialogState(
                              () => localHidden = !localHidden,
                            ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                color: subTextColor.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final phone = _phoneController.text.trim();
                              final pwd = _passwordController.text.trim();
                              if (phone.isEmpty) return;
                              final entry =
                                  pwd.isNotEmpty ? '$phone $pwd' : phone;
                              setState(() {
                                _phoneSet.add(entry);
                                _selectedPhone = entry;
                              });
                              _savePhones();
                              Navigator.pop(context);
                              '添加成功'.toast();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('添加'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
    );
  }

  // ==================== 弹窗：编辑账号 ====================

  void _showEditPhoneDialog(String phone) {
    final parts = phone.split(' ');
    _editPhoneController.text = parts[0];
    _editPasswordController.text = parts.length > 1 ? parts[1] : '';
    bool editHidden = _passwordHidden;
    final textColor = _dialogTextColor();
    final subTextColor = _dialogSubTextColor();
    final primaryColor = _dialogPrimaryColor();

    _showBlurDialog(
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 标题
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        '编辑账号',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDialogTextField(
                      controller: _editPhoneController,
                      label: '手机号',
                      hint: '请输入手机号',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 18),
                    _buildDialogTextField(
                      controller: _editPasswordController,
                      label: '密码（选填）',
                      hint: '请输入密码',
                      obscureText: editHidden,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      suffixIcon: IconButton(
                        icon: Icon(
                          editHidden ? Icons.visibility_off : Icons.visibility,
                          color: subTextColor,
                          size: 20,
                        ),
                        onPressed:
                            () =>
                                setDialogState(() => editHidden = !editHidden),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                color: subTextColor.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final newPhone = _editPhoneController.text.trim();
                              final newPwd =
                                  _editPasswordController.text.trim();
                              if (newPhone.isEmpty) return;
                              final newEntry =
                                  newPwd.isNotEmpty
                                      ? '$newPhone $newPwd'
                                      : newPhone;
                              setState(() {
                                _phoneSet.remove(phone);
                                _phoneSet.add(newEntry);
                                if (_selectedPhone == phone)
                                  _selectedPhone = newEntry;
                              });
                              _savePhones();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
    );
  }

  // ==================== 弹窗：删除确认 ====================

  void _showDeleteConfirmDialog() {
    if (_selectedPhone == null) return;
    final textColor = _dialogTextColor();
    final subTextColor = _dialogSubTextColor();

    _showBlurDialog(
      builder:
          (dialogContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '确认删除',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '确定要删除账号 $_selectedPhone 吗？',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: subTextColor.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _phoneSet.remove(_selectedPhone);
                          _selectedPhone =
                              _phoneSet.isNotEmpty ? _phoneSet.first : null;
                        });
                        _savePhones();
                        Navigator.pop(dialogContext);
                        '删除成功'.toast();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  // ==================== 弹窗：备份与恢复 ====================

  void _showBackupRestoreDialog() {
    final textColor = _dialogTextColor();
    final subTextColor = _dialogSubTextColor();
    final primaryColor = _dialogPrimaryColor();
    final isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final tileIconColor = isCyber ? subTextColor : primaryColor;

    _showBlurDialog(
      builder:
          (dialogContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '数据管理',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildDataActionTile(
                icon: Icons.backup,
                title: '备份数据',
                subtitle: '将账号和青龙配置导出为JSON',
                color: tileIconColor,
                textColor: textColor,
                subTextColor: subTextColor,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _doBackup();
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  color: subTextColor.withOpacity(0.15),
                  height: 1,
                ),
              ),
              _buildDataActionTile(
                icon: Icons.restore,
                title: '恢复数据',
                subtitle: '从JSON数据恢复账号和青龙配置',
                color: tileIconColor,
                textColor: textColor,
                subTextColor: subTextColor,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _doRestore();
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
    );
  }

  Widget _buildDataActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subTextColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _doBackup() {
    final data = {
      'version': '1.0.0',
      'accounts': _phoneSet.toList(),
      'selectedPhone': _selectedPhone,
      'qlInfo': {
        'address': _qlAddressController.text,
        'clientId': _qlClientIdController.text,
        'clientSecret': _qlClientSecretController.text,
        'token': _qlToken,
      },
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: jsonStr));
    '备份数据已复制到剪切板'.toast();
  }

  void _doRestore() {
    _restoreController.clear();
    final textColor = _dialogTextColor();
    final subTextColor = _dialogSubTextColor();
    final primaryColor = _dialogPrimaryColor();

    _showBlurDialog(
      builder:
          (dialogContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '恢复数据',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '请粘贴之前备份的JSON数据：',
                style: TextStyle(color: subTextColor, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _restoreController,
                maxLines: 6,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '粘贴JSON数据...',
                  hintStyle: TextStyle(
                    color: subTextColor.withOpacity(0.85),
                    fontSize: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: subTextColor.withOpacity(0.25),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: subTextColor.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final data =
                              json.decode(_restoreController.text)
                                  as Map<String, dynamic>;
                          final prefs = await _getPrefs();

                          if (data['accounts'] != null) {
                            final accounts =
                                (data['accounts'] as List).cast<String>();
                            await prefs.setString(
                              _spPhoneStr,
                              accounts.join('\n'),
                            );
                            setState(() {
                              _phoneSet = accounts.toSet();
                            });
                          }
                          if (data['selectedPhone'] != null) {
                            await prefs.setString(
                              _spSelectedPhone,
                              data['selectedPhone'],
                            );
                            setState(() {
                              _selectedPhone = data['selectedPhone'];
                            });
                          }
                          if (data['qlInfo'] != null) {
                            final ql = data['qlInfo'] as Map<String, dynamic>;
                            final address = ql['address'] ?? '';
                            final clientId = ql['clientId'] ?? '';
                            final clientSecret = ql['clientSecret'] ?? '';
                            final token = ql['token'];

                            await prefs.setString(_spQlAddress, address);
                            await prefs.setString(_spQlClientId, clientId);
                            await prefs.setString(
                              _spQlClientSecret,
                              clientSecret,
                            );
                            if (token != null) {
                              await prefs.setString(_spQlToken, token);
                            }

                            _qlAddressController.text = address;
                            _qlClientIdController.text = clientId;
                            _qlClientSecretController.text = clientSecret;
                            _qlToken = token;
                          }

                          if (mounted) {
                            Navigator.pop(dialogContext);
                            '恢复成功'.toast();
                            if (_qlToken != null && _qlToken!.isNotEmpty) {
                              _checkQlLogin();
                            }
                          }
                        } catch (e) {
                          if (mounted) 'JSON格式错误: $e'.toast();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('恢复'),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  // ==================== 账号选择器 ====================

  void _showPhonePicker() {
    if (_phoneSet.isEmpty) {
      '请先添加账号'.toast();
      return;
    }
    // 切换显示 — 弹窗作为页面 Stack 子 widget，紧贴触发按钮下方
    setState(() => _showPhoneList = !_showPhoneList);
  }

  // ==================== UI构建 ====================

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final Color primaryColor = ref.watch(themeProvider).primaryColor;

    Widget body = SafeArea(
      child: Column(
        children: [
          _buildStatusBar(isCyber, primaryColor),
          _buildControlPanel(isCyber, primaryColor),
          Expanded(child: _buildWebView(isCyber)),
        ],
      ),
    );

    if (isCyber) {
      body = CyberBackground(child: body);
    }

    return Scaffold(
      appBar: AppBar(
        // 京东助手 AppBar：标题黑色 + 图标主色，覆盖主题默认的白色文字（看不清）
        backgroundColor: Colors.transparent,
        foregroundColor:
            isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
        titleTextStyle: TextStyle(
          color: isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isCyber ? CyberColors.cyan : primaryColor,
        ),
        actionsIconTheme: IconThemeData(
          color: isCyber ? CyberColors.cyan : primaryColor,
        ),
        title: Text('京东助手'),
        actions: [
          IconButton(
            icon: Icon(_smsEnabled ? Icons.sms : Icons.sms_outlined),
            onPressed: _toggleSms,
            tooltip: '短信识别',
          ),
          IconButton(
            icon: Icon(
              _qlLoggedIn ? Icons.cloud_done : Icons.cloud_outlined,
              color: _qlLoggedIn ? const Color(0xFF34C759) : null,
            ),
            onPressed: _showQlLoginDialog,
            tooltip: '青龙面板登录',
          ),
          IconButton(
            icon: const Icon(Icons.backup),
            onPressed: _showBackupRestoreDialog,
            tooltip: '备份/恢复',
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      // 弹窗作为页面 Stack 子 widget — 跟随页面 lifecycle
      // tabbar 切换页面隐藏时弹窗自动跟随隐藏
      // Stack 嵌套坐标系：弹窗用 screen 坐标，通过 _buildPhoneListOverlay 内部减去 AppBar/statusBar
      body: Stack(children: [body, _buildPhoneListOverlay()]),
    );
  }

  /// 账号选择下拉弹窗 — 作为京东助手页面 Widget 树的一部分
  /// 跟随页面 lifecycle，tabbar 切换时自动隐藏，pop 时随页面销毁
  /// Stack 嵌套坐标修正：用 screen 坐标 - kToolbarHeight 转为相对 Scaffold body 坐标
  Widget _buildPhoneListOverlay() {
    if (!_showPhoneList) return const SizedBox.shrink();
    final ctx = _selectorKey.currentContext;
    if (ctx == null) return const SizedBox.shrink();
    final renderBox = ctx.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    // Scaffold body 内的 Stack 坐标系：相对 Scaffold body origin
    // Scaffold body origin (相对屏幕) = AppBar bottom = kToolbarHeight + statusBar
    final double topInStack =
        offset.dy - kToolbarHeight - MediaQuery.of(context).padding.top;
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final primaryColor = ref.watch(themeProvider).primaryColor;

    return Stack(
      children: [
        // 全屏点击外部关闭弹窗
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showPhoneList = false),
          ),
        ),
        // 账号选择下拉弹窗 — frosted glass
        Positioned(
          left: offset.dx,
          top: topInStack + size.height + 4,
          width: size.width,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                isCyber ? 12 : AppleColors.radiusSmall,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10),
                  sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isCyber
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0x80FFFFFF),
                    borderRadius: BorderRadius.circular(
                      isCyber ? 12 : AppleColors.radiusSmall,
                    ),
                    border:
                        isCyber
                            ? Border.all(
                              color: CyberColors.cyan.withValues(alpha: 0.5),
                              width: 1,
                            )
                            : Border.all(
                              color: const Color(0x1A000000),
                              width: 1,
                            ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _phoneSet.length,
                      itemBuilder: (context, index) {
                        final phone = _phoneSet.elementAt(index);
                        final isSelected = phone == _selectedPhone;
                        final parts = phone.split(' ');
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedPhone = phone;
                              _showPhoneList = false;
                            });
                            _savePhones();
                          },
                          onLongPress: () {
                            setState(() => _showPhoneList = false);
                            _showEditPhoneDialog(phone);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        parts[0],
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? (isCyber
                                                      ? CyberColors.cyan
                                                      : primaryColor)
                                                  : (isCyber
                                                      ? CyberColors.titleWhite
                                                      : AppleColors
                                                          .textPrimary),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check,
                                        color:
                                            isCyber
                                                ? CyberColors.cyan
                                                : primaryColor,
                                        size: 18,
                                      ),
                                  ],
                                ),
                                if (parts.length > 1)
                                  Text(
                                    _passwordHidden ? '••••••' : parts[1],
                                    style: TextStyle(
                                      color:
                                          isCyber
                                              ? CyberColors.descColor
                                              : const Color(0xFF666666),
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 青龙登录状态指示条
  Widget _buildStatusBar(bool isCyber, Color primaryColor) {
    if (_qlLoggedIn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF34C759).withOpacity(0.1),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: const Color(0xFF34C759)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '青龙面板已连接',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isCyber
                          ? CyberColors.descColor
                          : AppleColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: (isCyber ? CyberColors.cyan : primaryColor).withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: isCyber ? CyberColors.cyan : primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '未登录青龙面板，上传Cookie前请先登录',
              style: TextStyle(
                fontSize: 13,
                color:
                    isCyber ? CyberColors.descColor : AppleColors.textSecondary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _showQlLoginDialog,
            child: Text(
              '去登录',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isCyber ? CyberColors.cyan : primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isCyber, Color primaryColor) {
    return GlassCard(
      margin: const EdgeInsets.all(AppleColors.spaceMd),
      padding: const EdgeInsets.all(AppleColors.spaceSm),
      sigma: 10,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  key: _selectorKey,
                  onTap: _showPhonePicker,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppleColors.radiusSmall,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 6),
                        sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 6),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isCyber
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(
                            AppleColors.radiusSmall,
                          ),
                          border: Border.all(
                            color:
                                isCyber
                                    ? CyberColors.borderGlow
                                    : AppleColors.cardBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPhone?.split(' ')[0] ?? '选择账号',
                                style: TextStyle(
                                  color:
                                      _selectedPhone != null
                                          ? (isCyber
                                              ? CyberColors.titleWhite
                                              : AppleColors.textPrimary)
                                          : (isCyber
                                              ? CyberColors.descColor
                                              : AppleColors.textSecondary),
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color:
                                  isCyber
                                      ? CyberColors.descColor
                                      : AppleColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppleColors.spaceSm),
              _buildActionButton(
                Icons.add,
                '添加',
                _showAddPhoneDialog,
                isCyber,
                primaryColor,
              ),
              const SizedBox(width: AppleColors.spaceSm),
              _buildActionButton(
                Icons.delete_outline,
                '删除',
                _showDeleteConfirmDialog,
                isCyber,
                primaryColor,
              ),
            ],
          ),
          const SizedBox(height: AppleColors.spaceSm),
          Row(
            children: [
              _buildActionButton(
                Icons.input,
                '输入',
                _inputPhone,
                isCyber,
                primaryColor,
              ),
              const SizedBox(width: AppleColors.spaceSm),
              _buildActionButton(
                Icons.cookie_outlined,
                '获取',
                _getCookie,
                isCyber,
                primaryColor,
              ),
              const SizedBox(width: AppleColors.spaceSm),
              _buildActionButton(
                Icons.refresh,
                '重置',
                _resetWebView,
                isCyber,
                primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
    bool isCyber,
    Color primaryColor,
  ) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isCyber ? const Color(0x20FFFFFF) : primaryColor,
          foregroundColor: isCyber ? CyberColors.cyan : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusSmall),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildWebView(bool isCyber) {
    return GlassCard(
      margin: const EdgeInsets.all(AppleColors.spaceMd),
      padding: EdgeInsets.zero,
      sigma: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppleColors.radiusCard),
        child: Stack(
          children: [
            if (_webViewReady)
              RepaintBoundary(
                child: WebViewWidget(controller: _webViewController),
              ),
            if (_isLoading || !_webViewReady)
              Center(
                child: CircularProgressIndicator(
                  color:
                      isCyber
                          ? CyberColors.cyan
                          : ref.read(themeProvider).primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationComplete);
    _smsSubscription?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _editPhoneController.dispose();
    _editPasswordController.dispose();
    _qlAddressController.dispose();
    _qlClientIdController.dispose();
    _qlClientSecretController.dispose();
    _restoreController.dispose();
    _dio.close();
    super.dispose();
  }
}
