import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/package_info_controller.dart';
import '../../../utility/constants.dart';
import '../../../utility/sizes.dart';
import '../contact_tile/contact_list_tile.dart';
import '../custom_list_tile.dart';
import '../navigation/app_navigation_rail.dart';

class SettingsDesktopView extends ConsumerWidget {
  const SettingsDesktopView({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final packageInfoController = ref.read(packageInfo);
    return Scaffold(
      body: SafeArea(
          child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppNavigationRail(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21),
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sizes.p20),
                    child: Text(
                      strings.settings,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  gapH20,
                  const Text('Account'),
                  gapH16,
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ContactListTile(),
                  ),
                  gapH36,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                        height: 180,
                        width: 540,
                        decoration: BoxDecoration(
                          color: kProfileBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GridView.count(childAspectRatio: 202 / 60, crossAxisCount: 2, children: const [
                          CustomListTile.keyManagement(),
                          CustomListTile.backUpYourKey(),
                          CustomListTile.switchAtsign(),
                          CustomListTile.resetAtsign(),
                        ])),
                  ),
                  Text('App Version ${packageInfoController.version} (${packageInfoController.buildNumber})'),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}
