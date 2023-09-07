import 'package:at_backupkey_flutter/at_backupkey_flutter.dart';
import 'package:at_contacts_flutter/services/contact_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/reset_app_button.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repository/navigation_service.dart';
import '../../utils/sizes.dart';
import '../widgets/utility/settings_button.dart';
import '../widgets/utility/switch_atsign.dart';

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
                  // Text(
                  //   ContactService().currentAtsign,
                  //   style: Theme.of(context).textTheme.bodyLarge,
                  // ),
                  // Text(
                  //   ContactService().loggedInUserDetails!.tags!['name'] ?? '',
                  //   style: Theme.of(context).textTheme.displaySmall,
                  // ),
                  // const SizedBox(
                  //   height: 30,
                  // ),
                  // SettingsButton(
                  //   icon: Icons.block_outlined,
                  //   title: 'Blocked Contacts',
                  //   onTap: () {
                  //     Navigator.of(context).pushNamed(CustomBlockedScreen.routeName);
                  //   },
                  // ),
                  const SizedBox(
                    height: 59,
                  ),
                  SettingsButton(
                    icon: Icons.bookmark_outline,
                    title: strings.backupYourKeys,
                    onTap: () {
                      BackupKeyWidget(atsign: ContactService().currentAtsign).showBackupDialog(context);
                    },
                  ),
                  gapH16,
                  SettingsButton(
                    icon: Icons.logout_rounded,
                    title: strings.switchAtsign,
                    onTap: () async {
                      await showModalBottomSheet(
                          context: NavigationService.navKey.currentContext!,
                          builder: (context) => const AtSignBottomSheet());
                    },
                  ),
                  gapH16,
                  const ResetAppButton(),
                  gapH36,
                  SettingsButton(
                    icon: Icons.help_center_outlined,
                    title: strings.faq,
                    onTap: () async {
                      final Uri url = Uri.parse('https://atsign.com/faqs/');
                      if (!await launchUrl(url)) {
                        throw Exception('Could not launch $url');
                      }
                    },
                  ),
                  gapH16,
                  SettingsButton(
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
                  ),
                  gapH16,
                  SettingsButton(
                    icon: Icons.account_balance_wallet_outlined,
                    title: strings.privacyPolicy,
                    onTap: () async {
                      final Uri url = Uri.parse('https://atsign.com/apps/atdatabrowser-privacy-policy/');
                      if (!await launchUrl(url)) {
                        throw Exception('Could not launch $url');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}
