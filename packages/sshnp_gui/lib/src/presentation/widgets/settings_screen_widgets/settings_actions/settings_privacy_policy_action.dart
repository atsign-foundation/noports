import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/settings_screen_widgets/settings_actions/settings_action_button.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPrivacyPolicyAction extends StatelessWidget {
  const SettingsPrivacyPolicyAction({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SettingsActionButton(
      icon: Icons.account_balance_wallet_outlined,
      title: strings.privacyPolicy,
      onTap: () async {
        final Uri url = Uri.parse('https://atsign.com/apps/atdatabrowser-privacy-policy/');
        if (!await launchUrl(url)) {
          throw Exception('Could not launch $url');
        }
      },
    );
  }
}
