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
              padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21, right: Sizes.p36),
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
                  const Row(
                    children: [
                      Flexible(child: CustomListTile.keyManagement()),
                      Flexible(child: CustomListTile.backUpYourKey()),
                    ],
                  ),
                  gapH20,
                  const Divider(
                    color: kProfileFormFieldColor,
                  ),
                  gapH20,
                  const Row(
                    children: [
                      Flexible(child: CustomListTile.switchAtsign()),
                      Flexible(child: CustomListTile.resetAtsign()),
                    ],
                  ),
                  gapH40,
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
