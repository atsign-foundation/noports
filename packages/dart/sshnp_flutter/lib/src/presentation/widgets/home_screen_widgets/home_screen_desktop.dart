import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../utility/sizes.dart';
import '../navigation/app_navigation_rail.dart';
import 'home_screen_actions/home_screen_actions.dart';
import 'home_screen_core.dart';

class HomeScreenDesktop extends StatelessWidget {
  const HomeScreenDesktop({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      body: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppNavigationRail(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: Sizes.p36, right: Sizes.p36, top: Sizes.p21),
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
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          Text(
                            strings.currentConnectionsDescription,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const HomeScreenActions(),
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
