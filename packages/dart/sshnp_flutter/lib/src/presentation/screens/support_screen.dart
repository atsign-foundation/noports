import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/presentation/widgets/support_screen_widgets/support_screen_desktop_view.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/responsive_widget.dart';

import '../widgets/support_screen_widgets/support_screen_mobile_view.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);
  static String route = 'supportScreen';

  @override
  Widget build(BuildContext context) {
    return const ResponsiveWidget(
      mobileScreen: SupportScreenMobileView(),
      largeScreen: SupportScreenDesktopView(),
      tabletScreen: SupportScreenDesktopView(),
    );
  }
}
