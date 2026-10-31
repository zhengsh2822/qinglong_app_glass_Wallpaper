/// 通知审计日志条目（青龙 2.24.0 新增 GET /system/notify-log）
///
/// 对齐面板 back/data/system.ts 的 NotifyLogInfo：
/// status: 0=成功 1=失败；source: 'system'=系统通知 'script'=脚本通知
class NotifyLogBean {
  int? id;
  int? timestamp;
  String? title;
  String? content;

  /// 0=成功 1=失败
  int? status;

  /// 推送渠道（telegram / dingtalk ...）
  String? notifyType;

  /// 'system'=系统通知 'script'=脚本通知
  String? source;
  String? scriptName;
  String? taskId;

  NotifyLogBean({
    this.id,
    this.timestamp,
    this.title,
    this.content,
    this.status,
    this.notifyType,
    this.source,
    this.scriptName,
    this.taskId,
  });

  NotifyLogBean.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    timestamp = json['timestamp'];
    title = json['title'];
    content = json['content'];
    status = json['status'];
    notifyType = json['notifyType'];
    source = json['source'];
    scriptName = json['scriptName'];
    taskId = json['taskId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['timestamp'] = timestamp;
    data['title'] = title;
    data['content'] = content;
    data['status'] = status;
    data['notifyType'] = notifyType;
    data['source'] = source;
    data['scriptName'] = scriptName;
    data['taskId'] = taskId;
    return data;
  }

  static NotifyLogBean jsonConversion(Map<String, dynamic> json) {
    return NotifyLogBean.fromJson(json);
  }
}
