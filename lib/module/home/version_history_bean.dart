class VersionHistoryBean {
  String? host;
  String? version;

  VersionHistoryBean({this.host, this.version});

  VersionHistoryBean.fromJson(Map<String, dynamic> json) {
    host = json['host'];
    version = json['version'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['host'] = host;
    data['version'] = version;
    return data;
  }
}
