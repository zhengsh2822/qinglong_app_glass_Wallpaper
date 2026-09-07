import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;

import 'package:qinglong_app/base/http/http_cache.dart';
import 'package:qinglong_app/base/http/token_interceptor.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../json.jc.dart';
import '../../main.dart';
import '../routes.dart';

class Http {
  Dio? _dio;
  bool pushedLoginPage = false;

  /// 非激活账号有待处理的登录失败弹窗，切换到该账号时触发
  bool pendingExitLogin = false;

  String host;
  int index;

  Http(this.host, this.index) {
    _init();
  }

  void initDioConfig(String host) {
    _dio = Dio(
      BaseOptions(
        baseUrl: host,
        connectTimeout: Duration(milliseconds: 15000),
        receiveTimeout: Duration(milliseconds: 30000),
        sendTimeout: Duration(milliseconds: 15000),
        contentType: "application/json",
        responseType: ResponseType.plain,
      ),
    );
    _dio?.interceptors.add(TokenInterceptor(host, index));
    (_dio?.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (
      HttpClient client,
    ) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };
  }

  void _init() {
    if (_dio == null) {
      initDioConfig(host);
    }
  }

  void clear() {
    _dio = null;
    HttpCache.clearAccount(index);
  }

  Future<HttpResponse<T>> get<T>(
    String uri,
    Map<String, String?>? json, {
    bool compute = true,
    String serializationName = "data",
    bool useCache = true,
    Duration? ttl,
    bool reloginRetry = false,
  }) async {
    try {
      _init();

      final cacheKey = _buildCacheKey(uri, json);
      if (useCache) {
        final cached = HttpCache(index).get<HttpResponse<T>>(cacheKey);
        if (cached != null) {
          return cached;
        }
      }

      var response = await _dio!.get(uri, queryParameters: json);
      // 大响应(>= 256KB)在 Isolate 中预解析 JSON,避免主线程卡顿
      // 主要场景:大脚本内容、大日志详情
      if (response.data is String) {
        final raw = response.data as String;
        if (raw.length >= _isolateDecodeThreshold) {
          response.data = await foundation.compute(_decodeJsonInIsolate, raw);
        }
      }
      var result = decodeResponse<T>(response, serializationName, compute);

      // token 失效（HTML 登录页）/ 解析异常 / Dio 死连接：
      // 重建 Dio + 静默刷新 token，然后无论如何都重试一次
      // 即使 silentReLogin 失败（如未记住密码），Dio 已重建，重试可能直接成功
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return get<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            useCache: false,
            reloginRetry: true);
      }

