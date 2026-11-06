
class LoginLogBean {
  int? timestamp;
  String? address;
  String? ip;
  String? platform;
  int? status; //0代表成功,1代表失败

  LoginLogBean(
      {this.timestamp, this.address, this.ip, this.platform, this.status});

  LoginLogBean.fromJson(Map<String, dynamic> json) {
    timestamp = int.tryParse(json['timestamp'].toString());
    address = json['address'];
    ip = json['ip'];
    platform = json['platform'];
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['timestamp'] = timestamp;
    data['address'] = address;
    data['ip'] = ip;
    data['platform'] = platform;
    data['status'] = status;
    return data;
  }

  static LoginLogBean jsonConversion(Map<String, dynamic> json) {
    return LoginLogBean.fromJson(json);
  }
}
