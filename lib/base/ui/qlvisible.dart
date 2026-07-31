import 'dart:io' show Platform;

import 'package:flutter/material.dart';



class QlVisible extends StatelessWidget {
  final Widget child;
  final Widget? childReplace;

  const QlVisible({
    super.key,
    required this.child,
    this.childReplace,
  });

  @override
  Widget build(BuildContext context) {
    if (childReplace != null && Platform.isAndroid) return childReplace!;
    return Visibility(
      visible: Platform.isIOS,
      child: child,
    );
  }
}
