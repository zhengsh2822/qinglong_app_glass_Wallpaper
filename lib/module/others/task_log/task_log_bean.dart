

class TaskLogBean {
  String? name;
  bool? isDir;
  List<String>? files;
  List<Children>? children;

  TaskLogBean({this.name, this.files});

  TaskLogBean.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? json['title'];
    isDir = json['isDir'] ?? (json['type'] == "directory");

    files = json['files']?.cast<String>();
    if (json['children'] != null) {
      children = <Children>[];
      json['children'].forEach((v) {
        children!.add(Children.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['files'] = files;
    if (children != null) {
      data['children'] = children!.map((v) => v.toJson()).toList();
    }
    return data;
  }

  static TaskLogBean jsonConversion(Map<String, dynamic> json) {
    return TaskLogBean.fromJson(json);
  }
}

class Children {
  String? title;
  String? value;
  String? type;
  String? key;
  String? parent;

  Children({this.title, this.value, this.type, this.key, this.parent});

  Children.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    value = json['value'];
    type = json['type'];
    key = json['key'];
    parent = json['parent'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['value'] = value;
    data['type'] = type;
    data['key'] = key;
    data['parent'] = parent;
    return data;
  }
}
