import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/extension.dart';

import 'log_models.dart';
import 'log_image_preview_page.dart';
import 'log_ascii_art_preview_page.dart';

/// ============================================================
/// 识别工具（纯函数，可被单元测试直接调用）
/// ============================================================

/// 识别 .png/.jpg/.jpeg 图片路径
/// 兼容：/xxx/...png、相对路径、URI 编码
/// 不要求路径以 / 开头，避免误判
final RegExp _imgPathRe = RegExp(
  r'([\w./\-%]+\.(?:png|jpg|jpeg))(?=\s|$|[,;\)\]])',
  caseSensitive: false,
);

/// 识别 data URI: data:image/png;base64,xxxxx
final RegExp _dataUriRe = RegExp(
  r'data:image/(png|jpe?g);base64,([A-Za-z0-9+/=]+)',
  caseSensitive: false,
);

/// 识别 [QR_BASE64]xxxxx 或 [BASE64_IMAGE]xxxxx
final RegExp _taggedBase64Re = RegExp(
  r'\[(?:QR_BASE64|BASE64_IMAGE|IMG_BASE64)\]\s*([A-Za-z0-9+/=]{64,})',
  caseSensitive: false,
);

/// Unicode block elements（qrcode-terminal 字符画的主要字符集）
/// 半角：█▀▄▌▐；上下半：▛▜▙▟▚▞；小方块：▗▖▝▘
/// 加上全角字符（部分中文字体也用全角空格画）
const String _blockChars =
    '█▀▄▌▐▛▜▙▟▚▞▗▖▝▘■□▪▫●○◾◽⬛⬜';

/// 单行 block 字符的最小密度阈值（占比）
const double _asciiArtLineDensity = 0.15;

/// 过滤 ANSI 控制字符（颜色码 \u001b[31m 等）
/// 实际日志里还可能出现 \r、\u0000 等
String stripAnsiAndControls(String s) {
  // 去掉 ANSI 转义序列：ESC [ ... m
  var result = s.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
  // 进度条/进度覆盖用 \r：取最后一个 \r 之后的内容（避免和上一行内容视觉重叠）
  if (result.contains('\r')) {
    result = result.substring(result.lastIndexOf('\r') + 1);
  }
  // 去掉 NUL 和 BEL
  result = result.replaceAll('\x00', '').replaceAll('\x07', '');
  return result;
}

ImagePathLine? tryExtractImagePath(String line) {
  final m = _imgPathRe.firstMatch(line);
  if (m == null) return null;
  final path = m.group(1)!;
  // 启发式：路径必须包含 / 或 \，避免把普通文本中的 .png 字误判
  if (!path.contains('/') && !path.contains('\\')) return null;
  return ImagePathLine(line, path);
}

Base64ImageLine? tryExtractBase64Image(String line) {
  final m = _dataUriRe.firstMatch(line);
  if (m != null) {
    return Base64ImageLine(
      base64: m.group(2)!,
      mime: m.group(1)!.toLowerCase().contains('jp') ? 'image/jpeg' : 'image/png',
      raw: line,
    );
  }
  final m2 = _taggedBase64Re.firstMatch(line);
  if (m2 != null) {
    return Base64ImageLine(
      base64: m2.group(1)!,
      mime: 'image/png',
      raw: line,
    );
  }
  return null;
}

/// 单行是否是 block characters 字符画行
/// 条件：行长度 ≥ 8 且 block 字符占比 ≥ 15%
bool isAsciiArtLine(String line) {
  if (line.length < 8) return false;
  int blockCount = 0;
  for (int i = 0; i < line.length; i++) {
    if (_blockChars.contains(line[i])) blockCount++;
  }
  // 允许行尾 \r 残留（前面已处理，但保险起见）
  return blockCount / line.length >= _asciiArtLineDensity;
}

/// ============================================================
/// 行渲染器
/// ============================================================

/// 空白回调（用于 loading 状态下禁用按钮）
class _NoopCallback {
  static void instance() {}
}

