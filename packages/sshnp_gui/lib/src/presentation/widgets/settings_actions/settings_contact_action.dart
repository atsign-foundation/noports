import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/presentation/widgets/settings_actions/settings_action_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsContactAction extends StatelessWidget {
  const SettingsContactAction({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SettingsActionButton(
      icon: Icons.forum_outlined,
      title: strings.contactUs,
      onTap: () async {
        Uri emailUri = Uri(
          scheme: 'mailto',
          path: 'atDataBrowser@atsign.com',
        );
        if (!await launchUrl(emailUri)) {
          throw Exception('Could not launch $emailUri');
        }
      },
    );
  }
}
