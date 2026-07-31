import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';

/// 赛博终端风脚本查看/编辑演示页
///
/// 背景层级：CyberBackground(纯黑+光影) → Scaffold(transparent) → 代码区(black 0.3 + 青色边框)
/// 字体颜色：普通代码 #E0E0E0 / 注释 #607D8B / 关键字 #00F0FF / 字符串 #00FF94
class ScriptEditorPage extends ConsumerWidget {
  final String title;
  final String content;

  const ScriptEditorPage({
    super.key,
    this.title = 'WangChao.js',
    this.content = _demoScript,
  });

  /// 示例脚本内容
  static const String _demoScript = r'''/**
 * WangChao.js
 * cron: 20 9 * * *
 * 自动签到脚本
 */

const $ = require('env.js');
const notify = require('./sendNotify');
const crypto = require('crypto');

const KEY = 'qinglong_secret';

async function main() {
  // 初始化环境变量
  const cookie = $.get('wc_cookie');
  if (!cookie) {
    console.log('未配置cookie');
    return;
  }

  // 登录
  console.log('开始执行');
  const result = await login(cookie);
  if (result.code === 200) {
    await notify.sendNotify('WangChao', '签到成功');
  } else {
    await notify.sendNotify('WangChao', '签到失败: ' + result.msg);
  }
}

async function login(cookie) {
  const sign = crypto.createHmac('sha256', KEY)
    .update(cookie)
    .digest('hex');
  return { code: 200, sign: sign };
}

module.exports = main;
''';

