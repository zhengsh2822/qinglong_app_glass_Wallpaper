import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';

/// 固定顶部悬浮搜索框容器（对齐顶部 tab 大胶囊的悬浮机制）
///
/// 参考 task_page 顶部 tab（SliverPersistentHeader pinned）的悬浮方式：
///  - 搜索框 Positioned 固定悬浮在顶部，列表铺满整个区域
///  - 列表自身的顶部 padding（滚动内容的一部分）提供"搜索框与第一项之间的间距"，
///    滚动时间距被内容填充，因此**不会出现固定的背景色块**
///  - 列表滚动时从胶囊底下穿过（被盖住），实现悬浮
///
/// 用法（页面 body）：
/// ```dart
/// FloatingSearchBarArea(
///   controller: searchText,
///   listView: RefreshIndicator(
///     onRefresh: ...,
///     child: ListView.separated(
///       padding: EdgeInsets.only(top: 94, bottom: 80), // 顶部间距在列表内部
///       ...
///     ),
///   ),
/// )
/// ```
class FloatingSearchBarArea extends StatelessWidget {
  final TextEditingController controller;

  /// 滚动列表（底层，铺满整个区域；顶部间距由列表自身 padding 提供）
  final Widget listView;

  /// 搜索框距顶距离
  final double top;

  const FloatingSearchBarArea({
    super.key,
    required this.controller,
    required this.listView,
    this.top = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 底层：滚动列表（从屏幕顶部开始，顶部间距由列表自身 padding 提供，
        // 滚动时被内容填充，无固定背景色块）
        Positioned.fill(child: listView),
        // 顶层：固定悬浮搜索框
        Positioned(
          top: top,
          left: 15,
          right: 15,
          child: SearchCell(controller: controller),
        ),
      ],
    );
  }
}