      // 重试仍失败且 needRelogin=true：说明 token 确实失效，跳转登录页
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }

      if (useCache && result.success) {
        // 优先使用调用方显式传入的 ttl,否则按 URI 推断分级 TTL
        final effectiveTtl = ttl ?? CacheTtl.forUri(uri);
        HttpCache(index).set<HttpResponse<T>>(cacheKey, result, ttl: effectiveTtl);
      }

      return result;
    } on DioException catch (e) {
      final result = exceptionHandler<T>(e, uri);
      // 401 也走静默刷新重试
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return get<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            useCache: false,
            reloginRetry: true);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }
      return result;
    } catch (e) {
      logger.e(e);
      return HttpResponse<T>(success: false, code: -1000, message: "请求失败");
    }
  }

  String _buildCacheKey(String uri, Map<String, String?>? json) {
    if (json == null || json.isEmpty) return uri;
    final sortedParams = Map.fromEntries(
      json.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return '$uri?${Uri(queryParameters: sortedParams.map((k, v) => MapEntry(k, v ?? ''))).query}';
  }

  /// 重建 Dio 实例，清空可能失效的 TCP 连接池
  /// 长时间不活动后，底层 keep-alive 连接可能已被运营商/路由器/服务器静默断开
  /// Dio 复用死连接会导致响应乱码/截断，重建 Dio 是最彻底的修复
  void _rebuildDio() {
    try {
      _dio?.close(force: true);
    } catch (_) {}
    initDioConfig(host);
  }

  /// 并发安全：多个请求同时失败时，只重建一次 Dio + 刷新一次 token
  /// 其他请求等待结果，避免重复重建 Dio 导致竞态
  Completer<void>? _reloginCompleter;

  /// 处理 token 失效 / 解析异常：重建 Dio + 静默刷新 token
  /// 并发安全：多个请求同时触发时，只执行一次，其他请求等待结果
  /// 不再负责跳转登录页，由调用方在重试失败后决定
  Future<void> _handleTokenExpired() async {
    if (_reloginCompleter != null) {
      return _reloginCompleter!.future;
    }
    _reloginCompleter = Completer<void>();
    try {
      // 先重建 Dio，清空可能失效的连接池（解决长时间不活动后死连接问题）
      _rebuildDio();
      // 静默刷新 token（失败也无所谓，重试可能仍会成功，因为 Dio 已重建）
      await silentReLogin();
      _reloginCompleter!.complete();
    } catch (e) {
      _reloginCompleter!.completeError(e);
    } finally {
      _reloginCompleter = null;
    }
  }

  Future<HttpResponse<T>> post<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
    bool reloginRetry = false,
  }) async {
    try {
      _init();
      var response = await _dio!.post(uri, data: json);

      _invalidateRelatedCache(uri);

      var result = decodeResponse<T>(response, serializationName, compute);

      // token 失效 / 解析异常 / Dio 死连接：重建 Dio + 静默刷新 + 重试一次
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return post<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            reloginRetry: true);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }

      return result;
    } on DioException catch (e) {
      final result = exceptionHandler<T>(e, uri);
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return post<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            reloginRetry: true);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }
      return result;
    }
  }

  Future<HttpResponse<T>> delete<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
    bool reloginRetry = false,
  }) async {
    try {
      _init();
      var response = await _dio!.delete(uri, data: json);

      _invalidateRelatedCache(uri);

      var result = decodeResponse<T>(response, serializationName, compute);

      // token 失效 / 解析异常 / Dio 死连接：重建 Dio + 静默刷新 + 重试一次
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return delete<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            reloginRetry: true);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }

      return result;
    } on DioException catch (e) {
      final result = exceptionHandler<T>(e, uri);
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return delete<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            reloginRetry: true);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }
      return result;
    }
  }

  Future<HttpResponse<T>> put<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
    bool reloginRetry = false,
    bool rawResponse = false,
    Duration? receiveTimeout,
  }) async {
    try {
      _init();

      // 流式响应（Node/Linux 镜像源更新触发重装依赖）需要更长超时
      Options? options;
      if (rawResponse || receiveTimeout != null) {
        options = Options(
          receiveTimeout: receiveTimeout ?? const Duration(minutes: 5),
        );
      }

      var response = await _dio!.put(uri, data: json, options: options);

      _invalidateRelatedCache(uri);

      // 流式响应（octet-stream）不解析 JSON，直接根据 HTTP 状态码判断
      if (rawResponse) {
        if (response.statusCode == 200) {
          return HttpResponse<T>(success: true, code: 200);
        } else {
          return HttpResponse<T>(
            success: false,
            code: response.statusCode ?? 0,
            message: response.statusMessage ?? '请求失败',
          );
        }
      }

      var result = decodeResponse<T>(response, serializationName, compute);

      // token 失效 / 解析异常 / Dio 死连接：重建 Dio + 静默刷新 + 重试一次
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return put<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            reloginRetry: true,
            rawResponse: rawResponse,
            receiveTimeout: receiveTimeout);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }

      return result;
    } on DioException catch (e) {
      // 流式响应超时：服务器已接收请求并开始处理，设置已保存
      if (rawResponse && e.type == DioExceptionType.receiveTimeout) {
        return HttpResponse<T>(success: true, code: 200);
      }
      final result = exceptionHandler<T>(e, uri);
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return put<T>(uri, json,
            compute: compute,
            serializationName: serializationName,
            reloginRetry: true,
            rawResponse: rawResponse,
            receiveTimeout: receiveTimeout);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }
      return result;
    }
  }

  /// GET 拉取二进制文件（用于脚本运行时保存的图片、二维码等）
  /// [uri] 请求路径，[query] 查询参数
  /// 成功返回 GetBytesResult.success(bytes)
  /// 失败：返回对应 .http404/.http500/.http401/.network 携带状态码和响应体前 200 字符
  ///       便于 UI 直接把真实原因展示给用户
  ///
  /// 关键：青龙 v2.x 的 `/open/scripts/file` 实际是**统一 JSON 响应** `{code,data,message}`，
  /// data 字段才是真正的文件内容（可能为空字符串=文件不存在/未授权）。
  /// 我们会先按 JSON 解析；若 data 是空字符串则按"找不到"返回失败。
  Future<GetBytesResult> getBytes(
    String uri,
    Map<String, String?>? query,
  ) async {
    try {
      _init();
      final response = await _dio!.get(
        uri,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data is List<int>) {
        // 尝试按 UTF-8 解析 + JSON 解码（青龙统一 API 格式）
        try {
          final text = utf8.decode(data);
          final json = jsonDecode(text);
          if (json is Map && json.containsKey('code')) {
            // 青龙统一响应
            final code = json['code'];
            final payload = json['data'];
            final msg = json['message']?.toString() ?? '';
            if (code == 200) {
              if (payload is String && payload.isNotEmpty) {
                return GetBytesResult.success(utf8.encode(payload));
              }
              if (payload is List<int>) {
                return GetBytesResult.success(payload);
              }
              // data 为空字符串或 null = 文件不存在
              return GetBytesResult.fail(
                code: 200,
                message: '文件不存在或为空',
                bodyPreview:
                    '${jsonEncode({'code': code, 'data': payload, 'message': msg})}',
              );
            }
            return GetBytesResult.fail(
              code: code is int ? code : 0,
              message: msg.isNotEmpty ? msg : '业务错误',
              bodyPreview:
                  '${jsonEncode({'code': code, 'data': payload, 'message': msg})}',
            );
          }
        } catch (_) {
          // 不是 JSON 当成纯二进制（图片/文件流）
        }
        // 走纯二进制路径
        return GetBytesResult.success(data);
      }
      return GetBytesResult.fail(
        code: 0,
        message: '响应格式异常',
        bodyPreview: data?.toString() ?? '',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      String bodyPreview = '';
      final respData = e.response?.data;
      if (respData is List<int>) {
        try {
          bodyPreview = utf8.decode(respData.take(200).toList());
        } catch (_) {}
      } else if (respData != null) {
        bodyPreview = respData.toString();
        if (bodyPreview.length > 200) {
          bodyPreview = bodyPreview.substring(0, 200);
        }
      }
      if (status == 401) {
        await _handleTokenExpired();
        return GetBytesResult.fail(
          code: 401,
          message: '登录已过期',
          bodyPreview: bodyPreview,
        );
      }
      if (status == 404) {
        return GetBytesResult.fail(
          code: 404,
          message: '接口不存在（404）',
          bodyPreview: bodyPreview,
        );
      }
      if (status == 500) {
        return GetBytesResult.fail(
          code: 500,
          message: '服务器错误（500）',
          bodyPreview: bodyPreview,
        );
      }
      return GetBytesResult.fail(
        code: status,
        message: e.message ?? '网络请求失败',
        bodyPreview: bodyPreview,
      );
    } catch (e) {
      return GetBytesResult.fail(
        code: -1,
        message: e.toString(),
        bodyPreview: '',
      );
    }
  }

  /// 下载二进制流文件（用于数据导出 .tgz 压缩包备份）
  /// [uri] 请求路径，[body] JSON 请求体，[savePath] 本地保存路径
  /// 成功返回 null，失败返回错误信息
  Future<String?> downloadFile(
    String uri,
    Map<String, dynamic> body,
    String savePath,
  ) async {
    try {
      _init();
      final response = await _dio!.put(
        uri,
        data: body,
        options: Options(responseType: ResponseType.bytes),
      );

      // 检查响应是否为二进制流（导出成功）还是 JSON（导出失败）
      final data = response.data;
      if (data is List<int>) {
        final file = await File(savePath).create(recursive: true);
        await file.writeAsBytes(data);
        return null;
      }

      // 非 bytes 响应，可能是错误 JSON
      final raw = data is String ? data : data.toString();
      if (_isHtmlResponse(raw)) {
        await _handleTokenExpired();
        return "登录已过期，请重试";
      }
      return "服务器返回异常格式";
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleTokenExpired();
        return "登录已过期，请重试";
      }
      return e.message ?? "网络请求失败";
    } catch (e) {
      return e.toString();
    }
  }

  /// 上传文件（用于数据导入 .tgz 压缩包恢复）
  /// [uri] 请求路径，[filePath] 本地文件路径，[fieldName] 上传字段名
  /// 返回标准 HttpResponse，包含服务器解压输出信息
  Future<HttpResponse<T>> uploadFile<T>(
    String uri,
    String filePath,
    String fieldName, {
    bool reloginRetry = false,
  }) async {
    try {
      _init();
      final formdata = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
      });

      final response = await _dio!.put(uri, data: formdata);

      _invalidateRelatedCache(uri);

      var result = decodeResponse<T>(response, "data", false);

      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return uploadFile<T>(uri, filePath, fieldName, reloginRetry: true);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }

      return result;
    } on DioException catch (e) {
      final result = exceptionHandler<T>(e, uri);
      if (result.needRelogin && !reloginRetry) {
        await _handleTokenExpired();
        return uploadFile<T>(uri, filePath, fieldName, reloginRetry: true);
      }
      if (result.needRelogin && reloginRetry) {
        exitLogin();
      }
      return result;
    }
  }

  void _invalidateRelatedCache(String uri) {
    final cache = HttpCache(index);
    final path = uri.split('?').first;
    if (path.startsWith('/api/system') || path.startsWith('/open/system')) {
      cache.invalidatePrefix('/api/system');
      cache.invalidatePrefix('/open/system');
    } else if (path.startsWith('/api/user') || path.startsWith('/open/user')) {
      cache.invalidatePrefix('/api/user');
      cache.invalidatePrefix('/open/user');
    } else if (path.startsWith('/api/configs') ||
        path.startsWith('/open/configs')) {
      cache.invalidatePrefix('/api/configs');
      cache.invalidatePrefix('/open/configs');
    } else if (path.startsWith('/api/scripts') ||
        path.startsWith('/open/scripts')) {
      cache.invalidatePrefix('/api/scripts');
      cache.invalidatePrefix('/open/scripts');
    } else if (path.startsWith('/api/envs') || path.startsWith('/open/envs')) {
      cache.invalidatePrefix('/api/envs');
      cache.invalidatePrefix('/open/envs');
    } else if (path.startsWith('/api/crons') ||
        path.startsWith('/open/crons')) {
      cache.invalidatePrefix('/api/crons');
      cache.invalidatePrefix('/open/crons');
    } else if (path.startsWith('/api/logs') || path.startsWith('/open/logs')) {
      cache.invalidatePrefix('/api/logs');
      cache.invalidatePrefix('/open/logs');
    } else if (path.startsWith('/api/apps') || path.startsWith('/open/apps')) {
      cache.invalidatePrefix('/api/apps');
      cache.invalidatePrefix('/open/apps');
    } else if (path.startsWith('/api/dependencies') ||
        path.startsWith('/open/dependencies')) {
      cache.invalidatePrefix('/api/dependencies');
      cache.invalidatePrefix('/open/dependencies');
    } else if (path.startsWith('/api/subscriptions') ||
        path.startsWith('/open/subscriptions')) {
      cache.invalidatePrefix('/api/subscriptions');
      cache.invalidatePrefix('/open/subscriptions');
    } else {
      cache.invalidateAll();
    }
  }

  /// 刷新失败后弹窗让用户选择是否重新登录（不直接跳转）
  /// 用 pushedLoginPage 防止并发请求触发多个弹窗
  /// 非激活账号不弹窗，标记 pendingExitLogin，切换到该账号时再弹
  Future<void> exitLogin() async {
    if (pushedLoginPage) return;

    // 多账号场景：非激活账号不弹窗，标记待处理，切换到该账号时再弹
    // 避免断网的非激活账号在后台请求失败时弹窗干扰用户
    if (MultiAccountPageState.currentAccountIndex != index) {
      pendingExitLogin = true;
      return;
    }

    pushedLoginPage = true;

    final navigatorKey = getIt<GlobalKey<NavigatorState>>(
      instanceName: index.toString(),
    );
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      // 无可用 context，复位标志，放弃跳转
      pushedLoginPage = false;
      return;
    }

    // 弹窗让用户选择：重新登录 或 取消（留在当前页面）
    final shouldLogin = await showConfirmDialog(
      context,
      title: '连接失败',
      content: '网络连接失败，是否重新登录？',
      cancelLabel: '取消',
      confirmLabel: '重新登录',
      danger: false,
    );

    if (shouldLogin == true) {
      getIt<UserInfoViewModel>(
        instanceName: index.toString(),
      ).exitLoginFocus(index);
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(Routes.routeLogin, (route) => false);
    } else {
      // 用户取消，复位标志允许下次再问
      pushedLoginPage = false;
    }
  }

  /// 复位登录页跳转标志，允许下次再次触发跳转
  /// 同时清空待处理弹窗标记
  void resetExitLoginFlag() {
    pushedLoginPage = false;
    pendingExitLogin = false;
  }

  // ============ 静默重新登录（token 过期自动刷新） ============

  /// 静默刷新锁：并发请求只触发一次刷新，其他请求等待结果
  bool _isReLoggingIn = false;

  /// 检测响应内容是否为 HTML 登录页（token 失效的典型特征）
  /// 青龙面板 token 过期后返回 302 → 登录页 HTML（状态码 200），非 JSON
  static bool _isHtmlResponse(dynamic data) {
    if (data is! String) return false;
    final lower = data.toLowerCase();
    // 登录页 HTML 特征：含 <html / <!DOCTYPE / <script 标签
    return lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('<script');
  }

  /// 判断本地是否有足够凭证进行静默刷新
  bool _canSilentRelogin() {
    final userInfo = getIt<UserInfoViewModel>(
      instanceName: index.toString(),
    );
    return userInfo.userName != null &&
        userInfo.userName!.isNotEmpty &&
        userInfo.passWord != null &&
        userInfo.passWord!.isNotEmpty;
  }

  /// 用本地保存的凭证静默重新登录，换取新 token
  /// 并发安全：多个请求同时失败时，只发起一次登录请求，其他请求等待结果
  /// 返回 true 表示刷新成功，可重试原请求；false 表示失败，需跳登录页
  Future<bool> silentReLogin() async {
    // 防递归：登录接口本身也会走 Http 层，若正在刷新则直接返回 false
    if (_isReLoggingIn) return false;
    _isReLoggingIn = true;

    try {
      // 无凭证（未记住密码），无法静默刷新
      if (!_canSilentRelogin()) return false;

      final userInfo = getIt<UserInfoViewModel>(
        instanceName: index.toString(),
      );

      // 直接用 Dio 发请求，绕过 decodeResponse 的 HTML 检测，避免递归
      // secret 登录用户用 client_id 方式，密码登录用户用账号密码方式
      final isSecretLogin = userInfo.useSecretLogined;

      final rawResponse = isSecretLogin
          ? await _dio!.get(
              Url.loginByClientId,
              queryParameters: {
                'client_id': userInfo.userName,
                'client_secret': userInfo.passWord,
              },
            )
          : await _dio!.post(
              Url.login,
              data: {
                'username': userInfo.userName,
                'password': userInfo.passWord,
              },
            );

      final data = rawResponse.data is String
          ? jsonDecode(rawResponse.data)
          : rawResponse.data;

      if (data is Map &&
          data['code'] == 200 &&
          data['data'] != null &&
          data['data']['token'] != null) {
        // 刷新成功，更新 token
        userInfo.updateToken(
          index,
          userInfo.host,
          data['data']['token'].toString(),
          userInfo.useSecretLogined,
          userInfo.rawAlias,
        );
        // 清除缓存（旧缓存可能是失败结果）
        HttpCache.clearAccount(index);
        return true;
      }

      return false;
    } catch (e) {
      logger.e('silentReLogin failed: $e');
      return false;
    } finally {
      _isReLoggingIn = false;
    }
  }

  HttpResponse<T> exceptionHandler<T>(DioException e, String path) {
    try {
      logger.e(e);
      if (e.response?.statusCode == 401 && !Url.inWhiteList(path)) {
        // 401 统一标记 needRelogin，由 get/post/put/delete 触发静默刷新
        return HttpResponse<T>(
          success: false,
          message: "登录已过期，请重新登录",
          code: 401,
          needRelogin: true,
        );
      }

      // 网络错误（死连接 / 超时 / 连接失败）：标记 needRelogin 触发重建 Dio + 重试
      // 长时间不活动后 Dio keep-alive 连接失效，表现为 connectionTimeout / receiveTimeout / connectionError
      // 重建 Dio 清空连接池后重试即可恢复，无需用户重启 app
      final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown;
      if (isNetworkError) {
        return HttpResponse<T>(
          success: false,
          message: "网络连接异常，正在重试...",
          code: -1000,
          needRelogin: true,
        );
      }

      if (e.response != null && e.response!.data != null) {
        final responseData = e.response!.data;
        // responseData 可能是 String（如 HTML 错误页面），需先判断类型
        if (responseData is Map) {
          return HttpResponse(
            success: false,
            message: responseData["message"] ?? e.message,
            code: responseData["code"] ?? 0,
          );
        } else {
          return HttpResponse(
            success: false,
            message: e.message ?? responseData.toString(),
            code: e.response?.statusCode ?? 0,
          );
        }
      } else {
        return HttpResponse(
          success: false,
          message: e.message,
          code: e.response?.statusCode ?? 0,
        );
      }
    } catch (e) {
      return HttpResponse(success: false, message: e.toString(), code: 400);
    }
  }

  static HttpResponse<T> decodeResponse<T>(
    Response<dynamic> response,
    String serializationName,
    bool compute,
  ) {
    int code = 0;
    if (response.statusCode == 200) {
      try {
        // responseType 为 plain 时，response.data 是 String，需先 jsonDecode
        dynamic data = response.data;
        if (data is String) {
          if (data.isEmpty) {
            return HttpResponse<T>(
              success: false,
              code: -1000,
              message: "服务器返回空响应",
              needRelogin: true,
            );
          }
          // 检测 HTML 登录页：青龙面板 token 过期后返回 302 → 登录页 HTML（状态码 200）
          // 此时 jsonDecode 必然抛异常，提前识别并标记 needRelogin
          if (_isHtmlResponse(data)) {
            return HttpResponse<T>(
              success: false,
              code: -1000,
              message: "登录已过期，请重新登录",
              needRelogin: true,
            );
          }
          data = jsonDecode(data);
        }
        if (data is! Map) {
          // 非 Map 非 HTML 的异常格式（如纯数组、纯字符串）
          // 青龙 API 标准格式为 {code, data, message}，非 Map 属于异常，触发重试
          return HttpResponse<T>(
            success: false,
            code: -1000,
            message: "服务器响应格式异常",
            needRelogin: true,
          );
        }
        if (data["code"] == 200) {
          if (data[serializationName] != null) {
            if (T == NullResponse) {
              return HttpResponse<T>(success: true, code: 200);
            }

            dynamic serialData = data[serializationName];
            T t;
            if (T == String) {
              if (serialData is String) {
                t = serialData as T;
              } else {
                t = jsonEncode(serialData) as T;
              }
              return HttpResponse<T>(success: true, code: 200, bean: t);
            } else {
              T bean = JsonConversion$Json.fromJson<T>(serialData);
              return HttpResponse<T>(success: true, code: 200, bean: bean);
            }
          } else {
            return HttpResponse<T>(success: true, code: 200);
          }
        } else {
          String message = data["message"]?.toString() ?? "请求失败";
          // 过滤底层库（GSON/Moshi等）错误信息，给用户友好提示
          if (message.contains("JsonReader") ||
              message.contains("malformed JSON") ||
              message.contains("com.google.gson") ||
              message.contains("com.squareup.moshi")) {
            message = "服务器响应异常，请检查面板服务状态";
          }
          return HttpResponse<T>(
            success: false,
            code: data["code"],
            message: message,
          );
        }
      } catch (e) {
        logger.e(e);
        // catch 分支也检测 HTML：jsonDecode 抛异常时，原始数据可能是 HTML 登录页
        final rawData = response.data;
        if (_isHtmlResponse(rawData)) {
          return HttpResponse<T>(
            success: false,
            code: -1000,
            message: "登录已过期，请重新登录",
            needRelogin: true,
          );
        }
        // 格式异常也可能是 token 过期（服务器返回非 HTML 的非 JSON 内容）
        // 或 Dio 连接池失效导致响应乱码/截断
        // 标记 needRelogin 触发重建 Dio + 静默刷新 + 重试
        final preview = rawData is String
            ? (rawData.length > 200 ? rawData.substring(0, 200) : rawData)
            : rawData.toString();
        logger.e('decodeResponse 格式异常，响应内容预览: $preview');
        return HttpResponse<T>(
          success: false,
          code: -1000,
          message: "服务器响应格式异常",
          needRelogin: true,
        );
      }
    } else {
      code = response.statusCode ?? 0;
      return HttpResponse(
        success: false,
        code: code,
        message: response.statusMessage,
      );
    }
  }
}

