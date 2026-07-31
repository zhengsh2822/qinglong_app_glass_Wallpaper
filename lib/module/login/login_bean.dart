
class LoginBean {
  String? token;
  String? lastip;
  String? lastaddr;
  int? lastlogon;
  int? retries;
  String? platform;

  LoginBean(
      {this.token,
      this.lastip,
      this.lastaddr,
      this.lastlogon,
      this.retries,
      this.platform});

  LoginBean.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    lastip = json['lastip'];
    lastaddr = json['lastaddr'];
    lastlogon = int.tryParse(json['lastlogon'].toString());
    retries = json['retries'];
    platform = json['platform'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['token'] = token;
    data['lastip'] = lastip;
    data['lastaddr'] = lastaddr;
    data['lastlogon'] = lastlogon;
    data['retries'] = retries;
    data['platform'] = platform;
    return data;
  }

  static LoginBean jsonConversion(Map<String, dynamic> json) {
    return LoginBean.fromJson(json);
  }
}
