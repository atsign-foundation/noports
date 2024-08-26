import 'package:flutter/material.dart';

import '../styles/app_color.dart';
import '../styles/sizes.dart';

class CustomCard extends StatelessWidget {
  const CustomCard({
    required this.child,
    required this.height,
    required this.width,
    required this.color,
    required this.radiusTopLeft,
    required this.radiusTopRight,
    required this.radiusBottomLeft,
    required this.radiusBottomRight,
    required this.leftPadding,
    super.key,
  });

  const CustomCard.settingsDashboard({
    required this.child,
    super.key,
  })  : height = Sizes.p436,
        width = Sizes.p202,
        color = Colors.white,
        radiusTopLeft = const Radius.circular(Sizes.p10),
        radiusTopRight = const Radius.circular(Sizes.p10),
        radiusBottomLeft = const Radius.circular(Sizes.p10),
        radiusBottomRight = const Radius.circular(Sizes.p10),
        leftPadding = 0;

  const CustomCard.settingsContent({
    required this.child,
    super.key,
  })  : height = Sizes.p436,
        width = Sizes.p664,
        color = AppColor.cardColorDark,
        radiusTopLeft = Radius.zero,
        radiusTopRight = const Radius.circular(Sizes.p20),
        radiusBottomLeft = Radius.zero,
        radiusBottomRight = const Radius.circular(Sizes.p20),
        leftPadding = Sizes.p10;

  final Widget child;
  final double height;
  final double width;
  final Color color;
  final Radius radiusTopLeft;
  final Radius radiusTopRight;
  final Radius radiusBottomLeft;
  final Radius radiusBottomRight;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: radiusTopLeft,
          topRight: radiusTopRight,
          bottomLeft: radiusBottomLeft,
          bottomRight: radiusBottomRight,
        ),
      ),
      height: height,
      width: width,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: child,
      ),
    );
  }
}
