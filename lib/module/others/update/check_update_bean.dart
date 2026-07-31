


class CheckUpdateBean {
  bool? hasNewVersion;
  String? lastVersion;
  String? lastLog;

  CheckUpdateBean({this.hasNewVersion, this.lastVersion, this.lastLog});

  CheckUpdateBean.fromJson(Map<String, dynamic> json) {
    hasNewVersion = json['hasNewVersion'];
    lastVersion = json['lastVersion'];
    lastLog = json['lastLog'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['hasNewVersion'] = hasNewVersion;
    data['lastVersion'] = lastVersion;
    data['lastLog'] = lastLog;
    return data;
  }

  static CheckUpdateBean jsonConversion(Map<String, dynamic> json) {
    return CheckUpdateBean.fromJson(json);
  }
}
