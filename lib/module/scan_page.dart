import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/glass_card.dart';
import 'package:qinglong_app/base/ui/radar_scan_view.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_bean.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../base/http/http.dart';
import '../base/ui/button.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ScanPage> createState() => ScanPageState();
}

class ScanPageState extends ConsumerState<ScanPage> {
  bool scaning = false;
  int _totalCount = 0;
  int _currentIndex = 0;

  /// 扫描轮次令牌：每启动新一轮扫描自增。
  /// 旧轮次循环发现令牌不匹配时立即退出，且不再触碰任何状态，
  /// 防止旧循环结束时把新一轮的状态覆盖回"扫描完成"。
  int _scanGeneration = 0;

  var textProvider = StateProvider<String>((ref) => "");

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: QlAppBar(
        title: "扫描缺失的依赖",
        backCall: () {
          if (!scaning) {
            Navigator.of(context).pop();
          } else {
            if (isCyber) {
              showCyberConfirmDialog(
                context,
                title: '温馨提示',
                content: '当前正在扫描文件,确定退出吗?',
                danger: true,
              ).then((confirmed) {
                if (confirmed == true) {
                  Navigator.of(context).pop();
                }
              });
              return;
            }
            showCupertinoDialog(
              context: context,
              useRootNavigator: false,
              builder:
                  (childContext) => CupertinoAlertDialog(
                    title: const Text("温馨提示"),
                    content: const Text("当前正在扫描文件,确定退出吗?"),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text(
                          "取消",
                          style: TextStyle(color: Color(0xff999999)),
                        ),
                        onPressed: () {
                          Navigator.of(childContext).pop();
                        },
                      ),
                      CupertinoDialogAction(
                        child: Text(
                          "确定",
                          style: TextStyle(
                            color: ref.watch(themeProvider).primaryColor,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(childContext).pop();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
            );
          }
        },
      ),
      body: GlassPageBackground(child: scanWidget()),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  void _startScan() async {
    // 本轮令牌：启动新一轮时自增，旧轮次据此退出
    final int generation = ++_scanGeneration;
    try {
      List<String> jsInstalled = [];
      List<String> pyInstalled = [];
      Api api = Api(SingleAccountPageState.of(context)?.index ?? 0);
      List<TaskBean> list =
          ref
              .read(
                SingleAccountPageState.ofTaskProvider(context)(
                  getProviderName(context),
                ).notifier,
              )
              .list;
      List<DependencyBean> jsList = [];
      List<DependencyBean> pyList = [];
      var jsDep = await api.dependencies("nodejs");

      // 网络请求期间可能已启动新一轮扫描，旧轮次立即废弃
      if (generation != _scanGeneration) return;

      if (jsDep.success) {
        jsList.addAll(jsDep.bean ?? []);
      }
      var pyDep = await api.dependencies("python3");
      if (generation != _scanGeneration) return;
      if (pyDep.success) {
        pyList.addAll(pyDep.bean ?? []);
      }

      // 在网络请求之后才计算需要扫描的有效任务数，确保进度条数字和"实际扫描"严格对齐
      int totalCount = 0;
      for (TaskBean bean in list) {
        if (bean.command == null || bean.command!.isEmpty) continue;
        String command = bean.command!.trim().split(" ").last;
        if (!command.endsWith(".js") &&
            !command.endsWith(".ts") &&
            !command.endsWith(".py"))
          continue;
        totalCount++;
      }
      _totalCount = totalCount;
      _currentIndex = 0;
      if (mounted) setState(() {});

      for (TaskBean bean in list) {
        // 旧轮次（被新一轮取代 / 被停止）直接退出，不再触碰状态
        if (scaning == false || generation != _scanGeneration) return;
        if (bean.command == null || bean.command!.isEmpty) continue;
        String command = bean.command!.trim().split(" ").last;
        if (!command.endsWith(".js") &&
            !command.endsWith(".ts") &&
            !command.endsWith(".py"))
          continue;

        _currentIndex++;
        if (mounted) setState(() {});
        _updateDescText("正在扫描: $command");
        HttpResponse<String> response = await SingleAccountPageState.ofApi(
          context,
        ).inTimeLog(bean.sId!);

        String text = "";

        if (response.success &&
            response.bean != null &&
            response.bean!.isNotEmpty) {
          text = response.bean ?? "";
          String? found = foundReg(command, text);
          if (found != null && found.isNotEmpty) {
            var result = await autoInstallFounded(api, found, command);
            if (result == true) {
              if (command.endsWith(".py")) {
                pyInstalled.add(found);
              } else {
                jsInstalled.add(found);
              }
            }
          }
        }
      }

      // 收尾前再次确认本 轮次仍是最新（防止 await 期间被新一轮取代）
      if (generation != _scanGeneration) return;

      // 扫描完成：进度条收尾到 100%
      _currentIndex = _totalCount;
      if (mounted) setState(() {});

      scaning = false;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (jsInstalled.isNotEmpty || pyInstalled.isNotEmpty) {
          final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
          if (isCyber) {
            showCyberConfirmDialog(
              context,
              title: '本次已安装如下依赖',
              content:
                  'NodeJS:\n ${jsInstalled.join("\n").toString()} \n Python3:\n ${pyInstalled.join("\n").toString()}',
              confirmLabel: '知道了',
            );
            return;
          }
          showCupertinoDialog(
            context: context,
            useRootNavigator: false,
            builder:
                (childContext) => CupertinoAlertDialog(
                  title: const Text("本次已安装如下依赖"),
                  content: Text(
                    "NodeJS:\n ${jsInstalled.join("\n").toString()} \n Python3:\n ${pyInstalled.join("\n").toString()}",
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: Text(
                        "知道了",
                        style: TextStyle(
                          color: ref.watch(themeProvider).primaryColor,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(childContext).pop();
                      },
                    ),
                  ],
                ),
          );
        } else {
          "暂未发现缺失的依赖".toast();
        }
      });
      setState(() {});
    } catch (e) {
      // 异常也只由最新轮次处理
      if (generation != _scanGeneration) return;
      scaning = false;
      _totalCount = 0;
      _currentIndex = 0;
      setState(() {});
      "扫描失败: $e".toast();
    }
  }

  Widget scanWidget() {
    final theme = ref.watch(themeProvider);
    final primaryColor = theme.primaryColor;
    final descColor = theme.themeColor.descColor();
    final progress = _totalCount == 0 ? 0.0 : _currentIndex / _totalCount;
    final radarSize = MediaQuery.of(context).size.width * 0.62;

    // 计算 percentText / bottomText
    // 严格区分：未扫描 / 准备中（已点开始但还在等网络）/ 扫描中 / 扫描完成
    String percentText;
    String bottomText;
    if (scaning) {
      if (_totalCount == 0) {
        // 已点击开始扫描，但 _startScan 还在 await 网络请求，进度条数字还没确定
        percentText = '';
        bottomText = '准备中...';
      } else {
        percentText = '${(progress * 100).toStringAsFixed(0)}%';
        bottomText = '$_currentIndex / $_totalCount';
      }
    } else if (_totalCount > 0) {
      percentText = '100%';
      bottomText = '扫描完成';
    } else {
      percentText = '0%';
      bottomText = '准备就绪';
    }

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              kToolbarHeight,
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              RadarScanView(
                size: radarSize,
                progress: progress,
                primaryColor: primaryColor,
                descColor: descColor,
                percentText: percentText,
                bottomText: bottomText,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: Consumer(
                  builder: (context, ref, _) {
                    String text = ref.watch(textProvider);
                    return Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 12,
                        color: descColor,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: _buildScanButton(primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateDescText(String s) {
    ref.read(textProvider.notifier).state = s;
  }

  /// 根据扫描状态构造按钮
  Widget _buildScanButton(Color primaryColor) {
    final String title;
    final VoidCallback? onTap;
    if (scaning) {
      title = "停止扫描";
      onTap = () {
        scaning = false;
        // 令牌失效，让仍在 await 的旧轮次循环彻底退出
        _scanGeneration++;
        setState(() {});
        ref.read(textProvider.notifier).state = "";
      };
    } else {
      // 未扫描 / 已完成：都可点击启动新一轮扫描
      title = _totalCount > 0 ? "再次扫描" : "开始扫描";
      onTap = () {
        scaning = true;
        _totalCount = 0;
        _currentIndex = 0;
        setState(() {});
        _startScan();
      };
    }
    return Opacity(
      opacity: 1.0,
      child: ButtonWidget(title: title, onTap: onTap ?? () {}),
    );
  }

  static Future<bool> autoInstallFounded(
    Api api,
    String found,
    String command,
  ) async {
    if (found.contains(".") || found.contains("/")) return false;
    if (command.endsWith(".py")) {
      List<DependencyBean> pyList = [];
      var pyDep = await api.dependencies("python3");
      if (pyDep.success) {
        pyList.addAll(pyDep.bean ?? []);
      }
      DependencyBean bean = pyList.firstWhere(
        (element) => element.name == found,
        orElse: () => DependencyBean(),
      );
      if (bean.name == null || bean.name!.isEmpty) {
        await api.addDependency([
          {"name": found, "type": 1},
        ]);
        return true;
      }
    } else {
      var jsDep = await api.dependencies("nodejs");
      List<DependencyBean> jsList = [];

      if (jsDep.success) {
        jsList.addAll(jsDep.bean ?? []);
      }
      DependencyBean bean = jsList.firstWhere(
        (element) => element.name == found,
        orElse: () => DependencyBean(),
      );

      if (bean.name == null || bean.name!.isEmpty) {
        await api.addDependency([
          {"name": found, "type": 0},
        ]);
        return true;
      }
    }
    return false;
  }

  static String? foundReg(String command, String text) {
    if (text.isEmpty) return null;

    if (command.isEmpty) return null;

    String? founded;
    if (command.endsWith(".py")) {
      RegExp firstReg = RegExp(r"No module named '(.*)'");

      var firstMatch = firstReg.firstMatch(text);
      int firstStart = firstMatch?.start ?? -1;
      int firstEnd = firstMatch?.end ?? -1;

      if (firstStart >= 0 && firstEnd >= 0) {
        founded = text.substring(firstStart + 17, firstEnd - 1);
      } else {
        RegExp secondReg = RegExp(r'No module named "(.*)"');

        var secondMatch = secondReg.firstMatch(text);
        int secondStart = secondMatch?.start ?? -1;
        int secondEnd = secondMatch?.end ?? -1;
        if (secondStart >= 0 && secondEnd >= 0) {
          founded = text.substring(secondStart + 17, secondEnd - 1);
        }
      }
    } else {
      RegExp firstReg = RegExp(r"Cannot find module '(.*)'");

      var firstMatch = firstReg.firstMatch(text);
      int firstStart = firstMatch?.start ?? -1;
      int firstEnd = firstMatch?.end ?? -1;

      if (firstStart >= 0 && firstEnd >= 0) {
        founded = text.substring(firstStart + 20, firstEnd - 1);
      } else {
        RegExp secondReg = RegExp(r'Cannot find module "(.*)"');

        var secondMatch = secondReg.firstMatch(text);
        int secondStart = secondMatch?.start ?? -1;
        int secondEnd = secondMatch?.end ?? -1;
        if (secondStart >= 0 && secondEnd >= 0) {
          founded = text.substring(secondStart + 20, secondEnd - 1);
        }
      }
    }

    if (founded != null && founded.isNotEmpty) {
      if (founded.contains((".")) || founded.contains("/")) {
        return null;
      } else {
        return founded;
      }
    }

    return null;
  }
}
