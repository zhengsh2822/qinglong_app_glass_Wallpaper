import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

const double _sheetBlurSigma = 25.0;
const double _sheetBarrierDim = 0.65;

class CupertinoSheer extends ConsumerWidget {
  final String title;
  final GestureTapCallback onTap;

  const CupertinoSheer({Key? key, required this.title, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (isCyber) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: CyberColors.titleWhite,
                  fontSize: 16,
                  fontFamily: CyberColors.monoFont,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          color: Colors.transparent,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: ref.watch(themeProvider).themeColor.titleColor(),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget addDivider() {
  return Consumer(
    builder: (context, ref, _) {
      final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
      if (isCyber) {
        return Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: CyberColors.borderGlow.withValues(alpha: 0.25),
        );
      }
      return const Divider(height: 0.5);
    },
  );
}

void showMoreOperate(BuildContext context, List<Widget> list) {
  final bool isCyber =
      ProviderScope.containerOf(context).read(themeProvider).themeMode ==
      modeCyber;

  if (isCyber) {
    _showCyberMoreOperate(context, list);
    return;
  }

  _showAppleMoreOperate(context, list);
}

void _showAppleMoreOperate(BuildContext context, List<Widget> list) {
  showCupertinoModalPopup<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      return _AppleActionSheet(list: list);
    },
  );
}

class _AppleActionSheet extends StatelessWidget {
  final List<Widget> list;

  const _AppleActionSheet({required this.list});

  @override
  Widget build(BuildContext context) {
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: _sheetBlurSigma);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: effectiveSigma,
                sigmaY: effectiveSigma,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    ...list,
                    Container(
                      width: double.infinity,
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.black.withValues(alpha: 0.1),
                    ),
                    CupertinoSheer(title: "取消", onTap: () {}),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showCyberMoreOperate(BuildContext context, List<Widget> list) {
  showCupertinoModalPopup<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      return _CyberActionSheet(list: list);
    },
  );
}

class _CyberActionSheet extends StatelessWidget {
  final List<Widget> list;

  const _CyberActionSheet({required this.list});

  @override
  Widget build(BuildContext context) {
    final effectiveSigma = SpUtil.getDouble(spCardBlurSigma, defValue: _sheetBlurSigma);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: effectiveSigma,
                sigmaY: effectiveSigma,
              ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: CyberColors.cyan.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  ...list,
                  Container(
                    width: double.infinity,
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: CyberColors.borderGlow.withValues(alpha: 0.25),
                  ),
                  CupertinoSheer(title: "取消", onTap: () {}),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
