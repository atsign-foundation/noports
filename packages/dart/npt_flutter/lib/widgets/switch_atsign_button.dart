import 'dart:developer';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/connected_profiles_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SwitchAtsignButton extends StatelessWidget {
  const SwitchAtsignButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Sizes.p10,
          vertical: Sizes.p6,
        ),
        decoration: BoxDecoration(
          color: AppColor.surfaceColor,
          borderRadius: BorderRadius.circular(Sizes.p8),
        ),
        child: ListTile(
          leading: PhosphorIcon(PhosphorIcons.userCircle()),
          title: Text(strings.switchAtSign),
          trailing: PhosphorIcon(PhosphorIcons.caretUpDown()),
          onTap: () async {
            // Select atsign to switch
            final atSignList = await KeychainUtil.getAtsignList();
            // set to dynamic to handle being popped by the AppBar back button which returns a 'StatefulElement'
            final selectedAtSign = await showMenu<dynamic>(
              context: context,
              position: const RelativeRect.fromLTRB(
                -1000,
                1,
                0,
                0,
              ), // You may want to calculate this based on tap position
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  color: AppColor.primaryColor,
                  width: Sizes.p2,
                ),
                borderRadius: BorderRadius.circular(Sizes.p8),
              ),
              items: (atSignList ?? [])
                  .map(
                    (atSign) => PopupMenuItem<String>(
                      padding: const EdgeInsets.all(Sizes.p0),
                      value: atSign,
                      child: _HoverableMenuItem(atSign: atSign),
                    ),
                  )
                  .toList(),
            );

            if (selectedAtSign is! String) {
              //
              return; // Exit if selectedAtsign is not a string.
            }

            // Check for connected profiles before switching
            var isProfileConnected = false;

            if (context
                .read<ProfilesRunningCubit>()
                .state
                .socketConnectors
                .keys
                .toSet()
                .isNotEmpty) {
              isProfileConnected = await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (context) => const ConnectedProfilesDialog(),
              );
            }
            if (context.mounted && isProfileConnected) {
              // If a proifle is connected, exit.
              return;
            }
            final currentContext = App.navState.currentContext!;

            final rootDomain = currentContext
                .read<OnboardingCubit>()
                .getRootDomain(); // Or get from your state/cubit if needed
            final atClientPreference =
                await AtClientMethods.loadAtClientPreference(rootDomain);
            await preSignout();
            final result = await AtOnboarding.changePrimaryAtsign(
              atsign: selectedAtSign,
            );

            if (result) {
              final onboardingResult = await AtOnboarding.onboard(
                atsign: selectedAtSign,
                context: currentContext,
                config: AtOnboardingConfig(
                  atClientPreference: atClientPreference,
                  domain: rootDomain,
                  rootEnvironment: RootEnvironment.Production,
                  appAPIKey: await Constants.appAPIKey,
                ),
              );

              if (onboardingResult.status == AtOnboardingResultStatus.success) {
                await BackupKeyUtils().backupKeyStatusCheck();
                log("postOnbarding called");
                await postOnboard(selectedAtSign, rootDomain);
              }
            }
          },
        ),
      ),
    );
  }
}

class _HoverableMenuItem extends StatefulWidget {
  final String atSign;
  const _HoverableMenuItem({required this.atSign});
  @override
  State<_HoverableMenuItem> createState() => _HoverableMenuItemState();
}

class _HoverableMenuItemState extends State<_HoverableMenuItem> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        color: _hovering
            ? AppColor.primaryColorButtonBackgroundAlt
            : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Sizes.p16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '@',
                          style: TextStyle(color: AppColor.primaryColor),
                        ),
                        TextSpan(
                          text: widget.atSign.split('@').last,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(),
                        ),
                      ],
                    ),
                  ),
                  PhosphorIcon(
                    PhosphorIcons.dotOutline(),
                    size: 40,
                    color: _hovering ? AppColor.primaryColor : null,
                  ),
                ],
              ),
            ),
            gapH12,
            const Divider(color: AppColor.dividerColor, height: Sizes.p0),
          ],
        ),
      ),
    );
  }
}
