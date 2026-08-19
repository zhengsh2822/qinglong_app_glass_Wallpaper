import 'package:share_plus/share_plus.dart';

class ShareUtils {
  static Future<void> share(String text) async {
    if (text.isEmpty) return;
    await Share.share(text, subject: '青龙面板日志');
  }

  static Future<void> shareApp() async {
    const String shareText =
        '分享一款好用的青龙客户端，快去点击下面的链接地址下载吧 https://github.com/zhengsh2822/qinglong_app_glass_Wallpaper';
    await Share.share(shareText, subject: '青龙客户端');
  }
}
