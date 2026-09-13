import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';

/// 可预览的图片扩展名（供各文件入口分流判断共用）
const List<String> kImageExts = [
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
];

/// 文件名是否为可预览图片（大小写不敏感）
bool isImageFileName(String name) {
  final t = name.toLowerCase();
  return kImageExts.any(t.endsWith);
}

/// 独立图片预览页：供上传组件/配置页等入口 push。
/// [localPath] 传本地路径则直接读本地字节（不走面板接口）；
/// 否则按 [fileName]+[dirPath] 走 POST /scripts/download 拉面板脚本文件。
class ScriptImagePreviewPage extends ConsumerWidget {
  final String fileName;
  final String? dirPath;
  final String? localPath;

  const ScriptImagePreviewPage({
    Key? key,
    required this.fileName,
    this.dirPath,
    this.localPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final Widget scaffold = Scaffold(
      backgroundColor:
          isCyber
              ? Colors.transparent
              : ref.watch(themeProvider).themeColor.codeBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          Navigator.of(context).pop();
        },
        title: fileName,
      ),
      body: ScriptImagePreviewBody(
        accountIndex: SingleAccountPageState.of(context)?.index ?? 0,
        fileName: fileName,
        dirPath: dirPath,
        localPath: localPath,
      ),
    );
    // 赛博模式：CyberBackground 包裹透明 Scaffold，与脚本详情页同款处理
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }
}

/// 脚本图片预览主体（脚本详情页内嵌 / 独立页共用）
///
/// 面板取数走 [/open/scripts/download]（filename+path）原始文件流；
/// 渲染用 [FilterQuality.none] 像素级缩放——二维码等小图放大后保持锐利可扫，
/// 默认双线性插值会把小尺寸二维码糊掉（这正是"符号拼接感"的来源之一）。
class ScriptImagePreviewBody extends StatefulWidget {
  /// 构建注入的序号，界面可见——用于确认手机上跑的是哪个构建
  ///（曾出现 gradle 缓存导致新旧构建产物 MD5 相同的假更新）
  static const int buildNo = int.fromEnvironment('LOCAL_BUILD_NO');

  final int accountIndex;
  final String fileName;

  /// 脚本在 scripts 目录下的子目录（无分隔符结尾，可空）
  final String? dirPath;

  /// 本地文件模式：传本地路径则读本地字节（上传/配置页入口），不走面板接口
  final String? localPath;

  const ScriptImagePreviewBody({
    Key? key,
    required this.accountIndex,
    required this.fileName,
    this.dirPath,
    this.localPath,
  }) : super(key: key);

  @override
  State<ScriptImagePreviewBody> createState() =>
      _ScriptImagePreviewBodyState();
}

class _ScriptImagePreviewBodyState extends State<ScriptImagePreviewBody> {
  bool _loading = true;
  Uint8List? _bytes;
  int _width = 0;
  int _height = 0;
  String _loadedFrom = '';
  String _error = '';

  /// 候选 path（scripts 下相对子目录）：详情页传入的优先，空路径兜底
  /// （文件实际在 scripts 根时 dirPath 传了也取不到）
  List<String> _buildPathCandidates() {
    final dir = (widget.dirPath ?? '').trim();
    return dir.isEmpty ? <String>[''] : <String>[dir, ''];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    // 本地文件模式（上传/配置页入口）：直接读本地字节，不走面板接口
    final local = widget.localPath;
    if (local != null && local.isNotEmpty) {
      try {
        final bytes = await File(local).readAsBytes();
        final size = await _decodeSize(bytes);
        if (!mounted) return;
        if (size == null) {
          setState(() {
            _loading = false;
            _error = '本地文件不是有效图片';
          });
          return;
        }
        setState(() {
          _bytes = bytes;
          _width = size.$1;
          _height = size.$2;
          _loadedFrom = '本地文件';
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
      return;
    }
    final api = Api(widget.accountIndex);
    final attempts = <String>[];
    for (final dir in _buildPathCandidates()) {
      // POST /scripts/download（filename+path）→ res.download 原始文件流
      final r = await api.scriptFileDownload(widget.fileName, dir);
      if (r.success && r.bytes.isNotEmpty) {
        final bytes = Uint8List.fromList(r.bytes);
        // 能解码成图片才算命中（403 等错误已由接口层转 fail，此处兜底）
        final size = await _decodeSize(bytes);
        if (size != null) {
          if (!mounted) return;
          setState(() {
            _bytes = bytes;
            _width = size.$1;
            _height = size.$2;
            _loadedFrom = 'path="$dir"';
            _loading = false;
          });
          return;
        }
        attempts.add('path="$dir" → 响应非图片数据(${_bytesPreview(bytes)})');
        continue;
      }
      attempts.add(
        'path="$dir" → ${r.code} ${r.message ?? ""}${_bodyPreview(r.bodyPreview)}',
      );
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = attempts.join('\n');
    });
  }

  /// 解码取尺寸，同时验证字节确实是图片；失败返回 null
  Future<(int, int)?> _decodeSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  /// 诊断用：非图片响应的前 80 字节文本快照（识别 HTML 兜底页/JSON 错误体）
  String _bytesPreview(Uint8List bytes) {
    final n = bytes.length > 80 ? 80 : bytes.length;
    return utf8
        .decode(bytes.take(n).toList(), allowMalformed: true)
        .replaceAll('\n', ' ');
  }

  String _bodyPreview(String s) {
    if (s.isEmpty) return '';
    final t = s.length > 120 ? s.substring(0, 120) : s;
    return ' · ${t.replaceAll('\n', ' ')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CupertinoActivityIndicator(radius: 14),
            SizedBox(height: 10),
            Text('正在拉取图片…', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    if (_bytes == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 36,
              color: CupertinoColors.systemOrange,
            ),
            const SizedBox(height: 12),
            const Text(
              '图片拉取失败（已尝试以下参数）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'build=${ScriptImagePreviewBody.buildNo}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _error,
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              onPressed: _load,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final kb = (_bytes!.length / 1024).toStringAsFixed(1);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 8,
                child: Image.memory(
                  _bytes!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$_width×$_height · $kb KB · build=${ScriptImagePreviewBody.buildNo}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
            Text(
              _loadedFrom,
              style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              onPressed: _load,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.refresh, size: 15),
                  SizedBox(width: 4),
                  Text('刷新', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
