import 'package:at_contacts_flutter/services/contact_service.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/routes.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/onboarding/onboarding.dart';
import '../styles/sizes.dart';
import 'custom_snack_bar.dart';

class CustomTextButton extends StatelessWidget {
  const CustomTextButton({
    super.key,
    required this.iconData,
    required this.title,
    required this.type,
  });

  const CustomTextButton.email({
    super.key,
  })  : iconData = Icons.email_outlined,
        title = 'Email',
        type = CustomListTileType.email;

  const CustomTextButton.discord({
    super.key,
  })  : iconData = Icons.discord,
        title = 'Discord',
        type = CustomListTileType.discord;

  const CustomTextButton.faq({
    super.key,
  })  : iconData = Icons.help_center_outlined,
        title = 'FAQ',
        type = CustomListTileType.faq;

  const CustomTextButton.privacyPolicy({
    super.key,
  })  : iconData = Icons.account_balance_wallet_outlined,
        title = 'Privacy Policy',
        type = CustomListTileType.privacyPolicy;

  // const CustomListTile.switchAtsign(
  //     {this.iconData = Icons.switch_account_outlined,
  //     this.title = 'Switch atsign',
  //     this.type = CustomListTileType.switchAtsign,
  //     super.key});

  const CustomTextButton.backUpYourKey(
      {this.iconData = Icons.bookmark_outline,
      this.title = 'Back Up Your Keys',
      this.type = CustomListTileType.backupYourKey,
      super.key});

  const CustomTextButton.resetAtsign(
      {this.iconData = Icons.rotate_right,
      this.title = 'Reset App',
      this.type = CustomListTileType.resetAtsign,
      super.key});

  const CustomTextButton.feedback(
      {this.iconData = Icons.feedback_outlined,
      this.title = 'Feedback',
      this.type = CustomListTileType.feedback,
      super.key});

  final IconData iconData;
  final String title;
  final CustomListTileType type;

  @override
  Widget build(BuildContext context) {
    // SizeConfig().init(context);
    // final bodyMedium = Theme.of(context).textTheme.bodyMedium!;
    // final bodySmall = Theme.of(context).textTheme.bodySmall!;
    Future<void> onTap() async {
      switch (type) {
        case CustomListTileType.email:
          Uri emailUri = Uri(
            scheme: 'mailto',
            path: 'info@noports.com',
          );
          if (!await launchUrl(emailUri)) {
            CustomSnackBar.notification(content: 'No email client available');
          }
          break;
        case CustomListTileType.discord:
          final Uri url = Uri.parse('https://discord.gg/atsign-778383211214536722');
          if (!await launchUrl(url)) {
            throw Exception('Could not launch $url');
          }
          break;
        case CustomListTileType.faq:
          final Uri url = Uri.parse('https://docs.noports.com/ssh-no-ports/faq');
          if (!await launchUrl(url)) {
            throw Exception('Could not launch $url');
          }
          break;
        case CustomListTileType.privacyPolicy:
          final Uri url = Uri.parse('https://atsign.com/privacy-policy/');
          if (!await launchUrl(url)) {
            throw Exception('Could not launch $url');
          }
          break;
        // case CustomListTileType.switchAtsign:
        //   if (context.mounted) {
        //     await showModalBottomSheet(context: context, builder: (context) => const SwitchAtSignBottomSheet());
        //   }
        //   break;
        case CustomListTileType.backupYourKey:
          if (context.mounted) {
            BackupKeyWidget(atsign: ContactService().currentAtsign).showBackupDialog(context);
          }
          break;
        case CustomListTileType.resetAtsign:
          final futurePreference = await loadAtClientPreference();
          if (context.mounted) {
            final result = await AtOnboarding.reset(
              context: context,
              config: AtOnboardingConfig(
                atClientPreference: futurePreference,
                rootEnvironment: RootEnvironment.Testing,
                domain: Constants.rootDomain,
                appAPIKey: Constants.appAPIKey,
              ),
            );
            final OnboardingService onboardingService = OnboardingService.getInstance();

            if (context.mounted && result == AtOnboardingResetResult.success) {
              onboardingService.setAtsign = null;
              Navigator.of(context).pushNamed(Routes.onboarding);
            }
          }
          break;

        case CustomListTileType.feedback:
          final emailUri = Uri(
            scheme: 'mailto',
            path: 'info@noports.com',
            query: 'subject=SSH No Ports Desktop Feedback',
          );

          if (!await launchUrl(emailUri)) {
            CustomSnackBar.notification(content: 'No email client available');
          }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: Sizes.p30, right: Sizes.p30, bottom: Sizes.p10),
      child: TextButton.icon(
        label: Text(
          title,
          // style: bodyMedium.copyWith(fontSize: bodyMedium.fontSize!.toFont),
        ),
        onPressed: onTap,
        icon: Icon(
          iconData,
        ),
      ),
    );
  }
}

enum CustomListTileType {
  email,
  discord,
  faq,
  privacyPolicy,
  // switchAtsign,
  backupYourKey,
  resetAtsign,
  feedback,
}