  @override
  Widget build(BuildContext context, ref) {
    return CyberBackground(
      showGradient: true,
      child: Scaffold(
        // 【背景透明】强制transparent，让CyberBackground的光影透出
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          // 【AppBar透明】背景透明，融入暗黑主题
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: CyberColors.cyan),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            title,
            // 【等宽字体】标题使用等宽字体
            style: const TextStyle(
              color: CyberColors.cyan,
              fontSize: 16,
              fontFamily: CyberColors.monoFont,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {},
              child: const Text(
                '保存',
                style: TextStyle(
                  color: CyberColors.cyan,
                  fontSize: 15,
                  fontFamily: CyberColors.monoFont,
                ),
              ),
            ),
          ],
        ),
        body: _buildCodeViewer(context),
      ),
    );
  }

  /// 代码查看区：暗色背景 + 青色边框 + 等宽字体 + 语法高亮
  Widget _buildCodeViewer(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // 【编辑器背景】半透明黑色填充，非白色
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        // 【青色边框】1像素赛博青微透明边框
        border: Border.all(
          color: CyberColors.cyan.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: SelectableText.rich(
          TextSpan(
            children: _highlightCode(content),
            // 【等宽字体】代码强制使用等宽字体
            style: const TextStyle(
              fontFamily: CyberColors.monoFont,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          selectionControls: cupertinoTextSelectionControls,
        ),
      ),
    );
  }

  /// 简易 JS 语法高亮
  ///
  /// 颜色规范：
  /// - 注释 `//...` / `/*...*/`：灰蓝色 #607D8B
  /// - 字符串 `"..."` / `'...'`：荧光绿 #00FF94
  /// - 关键字 const/async/function 等：赛博青 #00F0FF
  /// - 普通代码：冷白色 #E0E0E0
  List<TextSpan> _highlightCode(String code) {
    final spans = <TextSpan>[];

    // JS 关键字列表
    const keywords = {
      'const',
      'let',
      'var',
      'function',
      'return',
      'if',
      'else',
      'for',
      'while',
      'await',
      'async',
      'require',
      'module',
      'exports',
      'new',
      'class',
      'import',
      'export',
      'default',
      'typeof',
      'try',
      'catch',
      'finally',
      'throw',
      'break',
      'continue',
      'switch',
      'case',
      'this',
    };

    final lines = code.split('\n');

    for (int li = 0; li < lines.length; li++) {
      final line = lines[li];
      _highlightLine(line, keywords, spans);
      if (li < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  /// 逐行高亮：先提取注释，再处理剩余部分的字符串和关键字
  void _highlightLine(String line, Set<String> keywords, List<TextSpan> spans) {
    // 检测行注释 //
    int commentIdx = -1;

    // 简单检测：找到 `//` 且不在字符串内
    int i = 0;
    bool inString = false;
    String stringChar = '';
    while (i < line.length - 1) {
      final ch = line[i];
      final next = line[i + 1];

      if (inString) {
        if (ch == stringChar && line[i - 1] != '\\') {
          inString = false;
        }
      } else {
        if (ch == '"' || ch == "'") {
          inString = true;
          stringChar = ch;
        } else if (ch == '/' && next == '/') {
          commentIdx = i;
          break;
        }
      }
      i++;
    }

    String codePart = line;
    String commentPart = '';

    if (commentIdx >= 0) {
      codePart = line.substring(0, commentIdx);
      commentPart = line.substring(commentIdx);
    }

    // 检测块注释 /* ... */（单行内的情况）
    final blockStart = codePart.indexOf('/*');
    final blockEnd = codePart.indexOf('*/');
    if (blockStart >= 0) {
      if (blockEnd >= 0 && blockEnd > blockStart) {
        // 单行内完整的块注释
        _tokenizeKeywords(codePart.substring(0, blockStart), keywords, spans);
        spans.add(
          TextSpan(
            text: codePart.substring(blockStart, blockEnd + 2),
            // 【注释颜色】灰蓝色
            style: const TextStyle(color: Color(0xFF607D8B)),
          ),
        );
        _tokenizeKeywords(codePart.substring(blockEnd + 2), keywords, spans);
      } else {
        // 块注释开始，未结束
        _tokenizeKeywords(codePart.substring(0, blockStart), keywords, spans);
        spans.add(
          TextSpan(
            text: codePart.substring(blockStart),
            style: const TextStyle(color: Color(0xFF607D8B)),
          ),
        );
      }
      // 添加行注释部分
      if (commentPart.isNotEmpty) {
        spans.add(
          TextSpan(
            text: commentPart,
            style: const TextStyle(color: Color(0xFF607D8B)),
          ),
        );
      }
      return;
    }

    // 高亮代码部分（关键字 + 字符串 + 普通文本）
    _tokenizeKeywords(codePart, keywords, spans);

    // 添加行注释
    if (commentPart.isNotEmpty) {
      spans.add(
        TextSpan(
          text: commentPart,
          // 【注释颜色】灰蓝色 #607D8B
          style: const TextStyle(color: Color(0xFF607D8B)),
        ),
      );
    }
  }

  /// 分词高亮：字符串用绿色，关键字用青色，其余用冷白色
  void _tokenizeKeywords(
    String text,
    Set<String> keywords,
    List<TextSpan> spans,
  ) {
    if (text.isEmpty) return;

    // 正则匹配：字符串、关键字、标识符、数字、符号
    final regex = RegExp(
      r'''("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|([A-Za-z_$][A-Za-z0-9_$]*)|(\d+)|(\s+)|([^\sA-Za-z0-9_$"'])''',
    );

    for (final match in regex.allMatches(text)) {
      if (match.group(1) != null) {
        // 字符串
        spans.add(
          TextSpan(
            text: match.group(1),
            // 【字符串颜色】荧光绿 #00FF94
            style: const TextStyle(color: CyberColors.neonGreen),
          ),
        );
      } else if (match.group(2) != null) {
        final word = match.group(2)!;
        if (keywords.contains(word)) {
          spans.add(
            TextSpan(
              text: word,
              // 【关键字颜色】赛博青 #00F0FF
              style: const TextStyle(color: CyberColors.cyan),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: word,
              // 【普通代码颜色】冷白色 #E0E0E0
              style: const TextStyle(color: Color(0xFFE0E0E0)),
            ),
          );
        }
      } else if (match.group(3) != null) {
        // 数字
        spans.add(
          TextSpan(
            text: match.group(3),
            style: const TextStyle(color: CyberColors.neonGreen),
          ),
        );
      } else if (match.group(4) != null) {
        // 空白
        spans.add(TextSpan(text: match.group(4)));
      } else if (match.group(5) != null) {
        // 符号
        spans.add(
          TextSpan(
            text: match.group(5),
            style: const TextStyle(color: Color(0xFFE0E0E0)),
          ),
        );
      }
    }
  }
}
