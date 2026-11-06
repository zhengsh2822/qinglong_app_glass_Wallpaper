


class LogDelBean {
  int? id;
  String? type;
  Info? info;
  String? createdAt;
  String? updatedAt;
  int? frequency;

  LogDelBean({
    this.id,
    this.type,
    this.info,
    this.createdAt,
    this.updatedAt,
    this.frequency,
  });

  LogDelBean.fromJson(Map<String, dynamic> json) {
    frequency = json['frequency'];
    id = json['id'];
    type = json['type'];
    info = json['info'] != null ? Info.fromJson(json['info']) : null;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['frequency'] = frequency;
    data['id'] = id;

    data['type'] = type;
    if (info != null) {
      data['info'] = info!.toJson();
    }
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    return data;
  }

  static LogDelBean jsonConversion(Map<String, dynamic> json) {
    return LogDelBean.fromJson(json);
  }
}

class Data {}

class Info {
  int? frequency;
  int? logRemoveFrequency;

  Info({this.frequency, this.logRemoveFrequency});

  Info.fromJson(Map<String, dynamic> json) {
    frequency = json['frequency'];
    logRemoveFrequency = json['logRemoveFrequency'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['frequency'] = frequency;
    data['logRemoveFrequency'] = logRemoveFrequency;
    return data;
  }
}
