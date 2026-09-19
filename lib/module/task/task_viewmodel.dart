import 'package:flutter/cupertino.dart';
import 'package:qinglong_app/base/base_viewmodel.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../main.dart';

Map<int, int> sort = {0: 0, 5: 1, 3: 2, 1: 3, 4: 4};

class TaskViewModel extends BaseViewModel {
  static const String allStr = "全部";
  static const String runningStr = "运行中";
  static const String neverStr = "未使用";
  static const String notScriptStr = "拉库";
  static const String disableStr = "已禁用";

  List<TaskBean> list = [];
  List<TaskBean> running = [];
  List<TaskBean> neverRunning = [];
  List<TaskBean> notScripts = [];
  List<TaskBean> disabled = [];

  @override
  void retry(BuildContext context, {bool showLoading = true}) {
    loadData(context, showLoading);
  }

  bool runAllTasked = false;

  Future<void> loadData(BuildContext context, [isLoading = true]) async {
    if (isLoading && list.isEmpty) {
      loading(notify: true);
    }

    final tasks = await _fetchTasks(context);
    if (tasks == null) {
      list.clear();
      failed(null, notify: true);
      return;
    }
    list.clear();
    list.addAll(tasks);
    sortList(context);
    success();
    // 同步"运行中"快照，确保加载后启动轮询首轮不会因快照为空而误判有变化
    _syncRunningSnapshot();
    if (MultiAccountPageState.actionRunAll == MultiAccountPageState.useAction() &&
        !runAllTasked) {
      runAllTasked = true;
      runAllTasks(context);
    }
  }

  /// 按青龙版本分支拉取任务列表（成功返回解析后的列表，失败返回 null）。
  Future<List<TaskBean>?> _fetchTasks(BuildContext context) {
    if (getIt<SystemBean>(
      instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString(),
    ).isUpperVersion2_13_9()) {
      return SingleAccountPageState.ofApi(context).crons2_13_09().then((temp) {
        if (temp.success && temp.bean != null) {
          return temp.bean!.data ?? [];
        }
        return null;
      });
    } else {
      return SingleAccountPageState.ofApi(context).crons().then((result) {
        if (result.success && result.bean != null) {
          return result.bean!;
        }
        return null;
      });
    }
  }

  // ------------------------------------------------------------------
  // 运行中状态实时同步（方案 B 的轻量轮询）
  // ------------------------------------------------------------------
  // 上一轮"运行中"任务 id 快照：轮询时只对比快照变化，没有变化就完全不
  // notify 列表（零重建），从而保证"只在有运行中任务、且状态真的变化时才刷新"。
  Set<String> _runningIdsSnapshot = {};

