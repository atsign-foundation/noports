import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_flutter/src/presentation/widgets/settings_screen_widgets/settings_actions/settings_action_button.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsFaqAction extends StatelessWidget {
  const SettingsFaqAction({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SettingsActionButton(
      icon: Icons.help_center_outlined,
      title: strings.faq,
      onTap: () async {
        final Uri url = Uri.parse('https://atsign.com/faqs/');
        if (!await launchUrl(url)) {
          throw Exception('Could not launch $url');
        }
      },
    );
  }
}
