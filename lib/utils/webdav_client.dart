import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

/// WebDAV 远端文件条目
class WebDavFile {
  /// 文件名（basename，已 decode）
  final String name;

  /// 服务端返回的 href（已 decode）
  final String href;

  final DateTime? modified;

  final int size;

  final bool isDir;

  const WebDavFile({
    required this.name,
    required this.href,
    this.modified,
    this.size = 0,
    this.isDir = false,
  });
}

/// 基于 dio 的轻量 WebDAV 客户端（Basic 认证 + 自签证书放行，与项目 Http 类行为一致）。
/// 仅实现备份所需方法：PROPFIND / MKCOL / PUT / GET / DELETE。
/// 所有失败均抛 Exception（中文消息可直接 toast）。
class WebDavClient {
  /// 归一化后的基准目录（以 / 结尾，含服务器路径，如 https://dav.jianguoyun.com/dav/）
  final String baseDir;
  final Dio _dio;

  WebDavClient(String url, {required String user, required String password})
    : baseDir = _normalizeUrl(url),
      _dio = _buildDio(url, user, password);

  static String _normalizeUrl(String url) {
    String u = url.trim();
    if (u.isEmpty) {
      throw Exception("WebDAV 服务器地址不能为空");
    }
    if (!u.startsWith("http://") && !u.startsWith("https://")) {
      u = "https://$u";
    }
    while (u.endsWith("/")) {
      u = u.substring(0, u.length - 1);
    }
    return "$u/";
  }

