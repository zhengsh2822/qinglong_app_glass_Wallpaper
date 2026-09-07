import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/extension.dart';

import 'log_line_renderers.dart';
import 'log_models.dart';

/// 脚本日志通用渲染组件（重构版）：
/// - 多类型行级识别器：文本行 / 图片路径行 / Base64 图片行 / ANSI 控制字符过滤
/// - 图片路径行：可点击卡片 → 弹动作菜单（尝试拉图 / 复制路径 / 在 PC 端看）
/// - Base64 行：直接解码渲染缩略图，点击全屏预览
/// - 文本行：SelectableText 支持长按选择复制
///
/// 三处复用：
/// 1. intime_log_page.dart（实时日志）
/// 2. intime_history_log_page.dart（历史日志）
/// 3. task_log_detail_page.dart（任务日志详情）
class LogTextView extends ConsumerStatefulWidget {
  final String? content;
  final String emptyText;
  final int accountIndex;
  final TextStyle? textStyle;
  final EdgeInsets padding;
  final ScrollController? scrollController;

  /// 是否显示右上角"复制全部"悬浮按钮（默认开启，一键复制整段日志）
  final bool showCopyAll;

  const LogTextView({
    super.key,
    required this.content,
    required this.accountIndex,
    this.emptyText = '暂无日志',
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 15),
    this.scrollController,
    this.showCopyAll = true,
  });

  @override
  ConsumerState<LogTextView> createState() => _LogTextViewState();
}

class _LogTextViewState extends ConsumerState<LogTextView> {
  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    if (content == null || content.isEmpty) {
      return Center(
        child: Padding(
          padding: widget.padding,
          child: Text(
            widget.emptyText,
            style: widget.textStyle ??
                const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
          ),
        ),
      );
    }

    // 解析为多类型行
    final lines = parseLogContent(content);
    final children = <Widget>[];

    // 连续文本行聚合为单个 SelectableText，支持跨行自由框选复制；
    // 遇到图片/Base64/字符画卡片时 flush 文本块，作为独立交互分隔段。
    final textBuffer = <String>[];
    void flushText() {
      if (textBuffer.isEmpty) return;
      final text = textBuffer.join('\n');
      textBuffer.clear();
      children.add(buildTextBlock(text, widget.textStyle));
    }

    for (final line in lines) {
      if (line is EmptyLine) {
        // 空行并入文本块，保留原始换行结构
        textBuffer.add('');
        continue;
      }
      if (line is TextLine) {
        textBuffer.add(line.text);
        continue;
      }
      flushText();
      if (line is ImagePathLine) {
        children.add(buildImagePathCard(
          context: context,
          line: line,
          accountIndex: widget.accountIndex,
        ));
      } else if (line is Base64ImageLine) {
        children.add(buildBase64ImageCard(context: context, line: line));
      } else if (line is AsciiArtLine) {
        children.add(buildAsciiArtCard(context: context, line: line));
      }
    }
    flushText();

    return Stack(
      children: [
        SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(
            left: widget.padding.left,
            right: widget.padding.right,
            top: widget.padding.top,
            bottom: MediaQuery.of(context).viewPadding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        if (widget.showCopyAll)
          Positioned(
            top: 6,
            right: widget.padding.right,
            child: _CopyAllButton(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (context.mounted) '已复制全部日志'.toast();
              },
            ),
          ),
      ],
    );
  }
}

/// 右上角"复制全部"悬浮按钮
/// 设计语言与 LogScrollButton / 卡片"运行/停止"胶囊按钮保持一致
class _CopyAllButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _CopyAllButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final Color accent = isCyber
        ? CyberColors.cyan
        : ref.watch(themeProvider).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: 0.3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.doc_on_doc, size: 15, color: accent),
            const SizedBox(width: 4),
            Text(
              '复制全部',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 入口：复用给外部直接调用
/// 解析日志文本为多类型行（文本/图片路径/Base64/字符画/空行）
///
/// 算法：两遍扫描
/// 1. 第一遍：逐行分类（空/Base64/路径/字符画候选/文本）
/// 2. 第二遍：把连续的字符画候选行（≥ _asciiArtMinLines）聚合成一张 AsciiArtLine
List<LogLine> parseLogContent(String content) {
  final lines = content.split('\n');
  final classified = <LogLine>[];

  for (final raw in lines) {
    // 过滤 ANSI 控制字符（\u001b[...m / \r 等）
    final cleaned = stripAnsiAndControls(raw);
    if (cleaned.trim().isEmpty) {
      classified.add(EmptyLine());
      continue;
    }
    // 1. 尝试 Base64 行：data:image/png;base64,xxxx 或 [QR_BASE64]xxxx
    final base64 = tryExtractBase64Image(cleaned);
    if (base64 != null) {
      classified.add(base64);
      continue;
    }
    // 2. 尝试图片路径行
    final path = tryExtractImagePath(cleaned);
    if (path != null) {
      classified.add(path);
      continue;
    }
    // 3. 检查是否是字符画行（block 字符密度高）
    if (isAsciiArtLine(cleaned)) {
      classified.add(_ArtCandidateLine(cleaned));
      continue;
    }
    // 4. 默认：普通文本
    classified.add(TextLine(cleaned));
  }

  // 第二遍：聚合连续字符画候选
  final result = <LogLine>[];
  int i = 0;
  while (i < classified.length) {
    final line = classified[i];
    if (line is _ArtCandidateLine) {
      final buffer = <String>[line.text];
      int j = i + 1;
      while (j < classified.length && classified[j] is _ArtCandidateLine) {
        buffer.add((classified[j] as _ArtCandidateLine).text);
        j++;
      }
      if (buffer.length >= 4) {
        result.add(AsciiArtLine(buffer));
      } else {
        // 不足 4 行：当作普通文本行处理
        for (final t in buffer) {
          result.add(TextLine(t));
        }
      }
      i = j;
    } else {
      result.add(line);
      i++;
    }
  }
  return result;
}

/// 内部：单行识别为"字符画候选"但还没聚合
class _ArtCandidateLine extends LogLine {
  final String text;
  const _ArtCandidateLine(this.text);
}
