import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/cupertino_sheet.dart';
import 'package:qinglong_app/base/http/http_cache.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/share_utils.dart';

import 'config_bean.dart';

/// 青龙服务自带（系统生成 / 官方 sample 复制）的配置文件，禁止删除。
///
/// 依据：青龙 shell/share.sh 里 config 目录固定文件清单
/// （config.sh / extra.sh / task_before.* / task_after.sh / sharecode.sh）
/// 与 back/config/index.ts 的 blackFileList（auth.json、crontab.list、env.*、
/// dependence-proxy.sh、cookie.sh 等，这些本身也不会出现在 /configs/files 列表）。
const Set<String> kBuiltInConfigFiles = {
  'config.sh',
  'config.sh.sample',
  'config.sample.sh',
  'extra.sh',
  'extra.sample.sh',
  'task_before.sh',
  'task_before.js',
  'task_before.py',
  'task_after.sh',
  'task.sample.sh',
  'sharecode.sh',
  'repo.sh',
  'dependence-proxy.sh',
  'cookie.sh',
  'auth.json',
  'token.json',
  'crontab.list',
  'env.sh',
  'env.js',
  'env.py',
};

/// 是否为青龙自带配置文件（大小写不敏感）——自带文件不提供删除入口
bool isBuiltInConfigFile(String? title) =>
    kBuiltInConfigFiles.contains((title ?? '').toLowerCase());

/// 文件名安全性校验（防命令注入）：仅允许 字母/数字/下划线/中横线/点/中文/空格
final RegExp _safeFileNameReg = RegExp(r'^[A-Za-z0-9_\-. \u4e00-\u9fa5]+$');

/// 配置文件"更多操作"弹层
///
/// 列表页长按与详情页右上角共用同一份操作集（编辑/分享/下载/删除），
/// 避免两处各写一套导致行为不一致。
/// [content] 已知文件内容（详情页传入），为空时按需向面板拉取。
/// [onDeleted] 删除成功后回调（列表页刷新列表 / 详情页返回）。
void showConfigActions(
  BuildContext context, {
  required ConfigBean bean,
  String? content,
  ValueChanged<String>? onContentChanged,
  VoidCallback? onDeleted,
}) {
  final String title = bean.title ?? '';
  final bool builtIn = isBuiltInConfigFile(title);

  showMoreOperate(context, [
    CupertinoSheer(
      title: '编辑',
      onTap: () => _editConfig(context, bean, content, onContentChanged),
    ),
    addDivider(),
    CupertinoSheer(
      title: '分享',
      onTap: () async {
        final String? text = await _resolveContent(context, bean, content);
        if (text == null) return;
        ShareUtils.share(text);
      },
    ),
    addDivider(),
    CupertinoSheer(
      title: '下载',
      onTap: () async {
        final String? text = await _resolveContent(context, bean, content);
        if (text == null) return;
        try {
          String name = "${Random().nextInt(40000)}_$title";
          await FileUtil(0).writeDownloadFile(name, text);
          "已写入qinglong_app文件夹下,文件名$name".toast2();
        } catch (e) {
          e.toString().toast();
        }
      },
    ),
    // 自带配置文件不显示删除项（青龙自带不可删，只允许删用户自建）
    if (!builtIn) ...[
      addDivider(),
      CupertinoSheer(
        title: '删除',
        danger: true,
        onTap: () async {
          final bool ok = await deleteConfigFile(context, bean);
          if (ok) onDeleted?.call();
        },
      ),
    ],
  ]);
}

/// 删除配置文件（仅限用户自建）
///
/// 青龙官方 HTTP API（/configs/files、/detail、/save）**没有删除接口**，
/// 面板自身也没有删除入口，因此这里采用"临时任务执行 rm"的曲线方案：
/// 新建一个不会自然触发的临时任务 → 立即运行 → 删除临时任务。
Future<bool> deleteConfigFile(BuildContext context, ConfigBean bean) async {
  final String name = bean.value ?? bean.title ?? '';
  if (isBuiltInConfigFile(name)) {
    '青龙自带配置文件不可删除'.toast();
    return false;
  }
  if (!_safeFileNameReg.hasMatch(name)) {
    '该文件名含特殊字符，暂不支持删除'.toast();
    return false;
  }

  final bool isCyber =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeCyber;
  final String tip = '确认删除配置文件 $name 吗？\n该操作不可撤销';
  final dynamic confirmed =
      isCyber
          ? await showCyberConfirmDialog(
            context,
            title: '确认删除',
            content: tip,
            confirmLabel: '删除',
            danger: true,
          )
          : await showConfirmDialog(
            context,
            title: '确认删除',
            content: tip,
            confirmLabel: '删除',
            danger: true,
          );
  if (confirmed != true) return false;
  if (!context.mounted) return false;

  return _deleteByTempTask(context, name);
}

