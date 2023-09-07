import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sshnp_gui/src/controllers/sshnp_config_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/actions/profile_actions.dart';
import 'package:sshnp_gui/src/presentation/widgets/home_screen_table/home_screen_table_header.dart';
import 'package:sshnp_gui/src/presentation/widgets/home_screen_table/home_screen_table_text.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/profile_bar.dart';

import '../../utils/sizes.dart';
import '../widgets/navigation/app_navigation_rail.dart';

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

    final strings = AppLocalizations.of(context)!;
    final profileNames = ref.watch(paramsListController);

    return Scaffold(
      body: SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SvgPicture.asset(
                    'assets/images/noports_light.svg',
                  ),
                  gapH24,
                  Text(strings.availableConnections),
                  profileNames.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, s) => Text(e.toString()),
                    data: (profiles) {
                      if (profiles.isEmpty) {
                        return const Text('No SSHNP Configurations Found');
                      }
                      return Expanded(
                        child: ListView(
                          children: profiles.map((profileName) => ProfileBar(profileName)).toList(),
                        ),
                      );
                    },
                  )
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreenBodyWrapper extends StatelessWidget {
  const HomeScreenBodyWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
