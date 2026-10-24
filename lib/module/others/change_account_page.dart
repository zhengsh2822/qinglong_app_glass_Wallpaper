import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/container_transform_route.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slidable.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/optimized_frosted_glass.dart';
import 'package:qinglong_app/base/ui/shared_page_entrance.dart';
import 'package:qinglong_app/base/ui/wallpaper_background.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../main.dart';
import '../login/login_page.dart';

class ChangeAccountPage extends ConsumerStatefulWidget {
  /// 共享容器转场传入的动画；为 null 时保持原行为（零时长整页打开）。
  /// 非空时页面不再自绘 CyberBackground，背景由转场容器提供。
  final Animation<double>? animation;

  const ChangeAccountPage({Key? key, this.animation}) : super(key: key);

  @override
  _ChangeAccountPageState createState() => _ChangeAccountPageState();
}

class _ChangeAccountPageState extends ConsumerState<ChangeAccountPage> {
  /// 添加账号卡片（共享转场源）
  final GlobalKey _addAccountKey = GlobalKey();
  bool _addAccountOpening = false;

  @override
  void initState() {
    super.initState();

    FocusManager.instance.primaryFocus?.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (MultiAccountUserInfoViewModel.maxAccount == 1 &&
          SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal) {
        "请杀掉App重新进入,即可启用多账号切换功能".toast();
      }
    });
  }

  bool get _isCyber => ref.watch(themeProvider).themeMode == modeCyber;

  @override
  Widget build(BuildContext context) {
    final viewModel = getIt<MultiAccountUserInfoViewModel>();
    // 有效账号槽位：host 非空 + 槽位单例已注册（删除账号后槽位会被重置为空）
    // 注意：tokenBeans 是按"槽位下标"定位的，删除后槽位会留空，
    // 所以列表展示 index 与槽位 index 必须分开，避免串位。
    final List<int> usedSlots = [];
    for (int i = 0; i < viewModel.tokenBeans.length; i++) {
      if ((viewModel.tokenBeans[i].host ?? "").isEmpty) continue;
      if (!getIt.isRegistered<UserInfoViewModel>(instanceName: i.toString())) {
        continue;
      }
      usedSlots.add(i);
    }
    // 第一个空闲槽位 → 唯一的"添加账号"入口；槽位满了就不显示（避免出现两个添加按钮）
    int? freeSlot;
    for (int i = 0; i < MultiAccountUserInfoViewModel.maxAccount; i++) {
      if (!usedSlots.contains(i)) {
        freeSlot = i;
        break;
      }
    }
    final int itemCount = usedSlots.length + (freeSlot == null ? 0 : 1);
    final bool isCyber = _isCyber;
    final Animation<double>? entrance = widget.animation;

    /// 共享转场时按区间做透明度 + 轻微位移的错峰入场；
    /// 普通入口（animation 为空）保持原样，不额外包裹。
    Widget stagger(
      Widget child, {
      required double start,
      required double end,
      double offsetY = 0,
    }) {
      if (entrance == null) return child;
      return _AccountPageStagger(
        animation: entrance,
        start: start,
        end: end,
        offsetY: offsetY,
        child: child,
      );
    }

    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            (ref.watch(themeProvider).themeMode == modeDark || isCyber)
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
        child: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: stagger(
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: kToolbarHeight,
                        ),
                        child: Icon(
                          CupertinoIcons.clear_thick,
                          size: 24,
                          color: isCyber ? CyberColors.cyan : null,
                        ),
                      ),
                    ),
                    start: 0.40,
                    end: 0.68,
                    offsetY: 8,
                  ),
                ),
                const SizedBox(height: 10),
                stagger(
                  Text(
                    "轻触账号以切换身份使用",
                    style: TextStyle(
                      color:
                          isCyber
                              ? Colors.blueGrey
                              : ref.watch(themeProvider).themeColor.descColor(),
                      fontSize: 13,
                    ),
                  ),
                  start: 0.45,
                  end: 0.73,
                  offsetY: 10,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 30),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      Widget item;
                      if (index >= usedSlots.length) {
                        item = addAccount(context, freeSlot!);
                      } else {
                        final int slot = usedSlots[index];
                        final userInfo = getIt<UserInfoViewModel>(
                          instanceName: slot.toString(),
                        );
                        item = GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            context
                                .findAncestorStateOfType<
                                  MultiAccountPageState
                                >()
                                ?.updateIndex(slot);
                            Navigator.of(context).pop();
                          },
                          child: _buildAccountCard(userInfo, slot, isCyber),
                        );
                      }
                      return stagger(
                        item,
                        start: 0.50 + index * 0.05,
                        end: 0.78 + index * 0.05,
                        offsetY: 16,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemCount: itemCount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // 共享容器转场自带整页底色，不能再叠加 CyberBackground；
    // 其它入口（animation 为空）保持原赛博背景。
    if (isCyber && entrance == null) {
      return CyberBackground(child: scaffold);
    }
    return scaffold;
  }

  /// 构建账号卡片（赛博/非赛博统一布局，仅颜色不同）
  Widget _buildAccountCard(
    UserInfoViewModel userInfo,
    int index,
    bool isCyber,
  ) {
    final child = _buildCell(userInfo, index, isCyber);

    if (userInfo.host == null || userInfo.host!.isEmpty) {
      return child;
    }

    // 卡片容器
    Widget card;
    if (isCyber) {
      card = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: OptimizedFrostedGlass(
          sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CyberColors.cardStroke, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
          ),
        ),
      );
    } else {
      card = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: OptimizedFrostedGlass(
          sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CyberColors.cardStroke, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
          ),
        ),
      );
    }

    // 滑动删除
    if (isCyber) {
      return CyberSlidable(
        slidableKey: ValueKey(userInfo.host),
        endActions: [
          CyberSlideAction(
            label: '删除',
            icon: CupertinoIcons.delete,
            color: const Color(0xFFFF3D5C),
            onTap: () => _confirmDelete(userInfo, index),
          ),
        ],
        child: card,
      );
    }

    return Slidable(
      key: ValueKey(userInfo.host),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          AppSlideButton(
            context: context,
            color: const Color(0xffEA4D3E),
            icon: CupertinoIcons.delete,
            onTap: () => _confirmDelete(userInfo, index),
            cyberMode: false,
            width: double.infinity,
            cornerRadius: 12,
            iconSize: 22,
            outerGap: 5,
            innerGap: 6,
          ),
        ],
      ),
      child: card,
    );
  }

  /// 确认删除（统一弹窗）
  void _confirmDelete(UserInfoViewModel model, int index) {
    if (model.token != null && model.token!.isNotEmpty) {
      "请先退出登录，再删除".toast();
      return;
    }
    showConfirmDialog(
      context,
      title: '温馨提示',
      content: '确定删除吗?',
      danger: true,
    ).then((confirmed) {
      if (confirmed == true) {
        final viewModel = getIt<MultiAccountUserInfoViewModel>();
        // 仅当没有其它槽位使用同一 host 时才清理历史记录：
        // 否则会连带删掉同 host 的其它账号历史（本次实机复现：两个槽位同 host）
        final bool sharedByOtherSlot =
            viewModel.tokenBeans
                .asMap()
                .entries
                .any((e) => e.key != index && e.value.host == model.host);
        if (!sharedByOtherSlot) {
          viewModel.removeHistoryAccount(model.host);
        }
        // 槽位单例可能已被清理过，查询前先判断注册状态，避免抛异常
        if (getIt.isRegistered<UserInfoViewModel>(
          instanceName: index.toString(),
        )) {
          getIt<UserInfoViewModel>(
            instanceName: index.toString(),
          ).clearCurrentInfo(index);
        }
        setState(() {});
      }
    });
  }

  /// 账号单元格内容（赛博/非赛博统一布局：host + alias + 状态指示器）
  Widget _buildCell(UserInfoViewModel model, int index, bool isCyber) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.host ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'MiSans',
                    color:
                        isCyber
                            ? CyberColors.titleWhite
                            : ref.watch(themeProvider).themeColor.titleColor(),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  model.alias ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isCyber
                            ? CyberColors.descColor
                            : ref.watch(themeProvider).themeColor.descColor(),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatus(model, isCyber),
        ],
      ),
    );
  }

  /// 状态指示器（赛博/非赛博统一：圆点 + 文本）
  Widget _buildStatus(UserInfoViewModel model, bool isCyber) {
    final bool loggedIn = model.token != null && model.token!.isNotEmpty;
    final Color color =
        loggedIn
            ? (isCyber ? CyberColors.neonGreen : AppleColors.accent)
            : (isCyber ? CyberColors.neonRed : const Color(0xffFB5858));
    final String text = loggedIn ? "已登录" : "未登录";
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow:
                isCyber ? [BoxShadow(color: color, blurRadius: 4)] : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  /// 添加账号：从卡片共享展开到登录页（同导航器，返回时收回卡片）
  void _openAddAccountPage(int index, Color accentColor) {
    final RenderBox? box =
        _addAccountKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      // 兜底：保持原行为
      context
          .findAncestorStateOfType<MultiAccountPageState>()
          ?.updateIndex(index);
      Navigator.of(context).pop();
      return;
    }

    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    final double sigma = SpUtil.getDouble(spCardBlurSigma, defValue: 4);

    HapticFeedback.lightImpact();
    setState(() => _addAccountOpening = true);

    Navigator.of(context)
        .push(
          ContainerTransformRoute(
            sourceRect: rect,
            sourceChild: _buildAddAccountContent(accentColor),
            background: const WallpaperBackground(cacheBlur: true),
            sourceBlurSigma: sigma,
            sourceHighlightOpacity: 0,
            pageBackground: const Color(0xFF080A0D),
            pageBuilder:
                (context, animation) => AccountIndexScope(
                  index: index,
                  child: SharedPageEntrance(
                    animation: animation,
                    child: LoginPage(
                      fromAddNewAccount: true,
                      targetAccountIndex: index,
                    ),
                  ),
                ),
          ),
        )
        .whenComplete(() {
          if (mounted) {
            setState(() => _addAccountOpening = false);
          }
        });
  }

  /// 添加账号按钮（赛博/非赛博统一布局）
  Widget addAccount(BuildContext context, int index) {
    final bool isCyber = _isCyber;
    final accentColor =
        isCyber ? CyberColors.cyan : ref.watch(themeProvider).primaryColor;
    return Opacity(
      opacity: _addAccountOpening ? 0 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openAddAccountPage(index, accentColor),
        child:
            isCyber
                ? Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: KeyedSubtree(
                    key: _addAccountKey,
                    child: OptimizedFrostedGlass(
                      sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: CyberColors.cardStroke,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: _buildAddAccountContent(accentColor),
                        ),
                      ),
                    ),
                  ),
                )
                : Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: KeyedSubtree(
                    key: _addAccountKey,
                    child: OptimizedFrostedGlass(
                      sigma: SpUtil.getDouble(spCardBlurSigma, defValue: 4),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: CyberColors.cardStroke,
                            width: 1,
                          ),
                        ),
                        child: _buildAddAccountContent(accentColor),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  /// 添加账号内容（统一布局：圆形图标 + 文本）
  Widget _buildAddAccountContent(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(CupertinoIcons.add, color: accentColor),
          ),
          const SizedBox(width: 15),
          Text("添加账号", style: TextStyle(color: accentColor, fontSize: 15)),
        ],
      ),
    );
  }
}

/// 共享容器转场下的错峰入场：透明度 + 轻微上移。
/// 反向播放时区间自动倒放，元素先退场，容器再收回卡片。
class _AccountPageStagger extends StatelessWidget {
  const _AccountPageStagger({
    required this.animation,
    required this.start,
    required this.end,
    required this.offsetY,
    required this.child,
  });

  final Animation<double> animation;
  final double start;
  final double end;
  final double offsetY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final double progress = Interval(
          start,
          end,
          curve: Curves.easeOutCubic,
        ).transform(animation.value);
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
