import 'dart:developer';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_flutter/features/onboarding/widgets/get_started_dialog.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/connected_profiles_dialog.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/loading_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SwitchAtsignButton extends StatelessWidget {
  const SwitchAtsignButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final atsign = context.watch<OnboardingCubit>().getAtsign();

    return Padding(
      padding: const EdgeInsets.only(right: 24.0),
      child: GestureDetector(
        onTap: () async => await _handleSwitchAtsign(context),
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
                    : strings.switchAtsign,
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

Future<void> _handleSwitchAtsign(BuildContext context) async {
  final strings = AppLocalizations.of(context)!;

  final selection = await _showAtsignMenu(context, strings);
  if (selection == null) return;
  if (!context.mounted) return;

  if (!await _checkAndHandleConnectedProfiles(context)) return;
  if (!context.mounted) return;

  await _handleSelection(context, selection, strings);
}

Future<String?> _showAtsignMenu(
  BuildContext context,
  AppLocalizations strings,
) async {
  final atsignList = await KeychainStorage().getAllAtsigns();
  if (!context.mounted) return null;

  final result = await showMenu<String?>(
    context: context,
    position: const RelativeRect.fromLTRB(
      Sizes.p1000,
      Sizes.p0,
      Sizes.p0,
      Sizes.p0,
    ),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColor.primaryColor, width: Sizes.p2),
      borderRadius: BorderRadius.circular(Sizes.p8),
    ),
    items: [
      ...atsignList.map(
        (atsign) => PopupMenuItem<String>(
          padding: const EdgeInsets.all(Sizes.p0),
          value: atsign,
          child: _HoverableMenuItem(label: atsign.toAtsign()),
        ),
      ),
      PopupMenuItem<String>(
        padding: const EdgeInsets.all(Sizes.p0),
        value: strings.addAtsign,
        child: _HoverableMenuItem(label: strings.addAtsign),
      ),
      PopupMenuItem<String>(
        padding: const EdgeInsets.all(Sizes.p0),
        value: strings.signout,
        child: _HoverableMenuItem(label: strings.signout),
      ),
    ],
  );

  return result is String ? result : null;
}

Future<bool> _checkAndHandleConnectedProfiles(BuildContext context) async {
  final hasConnectedProfiles = context
      .read<ProfilesRunningCubit>()
      .state
      .socketConnectors
      .keys
      .toSet()
      .isNotEmpty;

  if (!hasConnectedProfiles) return true;

  if (!context.mounted) return false;

  final shouldContinue = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => const ConnectedProfilesDialog(),
  );

  return shouldContinue !=
      true; // Invert: dialog returns true when profiles are connected
}

Future<void> _handleSelection(
  BuildContext context,
  String selection,
  AppLocalizations strings,
) async {
  if (selection == strings.signout) {
    await _handleSignout(context);
  } else if (selection == strings.addAtsign) {
    await _handleAddAtsign(context);
  } else {
    await _handleSwitchToAtsign(context, selection.toAtsign());
  }
}

Future<void> _handleSignout(BuildContext context) async {
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
  }
}

