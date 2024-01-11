import 'package:at_contacts_flutter/services/contact_service.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/settings_screen_widgets/settings_actions/settings_action_button.dart';

class SettingsBackupKeyAction extends StatelessWidget {
  const SettingsBackupKeyAction({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SettingsActionButton(
      icon: Icons.bookmark_outline,
      title: strings.backupYourKeys,
      onTap: () {
        BackupKeyWidget(atsign: ContactService().currentAtsign).showBackupDialog(context);
      },
    );
  }
}
