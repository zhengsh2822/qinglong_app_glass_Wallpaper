import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:path/path.dart' as ints;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:qinglong_app/base/cupertino_sheet.dart';

import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/glass_text_field.dart';
import 'package:qinglong_app/module/others/scripts/script_download_page.dart';
import 'package:qinglong_app/module/subscribe/add_subscribe_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../main.dart';
import '../others/scripts/script_code_detail_page.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class AddConfigPage extends ConsumerStatefulWidget {
  const AddConfigPage({
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<AddConfigPage> createState() => _AddConfigPageState();
}

class _AddConfigPageState extends ConsumerState<AddConfigPage> {
  final TextEditingController _nameController = TextEditingController();

  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  File? file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CommitButton(
            onTap: () {
              submit();
            },
          ),
        ],
        title: "新增配置文件",
      ),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "名称",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  GlassTextField(
                    focusNode: focusNode,
                    controller: _nameController,
                    hintText: "请输入配置文件名称",
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    "如果该配置文件的名称已存�?那就会直接替换该内容",
                    style: TextStyle(
                      color: ref.watch(themeProvider).themeColor.descColor(),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  const TitleWidget(
                    "上传配置文件",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: file == null ? addWidget(context) : addedWidget(context),
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void submit() async {
    if (_nameController.text.isEmpty) {
      "配置文件名称不能为空".toast();
      return;
    }

    commitReal();
  }

  Widget addWidget(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        showMoreOperate(
          context,
          [
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
            )
          ],
        );
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
                "上传配置文件",
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

  void commitReal() async {
    if (file == null) {
      "请先选择文件".toast();
      return;
    }
    if (!(file?.existsSync() ?? false)) {
      "该文件不存在".toast();
      return;
    }

    try {
      await EasyLoading.show(status: " 提交中");
      final contents = await file!.readAsString();
      var response = await SingleAccountPageState.ofApi(context).saveFile(_nameController.text, contents);
      await EasyLoading.dismiss();
      if (response.success) {
        "上传成功".toast();
        Navigator.of(context).pop(true);
      } else {
        response.message?.toast();
      }
    } catch (e) {
      e.toString().toast();
      EasyLoading.dismiss();
    }
  }

  void pickLocalFile() async {
    dynamic result = await Future.value(null);
    if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
      file = File(result.files.single.path!);

      if (file == null) return;
      _nameController.text = getFileName();
      if (file!.lengthSync() > 5242880) {
        file = null;
        "最大支持上传5M的文件".toast();
        return;
      }

      setState(() {});
    }
  }

  void fromRemote(BuildContext context) {
    Navigator.of(context)
        .push(
      WallpaperPageRoute(
        builder: (context) => const ScriptDownloadPage(),
      ),
    )
        .then((value) {
      if (value != null) {
        Map<String, String> data = value;

        _nameController.text = data["name"] ?? "";
        String path = data["path"] ?? "";
        file = File(path);
        if (file == null) return;
        if (file!.lengthSync() > 5242880) {
          file = null;
          "最大支持上传5M的文件".toast();
          return;
        }

        setState(() {});
      } else {
        _nameController.text = "";
      }
    });
  }

  Widget addedWidget(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        try {
          String content = await file!.readAsString();
          Navigator.of(context).push(
            WallpaperPageRoute(
              builder: (context) => ScriptCodeDetailPage(
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
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        child: Row(
          children: [
            Image.asset(
              getIconBySuffix(),
              width: 50,
              fit: BoxFit.cover,
            ),
            const SizedBox(
              width: 15,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getFileName(),
                    style: TextStyle(
                      color: ref.watch(themeProvider).themeColor.titleColor(),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
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
                _nameController.text = "";
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

  static String getFileSize(String filepath, int decimals) {
    var file = File(filepath);
    int bytes = file.lengthSync();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  String getFileName() {
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