  static Dio _buildDio(String url, String user, String password) {
    final token = base64.encode(utf8.encode("$user:$password"));
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 15000),
        // 备份文件传输可达 GB 级（全选内容），120s 会掐断大包收发
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 30),
        responseType: ResponseType.bytes,
        // WebDAV 有 207 Multi-Status、404/405 等需要自行判断的状态，放行到 499
        validateStatus: (s) => s != null && s < 500,
        headers: {"authorization": "Basic $token"},
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
    return dio;
  }

  /// 相对路径拼接（relPath 不以 / 开头）
  String _path(String relPath) {
    String p = relPath;
    while (p.startsWith("/")) {
      p = p.substring(1);
    }
    return "$baseDir$p";
  }

  /// PROPFIND Depth:0，验证连通性与凭据
  Future<void> ping() async {
    final response = await _dio.request<Uint8List>(
      baseDir,
      options: Options(method: "PROPFIND", headers: {"Depth": "0"}),
      data: _propfindBody,
    );
    final s = response.statusCode ?? 0;
    if (s == 401) {
      throw Exception("认证失败：请检查账号和应用密码");
    }
    if (s != 207 && s != 200) {
      throw Exception("连接失败：服务器返回 HTTP $s");
    }
  }

  /// 逐级创建目录（MKCOL），已存在（405）视为成功
  Future<void> mkcolAll(String relDir) async {
    final segments = relPathSegments(relDir);
    String current = "";
    for (final seg in segments) {
      current = current.isEmpty ? seg : "$current/$seg";
      final response = await _dio.request<Uint8List>(
        _path(current),
        options: Options(method: "MKCOL"),
      );
      final s = response.statusCode ?? 0;
      // 201 创建成功；405 已存在；其余视为失败
      if (s != 201 && s != 405 && s != 200 && s != 301) {
        if (s == 401) throw Exception("认证失败：请检查账号和应用密码");
        throw Exception("创建远程目录失败：HTTP $s（$seg）");
      }
    }
  }

  /// 上传字节（onSendProgress: 已发送字节/总字节）
  Future<void> putBytes(
    String relPath,
    Uint8List bytes, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final response = await _dio.put<Uint8List>(
      _path(relPath),
      data: bytes,
      options: Options(headers: {"content-type": "application/octet-stream"}),
      onSendProgress: onSendProgress,
    );
    final s = response.statusCode ?? 0;
    if (s != 200 && s != 201 && s != 204) {
      if (s == 401) throw Exception("认证失败：请检查账号和应用密码");
      throw Exception("上传失败：服务器返回 HTTP $s");
    }
  }

  /// 流式上传本地文件（不整体载入内存，用于大文件）
  Future<void> putFile(
    String relPath,
    File file, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final size = await file.length();
    final response = await _dio.put<Uint8List>(
      _path(relPath),
      data: file.openRead(),
      options: Options(
        headers: {
          "content-type": "application/octet-stream",
          "content-length": "$size",
        },
      ),
      onSendProgress: onSendProgress,
    );
    final s = response.statusCode ?? 0;
    if (s != 200 && s != 201 && s != 204) {
      if (s == 401) throw Exception("认证失败：请检查账号和应用密码");
      throw Exception("上传失败：服务器返回 HTTP $s");
    }
  }

  /// 流式下载远程文件到本地（不整体载入内存，用于大文件）
  Future<void> downloadToFile(
    String relPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final response = await _dio.get<ResponseBody>(
      _path(relPath),
      options: Options(responseType: ResponseType.stream),
      onReceiveProgress: onReceiveProgress,
    );
    final s = response.statusCode ?? 0;
    if (s == 404) {
      throw Exception("远程文件不存在");
    }
    if (s == 401) {
      throw Exception("认证失败：请检查账号和应用密码");
    }
    if (s != 200 && s != 206) {
      throw Exception("下载失败：服务器返回 HTTP $s");
    }
    final body = response.data;
    if (body == null) {
      throw Exception("下载失败：响应为空");
    }
    final sink = File(savePath).openWrite();
    try {
      await for (final chunk in body.stream) {
        sink.add(chunk);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  /// 下载文件，返回原始字节（onReceiveProgress: 已接收字节/总字节）
  Future<Uint8List> getBytes(
    String relPath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final response = await _dio.get<Uint8List>(
      _path(relPath),
      onReceiveProgress: onReceiveProgress,
    );
    final s = response.statusCode ?? 0;
    if (s == 404) {
      throw Exception("远程文件不存在");
    }
    if (s != 200) {
      if (s == 401) throw Exception("认证失败：请检查账号和应用密码");
      throw Exception("下载失败：服务器返回 HTTP $s");
    }
    return response.data ?? Uint8List(0);
  }

  /// 删除远端文件（404 视为已删除）
  Future<void> delete(String relPath) async {
    final response = await _dio.delete<Uint8List>(_path(relPath));
    final s = response.statusCode ?? 0;
    if (s != 200 && s != 204 && s != 404) {
      if (s == 401) throw Exception("认证失败：请检查账号和应用密码");
      throw Exception("删除失败：服务器返回 HTTP $s");
    }
  }

  /// PROPFIND Depth:1 列出目录下的 .qlbak 备份文件，按名称倒序（新的在前）。
  /// 目录不存在（404）返回空列表。
  Future<List<WebDavFile>> list(String relDir) async {
    final response = await _dio.request<Uint8List>(
      _path(relDir),
      options: Options(method: "PROPFIND", headers: {"Depth": "1"}),
      data: _propfindBody,
    );
    final s = response.statusCode ?? 0;
    if (s == 404) return [];
    if (s == 401) throw Exception("认证失败：请检查账号和应用密码");
    if (s != 207 && s != 200) {
      throw Exception("获取文件列表失败：服务器返回 HTTP $s");
    }
    final body = utf8.decode(
      response.data ?? Uint8List(0),
      allowMalformed: true,
    );
    final files = _parseMultistatus(body);
    final backupFiles =
        files.where((f) => !f.isDir && f.name.endsWith(".qlbak")).toList();
    backupFiles.sort((a, b) => b.name.compareTo(a.name));
    return backupFiles;
  }

  /// 解析 207 Multi-Status XML：仅按 local name 匹配节点，兼容任意命名空间前缀
  List<WebDavFile> _parseMultistatus(String body) {
    final result = <WebDavFile>[];
    late final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } catch (_) {
      throw Exception("获取文件列表失败：响应解析错误");
    }
    for (final node in doc.descendantElements) {
      if (node.name.local != "response") continue;
      final hrefEl = _childByLocal(node, "href");
      if (hrefEl == null) continue;
      final rawHref = hrefEl.innerText.trim();
      if (rawHref.isEmpty) continue;
      String pathPart = rawHref;
      if (rawHref.startsWith("http://") || rawHref.startsWith("https://")) {
        try {
          pathPart = Uri.parse(rawHref).path;
        } catch (_) {
          pathPart = rawHref;
        }
      } else {
        try {
          pathPart = Uri.decodeFull(rawHref);
        } catch (_) {
          pathPart = rawHref;
        }
      }
      final name = _basename(pathPart);
      if (name.isEmpty) continue;
      final isDir = node.descendantElements.any(
        (e) => e.name.local == "collection",
      );
      DateTime? modified;
      final lmEl = _descByLocal(node, "getlastmodified");
      if (lmEl != null) {
        try {
          modified = HttpDate.parse(lmEl.innerText.trim());
        } catch (_) {}
      }
      int size = 0;
      final sizeEl = _descByLocal(node, "getcontentlength");
      if (sizeEl != null) {
        size = int.tryParse(sizeEl.innerText.trim()) ?? 0;
      }
      result.add(
        WebDavFile(
          name: name,
          href: pathPart,
          modified: modified,
          size: size,
          isDir: isDir,
        ),
      );
    }
    return result;
  }

  /// 把相对路径拆成干净的段列表（去掉首尾斜杠与空段）
  static List<String> relPathSegments(String relPath) {
    return relPath
        .split("/")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _basename(String pathPart) {
    final segments = pathPart.split("/").where((e) => e.isNotEmpty).toList();
    if (segments.isEmpty) return "";
    try {
      return Uri.decodeComponent(segments.last);
    } catch (_) {
      return segments.last;
    }
  }

  static XmlElement? _childByLocal(XmlElement parent, String local) {
    for (final e in parent.childElements) {
      if (e.name.local == local) return e;
    }
    return null;
  }

  static XmlElement? _descByLocal(XmlElement parent, String local) {
    for (final e in parent.descendantElements) {
      if (e.name.local == local) return e;
    }
    return null;
  }

  void dispose() {
    _dio.close();
  }
}

const String _propfindBody =
    '<?xml version="1.0"?>\n<d:propfind xmlns:d="DAV:"><d:allprop/></d:propfind>';
