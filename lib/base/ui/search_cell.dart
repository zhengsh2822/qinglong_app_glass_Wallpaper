import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../sp_const.dart';
import '../theme.dart';
import '../../utils/sp_utils.dart';

class SearchCell extends ConsumerStatefulWidget {
  final TextEditingController controller;

  const SearchCell({Key? key, required this.controller}) : super(key: key);

  @override
  ConsumerState createState() => _SearchCellState();
}

class _SearchCellState extends ConsumerState<SearchCell> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: 8);
    final theme = ref.watch(themeProvider);
    final bool isCyber = theme.themeMode == modeCyber;

    final Color bgColor =
        isCyber ? const Color(0xFF12121A) : AppleColors.bgTertiary;
    final Color bgEndColor =
        isCyber ? const Color(0xFF12121A) : AppleColors.cardBgSolid;
    final Color borderColor =
        isCyber ? CyberColors.borderGlow : AppleColors.glassBorder;
    final Color textColor =
        isCyber ? CyberColors.titleWhite : AppleColors.textPrimary;
    final Color hintColor =
        isCyber ? CyberColors.descColor : AppleColors.textHint;
    final Color iconColor = isCyber ? CyberColors.cyan : AppleColors.textHint;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveSigma, sigmaY: effectiveSigma),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bgColor.withOpacity(isCyber ? 0.5 : 0.85),
                bgEndColor.withOpacity(isCyber ? 0.5 : 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: isCyber ? 0.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.search, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  maxLines: 1,
                  textAlign: TextAlign.left,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(fontSize: 14, color: textColor),
                  cursorColor: iconColor,
                  decoration: InputDecoration(
                    hintText: "搜索",
                    hintStyle: TextStyle(fontSize: 14, color: hintColor),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              ),
              if (widget.controller.text.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.controller.text = "";
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 16,
                      color: iconColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
