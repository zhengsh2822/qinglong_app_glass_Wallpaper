
import '../../main.dart';

class TaskBean {
  String? name;
  String? command;
  String? schedule;

  /// 附加定时规则（青龙 2.24+ 一任务多规则，Issue #3）。
  /// API 字段 extra_schedules 为对象数组 [{schedule: "..."}]，
  /// 客户端只关心表达式字符串，解析/提交时做映射。
  List<String>? extraSchedules;
  bool? saved;
  String? sId;
  int? id;
  String? _id;
  int? created;
  int? status;
  String? timestamp;
  int? isSystem;
  int? isDisabled;
  String? logPath;
  int? isPinned;
  int? lastExecutionTime;
  int? lastRunningTime;
  String? pid;
  String? updatedAt;
  String? createdAt;

  TaskBean({
    this.name,
    this.command,
    this.schedule,
    this.extraSchedules,
    this.saved,
    this.sId,
    this.created,
    this.status,
    this.timestamp,
    this.isSystem,
    this.isDisabled,
    this.logPath,
    this.isPinned,
    this.lastExecutionTime,
    this.lastRunningTime,
    this.pid,
  });

  get nId => _id;

  TaskBean.fromJson(Map<String, dynamic> json) {
    try {
      name = json['name'].toString();
      command = json['command'].toString();
      schedule = json['schedule'].toString();
      // 附加定时规则（老面板无此字段 → null，零影响）：
      // [{schedule: "0 8 * * *"}, ...] → ["0 8 * * *", ...]
      final dynamic extra = json['extra_schedules'];
      if (extra is List) {
        extraSchedules = extra
            .map((e) => e is Map ? e['schedule']?.toString() : e?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();
      }
      saved = json['saved'];
      id = json['id'];
      _id = json['_id'];
      sId =
          json.containsKey('_id')
              ? json['_id'].toString()
              : (json.containsKey('id') ? json['id'].toString() : "");
      created = int.tryParse(json['created'].toString());
      status = json['status'];
      timestamp = json['timestamp'].toString();
      createdAt = json['createdAt'];
      updatedAt = json['updatedAt'];
      isSystem = json['isSystem'];
      isDisabled = json['isDisabled'];
      logPath = json['log_path'].toString();
      isPinned = json['isPinned'];
      lastExecutionTime = int.tryParse(json['last_execution_time'].toString());
      lastRunningTime = json['last_running_time'];
      pid = json['pid'].toString();
    } catch (e) {
      logger.e(e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['command'] = command;
    data['schedule'] = schedule;
    // 回写对象数组格式（编辑全量覆盖需要；null 时不带字段，老面板零影响）
    if (extraSchedules != null) {
      data['extra_schedules'] = extraSchedules!
          .map((s) => {'schedule': s})
          .toList();
    }
    data['saved'] = saved;
    data['_id'] = sId;
    data['created'] = created;
    data['status'] = status;
    data['timestamp'] = timestamp;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['isSystem'] = isSystem;
    data['isDisabled'] = isDisabled;
    data['log_path'] = logPath;
    data['isPinned'] = isPinned;
    data['last_execution_time'] = lastExecutionTime;
    data['last_running_time'] = lastRunningTime;
    data['pid'] = pid;
    return data;
  }

  static TaskBean jsonConversion(Map<String, dynamic> json) {
    return TaskBean.fromJson(json);
  }
}