/// 通过临时任务删除目标配置文件
Future<bool> _deleteByTempTask(BuildContext context, String name) async {
  final api = SingleAccountPageState.ofApi(context);
  final int accountIndex = SingleAccountPageState.of(context)?.index ?? 0;
  // 任务名带时间戳，避免与残留任务重名
  final String taskName =
      '__ql_cfg_del_${DateTime.now().millisecondsSinceEpoch}';
  // 临时任务不设"永不触发"以外的语义：cron 设为 12-31 23:59，仅用于"立即运行"载体
  final addResult = await api.addTask(
    taskName,
    _buildRemoveCommand(name),
    '59 23 31 12 *',
  );
  if (!addResult.success) {
    (addResult.message ?? '创建临时任务失败').toast();
    return false;
  }

  final String? id = await _findTaskId(context, taskName);
  if (id == null || id.isEmpty) {
    '未找到临时任务，删除已中止'.toast();
    return false;
  }

  final runResult = await api.startTasks([id]);

  // 轮询复核（每 800ms、最多 15 次≈12s）：命中即成功，避免固定等待导致误判。
  // 每次查询前必须清掉配置文件缓存，否则读到的是 3 分钟 TTL 的旧列表。
  // 窗口需留足：命令里的 find 兜底在慢盘上可能要数秒，过早轮询结束会误判失败。
  bool removed = await _pollRemoved(api, accountIndex, name, 15);

  // 失败时读取临时任务日志，把真实环境信息（pwd / QL_DIR / QL_DATA_DIR）回显，
  // 便于定位"配置目录不在常见路径"的情况；必须在删除临时任务之前读
  String diag = '';
  if (!removed) {
    final logResult = await api.inTimeLog(id);
    final String log = (logResult.success ? logResult.bean : null) ?? '';
    if (log.trim().isNotEmpty) {
      final lines = log
          .split('\n')
          .map((e) => e.replaceAll('\r', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final failLine = lines.firstWhere(
        (e) => e.contains('QLDEL_FAIL'),
        orElse: () => '',
      );
      diag = failLine.isNotEmpty ? failLine : (lines.isEmpty ? '' : lines.last);
    }
    if (!runResult.success) {
      diag = '${runResult.message ?? "运行临时任务失败"} $diag'.trim();
    }
  }

  // 清理临时任务，避免残留在任务列表（放在复核之后，防止提前删除打断正在执行的 rm）
  await api.delTask([id]);

  // 兜底：任务机制在本面板不可用时，改用纯 HTTP 的"另存为"链路删除
  // （借面板自身的 rmPath 删掉 origin，完全不依赖调度器）
  if (!removed) {
    await _deleteBySaveAs(context, name);
    removed = await _pollRemoved(api, accountIndex, name, 4);
  }

  if (!removed) {
    if (diag.isEmpty) {
      '删除未生效（面板未返回任务日志）'.toast();
    } else {
      '删除未生效：$diag'.toast2();
    }
  }
  return removed;
}

/// 生成删除命令：先按常见路径直取，全部落空时再用 find 定位含 config.sh 的
/// config 目录（青龙数据目录可能是自定义路径）。
/// 仅在"目录名为 config + 同级有 config.sh + 目标文件存在"三条件同时满足时才 rm，
/// 文件名已通过 [_safeFileNameReg] 白名单校验，无命令注入风险。
String _buildRemoveCommand(String name) {
  return 'echo "QLDEL_ENV pwd=\$(pwd) qldir=\$QL_DIR qldata=\$QL_DATA_DIR"; '
      'd=""; '
      'for c in "\$QL_DATA_DIR/config" "\$QL_DIR/data/config" "/ql/data/config" '
      '"../config" "\$(dirname "\$(pwd)")/config" "\$(pwd)/../config"; do '
      'if [ -f "\$c/$name" ]; then d="\$c"; break; fi; done; '
      'if [ -z "\$d" ]; then '
      'f=\$(find /ql /data /opt /root /home /usr/local /srv /mnt /volume1 /volume2 '
      '"\$QL_DIR" "\$QL_DATA_DIR" -maxdepth 8 -type f -name "$name" -path "*/config/*" '
      '2>/dev/null | head -n 1); '
      'if [ -n "\$f" ] && [ -f "\$(dirname "\$f")/config.sh" ]; then d="\$(dirname "\$f")"; fi; '
      'fi; '
      'if [ -n "\$d" ] && [ -f "\$d/$name" ]; then rm -f "\$d/$name" && echo "QLDEL_OK \$d"; '
      'else echo "QLDEL_FAIL pwd=\$(pwd) qldir=\$QL_DIR qldata=\$QL_DATA_DIR"; fi';
}

/// 兜底删除用的锚点目录名
///
/// 位于青龙配置目录下，仅作为"另存为"的目标（写入目录必然失败，因此只保留
/// 面板自身 rmPath 删除 origin 的效果）；App 侧列表会过滤掉它，不影响用户。
const String kConfigDeleteAnchor = '__ql_del__';

/// 轮询复核目标文件是否已从配置列表消失（每次查询前清缓存，避免读到旧列表）
Future<bool> _pollRemoved(
  dynamic api,
  int accountIndex,
  String name,
  int rounds,
) async {
  for (int i = 0; i < rounds; i++) {
    await Future.delayed(const Duration(milliseconds: 800));
    HttpCache(accountIndex).invalidatePrefix('/api/configs');
    HttpCache(accountIndex).invalidatePrefix('/open/configs');
    final files = await api.files();
    if (files.success && files.bean != null) {
      if (!files.bean!.any((e) => (e.title ?? '') == name)) return true;
    }
  }
  return false;
}

/// 纯 HTTP 兜底删除：借 `POST /scripts` 的"另存为"语义（origin → dest 已存在）
///
/// 面板会把 origin 文件（目标配置文件）在自身逻辑里 rmPath 掉；dest 用配置目录下
/// 的锚点目录（写入会失败但不影响删除结果）。整条链路不依赖任务调度器。
Future<void> _deleteBySaveAs(BuildContext context, String name) async {
  final api = SingleAccountPageState.ofApi(context);
  // 1) 确保锚点目录存在（首次调用时创建，之后复用）
  await api.addScriptFolder(kConfigDeleteAnchor, '../config');
  // 2) 另存为：origin = 目标文件，dest = 锚点目录 → 面板 rmPath(origin)
  await api.moveScriptBySaveAs(
    '../config/$name',
    '../config/$kConfigDeleteAnchor',
  );
}

/// 按名称查临时任务 id（2.13.9+ 走分页接口，与任务列表页保持一致）
Future<String?> _findTaskId(BuildContext context, String name) async {
  final api = SingleAccountPageState.ofApi(context);
  SystemBean? systemBean;
  try {
    systemBean = getIt<SystemBean>(
      instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString(),
    );
  } catch (e) {
    systemBean = null;
  }

  List<TaskBean>? list;
  if (systemBean != null && systemBean.isUpperVersion2_13_9()) {
    final result = await api.crons2_13_09();
    list = result.success ? (result.bean?.data ?? <TaskBean>[]) : null;
  } else {
    final result = await api.crons();
    list = result.success ? result.bean : null;
  }
  if (list == null) return null;
  for (final TaskBean bean in list) {
    if ((bean.name ?? '') == name) return bean.sId;
  }
  return null;
}

/// 打开编辑页；[onContentChanged] 用于把编辑结果回填给调用方
Future<void> _editConfig(
  BuildContext context,
  ConfigBean bean,
  String? content,
  ValueChanged<String>? onContentChanged,
) async {
  final String? text = await _resolveContent(context, bean, content);
  if (text == null || !context.mounted) return;
  Navigator.of(context)
      .pushNamed(
        Routes.routeConfigEdit,
        arguments: {"title": bean.title, "content": text},
      )
      .then((value) {
    if (value != null && value is String && value.isNotEmpty) {
      onContentChanged?.call(value);
    }
  });
}

/// 取文件内容：优先用已缓存的内容，否则实时向面板拉取
Future<String?> _resolveContent(
  BuildContext context,
  ConfigBean bean,
  String? cached,
) async {
  if (cached != null) return cached;
  final result = await SingleAccountPageState.ofApi(
    context,
  ).content(bean.value ?? bean.title ?? "");
  if (result.success && result.bean != null) {
    return result.bean;
  }
  result.message?.toast();
  return null;
}
