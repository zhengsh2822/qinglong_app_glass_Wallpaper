import 'dart:convert';


import '../../main.dart';

class TaskBean {
  String? name;
  String? command;
  String? schedule;
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

  TaskBean(
      {this.name,
      this.command,
      this.schedule,
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
      this.pid});

  get nId => _id;

  TaskBean.fromJson(Map<String, dynamic> json) {
    try {
      name = json['name'].toString();
      command = json['command'].toString();
      schedule = json['schedule'].toString();
      saved = json['saved'];
      id = json['id'];
      _id = json['_id'];
      sId = json.containsKey('_id')
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
