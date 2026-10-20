import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:qinglong_app/base/single_account_page.dart';

import '../main.dart';

class Utils {
  static void hideKeyBoard(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 规范化面板地址输入（登录页域名框等 host 入口共用）
  ///
  /// - 无 scheme 时自动补 `http://`
  /// - 去掉结尾多余的 `/`（避免与相对路径拼接出现 `//`）
  /// - 裸 IPv6 字面量自动补方括号：`240e:1a2b::1:5700` → `http://[240e:1a2b::1]:5700`
  ///   URI 语法要求 IPv6 必须用 `[]` 包裹，否则 `Uri.parse` 会把最后一个冒号后的内容
  ///   当成端口并抛 `FormatException: Invalid port`，导致登录直接失败。
  /// 返回可直接作为 Dio baseUrl 使用的地址；空输入原样返回。
  static String normalizeHost(String raw) {
    var host = raw.trim();
    if (host.isEmpty) return host;

    String scheme = "http://";
    if (host.startsWith("https://")) {
      scheme = "https://";
      host = host.substring("https://".length);
    } else if (host.startsWith("http://")) {
      host = host.substring("http://".length);
    }

    while (host.endsWith("/")) {
      host = host.substring(0, host.length - 1);
    }
    if (host.isEmpty) return raw.trim();

    return "$scheme${_wrapIpv6IfNeeded(host)}";
  }

  /// 裸 IPv6 字面量补方括号；域名 / IPv4 + 端口不受影响
  ///
  /// 判定依据：域名或 IPv4 加端口只有 1 个冒号，IPv6 至少 2 个；
  /// 末段是纯数字且其前缀不以 `:` 结尾（`240e::1` 这类结尾冒号属于地址本体）时才视为端口。
  static String _wrapIpv6IfNeeded(String host) {
    if (host.startsWith("[")) return host;
    if (":".allMatches(host).length < 2) return host;

    final int lastColon = host.lastIndexOf(":");
    final String tail = host.substring(lastColon + 1);
    final String prefix = host.substring(0, lastColon);
    final bool tailIsPort =
        tail.isNotEmpty && int.tryParse(tail) != null && !prefix.endsWith(":");
    final String ip = tailIsPort ? prefix : host;
    return "[$ip]${tailIsPort ? ":$tail" : ""}";
  }

  static String formatGMTTime(String gmtTime) {
    // "Wed Jan 12 2022 20:33:39 GMT+0800 (中国标准时间)"
    try {
      if (gmtTime.isEmpty) return "-";
      List<String> splitedStr = gmtTime.split(" ");

      int year = int.parse(splitedStr[3]);
      String time = splitedStr[4];
      List<String> splitedTime = time.split(":");
      int hour = int.parse(splitedTime[0]);
      int min = int.parse(splitedTime[1]);
      int second = int.parse(splitedTime[2]);

      int day = int.parse(splitedStr[2]);

      String month = "01";

      switch (splitedStr[1]) {
        case "Jan":
          month = "01";
          break;
        case "Feb":
          month = "02";
          break;
        case "Mar":
          month = "03";
          break;
        case "Apr":
          month = "04";
          break;
        case "May":
          month = "05";
          break;
        case "Jun":
          month = "06";
          break;
        case "Jul":
          month = "07";
          break;
        case "Aug":
          month = "08";
          break;
        case "Sep":
          month = "09";
          break;
        case "Oct":
          month = "10";
          break;
        case "Nov":
          month = "11";
          break;
        case "Dec":
          month = "12";
          break;
      }

      var date = DateTime(year, int.parse(month), day, hour, min, second);

      return formatMessageTime(date.millisecondsSinceEpoch);
    } catch (e) {
      return "-";
    }
  }

  static String formatTime2(String? time) {
    try {
      if (time == null || time.isEmpty) {
        return "--";
      }
      return formatMessageTime(DateTime.parse(time).millisecondsSinceEpoch);
    } catch (e) {
      logger.e(e);
    }
    return '--';
  }

  static String formatMessageTime(int time) {
    if (time == 0) {
      return "-";
    }
    DateTime current = DateTime.now();
    DateTime chatTime;
    if (time.toString().length == 10) {
      chatTime = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    } else {
      chatTime = DateTime.fromMillisecondsSinceEpoch(time);
    }

    if (current.year == chatTime.year) {
      if (chatTime.month != current.month) {
        return DateFormat("M/d H:mm").format(chatTime);
      } else {
        if (current.day == chatTime.day) {
          if (chatTime.hour <= 12) {
            return DateFormat("上午 H:mm").format(chatTime);
          } else {
            return DateFormat("下午 H:mm").format(chatTime);
          }
        } else if (chatTime.day == current.day - 1) {
          return DateFormat("昨天 H:mm").format(chatTime);
        } else {
          return DateFormat("M/d H:mm").format(chatTime);
        }
      }
    } else {
      return DateFormat("yyyy/M/d HH:mm").format(chatTime);
    }
  }
}

String getProviderName(BuildContext context) {
  return SingleAccountPageState.ofUserInfo(context).host ?? "";
}
