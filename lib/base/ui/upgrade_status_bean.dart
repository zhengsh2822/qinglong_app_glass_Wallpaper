/// 面板安全升级任务状态（青龙 2.24.0 新增 GET /system/update-status）
///
/// 对齐面板 cli/src/internal/maintenance/panelUpgrade.cjs 的 job state：
/// - status: idle / starting / running / restarting（活跃） / ready（已下载待重启） / completed / failed
/// - phase: downloading / extracting / verifying / dependencies / prestarting /
///   repairing / ready / restarting / completed
class UpgradeStatusBean {
  String? id;

  /// 'download' = 下载暂存；'apply' = 重启应用更新
  String? action;

  /// idle / starting / running / restarting / ready / completed / failed
  String? status;
  String? phase;
  String? artifact;
  int? downloadedBytes;
  int? totalBytes;

  /// 0~100，可能为 null
  num? percent;
  String? version;
  String? error;

  /// 服务端返回的日志尾部（最大 32KB）
  String? log;

  UpgradeStatusBean({
    this.id,
    this.action,
    this.status,
    this.phase,
    this.artifact,
    this.downloadedBytes,
    this.totalBytes,
    this.percent,
    this.version,
    this.error,
    this.log,
  });

  /// 活跃状态集合（与面板 active = starting/running/restarting 一致）
  bool get isActive =>
      status == 'starting' || status == 'running' || status == 'restarting';

  bool get isReady => status == 'ready';

  bool get isCompleted => status == 'completed';

  bool get isFailed => status == 'failed';

  UpgradeStatusBean.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    action = json['action'];
    status = json['status'];
    phase = json['phase'];
    artifact = json['artifact'];
    downloadedBytes = json['downloadedBytes'];
    totalBytes = json['totalBytes'];
    percent = json['percent'];
    version = json['version'];
    error = json['error'];
    log = json['log'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['action'] = action;
    data['status'] = status;
    data['phase'] = phase;
    data['artifact'] = artifact;
    data['downloadedBytes'] = downloadedBytes;
    data['totalBytes'] = totalBytes;
    data['percent'] = percent;
    data['version'] = version;
    data['error'] = error;
    data['log'] = log;
    return data;
  }

  static UpgradeStatusBean jsonConversion(Map<String, dynamic> json) {
    return UpgradeStatusBean.fromJson(json);
  }
}