/// 连续文本块（多行合并成一个 SelectableText，跨行自由框选复制）
Widget buildTextBlock(String text, TextStyle? baseStyle) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: SelectableText(
      text,
      selectionControls: cupertinoTextSelectionControls,
      style: baseStyle ?? const TextStyle(fontSize: 12),
    ),
  );
}

/// 图片路径行卡片
Widget buildImagePathCard({
  required BuildContext context,
  required ImagePathLine line,
  required int accountIndex,
}) {
  return _ImagePathCard(
    path: line.path,
    raw: line.raw,
    accountIndex: accountIndex,
  );
}

/// Base64 图片行卡片
Widget buildBase64ImageCard({
  required BuildContext context,
  required Base64ImageLine line,
}) {
  return _Base64ImageCard(line: line);
}

/// ASCII 字符画卡片
Widget buildAsciiArtCard({
  required BuildContext context,
  required AsciiArtLine line,
}) {
  return _AsciiArtCard(line: line);
}

// ============================================================
// 图片路径行
// ============================================================
class _ImagePathCard extends ConsumerStatefulWidget {
  final String path;
  final String raw;
  final int accountIndex;

  const _ImagePathCard({
    required this.path,
    required this.raw,
    required this.accountIndex,
  });

  @override
  ConsumerState<_ImagePathCard> createState() => _ImagePathCardState();
}

class _ImagePathCardState extends ConsumerState<_ImagePathCard> {
  String get _fileName {
    final p = widget.path;
    final idx = p.lastIndexOf('/');
    final name = idx >= 0 ? p.substring(idx + 1) : p;
    return name.isEmpty ? p : name;
  }

  String get _prefix {
    // 提取路径在原始行中之前的内容（如"二维码图片已保存: "）
    final idx = widget.raw.indexOf(widget.path);
    if (idx <= 0) return '';
    return widget.raw.substring(0, idx).trim();
  }

