import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:path/path.dart' as ints;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:qinglong_app/base/cupertino_sheet.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/base/ui/selector_card.dart';
import 'package:qinglong_app/base/ui/tree/models/script_data.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/others/scripts/script_code_detail_page.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/file_picker_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import '../module/others/scripts/script_download_page.dart';
import '../module/subscribe/add_subscribe_page.dart';
import 'single_account_page.dart';
import 'package:qinglong_app/base/ui/script_image_preview_page.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

typedef StringCallBack = void Function(String? name);
typedef CronCallBack = void Function(String? name);

class UploadScriptWidget extends ConsumerStatefulWidget {
  final StringCallBack nameCallBack;
  final CronCallBack? cronCallBack;
  final bool onlyShowName;

  const UploadScriptWidget({
    Key? key,
    required this.nameCallBack,
    this.onlyShowName = false,
    this.cronCallBack,
  }) : super(key: key);

  @override
  ConsumerState<UploadScriptWidget> createState() => UploadScriptWidgetState();
}

class UploadScriptWidgetState extends ConsumerState<UploadScriptWidget>
    with LazyLoadState<UploadScriptWidget> {
  String scriptPath = "";
  File? file;
  String? fileName;
  List<String?> paths = [];
  bool isLoading = true;

  @override
  void onLazyLoad() {
    init();
  }

  void init() async {
    isLoading = true;
    HttpResponse<List<ScriptData>> response =
        await SingleAccountPageState.ofApi(context).scripts();

    if (response.success) {
      if (response.bean == null || response.bean!.isEmpty) {
        return;
      }
      void lookNode(ScriptData node) {
        if (node.type != "directory") {
          String name = node.parent;
          if (name == "") return;
          if (paths.isEmpty) {
            paths.add(name);
          } else {
            if (!paths.contains(name)) {
              paths.add(node.parent);
            }
          }
          return;
        } else {
          if (node.children.isEmpty) {
            String name = node.parent;
            if (name == "") return;
            if (paths.isEmpty) {
              paths.add(name + "/" + node.title);
            } else {
              if (!paths.contains(name + "/" + node.title)) {
                paths.add(name + "/" + node.title);
              }
            }
          } else {
            for (var value in node.children) {
              lookNode(value);
            }
          }
        }
      }

      if (response.bean != null) {
        for (var value in response.bean!) {
          lookNode(value);
        }
      }
      paths = paths.reversed.toList();
      isLoading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleWidget(widget.onlyShowName ? "父目录" : "脚本目录"),
        const SizedBox(height: 10),
        isLoading
            ? const Center(child: LoadingWidget())
            // 卡内展开选择器（主题版 SelectorCard 架构）：原底部弹窗改为
            // 卡片原地展开，根目录 + 动态路径 + 选中对勾，选中即收起；
            // SelectorCard 透明背景，底色圆角由 GlassCard 卡壳提供
            : GlassCard(
              padding: EdgeInsets.zero,
              child: SelectorCard(
                title: scriptPath.isEmpty ? "根目录" : scriptPath,
                subtitle: widget.onlyShowName ? "父目录" : "脚本目录",
                items: [
                  SelectorCardItem(
                    title: "根目录",
                    selected: scriptPath.isEmpty,
                    onTap: () {
                      scriptPath = "";
                      widget.nameCallBack(fileName);
                      setState(() {});
                    },
                  ),
                  ...paths
                      .where((e) => e != null)
                      .map(
                        (e) => SelectorCardItem(
                          title: e!,
                          selected: scriptPath == e,
                          onTap: () {
                            scriptPath = e!;
                            widget.nameCallBack(fileName);
                            setState(() {});
                          },
                        ),
                      ),
                ],
              ),
            ),
        const SizedBox(height: 30),
        Visibility(
          visible: !widget.onlyShowName,
          child: RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              text: "上传脚本",
              style: TextStyle(
                fontSize: 16,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
          ),
        ),
        Visibility(
          visible: !widget.onlyShowName,
          child: const SizedBox(height: 10),
        ),
        Visibility(
          visible: !widget.onlyShowName,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: SizedBox(
              width: double.infinity,
              child: file == null ? addWidget(context) : addedWidget(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget addWidget(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        showMoreOperate(context, [
          CupertinoSheer(
            title: "远程地址",
            onTap: () {
              fromRemote(context);
            },
          ),
          addDivider(),
          CupertinoSheer(
            title: "本地上传",
            onTap: () {
              pickLocalFile();
            },
          ),
        ]);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 80,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.add_circled,
                size: 28,
                color: ref.watch(themeProvider).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                "上传脚本文件",
                style: TextStyle(
                  color: ref.watch(themeProvider).themeColor.titleColor(),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 脚本目录选择弹窗（卡片样式 + 毛玻璃模糊）

  void pickLocalFile() async {
    var result = await FilePickerUtils.pickFile();
    if (result != null && result.path != null) {
      file = File(result.path!);
      fileName = null;

      if (file == null) return;
      if (file!.lengthSync() > 5242880) {
        file = null;
        "最大支持上传5M的文件".toast();
        return;
      }

      widget.nameCallBack(getFileName());
      setState(() {});
    }
  }

  void fromRemote(BuildContext context) {
    Navigator.of(context)
        .push(
          WallpaperPageRoute(builder: (context) => const ScriptDownloadPage()),
        )
        .then((value) {
          if (value != null) {
            Map<String, String> data = value;

            fileName = data["name"] ?? "";
            String path = data["path"] ?? "";
            file = File(path);
            if (file == null) return;
            if (file!.lengthSync() > 5242880) {
              file = null;
              "最大支持上传5M的文件".toast();
              return;
            }

            widget.nameCallBack(getFileName());
            setState(() {});
          } else {
            fileName = null;
          }
        });
  }

  Widget addedWidget(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        try {
          // 图片文件直接本地预览，不走文本读取（二进制 readAsString 会抛异常）
          if (isImageFileName(getFileName())) {
            Navigator.of(context).push(
              WallpaperPageRoute(
                builder:
                    (context) => ScriptImagePreviewPage(
                      fileName: getFileName(),
                      localPath: file!.path,
                    ),
              ),
            );
            return;
          }
          String content = await file!.readAsString();
          Navigator.of(context).push(
            WallpaperPageRoute(
              builder:
                  (context) => ScriptCodeDetailPage(
                    title: getFileName(),
                    content: content,
                  ),
            ),
          );
        } catch (e) {
          e.toString().toast();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Image.asset(getIconBySuffix(), width: 50, fit: BoxFit.cover),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getFileName(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ref.watch(themeProvider).themeColor.titleColor(),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    getFileSize(file!.path, 2),
                    style: TextStyle(
                      color: ref.watch(themeProvider).themeColor.descColor(),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                file = null;
                fileName = null;
                widget.nameCallBack(null);
                setState(() {});
              },
              child: Icon(
                CupertinoIcons.clear,
                size: 20,
                color: ref.watch(themeProvider).themeColor.descColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getFileSize(String filepath, int decimals) {
    var file = File(filepath);
    int bytes = file.lengthSync();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  String getFileName() {
    if (fileName != null) {
      return fileName!;
    }
    return ints.basename(file!.path);
  }

  String getIconBySuffix() {
    String end = file!.path;

    if (end.endsWith(".py")) {
      return "assets/images/py.png";
    }
    if (end.endsWith(".js")) {
      return "assets/images/js.png";
    }
    if (end.endsWith(".ts")) {
      return "assets/images/ts.png";
    }
    if (end.endsWith(".json")) {
      return "assets/images/json.png";
    }
    if (end.endsWith(".sh")) {
      return "assets/images/shell.png";
    }
    return "assets/images/other.png";
  }
}
