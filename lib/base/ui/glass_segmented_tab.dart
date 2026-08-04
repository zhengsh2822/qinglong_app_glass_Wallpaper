import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class GlassSegmentedTab extends ConsumerStatefulWidget {
  final List<String> tabs;
  final TabController tabController;
  final bool editMode;

  const GlassSegmentedTab({
    super.key,
    required this.tabs,
    required this.tabController,
    this.editMode = false,
  });

  @override
  ConsumerState<GlassSegmentedTab> createState() => _GlassSegmentedTabState();
}

class _GlassSegmentedTabState extends ConsumerState<GlassSegmentedTab> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final theme = ref.watch(themeProvider);

    final Color thumbColor = isCyber ? CyberColors.cyan : theme.primaryColor;
    final Color selectedTextColor = isCyber ? CyberColors.bg : Colors.white;
    final Color unselectedTextColor =
        isCyber ? CyberColors.descColor : theme.themeColor.title2Color();

    return SizedBox(
      height: 55,
      child: IgnorePointer(
        ignoring: widget.editMode,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 15,
            right: 15,
            bottom: 10,
            top: 10,
          ),
          child: AnimatedOpacity(
            opacity: _isReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _TabBarSlider(
              tabs: widget.tabs,
              tabController: widget.tabController,
              thumbColor: thumbColor,
              selectedTextColor: selectedTextColor,
              unselectedTextColor: unselectedTextColor,
              isCyber: isCyber,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarSlider extends StatelessWidget {
  final List<String> tabs;
  final TabController tabController;
  final Color thumbColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final bool isCyber;

  const _TabBarSlider({
    required this.tabs,
    required this.tabController,
    required this.thumbColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.isCyber,
  });

  @override
  Widget build(BuildContext context) {
    final int count = tabs.length;
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 15);

    // LayoutBuilder 提到 AnimatedBuilder 外层，避免每帧动画都重新布局
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double tabWidth = totalWidth / count;
        const double horizontalPadding = 3.0;
        final double thumbWidth = tabWidth - horizontalPadding * 2;

        return Container(
          height: 35,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: isCyber
                ? Border.all(color: CyberColors.borderGlow, width: 0.5)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: effectiveSigma, sigmaY: effectiveSigma),
              child: AnimatedBuilder(
                animation: tabController.animation!,
                builder: (context, child) {
                  final double animValue = tabController.animation!.value;
                  final double thumbLeft = horizontalPadding + animValue * tabWidth;

                  return Stack(
                    children: [
                      Positioned(
                        left: thumbLeft,
                        top: 3,
                        bottom: 3,
                        width: thumbWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: thumbColor,
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(count, (i) {
                          final double distance = (animValue - i).abs();
                          final double t = distance.clamp(0.0, 1.0);
                          final Color textColor = Color.lerp(
                            selectedTextColor,
                            unselectedTextColor,
                            t,
                          )!;

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                tabController.animateTo(
                                  i,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: Center(
                                child: Text(
                                  tabs[i],
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class GlassSegmentedTabDelegate extends SliverPersistentHeaderDelegate {
  final List<String> tabs;
  final TabController tabController;
  final bool editMode;

  const GlassSegmentedTabDelegate({
    required this.tabs,
    required this.tabController,
    this.editMode = false,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return GlassSegmentedTab(
      tabs: tabs,
      tabController: tabController,
      editMode: editMode,
    );
  }

  @override
  bool shouldRebuild(covariant GlassSegmentedTabDelegate oldDelegate) {
    return editMode != oldDelegate.editMode ||
        tabs.length != oldDelegate.tabs.length;
  }

  @override
  double get maxExtent => 55;

  @override
  double get minExtent => 55;
}
