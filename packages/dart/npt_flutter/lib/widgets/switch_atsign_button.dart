import 'dart:developer';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/connected_profiles_dialog.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/loading_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SwitchAtsignButton extends StatelessWidget {
  const SwitchAtsignButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final atsign = context.watch<OnboardingCubit>().getAtSign();
    return Padding(
      padding: const EdgeInsets.only(right: 24.0),
      child: GestureDetector(
        onTap: () async {
          // Select atsign to switch
          final atSignList = await KeychainUtil.getAtsignList();
          // set to dynamic to handle being popped by the AppBar back button which returns a 'StatefulElement'
          final selectedAtSign = await showMenu<dynamic>(
            context: context,
            position: const RelativeRect.fromLTRB(
              Sizes.p1000,
              Sizes.p0,
              Sizes.p0,
              Sizes.p0,
            ), // You may want to calculate this based on tap position
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                color: AppColor.primaryColor,
                width: Sizes.p2,
              ),
              borderRadius: BorderRadius.circular(Sizes.p8),
            ),
            items: [
              ...(atSignList ?? []).map(
                (atSign) => PopupMenuItem<String>(
                  padding: const EdgeInsets.all(Sizes.p0),
                  value: atSign,
                  child: _HoverableMenuItem(atSign: atSign),
                ),
              ),
              PopupMenuItem<String>(
                padding: const EdgeInsets.all(Sizes.p0),
                value: strings.signout,
                child: _HoverableMenuItem(atSign: strings.signout),
              ),
            ],
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

          // If User selects signout, navigate to loading page and signout
          // Otherwise, switch to the selected atsign
          if (selectedAtSign == strings.signout) {
            wrapperNav.currentState!.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoadingPage()),
              (route) => false,
            );
            await preSignout();
            if (context.mounted) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamedAndRemoveUntil(Routes.onboarding, (route) => false);

              return;
            }
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sizes.p10,
            vertical: Sizes.p6,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.primaryColor, width: Sizes.p1),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/At.svg',
                width: Sizes.p16,
                height: Sizes.p16,
              ),
              gapW4,
              Text(
                atsign.isNotEmpty
                    ? atsign.replaceFirst('@', '')
                    : strings.switchAtSign,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: Sizes.p12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              gapW4,
              PhosphorIcon(PhosphorIcons.caretUpDown()),
            ],
          ),
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
    final strings = AppLocalizations.of(context)!;
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
                        TextSpan(
                          text: !widget.atSign.contains(strings.signout)
                              ? '@'
                              : '   ',
                          style: const TextStyle(color: AppColor.primaryColor),
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
