import 'package:flutter/material.dart';

/// Constant sizes to be used in the app (paddings, gaps, rounded corners etc.)
class Sizes {
  static const p2 = 2.0;
  static const p3 = 3.0;
  static const p4 = 4.0;
  static const p5 = 5.0;
  static const p8 = 8.0;
  static const p10 = 10.0;
  static const p12 = 12.0;
  static const p14 = 14.0;
  static const p16 = 16.0;
  static const p18 = 18.0;
  static const p20 = 20.0;
  static const p21 = 21.0;
  static const p28 = 28.0;
  static const p24 = 24.0;
  static const p26 = 26.0;
  static const p30 = 30.0;
  static const p32 = 32.0;
  static const p34 = 34.0;
  static const p36 = 36.0;
  static const p38 = 38.0;
  static const p40 = 40.0;
  static const p46 = 46.0;
  static const p48 = 48.0;
  // static const p42 = 42.0;
  static const p60 = 60.0;
  static const p99 = 99.0;
  static const p103 = 103.0;
  static const p163 = 163.0;
  static const p185 = 185.0;
  static const p233 = 233.0;
  static const p244 = 244.0;
  static const p247 = 247.0;
  static const p286 = 286.0;
  static const p320 = 320.0;
  static const p460 = 460.0;
}

const gap0 = SizedBox();

/// Constant gap widths
const gapW8 = SizedBox(width: Sizes.p8);
const gapW12 = SizedBox(width: Sizes.p12);
const gapW16 = SizedBox(width: Sizes.p16);
// const gapW20 = SizedBox(width: Sizes.p20);
// const gapW24 = SizedBox(width: Sizes.p24);
// const gapW32 = SizedBox(width: Sizes.p32);
const gapW34 = SizedBox(width: Sizes.p34);
const gapW38 = SizedBox(width: Sizes.p38);
// const gapW48 = SizedBox(width: Sizes.p48);
// const gapW64 = SizedBox(width: Sizes.p64);

// /// Constant gap heights
const gapH4 = SizedBox(height: Sizes.p4);
const gapH8 = SizedBox(height: Sizes.p8);
const gapH10 = SizedBox(height: Sizes.p10);
const gapH12 = SizedBox(height: Sizes.p12);
const gapH14 = SizedBox(height: Sizes.p14);
const gapH16 = SizedBox(height: Sizes.p16);
const gapH20 = SizedBox(height: Sizes.p20);
const gapH24 = SizedBox(height: Sizes.p24);
const gapH30 = SizedBox(height: Sizes.p30);
// const gapH32 = SizedBox(height: Sizes.p32);
const gapH36 = SizedBox(height: Sizes.p36);
const gapH40 = SizedBox(height: Sizes.p40);
const gapH46 = SizedBox(height: Sizes.p46);
const gapH60 = SizedBox(height: Sizes.p60);

const kWindowsMinWindowSize = Size(684, 541);

/// A class defined to get dimensions for the screen size displayed,
/// using the proportion of the designed screen size.
class SizeConfig {
  SizeConfig._();

  static final SizeConfig _instance = SizeConfig._();

  factory SizeConfig() => _instance;
  late MediaQueryData _mediaQueryData;
  late double screenWidth;
  late double screenHeight;
  late double blockSizeHorizontal;
  late double blockSizeVertical;
  late double deviceTextFactor;

  late double _safeAreaHorizontal;
  late double _safeAreaVertical;
  late double safeBlockHorizontal;
  late double safeBlockVertical;

  double? profileDrawerWidth;
  late double refHeight;
  late double refWidth;

  double textFactor = 1.0;

  bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 700;

  bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 700 && MediaQuery.of(context).size.width < 1200;
  bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1200;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    refHeight = 505;
    refWidth = 671;

    deviceTextFactor = _mediaQueryData.textScaler.scale(20) / 20;

    // print("height is::: $screenHeight");

    if (screenHeight < 1200) {
      blockSizeHorizontal = screenWidth / 100;
      blockSizeVertical = screenHeight / 100;

      _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
      _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
      safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 100;
      safeBlockVertical = (screenHeight - _safeAreaVertical) / 100;
    } else {
      blockSizeHorizontal = screenWidth / 120;
      blockSizeVertical = screenHeight / 120;

      _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
      _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
      safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 120;
      safeBlockVertical = (screenHeight - _safeAreaVertical) / 120;
    }
    if (screenWidth > 700) {
      textFactor = 0.8;
    }
  }

  double getWidthRatio(double val) {
    // if (screenWidth >= 1200 || (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    //   return val;
    // }
    double res = (val / refWidth) * 100;
    double temp = res * blockSizeHorizontal;
    // print("width$temp");

    return temp;
  }

  double getHeightRatio(double val) {
    // if (screenWidth >= 1200 || (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    //   return val;
    // }
    double res = (val / refHeight) * 100;
    double temp = res * blockSizeVertical;
    return temp;
  }

  double getFontRatio(double val) {
    // if (screenWidth >= 1200 || (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    //   return val;
    // }
    double res = (val / refWidth) * 100;
    double temp = 0.0;
    if (screenWidth > screenHeight) {
      temp = res * safeBlockHorizontal + (val * 0.150521609538003) * textFactor;
    } else {
      temp = res * safeBlockVertical + (val * 0.2473919523099851) * textFactor;
    }
    // print('$val,$temp,$refHeight,$refWidth');
    final maxSize = val + Sizes.p4;
    if (temp > maxSize) {
      return maxSize;
    } else {
      return temp;
    }

    // var heightScale = (_mediaQueryData.size.height / refHeight);
    // var widthScale = (_mediaQueryData.size.width / refWidth);

    // if (_mediaQueryData.size.height > refHeight || _mediaQueryData.size.width > refWidth) {
    //   heightScale = heightScale * 0.9;
    //   widthScale = widthScale * 0.9;
    // }
    // return val * heightScale * widthScale;
  }
}

/// A shorthand usage of the functions defined in [SizeConfig].
extension SizeUtils on num {
  double get toWidth => SizeConfig().getWidthRatio(toDouble());

  double get toHeight => SizeConfig().getHeightRatio(toDouble());

  double get toFont => SizeConfig().getFontRatio(toDouble());
}
