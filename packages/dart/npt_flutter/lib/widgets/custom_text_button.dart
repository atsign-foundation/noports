import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/pages/loading_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:url_launcher/url_launcher.dart';

import '../styles/sizes.dart';
import 'custom_snack_bar.dart';

class CustomTextButton extends StatelessWidget {
  const CustomTextButton({
    super.key,
    required this.iconData,
    required this.type,
  });

  const CustomTextButton.email({
    super.key,
  })  : iconData = Icons.email_outlined,
        type = CustomListTileType.email;

  const CustomTextButton.discord({
    super.key,
  })  : iconData = Icons.discord,
        type = CustomListTileType.discord;

  const CustomTextButton.faq({
    super.key,
  })  : iconData = Icons.help_center_outlined,
        type = CustomListTileType.faq;

  const CustomTextButton.privacyPolicy({
    super.key,
  })  : iconData = Icons.account_balance_wallet_outlined,
        type = CustomListTileType.privacyPolicy;

  const CustomTextButton.backUpYourKey(
      {this.iconData = Icons.bookmark_outline, this.type = CustomListTileType.backupYourKey, super.key});

  const CustomTextButton.resetAtsign(
      {this.iconData = Icons.rotate_right, this.type = CustomListTileType.resetAtsign, super.key});
  const CustomTextButton.signOut(
      {this.iconData = Icons.logout_outlined, this.type = CustomListTileType.signOut, super.key});

  const CustomTextButton.feedback(
      {this.iconData = Icons.feedback_outlined, this.type = CustomListTileType.feedback, super.key});

  final IconData iconData;

  final CustomListTileType type;

  @override
  Widget build(BuildContext context) {
    // SizeConfig().init(context);
    // final bodyMedium = Theme.of(context).textTheme.bodyMedium!;
    // final bodySmall = Theme.of(context).textTheme.bodySmall!;
    final strings = AppLocalizations.of(context)!;
    Future<void> onTap({String? rootDomain}) async {
      switch (type) {
        case CustomListTileType.email:
          Uri emailUri = Uri(
            scheme: 'mailto',
            path: 'info@noports.com',
          );
          if (!await launchUrl(emailUri)) {
            CustomSnackBar.notification(content: strings.noEmailClientAvailable);
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
        case CustomListTileType.backupYourKey:
          if (context.mounted) {
            context.read<BackupKeyCubit>().backUpKeys();
          }
          break;
        case CustomListTileType.resetAtsign:
          final futurePreference = await AtClientMethods.loadAtClientPreference(rootDomain!);
          final apiKey = await Constants.appAPIKey;
          if (context.mounted) {
            final result = await AtOnboarding.reset(
              context: context,
              config: AtOnboardingConfig(
                atClientPreference: futurePreference,
                rootEnvironment: RootEnvironment.Testing,
                domain: rootDomain,
                appAPIKey: apiKey,
              ),
            );
            final OnboardingService onboardingService = OnboardingService.getInstance();

            if (context.mounted && result == AtOnboardingResetResult.success) {
              onboardingService.setAtsign = null;
              Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                Routes.onboarding,
                (route) => false,
              );
            }
          }
          break;

        case CustomListTileType.feedback:
          final emailUri = Uri(
            scheme: 'mailto',
            path: 'info@noports.com',
            query: 'subject=No Port Desktop Feedback',
          );

          if (!await launchUrl(emailUri)) {
            CustomSnackBar.notification(content: strings.noEmailClientAvailable);
          }
          break;

        case CustomListTileType.signOut:
          wrapperNav.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoadingPage()),
            (route) => false,
          );
          await preSignout();
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
              Routes.onboarding,
              (route) => false,
            );
          }
          break;
      }
    }

    String getTitle(AppLocalizations strings) {
      switch (type) {
        case CustomListTileType.email:
          return strings.email;
        case CustomListTileType.discord:
          return strings.discord;
        case CustomListTileType.faq:
          return strings.faq;
        case CustomListTileType.privacyPolicy:
          return strings.privacyPolicy;
        // case CustomListTileType.switchAtsign:
        //   return strings.switchAtsign;
        case CustomListTileType.backupYourKey:
          return strings.backupYourKey;
        case CustomListTileType.resetAtsign:
          return strings.resetAtsign;
        case CustomListTileType.feedback:
          return strings.feedback;
        case CustomListTileType.signOut:
          return strings.signout;
      }
    }

    if (type == CustomListTileType.resetAtsign) {
      return BlocBuilder<OnboardingCubit, AtsignInformation>(builder: (context, atsignInformation) {
        return Padding(
          padding: const EdgeInsets.only(left: Sizes.p30, right: Sizes.p30, bottom: Sizes.p10),
          child: TextButton.icon(
            label: Text(getTitle(strings)),
            onPressed: () {
              onTap(rootDomain: atsignInformation.rootDomain);
            },
            icon: Icon(
              iconData,
            ),
          ),
        );
      });
    }
    return Padding(
      padding: const EdgeInsets.only(left: Sizes.p30, right: Sizes.p30, bottom: Sizes.p10),
      child: TextButton.icon(
        label: Text(getTitle(strings)),
        onPressed: () {
          onTap();
        },
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
  backupYourKey,
  resetAtsign,
  feedback,
  signOut,
}
