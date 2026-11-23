import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/selectable_chip.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 一个青龙应用授权资源。中文名与 add_appkey_page.dart 的预设权限保持一致，
/// 作为唯一数据源，避免两个页面各维护一份。
class ScopeResource {
  final String key;
  final String label;
  final String description;
  final bool supportsWrite;

  const ScopeResource({
    required this.key,
    required this.label,
    required this.description,
    this.supportsWrite = true,
  });

  String get readKey => '$key:read';
}

const List<ScopeResource> kScopeResources = <ScopeResource>[
  ScopeResource(
      key: 'crons', label: '定时任务', description: '搜索/查看任务定义、运行与停止任务'),
  ScopeResource(
      key: 'envs', label: '环境变量', description: '查看环境变量元数据（值已脱敏）'),
  ScopeResource(key: 'configs', label: '配置文件', description: '查看配置文件'),
  ScopeResource(key: 'scripts', label: '脚本管理', description: '查看脚本与目录'),
  ScopeResource(key: 'logs', label: '任务日志', description: '读取任务日志尾部'),
  ScopeResource(
      key: 'dependencies', label: '依赖管理', description: '查看依赖与安装状态'),
  ScopeResource(key: 'subscriptions', label: '订阅管理', description: '查看订阅'),
  ScopeResource(
      key: 'system', label: '系统信息', description: '面板系统状态',
      supportsWrite: false),
  ScopeResource(
      key: 'dashboard',
      label: '仪表盘',
      description: '今日运行明细、趋势、实时运行态（青龙 2.22+）',
      supportsWrite: false),
];

/// 共享的应用授权 scope 选择器：只读 / 读写分级、中文说明、自定义 key。
/// 使用项目统一主题取色与 SelectableChip，供 Agent 设置页等复用。
class ScopePicker extends ConsumerStatefulWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const ScopePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  ConsumerState<ScopePicker> createState() => _ScopePickerState();
}

class _ScopePickerState extends ConsumerState<ScopePicker> {
  final TextEditingController _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _emit(Set<String> next) => widget.onChanged(next);

  void _toggleRead(ScopeResource resource, bool value) {
    final next = Set<String>.from(widget.selected);
    if (value) {
      next.remove(resource.key);
      next.add(resource.readKey);
    } else {
      next.remove(resource.readKey);
    }
    _emit(next);
  }

  void _toggleWrite(ScopeResource resource, bool value) {
    final next = Set<String>.from(widget.selected);
    if (value) {
      next.remove(resource.readKey);
      next.add(resource.key);
    } else {
      next.remove(resource.key);
    }
    _emit(next);
  }

  void _addCustom() {
    final key = _custom.text.trim();
    if (key.isEmpty) return;
    if (!RegExp(r'^[a-zA-Z0-9_:-]+$').hasMatch(key)) {
      'scope key 只能包含字母、数字、下划线、冒号或连字符'.toast();
      return;
    }
    final next = Set<String>.from(widget.selected)..add(key);
    _custom.clear();
    _emit(next);
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(themeProvider);
    final titleColor = model.themeColor.titleColor();
    final descColor = model.themeColor.descColor();
    final accent = model.primaryColor;

    final knownKeys = <String>{
      for (final r in kScopeResources) r.key,
      for (final r in kScopeResources) r.readKey,
    };
    final customKeys =
        widget.selected.where((e) => !knownKeys.contains(e)).toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '只读优先：只勾选「只读」的工具可用；需要运行/停止任务时再开「读写」。',
          style: TextStyle(fontSize: 12, color: descColor),
        ),
        const SizedBox(height: 10),
        ...kScopeResources.map((resource) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(resource.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight(
                              ref.watch(textWeightProvider)),
                          color: titleColor)),
                  const SizedBox(height: 2),
                  Text(resource.description,
                      style: TextStyle(fontSize: 11, color: descColor)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      SelectableChip(
                        label: '只读 ${resource.readKey}',
                        selected: widget.selected.contains(resource.readKey),
                        onToggle: (value) => _toggleRead(resource, value),
                      ),
                      if (resource.supportsWrite)
                        SelectableChip(
                          label: '读写 ${resource.key}',
                          selected: widget.selected.contains(resource.key),
                          onToggle: (value) => _toggleWrite(resource, value),
                        ),
                    ],
                  ),
                ],
              ),
            )),
        const SizedBox(height: 6),
        Text('自定义 scope key',
            style: TextStyle(fontSize: 13, color: titleColor)),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _custom,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addCustom(),
                decoration: InputDecoration(
                  hintText: '青龙新增权限，如 dashboard:read',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintStyle: TextStyle(fontSize: 12, color: descColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _addCustom, child: const Text('添加')),
          ],
        ),
        if (customKeys.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: customKeys
                .map((key) => GestureDetector(
                      onTap: () {
                        final next = Set<String>.from(widget.selected)
                          ..remove(key);
                        _emit(next);
                      },
                      child: Chip(
                        label: Text(key,
                            style: TextStyle(fontSize: 11, color: accent)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          final next = Set<String>.from(widget.selected)
                            ..remove(key);
                          _emit(next);
                        },
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
