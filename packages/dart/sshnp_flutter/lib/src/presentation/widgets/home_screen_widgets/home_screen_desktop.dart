import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/config_controller.dart';
import '../../../utility/sizes.dart';
import '../navigation/app_navigation_rail.dart';
import 'home_screen_actions/home_screen_actions.dart';
import 'home_screen_core.dart';

class HomeScreenDesktop extends ConsumerWidget {
  const HomeScreenDesktop({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SizeConfig().init(context);
    final strings = AppLocalizations.of(context)!;
    final headlineLarge = Theme.of(context).textTheme.headlineLarge!;
    final bodySmall = Theme.of(context).textTheme.bodySmall!;
    final profileNames = ref.watch(configListController);

    return Scaffold(
      body: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppNavigationRail(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: Sizes.p36, right: Sizes.p36, top: Sizes.p21, bottom: Sizes.p21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.connectionProfiles,
                            style: headlineLarge.copyWith(fontSize: headlineLarge.fontSize!.toFont),
                          ),
                          Text(
                            strings.currentConnectionsDescription,
                            style: bodySmall.copyWith(fontSize: bodySmall.fontSize!.toFont),
                          ),
                        ],
                      ),
                      profileNames.value?.isNotEmpty == true ? const HomeScreenActions() : gapH8
                    ],
                  ),
                  gapH8,
                  const Expanded(child: HomeScreenCore())
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
