import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/base_state_widget.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/empty_widget.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/add_config_page.dart';
import 'package:qinglong_app/module/config/config_bean.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../home/home_page.dart';
import 'config_viewmodel.dart';
import 'package:qinglong_app/base/ui/wallpaper_page_route.dart';

class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({Key? key}) : super(key: key);

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends ConsumerState<ConfigPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  BuildContext? childContext;
  String? configContent;
  bool gotoConfigDetailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadConfigData(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (MultiAccountPageState.actionEditConfig ==
          MultiAccountPageState.useAction()) {
        gotoConfigDetailed = false;
        loadConfigData(context);
      }
    }
  }

  Future<void> loadConfigData(BuildContext context) async {
    HttpResponse<String> result = await SingleAccountPageState.ofApi(
      context,
    ).content("config.sh");
    if (result.success && result.bean != null) {
      configContent = result.bean;

      if (MultiAccountPageState.actionEditConfig ==
              MultiAccountPageState.useAction() &&
          !gotoConfigDetailed) {
        gotoConfigDetailed = true;
        Navigator.of(context)
            .pushNamed(
              Routes.routeConfigEdit,
              arguments: {"title": "config.sh", "content": configContent},
            )
            .then((value) {
              loadConfigData(context);
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    return Scaffold(
      appBar: QlAppBar(
        canBack: false,
        title: "配置文件",
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context)
                  .push(
                    WallpaperPageRoute(
                      builder: (context) => const AddConfigPage(),
                    ),
                  )
                  .then((value) {
                    if (value != null && value == true) {
                      ref
                          .read(
                            SingleAccountPageState.ofConfigProvider(context)(
                              getProviderName(context),
                            ).notifier,
                          )
                          .loadData(context, false);
                    }
                  });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Icon(
                  CupertinoIcons.add,
                  size: 24,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ),
            ),
          ),
        ],
      ),
      body: BaseStateWidget<ConfigViewModel>(
        builder: (ref, model, child) {
          List<Widget> list = [];
          for (int i = 0; i < model.list.length; i++) {
            ConfigBean value = model.list[i];

            if (value.title?.toLowerCase() == "config.sh") {
              list.add(
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    Navigator.of(context)
                        .pushNamed(
                          Routes.routeConfigEdit,
                          arguments: {
                            "title": value.title,
                            "content": configContent,
                          },
                        )
                        .then((value) {
                          Future.delayed(const Duration(seconds: 1), () {
                            loadConfigData(context);
                          });
                        });
                  },
                  child: ConfigCell(bean: value),
                ),
              );
            } else {
              list.add(ConfigCell(bean: value));
            }
          }

          final Widget content =
              model.list.isEmpty
                  ? const EmptyWidget()
                  : RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    onRefresh: () async {
                      await loadConfigData(context);
                      return model.loadData(context, false);
                    },
                    child: ListView(
                      primary: true,
                      padding: const EdgeInsets.only(
                        bottom: kBottomNavigationBarHeight + 50,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: list,
                    ),
                  );
          return isCyber ? CyberBackground(child: content) : content;
        },
        model: SingleAccountPageState.ofConfigProvider(context)(
          getProviderName(context),
        ),
        onReady: (viewModel) {
          viewModel.loadData(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ConfigCell extends ConsumerWidget {
  final ConfigBean bean;

  const ConfigCell({Key? key, required this.bean}) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;

    final Widget configContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              bean.title ?? "",
              maxLines: 1,
              style: TextStyle(
                overflow: TextOverflow.ellipsis,
                color:
                    isCyber ? CyberColors.titleWhite : AppleColors.textPrimary,
                fontSize: 17,
                fontWeight: isCyber ? null : FontWeight.w600,
                fontFamily: isCyber ? CyberColors.monoFont : null,
              ),
            ),
          ),
          Image.asset(
            "assets/images/icon_right.png",
            fit: BoxFit.cover,
            width: 18,
          ),
        ],
      ),
    );

    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(Routes.routeConfigDetail, arguments: {"bean": bean});
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: isCyber ? 12 : AppleColors.spaceMd,
                vertical: 6,
              ),
              decoration:
                  isCyber
                      ? null
                      : BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppleColors.radiusCard,
                        ),
                        border: Border.all(color: AppleColors.cardBorder),
                      ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppleColors.radiusCard),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: SpUtil.getDouble(spCardBlurSigma, defValue: 10), sigmaY: SpUtil.getDouble(spCardBlurSigma, defValue: 10)),
                  child:
                      isCyber
                          ? Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: CyberColors.borderGlow,
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: configContent,
                            ),
                          )
                          : Material(
                            color: Colors.transparent,
                            child: configContent,
                          ),
                ),
              ),
            ),
            isCyber ? const SizedBox.shrink() : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
