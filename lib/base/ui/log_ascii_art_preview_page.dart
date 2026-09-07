import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ASCII 字符画全屏预览
/// - 白底黑字 + 等宽字体（让 block elements 正确显示）
/// - InteractiveViewer 支持双指缩放
/// - 字号自适应：保证能完整看到
class LogAsciiArtPreviewPage extends StatefulWidget {
  final List<String> lines;

  const LogAsciiArtPreviewPage({Key? key, required this.lines})
      : super(key: key);

  @override
  State<LogAsciiArtPreviewPage> createState() => _LogAsciiArtPreviewPageState();
}

class _LogAsciiArtPreviewPageState extends State<LogAsciiArtPreviewPage> {
  /// 字号由"每行字符数"和"屏幕宽度"反推：尽量一行填满屏幕
  /// monospace 字符的等宽比大约 0.6，所以字号 ≈ 屏宽 / 行字符数 / 0.6
  double _fontSize(BuildContext context) {
    if (widget.lines.isEmpty) return 12;
    final maxWidth = widget.lines
        .map((l) => l.length)
        .fold<int>(0, (a, b) => b > a ? b : a);
    if (maxWidth == 0) return 12;
    final screenWidth = MediaQuery.of(context).size.width;
    // 留一点边距
    final usable = screenWidth - 32;
    final size = usable / maxWidth / 0.62;
    // 限制在 8~20 之间
    return size.clamp(8.0, 20.0);
  }

  String get _body => widget.lines.join('\n');

  @override
  Widget build(BuildContext context) {
    final fontSize = _fontSize(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _body,
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        height: 1.0,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 顶部操作条
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CircleAction(
                    icon: CupertinoIcons.doc_on_clipboard,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _body));
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger != null) {
                        messenger.showSnackBar(const SnackBar(
                          content: Text('已复制字符画到剪贴板'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _CircleAction(
                    icon: CupertinoIcons.clear,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleAction({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0x33FFFFFF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
