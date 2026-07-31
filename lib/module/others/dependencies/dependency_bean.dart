

class DependencyBean {
  String? sId;
  String? mustId;
  int? id;
  int? created;
  String? createdAt;
  int? status;
  int? type;
  String? timestamp;
  String? name;
  List<String>? log;
  String? remark;

  DependencyBean(
      {this.sId,
      this.created,
      this.status,
      this.type,
      this.timestamp,
      this.name,
      this.log,
      this.remark});

  DependencyBean.fromJson(Map<String, dynamic> json) {
    sId = json['_id'] as String?;
    id = json['id'] as int?;
    mustId = sId ?? (id?.toString() ?? "");
    final createdRaw = json['created'];
    if (createdRaw != null) {
      created = int.tryParse(createdRaw.toString());
    }
    createdAt = json['createdAt'] as String?;
    status = json['status'] as int?;
    type = json['type'] as int?;
    final tsRaw = json['timestamp'];
    timestamp = tsRaw?.toString();
    name = json['name'] as String?;
    // log 可能是 null、List<dynamic> 或 List<String>，安全转换
    final logRaw = json['log'];
    if (logRaw is List) {
      log = logRaw.map((e) => e?.toString() ?? "").toList();
    }
    remark = json['remark'] as String?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    data['created'] = created;
    data['status'] = status;
    data['type'] = type;
    data['timestamp'] = timestamp;
    data['name'] = name;
    data['log'] = log;
    data['remark'] = remark;
    return data;
  }

  static DependencyBean jsonConversion(Map<String, dynamic> json) {
    return DependencyBean.fromJson(json);
  }
}
