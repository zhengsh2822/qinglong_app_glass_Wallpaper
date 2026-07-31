import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';



class LoadingWidget extends StatelessWidget {
  final Color color;
  final double size;

  const LoadingWidget({
    super.key,
    this.color = const Color(0xffc8c9cc),
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return LoadingAnimationWidget.staggeredDotsWave(
      color: color,
      size: size,
    );
  }
}
