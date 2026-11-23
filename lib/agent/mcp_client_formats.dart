/// MCP 客户端接入格式注册表。
///
/// 同一个 Streamable HTTP 端点，各家客户端的配置落点、字段名与传输类型
/// 写法都不一样，硬编码一种格式必然有一半客户端贴不上：
///
/// - Cursor / Trae / Qoder：`"type": "http"`
/// - 通义灵码 / Cherry Studio / Cline：`"type": "streamableHttp"`
/// - Windsurf：只有 `"serverUrl"`
/// - Gemini CLI：只有 `"httpUrl"`
/// - GitHub Copilot（VS Code）：键名是 `"servers"`，不是 `"mcpServers"`
/// - Claude Code / Codex：走 CLI 子命令，不写 JSON
/// - Claude Desktop：只认 stdio，需要 `mcp-remote` 桥接
///
/// 新增客户端只需在 [mcpClientFormats] 追加一条记录，
/// 设置页选择器、复制内容、落点提示全部从这张表取，不再散落在 UI 里。
class McpClientFormat {
  const McpClientFormat({
    required this.id,
    required this.name,
    required this.snippetType,
    required this.target,
    required this.build,
  });

  /// 稳定 id：持久化选中项用，勿随意修改
  final String id;

  /// 展示名
  final String name;

  /// 片段类型标签：Shell / JSON / YAML / URL
  final String snippetType;

  /// 配置落点（文件路径或操作入口）
  final String target;

  /// 把端点 URL 渲染成该客户端可直接粘贴的片段
  final String Function(String url) build;
}

/// 标准 `mcpServers` + `type/url` 形态（Cursor / Trae / Qoder 等）
String _serversJson(String url, {String type = 'http'}) => '''{
  "mcpServers": {
    "qinglong_app": {
      "type": "$type",
      "url": "$url"
    }
  }
}''';

/// 按流行度排序：越靠前越常用，Manual 列表第一屏就能看到主流客户端。
final List<McpClientFormat> mcpClientFormats = <McpClientFormat>[
  McpClientFormat(
    id: 'cursor',
    name: 'Cursor',
    snippetType: 'JSON',
    target: '~/.cursor/mcp.json 或项目 .cursor/mcp.json',
    build: (url) => _serversJson(url),
  ),
  McpClientFormat(
    id: 'claude_code',
    name: 'Claude Code',
    snippetType: 'Shell',
    target: '终端执行；也可写入项目 .mcp.json 的 mcpServers',
    build: (url) => 'claude mcp add --transport http qinglong_app "$url"',
  ),
  McpClientFormat(
    id: 'codex',
    name: 'Codex (OpenAI)',
    snippetType: 'Shell',
    target: '终端执行；或写入 ~/.codex/config.toml',
    build: (url) => 'codex mcp add qinglong_app --url "$url"',
  ),
  McpClientFormat(
    id: 'copilot',
    name: 'GitHub Copilot',
    snippetType: 'JSON',
    target: '工作区 .vscode/mcp.json（键名是 servers）',
    build:
        (url) => '''{
  "servers": {
    "qinglong_app": {
      "type": "http",
      "url": "$url"
    }
  }
}''',
  ),
  McpClientFormat(
    id: 'cherry',
    name: 'Cherry Studio',
    snippetType: 'JSON',
    target: '设置 → MCP 服务器 → 添加（类型选 Streamable HTTP）',
    build: (url) => _serversJson(url, type: 'streamableHttp'),
  ),
  McpClientFormat(
    id: 'cline',
    name: 'Cline / Roo Code',
    snippetType: 'JSON',
    target: 'MCP Servers → Configure → cline_mcp_settings.json',
    build: (url) => _serversJson(url, type: 'streamableHttp'),
  ),
  McpClientFormat(
    id: 'lingma',
    name: 'Tongyi Lingma（通义灵码）',
    snippetType: 'JSON',
    target: '~/.lingma/mcp.json',
    build: (url) => _serversJson(url, type: 'streamableHttp'),
  ),
  McpClientFormat(
    id: 'kimi',
    name: 'Kimi (Moonshot)',
    snippetType: 'JSON',
    target: '~/.kimi/mcp.json',
    build: (url) => _serversJson(url),
  ),
  McpClientFormat(
    id: 'doubao',
    name: 'Doubao (MarsCode)',
    snippetType: 'JSON',
    target: '项目 .marscode/mcp.json',
    build: (url) => _serversJson(url),
  ),
  McpClientFormat(
    id: 'trae',
    name: 'Trae',
    snippetType: 'JSON',
    target: '~/.trae/mcp.json 或项目 .trae/mcp.json',
    build: (url) => _serversJson(url),
  ),
  McpClientFormat(
    id: 'qoder',
    name: 'Qoder',
    snippetType: 'JSON',
    target: '~/.qoder/mcp.json',
    build: (url) => _serversJson(url),
  ),
  McpClientFormat(
    id: 'gemini',
    name: 'Gemini CLI',
    snippetType: 'JSON',
    target: '~/.gemini/settings.json（字段是 httpUrl）',
    build:
        (url) => '''{
  "mcpServers": {
    "qinglong_app": {
      "httpUrl": "$url"
    }
  }
}''',
  ),
  McpClientFormat(
    id: 'windsurf',
    name: 'Windsurf',
    snippetType: 'JSON',
    target: '~/.codeium/windsurf/mcp_config.json（字段是 serverUrl）',
    build:
        (url) => '''{
  "mcpServers": {
    "qinglong_app": {
      "serverUrl": "$url"
    }
  }
}''',
  ),
  McpClientFormat(
    id: 'zed',
    name: 'Zed',
    snippetType: 'JSON',
    target: '~/.config/zed/settings.json（需支持远程 MCP 的版本）',
    build:
        (url) => '''{
  "context_servers": {
    "qinglong_app": {
      "source": "custom",
      "url": "$url"
    }
  }
}''',
  ),
  McpClientFormat(
    id: 'continue',
    name: 'Continue',
    snippetType: 'YAML',
    target: '~/.continue/config.yaml',
    build:
        (url) => '''mcpServers:
  - name: qinglong_app
    type: streamable-http
    url: $url''',
  ),
  McpClientFormat(
    id: 'goose',
    name: 'Goose',
    snippetType: 'YAML',
    target: '~/.config/goose/config.yaml',
    build:
        (url) => '''extensions:
  qinglong_app:
    enabled: true
    type: streamable_http
    uri: $url''',
  ),
  McpClientFormat(
    id: 'claude_desktop',
    name: 'Claude Desktop',
    snippetType: 'JSON',
    target: 'claude_desktop_config.json（仅 stdio，经 mcp-remote 转接）',
    build:
        (url) => '''{
  "mcpServers": {
    "qinglong_app": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "$url"]
    }
  }
}''',
  ),
  McpClientFormat(
    id: 'generic',
    name: '通用 Streamable HTTP',
    snippetType: 'JSON',
    target: '任意支持 mcpServers 的客户端',
    build: (url) => _serversJson(url),
  ),
  McpClientFormat(
    id: 'url',
    name: '仅端点 URL',
    snippetType: 'URL',
    target: 'LM Studio / Dify / n8n 等可直接填 URL 的客户端',
    build: (url) => url,
  ),
];

/// 按 id 取格式；找不到时回退第一条（Cursor），保证 UI 永远有内容可显示。
McpClientFormat mcpClientFormatOf(String id) => mcpClientFormats.firstWhere(
  (f) => f.id == id,
  orElse: () => mcpClientFormats.first,
);
