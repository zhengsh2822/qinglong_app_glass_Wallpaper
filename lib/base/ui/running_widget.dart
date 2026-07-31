import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';

class RunningWidget extends ConsumerWidget {
  const RunningWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final color =
        isCyber ? CyberColors.cyan : ref.watch(themeProvider).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color, width: 1),
        boxShadow:
            isCyber
                ? [
                  BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
                ]
                : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingWidget(color: color, size: 12),
          const SizedBox(width: 3),
          Text(
            "运行中",
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontFamily: isCyber ? CyberColors.monoFont : null,
            ),
          ),
        ],
      ),
    );
  }
}
