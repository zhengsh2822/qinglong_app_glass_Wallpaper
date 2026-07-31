/// 脚本/配置文件的代码语言识别工具
///
/// 统一从文件名后缀推断 highlight 语言 id，
/// 消除 [ScriptDetailPage] / [ConfigDetailPage] / [ConfigEditPage] 中的重复实现。
class LanguageUtils {
  LanguageUtils._();

  /// 根据文件名后缀返回 highlight 语言 id
  ///
  /// 支持：.js → javascript，.sh → shell，.py → python，
  /// .json → json，.yaml/.yml → yaml，其他默认 shell
  static String fromFileName(String title) {
    if (title.endsWith('.js')) return 'javascript';
    if (title.endsWith('.sh')) return 'shell';
    if (title.endsWith('.py')) return 'python';
    if (title.endsWith('.json')) return 'json';
    if (title.endsWith('.yaml') || title.endsWith('.yml')) return 'yaml';
    return 'shell';
  }
}
