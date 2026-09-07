/// 日志行模型（多类型识别）
///
/// 5 种行类型：
/// - EmptyLine        空白行
/// - TextLine         普通文本
/// - ImagePathLine    含图片路径（/xxx/...png|jpg|jpeg）
/// - Base64ImageLine  含 data:image/png;base64,xxx 或 [QR_BASE64]xxx
/// - AsciiArtLine     连续多行 block elements 字符画（如 qrcode-terminal 输出）
///
/// 新增类型只需在 LogLine 子类化，并在 parseLogContent 中加识别规则
/// 渲染器在 log_line_renderers.dart 中按类型分发
library;

abstract class LogLine {
  const LogLine();
}

class EmptyLine extends LogLine {
  const EmptyLine();
}

class TextLine extends LogLine {
  final String text;
  const TextLine(this.text);
}

class ImagePathLine extends LogLine {
  /// 完整原始行（用于"前缀提示"展示）
  final String raw;
  /// 识别到的图片绝对/相对路径
  final String path;

  const ImagePathLine(this.raw, this.path);
}

class Base64ImageLine extends LogLine {
  /// base64 字符串（不含前缀）
  final String base64;
  /// 推断的 mime（image/png / image/jpeg）
  final String mime;
  /// 原始行（用于在卡片中提示用户）
  final String raw;

  const Base64ImageLine({
    required this.base64,
    required this.mime,
    required this.raw,
  });
}

/// 连续多行 block elements 字符画
/// 由 parseLogContent 在"逐行"识别出连续若干"含 block 字符"行后聚合而成
class AsciiArtLine extends LogLine {
  /// 所有原始行（含末尾换行已 strip）
  final List<String> lines;

  const AsciiArtLine(this.lines);

  /// 推断的最大行宽（字符数）
  int get maxWidth {
    if (lines.isEmpty) return 0;
    int m = 0;
    for (final l in lines) {
      if (l.length > m) m = l.length;
    }
    return m;
  }
}
