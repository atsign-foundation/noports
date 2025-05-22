import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/app_color.dart';

import '../styles/sizes.dart';

class CustomContainer extends StatelessWidget {
  const CustomContainer({
    required this.child,
    required this.color,
    required this.padding,
    required this.width,
    this.decorationImage,
    this.height,
    super.key,
  });

  const CustomContainer.background({required this.child, this.width, super.key})
      : color = AppColor.surfaceColor,
        padding = Sizes.p16,
        height = null,
        decorationImage = null;

  const CustomContainer.foreground(
      {required this.child, this.width, super.key, this.padding = 0, this.decorationImage, this.height})
      : color = Colors.white;

  final Widget child;
  final Color color;
  final double padding;
  final double? width;
  final double? height;
  final DecorationImage? decorationImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      width: width,
      height: height,
      decoration: BoxDecoration(
        image: decorationImage,
        color: color,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: child,
    );
  }
}
