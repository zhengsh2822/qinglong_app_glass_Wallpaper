import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/others/file_directory_page.dart';
import 'package:qinglong_app/module/others/other_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../base/theme.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class IcloudPage extends ConsumerStatefulWidget {
  const IcloudPage({Key? key}) : super(key: key);

  @override
  ConsumerState<IcloudPage> createState() => _IcloudPageState();
}

class _IcloudPageState extends ConsumerState<IcloudPage>
    with LazyLoadState<IcloudPage> {
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
                title: "当你添加,修改,删除的时候,将会自动备份",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              SettingsCard(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsSwitchRow(
                      title: "自动备份",
                      value: SpUtil.getBool(spICloud, defValue: true),
                      onChanged: (v) {
                        SpUtil.putBool(spICloud, v);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 1, indent: 15),
                    SettingsTapRow(
                      title: "查看文件",
                      onTap: () async {
                        lookUpFiles();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              SectionHeader(
                title: "当前已有备份文件 $fileNum 个,共占用 $fileSizes 容量",
                padding: const EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 15),
              const SectionHeader(
                title: "环境变量",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              SettingsCard(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsTapRow(
                      title: "同步环境变量",
                      onTap: () async {
                        try {
                          var result = await Api(
                            SingleAccountPageState.of(context)!.index,
                          ).envs("");
                          await getIt<ICloudUtils>(
                            instanceName:
                                SingleAccountPageState.of(
                                  context,
                                )!.index.toString(),
                          ).asyncEnv(result.bean ?? [], focusUpdate: true);
                          SpUtil.putString(spEnvBackTime, ICloudUtils.now());
                          setState(() {});
                        } catch (e) {}
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            SpUtil.getString(
                              spEnvBackTime,
                              defValue: "",
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .descColor(),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.right_chevron,
                            size: 16,
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 15),
                    SettingsTapRow(
                      title: "还原备份",
                      onTap: () {
                        lookUpFiles();
                      },
                    ),
                    const Divider(height: 1, indent: 15),
                    SettingsTapRow(
                      title: "删除备份",
                      onTap: () async {
                        if (Platform.isAndroid) {
                          "请点击页面下方备份文件删除频率按钮设置删除".toast2();
                          return;
                        }
                        "请前往 \"文件\" App手动删除".toast();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              SectionHeader(
                title:
                    SpUtil.getInt(spVIP, defValue: typeNormal) == typeVIP
                        ? "config.sh文件"
                        : "配置文件",
                padding: const EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              SettingsCard(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsTapRow(
                      title: "同步config.sh文件",
                      onTap: () async {
                        String content;
                        HttpResponse<String> result =
                            await SingleAccountPageState.ofApi(
                              context,
                            ).content("config.sh");
                        if (result.success && result.bean != null) {
                          content = result.bean ?? "";
                          await ICloudUtils(
                            SingleAccountPageState.of(context)!.index,
                          ).asyncConfig(
                            "config.sh",
                            content,
                            focusUpdate: true,
                          );
                          SpUtil.putString(
                            spConfigBackTime,
                            ICloudUtils.now(),
                          );
                          setState(() {});
                        } else {
                          result.message!.toast();
                        }
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            SpUtil.getString(
                              spConfigBackTime,
                              defValue: "",
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .descColor(),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.right_chevron,
                            size: 16,
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 15),
                    SettingsTapRow(
                      title: "还原备份",
                      onTap: () {
                        lookUpFiles();
                      },
                    ),
                    const Divider(height: 1, indent: 15),
                    SettingsTapRow(
                      title: "删除备份",
                      onTap: () async {
                        if (Platform.isAndroid) {
                          "请点击页面下方备份文件删除频率按钮设置删除".toast2();
                          return;
                        }
                        "请前往 \"文件\" App手动删除".toast();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              const SectionHeader(
                title: "备份和还原配置文件",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 15),
              const SectionHeader(
                title: "订阅管理",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              SettingsCard(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsTapRow(
                      title: "同步订阅管理",
                      onTap: () async {
                        try {
                          var result =
                              await Api(
                                SingleAccountPageState.of(context)!.index,
                              ).subscribes();
                          await getIt<ICloudUtils>(
                            instanceName:
                                SingleAccountPageState.of(
                                  context,
                                )!.index.toString(),
                          ).asyncSubscribe(
                            result.bean ?? "",
                            focusUpdate: true,
                          );
                          SpUtil.putString(
                            spSubscribeBackTime,
                            ICloudUtils.now(),
                          );
                          setState(() {});
                        } catch (e) {}
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            SpUtil.getString(
                              spSubscribeBackTime,
                              defValue: "",
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .descColor(),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.right_chevron,
                            size: 16,
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 15),
                    SettingsTapRow(
                      title: "还原备份",
                      onTap: () {
                        lookUpFiles();
                      },
                    ),
                    const Divider(height: 1, indent: 15),
                    SettingsTapRow(
                      title: "删除备份",
                      onTap: () async {
                        if (Platform.isAndroid) {
                          "请点击页面下方备份文件删除频率按钮设置删除".toast2();
                          return;
                        }
                        "请前往 \"文件\" App手动删除".toast();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const SectionHeader(
                title: "功能",
                padding: EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 5),
              SettingsCard(
                margin: EdgeInsets.zero,
                child: SettingsTapRow(
                  title: "备份文件删除频率",
                  onTap: () {
                    _delDuration();
                  },
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Visibility(
                visible: Platform.isAndroid,
                child: const SectionHeader(
                  title:
                      "Android用户为了数据安全,备份文件保存在/data/user/0/work.master.qinglongapp/files/文件夹下,非root用户无法通过文件浏览器查看,只可以点击页面顶部的查看文件按钮查看",
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  void _delDuration() async {
    final initial = SpUtil.getInt(
      spLocalBackUpFileExperiedTime,
      defValue: getDefaultLogExperiedTime(),
    );
    final days = await showFrequencyDialog(
      context,
      title: '备份文件删除频率',
      initialValue: initial,
      minValue: 1,
      maxValue: 100,
      unit: '天',
    );
    if (days != null) {
      SpUtil.putInt(spLocalBackUpFileExperiedTime, days);
      setState(() {});
    }
  }

  @override
  void onLazyLoad() async {
    try {
      Map<String, int> result = await compute(
        dirStatSync,
        await FileUtil(
          SingleAccountPageState.of(context)?.index ?? 0,
        ).sourcePath,
      );
      fileNum = result["fileNum"].toString();
      fileSizes = getFileSizeString(result["size"] ?? 0, 2);
      setState(() {});
    } catch (e) {}
  }

  String? fileNum = "-";
  String fileSizes = "-";

  static String getFileSizeString(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)}${suffixes[i]}';
  }

  void lookUpFiles() async {
    String path =
        await FileUtil(
          SingleAccountPageState.of(context)?.index ?? 0,
        ).sourcePath;
    Navigator.of(context).push(
      WallpaperPageRoute(builder: (context) => FileDirectoryPage(path: path)),
    );
  }
}

Map<String, int> dirStatSync(String dirPath) {
  int fileNum = 0;
  int totalSize = 0;
  var dir = Directory(dirPath);
  try {
    if (dir.existsSync()) {
      dir.listSync(recursive: true, followLinks: false).forEach((
        FileSystemEntity entity,
      ) {
        if (entity is File) {
          fileNum++;
          totalSize += entity.lengthSync();
        }
      });
    }
  } catch (e) {}

  return {'fileNum': fileNum, 'size': totalSize};
}
