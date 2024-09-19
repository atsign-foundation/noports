import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/app_color.dart';

import '../styles/sizes.dart';

class CustomContainer extends StatelessWidget {
  const CustomContainer({
    required this.child,
    required this.color,
    required this.padding,
    super.key,
  });

  const CustomContainer.background({required this.child, super.key})
      : color = AppColor.surfaceColor,
        padding = Sizes.p16;

  const CustomContainer.foreground({required this.child, super.key})
      : color = Colors.white,
        padding = 0;

  final Widget child;
  final Color color;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: child,
    );
  }
}