Future<void> _handleAddAtsign(BuildContext context) async {
  final originalAtsign = App.navState.currentContext!
      .read<OnboardingCubit>()
      .state
      .atsign;
  final originalRootDomain = App.navState.currentContext!
      .read<OnboardingCubit>()
      .state
      .rootDomain;

  App.navState.currentContext!.read<OnboardingCubit>().setState(
    atsign: null,
    rootDomain: originalRootDomain,
  );

  final shouldOnboard = await showDialog<bool>(
    barrierDismissible: true,
    context: App.navState.currentContext!,
    builder: (BuildContext context) =>
        const GetStartedDialog(isMainSignInFlow: false),
  );

  if (shouldOnboard != true) {
    log('should Onboard is false or null');
    App.navState.currentContext!.read<OnboardingCubit>().setState(
      atsign: originalAtsign,
      rootDomain: originalRootDomain,
    );
    return;
  }

  final atsignInfo =
      App.navState.currentContext!.read<OnboardingCubit>().state;
  final newAtsign = atsignInfo.atsign!;
  final rootDomain = atsignInfo.rootDomain;

  final atsignList = await KeychainStorage().getAllAtsigns();

  showDialog(
    context: App.navState.currentContext!,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  try {
    if (atsignList.contains(newAtsign)) {
      await _performOnboarding(App.navState.currentContext!, newAtsign);
    } else {
      final util = await NoPortsOnboardingUtil.create(
        App.navState.currentContext!,
      );
      final onboardResult = await util.handleAtsignByStatus(
        context: App.navState.currentContext!,
        atsign: newAtsign,
      );

      final atClientPreference = await AtClientMethods.loadAtClientPreference(
        rootDomain,
      );

      switch (onboardResult) {
        case null:
        case OnboardCancelled():
          App.navState.currentContext!.read<OnboardingCubit>().setState(
            atsign: originalAtsign,
            rootDomain: originalRootDomain,
          );

        case OnboardError(:final message):
          App.navState.currentContext!.read<OnboardingCubit>().setState(
            atsign: originalAtsign,
            rootDomain: originalRootDomain,
          );
          ScaffoldMessenger.of(App.navState.currentContext!).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(message),
            ),
          );

        case OnboardSuccess(:final atsign, :final enrollmentId):
          await preSignout();
          await initializeAfterAuth(
            atsign: atsign,
            rootDomain: rootDomain,
            atClientPreference: atClientPreference,
            enrollmentId: enrollmentId,
          );
          await BackupKeyUtils().backupKeyStatusCheck(
            context: App.navState.currentContext!,
          );
          App.log('Add atsign onboard successful: $atsign'.loggable);
      }
    }
  } finally {
    Navigator.of(App.navState.currentContext!).pop();
  }
}

Future<void> _handleSwitchToAtsign(
  BuildContext context,
  Atsign targetAtsign,
) async {
  await preSignout();
  log('switching to atsign: $targetAtsign');
  await _performOnboarding(App.navState.currentContext!, targetAtsign);
}

/// Authenticates an atsign that is already in the keychain via PKAM and
/// then runs the shared post-auth initialisation.
Future<void> _performOnboarding(BuildContext context, Atsign atsign) async {
  final rootDomain = context.read<OnboardingCubit>().getRootDomain();
  final atClientPreference = await AtClientMethods.loadAtClientPreference(
    rootDomain,
  );

  final authRequest = AtAuthRequest(
    atsign,
    atKeysIo: KeychainAtKeysIo(),
    rootDomain: AtRootDomain(rootDomain, 64),
  );

  if (!context.mounted) return;
  final authResponse = await PkamDialog.show(context, request: authRequest);

  if (authResponse == null || !authResponse.isSuccessful) return;

  await initializeAfterAuth(
    atsign: atsign,
    rootDomain: rootDomain,
    atClientPreference: atClientPreference,
  );
  await BackupKeyUtils().backupKeyStatusCheck();
  log('postOnboarding called for $atsign');
}

class _HoverableMenuItem extends StatefulWidget {
  final String label;
  const _HoverableMenuItem({required this.label});

  @override
  State<_HoverableMenuItem> createState() => _HoverableMenuItemState();
}

class _HoverableMenuItemState extends State<_HoverableMenuItem> {
  bool _hovering = false;

  String displayAtsignPrefix(AppLocalizations strings) {
    if (widget.label == strings.addAtsign) {
      return '+ ';
    } else if (widget.label == strings.signout) {
      return '   ';
    } else {
      return '@';
    }
  }

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
                          text: displayAtsignPrefix(strings),
                          style: TextStyle(
                            color: AppColor.primaryColor,
                            fontSize: widget.label == strings.addAtsign
                                ? Sizes.p20
                                : Sizes.p12,
                          ),
                        ),
                        TextSpan(
                          text: widget.label.split('@').last,
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
