import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/repository/navigation_repository.dart';

class ResponsiveWidget extends StatelessWidget {
  final Widget? smallScreen;
  final Widget mediumScreen;
  final Widget? largeScreen;
  final Widget? extraLargeScreen;

  const ResponsiveWidget(
      {super.key, this.smallScreen, required this.mediumScreen, this.largeScreen, this.extraLargeScreen});

  // Device Size

  static const kSmallDeviceMinSize = 0;
  static const kSmallDeviceMaxSize = 599;
  static const kMediumDeviceMinSize = 600;
  static const kMediumDeviceMaxSize = 839;
  static const kLargeDeviceMinSize = 840;
  static const kLargeDeviceMaxSize = 1439;
  static const kExtraLargeDeviceMinSize = 1440;
// medium size is 800,large is 1200
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth <= kSmallDeviceMaxSize) {
        return smallScreen ?? mediumScreen;
      } else if (constraints.maxWidth >= kMediumDeviceMinSize && constraints.maxWidth <= kMediumDeviceMaxSize) {
        return mediumScreen;
      } else if (constraints.maxWidth >= kLargeDeviceMinSize && constraints.maxWidth <= kLargeDeviceMaxSize) {
        return largeScreen ?? mediumScreen;
      } else if (constraints.maxWidth >= kExtraLargeDeviceMinSize) {
        return extraLargeScreen ?? largeScreen ?? mediumScreen;
      } else {
        return largeScreen ?? mediumScreen;
      }
    });
  }

  static BuildContext get _context => NavigationRepository.navKey.currentContext!;
  static bool isExtraLargeScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kExtraLargeDeviceMinSize;
  }

  static bool isLargeScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kLargeDeviceMinSize && width <= kLargeDeviceMaxSize;
  }

  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kMediumDeviceMinSize && width <= kMediumDeviceMaxSize;
  }

  static bool isSmallScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kSmallDeviceMinSize && width <= kSmallDeviceMaxSize;
  }

  /// Get return the object based on the screen size
  static T getResponsiveObject<T>({
    T? small,
    required T medium,
    T? large,
    T? extraLarge,
  }) {
    if (isExtraLargeScreen(_context)) {
      return extraLarge ?? medium;
    } else if (isLargeScreen(_context)) {
      return large ?? medium;
    } else if (isMediumScreen(_context)) {
      return medium;
    } else {
      return small ?? medium;
    }
  }

  // static bool isTabletLandscape(BuildContext context) {
  //   return isMediumScreen(context) && MediaQuery.of(context).orientation == Orientation.landscape;
  // }

  // static bool isMobileLandscape(BuildContext context) {
  //   return isMediumScreen(context) && MediaQuery.of(context).orientation == Orientation.landscape;
  // }
}
