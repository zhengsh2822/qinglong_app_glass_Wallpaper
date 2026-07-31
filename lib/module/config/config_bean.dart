
class ConfigBean {
  String? title;
  String? value;

  ConfigBean({this.title, this.value});

  ConfigBean.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['value'] = value;
    return data;
  }

  static ConfigBean jsonConversion(Map<String, dynamic> json) {
    return ConfigBean.fromJson(json);
  }
}
