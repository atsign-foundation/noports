import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/presentation/widgets/terminal_screen_widgets/terminal_screen_desktop_view.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/responsive_widget.dart';

import '../widgets/terminal_screen_widgets/terminal_screen_mobile_view.dart';

// * Once the onboarding process is completed you will be taken to this screen
class TerminalScreen extends StatelessWidget {
  const TerminalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ResponsiveWidget(
        mobileScreen: TerminalScreenMobileView(),
        tabletScreen: TerminalScreenDesktopView(),
        largeScreen: TerminalScreenDesktopView());
  }
}
