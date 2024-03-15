import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/responsive_widget.dart';

import '../widgets/profile_screen_widgets/profile_editor_screen_desktop_view.dart';
import '../widgets/profile_screen_widgets/profile_editor_screen_mobile_view.dart';

// * Once the onboarding process is completed you will be taken to this screen
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return const ResponsiveWidget(
        mobileScreen: ProfileEditorScreenMobileView(),
        largeScreen: ProfileEditorScreenDesktopView(),
        tabletScreen: ProfileEditorScreenDesktopView());
  }
}