class HttpResponse<T> {
  late bool success;
  String? message;
  late int code;
  T? bean;
  /// 标记响应被识别为 token 失效（HTML 登录页 / 401），需触发静默刷新
  bool needRelogin;

  HttpResponse({
    required this.success,
    this.message,
    required this.code,
    this.bean,
    this.needRelogin = false,
  });
}

/// 二进制文件拉取结果（含错误详情）
/// 比简单返回 `List<int>?` 更能帮助定位青龙接口问题
class GetBytesResult {
  final bool success;
  final int code; // HTTP 状态码（0/-1 表示非 HTTP 错误）
  final String? message;
  final List<int> bytes;
  final String bodyPreview; // 错误响应体前 200 字符

  GetBytesResult._({
    required this.success,
    required this.code,
    this.message,
    required this.bytes,
    this.bodyPreview = '',
  });

  factory GetBytesResult.success(List<int> bytes) => GetBytesResult._(
    success: true,
    code: 200,
    bytes: bytes,
  );

  factory GetBytesResult.fail({
    required int code,
    String? message,
    String bodyPreview = '',
  }) => GetBytesResult._(
    success: false,
    code: code,
    message: message,
    bytes: const [],
    bodyPreview: bodyPreview,
  );
}

class DeserializeAction<T> {
  final dynamic json;

  DeserializeAction(this.json);

  T invoke() {
    return json as T;
  }

  static dynamic invokeJson(DeserializeAction a) => a.invoke();
}

mixin BaseBean<T> {
  T fromJson(Map<String, dynamic> json);
}

class CronBean with BaseBean<CronBean> {
  @override
  CronBean fromJson(Map<String, dynamic> json) {
    return CronBean();
  }
}

void decode<T>() async {
  foundation.compute(DeserializeAction.invokeJson, DeserializeAction<T>({}));
}

class NullResponse {}

class NotLoginException implements Exception {}

/// 大响应 Isolate 解码阈值:256KB
/// 超过此长度的响应字符串会在 Isolate 中预先 jsonDecode
/// 避免主线程卡顿(主要场景:大脚本、大日志详情)
const int _isolateDecodeThreshold = 256 * 1024;

/// 在 Isolate 中执行 jsonDecode
/// 顶层函数,compute 要求被调用函数必须是静态/顶层
dynamic _decodeJsonInIsolate(String raw) {
  return jsonDecode(raw);
}
