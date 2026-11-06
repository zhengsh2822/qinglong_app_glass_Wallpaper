import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:qinglong_app/base/base_viewmodel.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_bean.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_page.dart';
import 'package:qinglong_app/utils/extension.dart';

class DependencyViewModel extends BaseViewModel {
  List<DependencyBean> nodeJsList = [];
  List<DependencyBean> python3List = [];
  List<DependencyBean> linuxList = [];

  /// 删除中的依赖标识（mustId）：卡片立即显示「删除中」徽章并禁交互，
  /// 删除完成/失败后移除（失败保留卡片），删除成功由 del 内部刷新列表
  final Set<String> deletingKeys = {};

  Timer? _installPollTimer;
  int _installPollCount = 0;

  @override
  void retry(BuildContext context, {bool showLoading = true}) async {
    await Future.wait([
      loadData(
        context,
        DepedencyEnum.nodeJs.apiType,
        true,
      ),
      loadData(
        context,
        DepedencyEnum.python3.apiType,
        true,
      ),
      loadData(
        context,
        DepedencyEnum.linux.apiType,
        true,
      ),
    ]);
  }

  List<DependencyBean> getListByType(int index) {
    if (DependcyPageState.types[index].name ==
        DepedencyEnum.nodeJs.name) {
      return nodeJsList;
    } else if (DependcyPageState.types[index].name ==
        DepedencyEnum.python3.name) {
      return python3List;
    }
    return linuxList;
  }

  /// 存在「安装中」（status==0）依赖时轮询：每 2s 只刷新仍处于安装中的
  /// 类型（通常 1 个请求/周期，而非固定 3 个全量请求），装完自动停止。
  /// 上限 ~5 分钟防失控。
  void _syncInstallStatus(BuildContext context) {
    final List<String> pending = [
      if (nodeJsList.any((e) => (e.status ?? -1) == 0)) "nodejs",
      if (python3List.any((e) => (e.status ?? -1) == 0)) "python3",
      if (linuxList.any((e) => (e.status ?? -1) == 0)) "linux",
    ];
    if (pending.isEmpty) {
      _installPollTimer?.cancel();
      _installPollTimer = null;
      _installPollCount = 0;
      return;
    }
    if (_installPollTimer != null || _installPollCount > 150) return;
    _installPollTimer = Timer(const Duration(seconds: 2), () async {
      _installPollTimer = null;
      _installPollCount++;
      // 页面已退出时停止轮询，防止 context 失效
      if (!context.mounted) {
        _installPollCount = 0;
        return;
      }
      await Future.wait(pending.map((t) => loadData(context, t)));
    });
  }

  Future<void> loadData(
    BuildContext context,
    String type, [
    bool showLoading = false,
  ]) async {
    type = type.toLowerCase();
    if (showLoading &&
        ((type == "nodejs" && nodeJsList.isEmpty) ||
            (type == "python3" && python3List.isEmpty) ||
            (type == "linux" && linuxList.isEmpty))) {
      loading(notify: true);
    }

    HttpResponse<List<DependencyBean>> response =
        await SingleAccountPageState.ofApi(context).dependencies(type);
    if (response.success && response.bean != null) {
      if (type == "nodejs") {
        nodeJsList.clear();
        nodeJsList.addAll(response.bean!);
      }
      if (type == "python3") {
        python3List.clear();
        python3List.addAll(response.bean!);
      }
      if (type == "linux") {
        linuxList.clear();
        linuxList.addAll(response.bean!);
      }
      success();
      if (!context.mounted) return;
      _syncInstallStatus(context);
    } else {
      if (showLoading) {
        failed(response.message ?? "加载失败", notify: true);
      } else {
        response.message?.toast();
      }
    }
  }

  /// 新增提交成功后的乐观插入：新依赖卡片立即出现
  /// （接口返回时记录已创建且 status==0 = 安装中），
  /// 随后的 loadData 校准真实状态并联动安装状态轮询
  void insertOptimistic(Map<String, dynamic> json) {
    final DependencyBean bean = DependencyBean(
      sId: json['_id']?.toString(),
      status: (json['status'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt(),
      name: json['name']?.toString(),
      timestamp: json['timestamp']?.toString() ?? "",
    );
    bean.id = int.tryParse(json['id']?.toString() ?? '');
    bean.mustId = bean.sId ?? (bean.id?.toString() ?? "");
    // type 与 DepedencyEnum 对齐：0=NodeJS 1=Python3 2=Linux
    final List<DependencyBean> list;
    if ((bean.type ?? 0) == 1) {
      list = python3List;
    } else if ((bean.type ?? 0) == 2) {
      list = linuxList;
    } else {
      list = nodeJsList;
    }
    if ((bean.mustId ?? "").isNotEmpty &&
        !list.any((e) => e.mustId == bean.mustId)) {
      list.insert(0, bean);
    }
    success();
  }

  void reInstall(
    BuildContext context,
    String type,
    List<String?>? sId,
    List<int?>? id,
  ) async {
    await SingleAccountPageState.ofApi(
      context,
    ).dependencyReinstall(sId ?? [], id ?? []);
    if (!context.mounted) return;
    await loadData(context, type);
  }

  /// 删除依赖：keys 对应卡片立即进入「删除中」状态（禁交互），
  /// 成功后内部静默刷新列表（卡片消失）；失败 toast 并保留卡片
  Future<bool> del(
    BuildContext context,
    String type,
    List<String?>? sId,
    List<int?>? ids, {
    List<String?>? keys,
  }) async {
    final Set<String> keySet =
        keys?.whereType<String>().where((e) => e.isNotEmpty).toSet() ??
        <String>{};
    // 「删除中」徽章保底显示时长：本地面板删除响应仅 ~30ms，徽章一闪而过
    // 无法感知；不足最小时长时等补齐再移除卡片
    const minDeletingShow = Duration(milliseconds: 600);
    final addTime = DateTime.now();
    if (keySet.isNotEmpty) {
      deletingKeys.addAll(keySet);
      notifyListeners();
    }
    bool ok = false;
    try {
      final response = await SingleAccountPageState.ofApi(
        context,
      ).delDependency(sId, ids);
      ok = response.success;
      if (!ok && (response.message?.isNotEmpty ?? false)) {
        response.message!.toast();
      }
    } catch (e) {
      "删除失败：$e".toast();
    }
    if (ok && context.mounted) {
      await loadData(context, type);
    }
    if (keySet.isNotEmpty) {
      // 保底显示：删除+刷新完成后，若徽章显示不足最小时长则等补齐再移除
      final shown = DateTime.now().difference(addTime);
      if (shown < minDeletingShow) {
        await Future.delayed(minDeletingShow - shown);
      }
      deletingKeys.removeAll(keySet);
      notifyListeners();
    }
    return ok;
  }
}

enum DepedencyEnum {
  nodeJs,
  python3,
  linux;

  /// 青龙接口使用的类型字符串（全小写）
  String get apiType => name.toLowerCase();

  /// 界面展示名称
  String get label => switch (this) {
    DepedencyEnum.nodeJs => 'NodeJS',
    DepedencyEnum.python3 => 'Python3',
    DepedencyEnum.linux => 'Linux',
  };
}