  /// 从当前 [list] 重建"运行中"快照。
  void _syncRunningSnapshot() {
    _runningIdsSnapshot = list
        .where((e) => (e.status ?? 1) == 0)
        .map((e) => e.sId ?? "")
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// 对比最新任务列表里的"运行中"集合，若与上一轮一致则静默跳过（不刷新），
  /// 一旦有任务开始/结束就正常刷新一次。供 TaskPage 定时轮询调用。
  Future<bool> pollRunning(BuildContext context) async {
    final tasks = await _fetchTasks(context);
    if (tasks == null) return false;

    final newRunning = tasks
        .where((e) => (e.status ?? 1) == 0)
        .map((e) => e.sId ?? "")
        .where((id) => id.isNotEmpty)
        .toSet();

    final changed =
        newRunning.length != _runningIdsSnapshot.length ||
        !newRunning.containsAll(_runningIdsSnapshot);
    _runningIdsSnapshot = newRunning;

    if (changed) {
      list.clear();
      list.addAll(tasks);
      sortList(context);
      success();
    }
    return changed;
  }

  /// 清除运行中快照（初始化/重进时避免误判"有变化"）。
  void resetRunningSnapshot() => _runningIdsSnapshot = {};

  static int _compareCreatedDesc(TaskBean a, TaskBean b) {
    bool aBeforeB = DateTime.fromMillisecondsSinceEpoch(
      a.created ?? 0,
    ).isBefore(DateTime.fromMillisecondsSinceEpoch(b.created ?? 0));
    if (aBeforeB) return 1;
    bool bBeforeA = DateTime.fromMillisecondsSinceEpoch(
      b.created ?? 0,
    ).isBefore(DateTime.fromMillisecondsSinceEpoch(a.created ?? 0));
    if (bBeforeA) return -1;
    return 0;
  }

  void sortList(BuildContext context) {
    //2.14.0之后就不需要排序
    if (!getIt<SystemBean>(
      instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString(),
    ).isUpperVersion2_14_0()) {
      // 单次遍历分区，替代 O(n²) 的 removeAt 循环
      List<TaskBean> p = [];
      List<TaskBean> r = [];
      List<TaskBean> d = [];
      List<TaskBean> rest = [];
      for (final item in list) {
        if (item.isPinned == 1) {
          p.add(item);
        } else if (item.status == 0) {
          r.add(item);
        } else if (item.isDisabled == 1) {
          d.add(item);
        } else {
          rest.add(item);
        }
      }

      // 合并 p 的三次排序为单次复合排序
      p.sort((a, b) {
        int statusA = a.status ?? 1;
        int statusB = b.status ?? 1;
        if (statusA == 0 && statusB == 0) {
          int cmp = _compareCreatedDesc(a, b);
          if (cmp != 0) return cmp;
        } else if (statusA != statusB) {
          return statusA - statusB;
        }
        int disabledCmp = (a.isDisabled ?? 0) - (b.isDisabled ?? 0);
        if (disabledCmp != 0) return disabledCmp;
        return _compareCreatedDesc(a, b);
      });

      r.sort(_compareCreatedDesc);
      rest.sort(_compareCreatedDesc);
      d.sort(_compareCreatedDesc);

      list
        ..clear()
        ..addAll(p)
        ..addAll(r)
        ..addAll(rest)
        ..addAll(d);
    }

    // 单次遍历构建四个分类列表，替代四次 where 遍历
    running.clear();
    neverRunning.clear();
    notScripts.clear();
    disabled.clear();
    for (final item in list) {
      if (item.status == 0) running.add(item);
      if (item.lastRunningTime == null) neverRunning.add(item);
      if (item.command != null &&
          (item.command!.startsWith("ql repo") ||
              item.command!.startsWith("ql raw"))) {
        notScripts.add(item);
      }
      if (item.isDisabled == 1) disabled.add(item);
    }
  }

  Future<void> runCrons(BuildContext context, List<String> crons) async {
    HttpResponse<NullResponse> result = await SingleAccountPageState.ofApi(
      context,
    ).startTasks(crons);
    if (result.success) {
      loadData(context, false);
    } else {
      failToast(result.message, notify: true);
    }
  }

  Future<void> stopCrons(BuildContext context, List<String> crons) async {
    HttpResponse<NullResponse> result = await SingleAccountPageState.ofApi(
      context,
    ).stopTasks(crons);
    if (result.success) {
      loadData(context, false);
    } else {
      failToast(result.message, notify: true);
    }
  }

  Future<void> delCron(BuildContext context, List<String> id) async {
    HttpResponse<NullResponse> result = await SingleAccountPageState.ofApi(
      context,
    ).delTask(id);
    if (result.success) {
      "删除成功".toast();
      loadData(context, false);
    } else {
      failToast(result.message, notify: true);
    }
  }

  void updateBean(BuildContext context, TaskBean result) {
    loadData(context, false);
  }

  Future<void> pinTask(
    BuildContext context,
    List<String> sId,
    int isPinned,
  ) async {
    if (isPinned == 1) {
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(
        context,
      ).unpinTask(sId);

      if (response.success) {
        "取消置顶成功".toast();
        loadData(context, false);
      } else {
        failToast(response.message, notify: true);
      }
    } else {
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(
        context,
      ).pinTask(sId);

      if (response.success) {
        "置顶成功".toast();
        loadData(context, false);
      } else {
        failToast(response.message, notify: true);
      }
    }
  }

  Future<void> enableTask(
    BuildContext context,
    List<String> sId,
    int isDisabled,
  ) async {
    if (isDisabled == 0) {
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(
        context,
      ).disableTask(sId);

      if (response.success) {
        "禁用成功".toast();
        loadData(context, false);
      } else {
        failToast(response.message, notify: true);
      }
    } else {
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(
        context,
      ).enableTask(sId);

      if (response.success) {
        "启用成功".toast();
        loadData(context, false);
      } else {
        failToast(response.message, notify: true);
      }
    }
  }

  void runAllTasks(BuildContext context) {
    runAllTasked = true;
    List<String> ids =
        list
            .where((element) => element.isDisabled != 1)
            .map((e) => e.sId ?? "")
            .toList();
    "已运行${ids.length}个任务".toast();
    runCrons(context, ids);
  }
}
