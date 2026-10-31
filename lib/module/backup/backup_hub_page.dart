import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/module/backup/backup_restore_page.dart';

/// 文件备份聚合页：入口分发到「备份与恢复」（本地）与「WebDAV备份」（云）。
class BackupHubPage extends ConsumerStatefulWidget {
  const BackupHubPage({super.key});

  @override
  ConsumerState<BackupHubPage> createState() => _BackupHubPageState();
}

class _BackupHubPageState extends ConsumerState<BackupHubPage>
    with LazyLoadState<BackupHubPage> {
  @override
  void onLazyLoad() {}

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(title: "文件备份"),
      body: SingleChildScrollView(
        primary: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              const SectionHeader(
                title: "选择备份方式",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEntry(
                      icon: CupertinoIcons.archivebox_fill,
                      title: "备份与恢复",
                      desc: "三件套本地备份（环境变量 / config.sh / 订阅）+ 面板 .tgz 全量包",
                      onTap: () {
                        Navigator.of(context).push(
                          WallpaperPageRoute(
                            builder: (context) => const BackupRestorePage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 15),
                    _buildEntry(
                      icon: CupertinoIcons.cloud_fill,
                      title: "WebDAV备份",
                      desc: "加密备份到你自己的 WebDAV 服务器（坚果云 / NAS / OpenList 等）",
                      onTap: () {
                        Navigator.of(context).pushNamed(Routes.routeWebDav);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  /// 聚合页入口：整块区域（图标 + 标题 + 说明 + 箭头）都可点击
  Widget _buildEntry({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: ref.watch(themeProvider).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 15),
                Text(
                  title,
                  style: TextStyle(
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Icon(
                  CupertinoIcons.right_chevron,
                  size: 16,
                  color: ref.watch(themeProvider).themeColor.descColor(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 35),
              child: Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: ref.watch(themeProvider).themeColor.descColor(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