  void _showActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _PathActionSheet(
        path: widget.path,
        accountIndex: widget.accountIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isCyber = theme.themeMode == modeCyber;
    final accent = theme.primaryColor;
    final borderColor = accent.withOpacity(isCyber ? 0.55 : 0.35);
    final textColor = isCyber
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final dimColor = isCyber
        ? const Color(0xFF8D8D8D)
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _showActionSheet,
          child: Container(
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCyber
                        ? const Color(0xFF1A1A24)
                        : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: borderColor.withOpacity(0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.photo,
                    size: 20,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fileName,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _prefix.isNotEmpty
                            ? '$_prefix · 长按选择操作'
                            : '长按选择操作',
                        style: TextStyle(color: dimColor, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: dimColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 路径行点击后的动作弹窗
class _PathActionSheet extends ConsumerStatefulWidget {
  final String path;
  final int accountIndex;

  const _PathActionSheet({required this.path, required this.accountIndex});

  @override
  ConsumerState<_PathActionSheet> createState() => _PathActionSheetState();
}

class _PathActionSheetState extends ConsumerState<_PathActionSheet> {
  bool _loading = false;

  Future<void> _tryFetchImage() async {
    setState(() => _loading = true);
    try {
      final api = Api(widget.accountIndex);
      // 候选 path 列表
      final idx = widget.path.lastIndexOf('/');
      final rel = idx >= 0 && idx < widget.path.length - 1
          ? widget.path.substring(idx + 1)
          : widget.path;
      final candidates = <String>[
        widget.path,
        if (rel != widget.path) rel,
        if (rel != widget.path) 'data/scripts/$rel',
        if (rel != widget.path) 'scripts/$rel',
      ];

      GetBytesResult? success;
      GetBytesResult? lastError;
      for (final p in candidates) {
        final r = await api.scriptFile(p);
        if (r.success && r.bytes.isNotEmpty) {
          success = r;
          break;
        }
        lastError = r;
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      if (success != null) {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black87,
            pageBuilder: (_, __, ___) => LogImagePreviewPage(
              path: widget.path,
              bytes: Uint8List.fromList(success!.bytes),
            ),
          ),
        );
      } else {
        _showFetchFailedDialog(lastError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFetchFailedDialog(GetBytesResult? r) {
    // 必须用 builder 自己的 context 来 pop dialog
    // 否则外层 _PathActionSheetState.context（ActionSheet 已被关闭）会让 pop 无效
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('拉取失败'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SingleChildScrollView(
            child: Text(
              '青龙接口未找到该文件（常见原因：路径不在 /ql/scripts 目录）。\n\n'
              '可手动复制路径到 PC 端青龙面板查看。\n\n'
              '错误: ${r?.code ?? "-"} · ${r?.message ?? ""}\n'
              '响应: ${r?.bodyPreview ?? ""}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.path));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('复制路径'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.path));
    if (!mounted) return;
    Navigator.of(context).pop();
    '已复制路径到剪贴板'.toast();
  }

  // VoidCallback wrapper：忽略 _tryFetchImage 返回的 Future，规避类型推断问题
  void _onTapFetch() {
    _tryFetchImage();
  }

  // VoidCallback wrapper：忽略 _copyPath 返回的 Future
  void _onTapCopy() {
    _copyPath();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
      title: Text(widget.path),
      message: const Text('选择操作'),
      actions: [
        if (_loading)
          const CupertinoActionSheetAction(
            onPressed: _NoopCallback.instance,
            child: CupertinoActivityIndicator(),
          )
        else
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: _onTapFetch,
            child: const Text('尝试拉取图片'),
          ),
        CupertinoActionSheetAction(
          onPressed: _onTapCopy,
          child: const Text('复制路径'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        isDestructiveAction: true,
        child: const Text('取消'),
      ),
    );
  }
}

// ============================================================
// Base64 图片行
// ============================================================
class _Base64ImageCard extends StatefulWidget {
  final Base64ImageLine line;

  const _Base64ImageCard({required this.line});

  @override
  State<_Base64ImageCard> createState() => _Base64ImageCardState();
}

class _Base64ImageCardState extends State<_Base64ImageCard> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryDecode();
  }

  void _tryDecode() {
    try {
      final bytes = base64Decode(widget.line.base64);
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _bytes == null
              ? null
              : () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.black87,
                      pageBuilder: (_, __, ___) => LogImagePreviewPage(
                        path: 'Base64 图片',
                        bytes: _bytes!,
                      ),
                    ),
                  );
                },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00CCCC).withOpacity(0.4),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _bytes != null
                      ? Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true)
                      : Center(
                          child: Icon(
                            _error != null
                                ? CupertinoIcons.exclamationmark_triangle
                                : CupertinoIcons.photo,
                            color: const Color(0xFF555555),
                            size: 22,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Base64 内嵌图片',
                        style: TextStyle(
                          color: Color(0xFF00CCCC),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _error != null
                            ? '解码失败: $_error'
                            : '点击全屏预览 · ${(widget.line.base64.length / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(
                          color: Color(0xFF8D8D8D),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ASCII 字符画行（qrcode-terminal 风格的 Unicode block 输出）
// ============================================================
class _AsciiArtCard extends StatelessWidget {
  final AsciiArtLine line;

  const _AsciiArtCard({required this.line});

  /// 渲染预览缩略图：取前 N 行显示，让用户能预览"是不是字符画"
  static const int _previewLines = 8;

  @override
  Widget build(BuildContext context) {
    final preview = line.lines.take(_previewLines).join('\n');
    final moreCount = line.lines.length - _previewLines;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                barrierColor: Colors.black87,
                pageBuilder: (_, __, ___) => LogAsciiArtPreviewPage(
                  lines: line.lines,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00CCCC).withOpacity(0.4),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      preview,
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'monospace',
                        fontSize: 6,
                        height: 1.0,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ASCII 字符画',
                        style: TextStyle(
                          color: Color(0xFF00CCCC),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${line.lines.length} 行 · 宽 ${line.maxWidth} 字符'
                        '${moreCount > 0 ? " · 点击全屏查看" : ""}',
                        style: const TextStyle(
                          color: Color(0xFF8D8D8D),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: Color(0xFF8D8D8D),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
