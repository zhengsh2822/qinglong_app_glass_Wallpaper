

class UserBean {
  String? username;
  bool? twoFactorActivated;
  String? avatar;

  UserBean({
    this.username,
    this.twoFactorActivated,
    this.avatar,
  });

  UserBean.fromJson(Map<String, dynamic> json) {
    username = json['username'];
    avatar = json['avatar'];
    twoFactorActivated = json['twoFactorActivated'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['username'] = username;
    data['avatar'] = avatar;
    data['twoFactorActivated'] = twoFactorActivated;
    return data;
  }

  static UserBean jsonConversion(Map<String, dynamic> json) {
    return UserBean.fromJson(json);
  }
}
