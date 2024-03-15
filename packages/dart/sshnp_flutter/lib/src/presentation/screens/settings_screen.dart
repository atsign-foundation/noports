import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/presentation/widgets/settings_screen_widgets/settings_screen_desktop.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/responsive_widget.dart';

import '../widgets/settings_screen_widgets/settings_screen_mobile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  static String route = 'settingsScreen';

  @override
  Widget build(BuildContext context) {
    return const ResponsiveWidget(
        mobileScreen: SettingsMobileView(), largeScreen: SettingsDesktopView(), tabletScreen: SettingsDesktopView());
  }
}
