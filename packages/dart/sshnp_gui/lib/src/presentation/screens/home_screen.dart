import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/responsive_widget.dart';

import '../widgets/home_screen_widgets/home_screen_desktop.dart';
import '../widgets/home_screen_widgets/home_screen_mobile.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below

    return const ResponsiveWidget(
      mobileScreen: HomeScreenMobile(),
      tabletScreen: HomeScreenDesktop(),
      largeScreen: HomeScreenDesktop(),
    );
  }
}
