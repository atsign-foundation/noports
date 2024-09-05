import 'package:flutter/material.dart';

import '../styles/app_color.dart';
import '../styles/sizes.dart';

class CustomCard extends StatelessWidget {
  const CustomCard({
    required this.child,
    this.height,
    this.width,
    required this.color,
    required this.radiusTopLeft,
    required this.radiusTopRight,
    required this.radiusBottomLeft,
    required this.radiusBottomRight,
    required this.leftPadding,
    required this.rightPadding,
    required this.topPadding,
    required this.bottomPadding,
    super.key,
  });

  const CustomCard.settingsRail({
    required this.child,
    super.key,
  })  : height = Sizes.p436,
        width = Sizes.p202,
        color = Colors.white,
        radiusTopLeft = const Radius.circular(Sizes.p10),
        radiusTopRight = const Radius.circular(Sizes.p10),
        radiusBottomLeft = const Radius.circular(Sizes.p10),
        radiusBottomRight = const Radius.circular(Sizes.p10),
        leftPadding = 0,
        rightPadding = 0,
        topPadding = 0,
        bottomPadding = 0;

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
        leftPadding = Sizes.p10,
        rightPadding = 0,
        topPadding = 0,
        bottomPadding = 0;
  const CustomCard.dashboardContent({
    required this.child,
    super.key,
  })  : height = Sizes.p436,
        width = Sizes.p941,
        color = AppColor.cardColorDark,
        radiusTopLeft = const Radius.circular(Sizes.p20),
        radiusTopRight = const Radius.circular(Sizes.p20),
        radiusBottomLeft = const Radius.circular(Sizes.p20),
        radiusBottomRight = const Radius.circular(Sizes.p20),
        leftPadding = Sizes.p44,
        rightPadding = Sizes.p44,
        topPadding = Sizes.p32,
        bottomPadding = 0;

  const CustomCard.settingsPreview({
    required this.child,
    super.key,
  })  : height = null,
        width = null,
        color = Colors.white,
        radiusTopLeft = const Radius.circular(Sizes.p20),
        radiusTopRight = const Radius.circular(Sizes.p20),
        radiusBottomLeft = const Radius.circular(Sizes.p20),
        radiusBottomRight = const Radius.circular(Sizes.p20),
        leftPadding = Sizes.p10,
        rightPadding = 0,
        topPadding = 0,
        bottomPadding = 0;

  final Widget child;
  final double? height;
  final double? width;
  final Color color;
  final Radius radiusTopLeft;
  final Radius radiusTopRight;
  final Radius radiusBottomLeft;
  final Radius radiusBottomRight;
  final double leftPadding;
  final double rightPadding;
  final double topPadding;
  final double bottomPadding;

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
        padding: EdgeInsets.only(left: leftPadding, right: rightPadding, top: topPadding, bottom: bottomPadding),
        child: child,
      ),
    );
  }
}
