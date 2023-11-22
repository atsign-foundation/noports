import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/contact_tile/contact_list_tile.dart';
import 'package:sshnp_gui/src/presentation/widgets/custom_list_tile.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  static String route = 'settingsScreen';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
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
                          color: kProfileFormCardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GridView.count(childAspectRatio: 202 / 60, crossAxisCount: 2, children: const [
                          CustomListTile.keyManagement(),
                          CustomListTile.backUpYourKey(),
                          CustomListTile.switchAtsign(),
                          CustomListTile.resetAtsign(),
                        ])
                        // child: Row(
                        //   crossAxisAlignment: CrossAxisAlignment.start,
                        //   children: [
                        //     Flexible(child: CustomListTile.keyManagement(onTap: () {
                        //       showDialog(context: context, builder: ((context) => const SshKeyManagementDialog()));
                        //     })),
                        //     // Expanded(child: CustomListTile.deleteYourKey(onTap: () {})),
                        //   ],
                        // ),
                        ),
                  ),

                  // const Center(child: SettingsBackupKeyAction()),
                  // gapH16,
                  // const Center(child: SettingsSwitchAtsignAction()),
                  // gapH16,
                  // const Center(child: SettingsResetAppAction()),
                  // gapH36,
                  // const Center(child: SettingsFaqAction()),
                  // gapH16,
                  // const Center(child: SettingsContactAction()),
                  // gapH16,
                  // const Center(child: SettingsPrivacyPolicyAction()),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}
