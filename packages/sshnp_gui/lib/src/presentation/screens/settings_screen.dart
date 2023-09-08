import 'package:at_backupkey_flutter/at_backupkey_flutter.dart';
import 'package:at_contacts_flutter/services/contact_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/navigation/app_navigation_rail.dart';
import 'package:sshnp_gui/src/presentation/widgets/settings_actions/settings_actions.dart';
import 'package:sshnp_gui/src/presentation/widgets/settings_actions/settings_action_button.dart';
import 'package:sshnp_gui/src/repository/navigation_repository.dart';
import 'package:sshnp_gui/src/utils/sizes.dart';

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sizes.p20),
                    child: Text(
                      strings.settings,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(
                    height: 59,
                  ),
                  const SettingsBackupKeyAction(),
                  gapH16,
                  const SettingsSwitchAtsignAction(),
                  gapH16,
                  const SettingsResetAppAction(),
                  gapH36,
                  const SettingsFaqAction(),
                  gapH16,
                  const SettingsContactAction(),
                  gapH16,
                  const SettingsPrivacyPolicyAction(),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}
