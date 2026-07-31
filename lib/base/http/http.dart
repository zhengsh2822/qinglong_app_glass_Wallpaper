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
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../json.jc.dart';
import '../../main.dart';
import '../routes.dart';

class Http {
  Dio? _dio;
  bool pushedLoginPage = false;

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

      if (useCache && result.success) {
        // 优先使用调用方显式传入的 ttl,否则按 URI 推断分级 TTL
        final effectiveTtl = ttl ?? CacheTtl.forUri(uri);
        HttpCache(index).set<HttpResponse<T>>(cacheKey, result, ttl: effectiveTtl);
      }

      return result;
    } on DioException catch (e) {
      return exceptionHandler<T>(e, uri);
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

  Future<HttpResponse<T>> post<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
  }) async {
    try {
      _init();
      var response = await _dio!.post(uri, data: json);

      _invalidateRelatedCache(uri);

      return decodeResponse<T>(response, serializationName, compute);
    } on DioException catch (e) {
      return exceptionHandler<T>(e, uri);
    }
  }

  Future<HttpResponse<T>> delete<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
  }) async {
    try {
      _init();
      var response = await _dio!.delete(uri, data: json);

      _invalidateRelatedCache(uri);

      return decodeResponse<T>(response, serializationName, compute);
    } on DioException catch (e) {
      return exceptionHandler<T>(e, uri);
    }
  }

  Future<HttpResponse<T>> put<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
  }) async {
    try {
      _init();
      var response = await _dio!.put(uri, data: json);

      _invalidateRelatedCache(uri);

      return decodeResponse<T>(response, serializationName, compute);
    } on DioException catch (e) {
      return exceptionHandler<T>(e, uri);
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

  void exitLogin() {
    if (!pushedLoginPage) {
      "身份已过期,请重新登录".toast();
      pushedLoginPage = true;

      getIt<UserInfoViewModel>(
        instanceName: index.toString(),
      ).exitLoginFocus(index);

      getIt<GlobalKey<NavigatorState>>(instanceName: index.toString())
          .currentState
          ?.pushNamedAndRemoveUntil(Routes.routeLogin, (route) => false);
    }
  }

  HttpResponse<T> exceptionHandler<T>(DioException e, String path) {
    try {
      logger.e(e);
      if (e.response?.statusCode == 401 && !Url.inWhiteList(path)) {
        if (!getIt<UserInfoViewModel>(
          instanceName: index.toString(),
        ).useSecretLogined) {
          exitLogin();
        }
        return HttpResponse(success: false, message: "没有该模块的访问权限", code: 401);
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
            );
          }
          data = jsonDecode(data);
        }
        if (data is! Map) {
          return HttpResponse<T>(
            success: false,
            code: -1000,
            message: "服务器返回格式异常",
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
        return HttpResponse<T>(
          success: false,
          code: -1000,
          message: "json解析失败",
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

  HttpResponse({
    required this.success,
    this.message,
    required this.code,
    this.bean,
  });
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
