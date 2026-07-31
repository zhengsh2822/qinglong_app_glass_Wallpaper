import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

class ButtonWidget extends StatelessWidget {
  final GestureTapCallback onTap;
  final String? title;
  final bool isDestructive;

  const ButtonWidget({
    super.key,
    required this.onTap,
    this.title,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final primaryColor = ref.watch(themeProvider).primaryColor;
      return GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              gradient: isDestructive
                  ? const LinearGradient(
                      colors: [Color(0xffFF6B6B), Color(0xffEE5A24)],
                    )
                  : LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.85)],
                    ),
              borderRadius: BorderRadius.all(Radius.circular(AppleColors.radiusButton)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                title ?? "提交",
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    });
  }
}
