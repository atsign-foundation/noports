import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sshnp_flutter/src/controllers/package_info_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/responsive_widget.dart';

import '../widgets/home_screen_widgets/home_screen_desktop.dart';
import '../widgets/home_screen_widgets/home_screen_mobile.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(packageInfo.notifier).state = await PackageInfo.fromPlatform();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ResponsiveWidget(
      smallScreen: HomeScreenMobile(),
      mediumScreen: HomeScreenDesktop(),
      largeScreen: HomeScreenDesktop(),
    );
  }
}
