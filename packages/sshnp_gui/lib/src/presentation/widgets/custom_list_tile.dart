import 'package:at_app_flutter/at_app_flutter.dart';
import 'package:at_contacts_flutter/services/contact_service.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/presentation/screens/onboarding_screen.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_actions/settings_switch_atsign_action.dart';
import 'ssh_key_management/ssh_key_management_dialog.dart';

class CustomListTile extends StatelessWidget {
  const CustomListTile({
    super.key,
    required this.iconData,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.tileColor,
  });

  const CustomListTile.email(
      {this.iconData = Icons.email_outlined,
      this.title = 'Email',
      this.subtitle = 'Guranteed quick response',
      this.type = CustomListTileType.email,
      this.tileColor = kProfileBackgroundColor,
      Key? key})
      : super(key: key);
  const CustomListTile.discord({
    this.iconData = Icons.discord,
    this.title = 'Discord',
    this.subtitle = 'Join our server for help',
    this.type = CustomListTileType.discord,
    this.tileColor = kProfileBackgroundColor,
    Key? key,
  }) : super(key: key);
  const CustomListTile.faq({
    this.iconData = Icons.help_center_outlined,
    this.title = 'FAQ',
    this.subtitle = 'Frequently asked questions',
    this.type = CustomListTileType.faq,
    this.tileColor = kProfileBackgroundColor,
    Key? key,
  }) : super(key: key);
  const CustomListTile.privacyPolicy({
    this.iconData = Icons.account_balance_wallet_outlined,
    this.title = 'FAQ',
    this.subtitle = 'Frequently asked questions',
    this.type = CustomListTileType.faq,
    this.tileColor = kProfileBackgroundColor,
    Key? key,
  }) : super(key: key);
  const CustomListTile.keyManagement(
      {this.iconData = Icons.vpn_key_outlined,
      this.title = 'SSH Key Management',
      this.subtitle = 'Edit, add and delete SSH Keys',
      this.type = CustomListTileType.sshKeyManagement,
      this.tileColor = kProfileBackgroundColor,
      Key? key})
      : super(key: key);
  const CustomListTile.switchAtsign(
      {this.iconData = Icons.switch_account_outlined,
      this.title = 'Switch atsign',
      this.subtitle = 'Edit, add and delete SSH Keys',
      this.type = CustomListTileType.sshKeyManagement,
      this.tileColor = kProfileBackgroundColor,
      Key? key})
      : super(key: key);
  const CustomListTile.backUpYourKey(
      {this.iconData = Icons.bookmark_outline,
      this.title = 'Backup Your Keys',
      this.subtitle = 'Save a pair of your atKeys',
      this.type = CustomListTileType.resetAtsign,
      this.tileColor = kProfileBackgroundColor,
      Key? key})
      : super(key: key);
  const CustomListTile.resetAtsign(
      {this.iconData = Icons.rotate_right,
      this.title = 'Reset App',
      this.subtitle = 'App will be reset and you will be logged out',
      this.type = CustomListTileType.resetAtsign,
      this.tileColor = kProfileBackgroundColor,
      Key? key})
      : super(key: key);

  final IconData iconData;
  final String title;
  final String subtitle;

  final CustomListTileType type;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    Future<void> onTap() async {
      switch (type) {
        case CustomListTileType.email:
          Uri emailUri = Uri(
            scheme: 'mailto',
            path: 'info@noports.com',
          );
          if (!await launchUrl(emailUri)) {
            throw Exception('Could not launch $emailUri');
          }
          break;
        case CustomListTileType.discord:
          final Uri url = Uri.parse('https://discord.gg/atsign-778383211214536722');
          if (!await launchUrl(url)) {
            throw Exception('Could not launch $url');
          }
          break;
        case CustomListTileType.faq:
          final Uri url = Uri.parse('https://atsign.com/faqs/');
          if (!await launchUrl(url)) {
            throw Exception('Could not launch $url');
          }
          break;
        case CustomListTileType.privacyPolicy:
          final Uri url = Uri.parse('https://atsign.com/apps/atdatabrowser-privacy-policy/');
          if (!await launchUrl(url)) {
            throw Exception('Could not launch $url');
          }
          break;
        case CustomListTileType.sshKeyManagement:
          if (context.mounted) {
            showDialog(context: context, builder: ((context) => const SshKeyManagementDialog()));
          }
          break;
        case CustomListTileType.switchAtsign:
          if (context.mounted) {
            await showModalBottomSheet(context: context, builder: (context) => const SwitchAtSignBottomSheet());
          }
          break;
        case CustomListTileType.backupYourKey:
          if (context.mounted) {
            BackupKeyWidget(atsign: ContactService().currentAtsign).showBackupDialog(context);
          }
          break;
        case CustomListTileType.resetAtsign:
          if (context.mounted) {
            AtOnboarding.reset(
              context: context,
              config: AtOnboardingConfig(
                atClientPreference: await loadAtClientPreference(),
                rootEnvironment: AtEnv.rootEnvironment,
                domain: AtEnv.rootDomain,
                appAPIKey: AtEnv.appApiKey,
              ),
            );
          }
          break;
      }
    }

    return ListTile(
      leading: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: kIconColorBackground),
        onPressed: onTap,
        child: Icon(
          iconData,
          color: kIconColorDark,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: kTextColorDark),
      ),
      onTap: () async {
        await onTap();
      },
      tileColor: tileColor,
    );
  }
}

enum CustomListTileType {
  email,
  discord,
  faq,
  privacyPolicy,
  sshKeyManagement,
  switchAtsign,
  backupYourKey,
  resetAtsign,
}
