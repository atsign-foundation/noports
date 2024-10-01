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
    required this.bottomBorderSide,
    super.key,
  });

  const CustomCard.settingsRail({
    required this.child,
    this.height = Sizes.p436,
    this.width = Sizes.p202,
    super.key,
  })  : color = Colors.white,
        radiusTopLeft = const Radius.circular(Sizes.p10),
        radiusTopRight = const Radius.circular(Sizes.p10),
        radiusBottomLeft = const Radius.circular(Sizes.p10),
        radiusBottomRight = const Radius.circular(Sizes.p10),
        leftPadding = 0,
        rightPadding = 0,
        topPadding = 0,
        bottomPadding = 0,
        bottomBorderSide = BorderSide.none;

  const CustomCard.settingsContent({
    required this.child,
    this.height = Sizes.p470,
    this.width = Sizes.p664,
    super.key,
  })  : color = AppColor.cardColorDark,
        radiusTopLeft = Radius.zero,
        radiusTopRight = const Radius.circular(Sizes.p20),
        radiusBottomLeft = Radius.zero,
        radiusBottomRight = const Radius.circular(Sizes.p20),
        leftPadding = Sizes.p10,
        rightPadding = 0,
        topPadding = 0,
        bottomPadding = 0,
        bottomBorderSide = BorderSide.none;
  const CustomCard.profileFormContent({
    required this.child,
    this.height = Sizes.p500,
    super.key,
  })  : width = null,
        color = AppColor.cardColorDark,
        radiusTopLeft = const Radius.circular(Sizes.p20),
        radiusTopRight = const Radius.circular(Sizes.p20),
        radiusBottomLeft = const Radius.circular(Sizes.p20),
        radiusBottomRight = const Radius.circular(Sizes.p20),
        leftPadding = Sizes.p10,
        rightPadding = 0,
        topPadding = Sizes.p30,
        bottomPadding = Sizes.p30,
        bottomBorderSide = BorderSide.none;
  const CustomCard.dashboardContent({
    required this.child,
    this.height = Sizes.p500,
    this.width = Sizes.p941,
    super.key,
  })  : color = AppColor.cardColorDark,
        radiusTopLeft = const Radius.circular(Sizes.p20),
        radiusTopRight = const Radius.circular(Sizes.p20),
        radiusBottomLeft = const Radius.circular(Sizes.p20),
        radiusBottomRight = const Radius.circular(Sizes.p20),
        leftPadding = Sizes.p44,
        rightPadding = Sizes.p44,
        topPadding = Sizes.p32,
        bottomPadding = 0,
        bottomBorderSide = BorderSide.none;

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
        bottomPadding = 0,
        bottomBorderSide = BorderSide.none;

  const CustomCard.profile({
    required this.child,
    super.key,
  })  : height = null,
        width = null,
        color = Colors.white,
        radiusTopLeft = const Radius.circular(0),
        radiusTopRight = const Radius.circular(0),
        radiusBottomLeft = const Radius.circular(0),
        radiusBottomRight = const Radius.circular(0),
        leftPadding = Sizes.p10,
        rightPadding = 0,
        topPadding = 0,
        bottomPadding = 0,
        bottomBorderSide = const BorderSide(
          color: AppColor.dividerColor,
        );
  const CustomCard.profileHeader({
    required this.child,
    super.key,
  })  : height = null,
        width = null,
        color = Colors.white54,
        radiusTopLeft = const Radius.circular(Sizes.p10),
        radiusTopRight = const Radius.circular(Sizes.p10),
        radiusBottomLeft = const Radius.circular(0),
        radiusBottomRight = const Radius.circular(0),
        leftPadding = Sizes.p10,
        rightPadding = 0,
        topPadding = 0,
        bottomPadding = 0,
        bottomBorderSide = const BorderSide(
          color: AppColor.dividerColor,
        );

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
  final BorderSide bottomBorderSide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border(bottom: bottomBorderSide),
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
