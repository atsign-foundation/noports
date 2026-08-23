import 'dart:developer';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_flutter/features/onboarding/util/profile_progress_listener.dart';
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

  // Step 1: Show the menu and get selection
  final selection = await _showAtsignMenu(context);
  if (selection == null) return; // User cancelled;

  // Step 2: Check for connected profiles
  if (!await _checkAndHandleConnectedProfiles(context)) return;

  // Step 3: Handle the selection
  await _handleSelection(context, selection, strings);
}

/// Shows the atsign menu and returns the selected option
Future<String?> _showAtsignMenu(BuildContext context) async {
  final strings = AppLocalizations.of(context)!;
  final atsignList = await KeychainStorage().getAllAtsigns();

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

/// Checks for connected profiles and shows dialog if needed
/// Returns true if we should continue, false if we should abort
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
      true; // Invert because dialog returns true when profiles are connected
}

/// Handles the menu selection (signout, add atsign, or switch)
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

/// Handles the signout flow
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

/// Handles adding a new atsign
Future<void> _handleAddAtsign(BuildContext context) async {
  final options = await getAtsignEntries();

  // Store the current atsign before showing the dialog

  final originalAtsign = App.navState.currentContext!
      .read<OnboardingCubit>()
      .state
      .atsign;
  final originalRootDomain = App.navState.currentContext!
      .read<OnboardingCubit>()
      .state
      .rootDomain;

  // Clear the atsign field before showing the dialog
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
    // User cancelled - revert to original atsign

    App.navState.currentContext!.read<OnboardingCubit>().setState(
      atsign: originalAtsign,
      rootDomain: originalRootDomain,
    );

    return;
  }

  final atsignInfo = App.navState.currentContext!.read<OnboardingCubit>().state;
  final newAtsign = atsignInfo.atsign!;
  final rootDomain = atsignInfo.rootDomain;

  // Check if atsign already exists in keychain
  final atsignList = await KeychainStorage().getAllAtsigns();

  // Show loading dialog

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
      // Atsign exists in keychain - use existing flow
      await _performOnboarding(App.navState.currentContext!, newAtsign);
    } else {
      // New atsign - use shared util method for activation/APKAM flow
      final util = await NoPortsOnboardingUtil.create(
        App.navState.currentContext!,
      );
      final onboardingResult = await util.handleAtsignByStatus(
        context: App.navState.currentContext!,
        atsign: newAtsign,
      );

      switch (onboardingResult?.status ?? NoPortsOnboardingResultStatus.cancel) {
        case NoPortsOnboardingResultStatus.success:
          await preSignout();

          AtClientManager.getInstance().atClient.syncService
              .addProgressListener(ProfileProgressListener());
          AtClientManager.getInstance().atClient.syncService.sync();
          postOnboard(onboardingResult!.atsign!.toAtsign(), rootDomain);
          final result = await saveAtsignInformation(
            AtsignInformation(
              atsign: onboardingResult.atsign!.toAtsign(),
              rootDomain: rootDomain,
            ),
          );
          final backupKeyCubit = App.navState.currentContext!
              .read<BackupKeyCubit>();

          await backupKeyCubit.putBackupKeyStatus(backupKeyCubit.state);

          await BackupKeyUtils().backupKeyStatusCheck(
            context: App.navState.currentContext!,
          );

          App.log('atsign result is:$result'.loggable);
          return;
        case NoPortsOnboardingResultStatus.error:
          if (App.navState.currentContext!.mounted) {
            App.navState.currentContext!.read<OnboardingCubit>().setState(
              atsign: originalAtsign,
              rootDomain: originalRootDomain,
            );
          }
          ScaffoldMessenger.of(App.navState.currentContext!).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                onboardingResult?.message ??
                    AppLocalizations.of(
                      App.navState.currentContext!,
                    )!.onboardingError,
              ),
            ),
          );

          break;
        case NoPortsOnboardingResultStatus.cancel:
          App.navState.currentContext!.read<OnboardingCubit>().setState(
            atsign: originalAtsign,
            rootDomain: originalRootDomain,
          );

          break;
      }
    }
  } finally {
    // Dismiss loading dialog

    Navigator.of(App.navState.currentContext!).pop();
  }
}

/// Handles switching to an existing atsign
Future<void> _handleSwitchToAtsign(
  BuildContext context,
  Atsign targetAtsign,
) async {
  await preSignout();

  log('switching to atsign: $targetAtsign');

  final currentContext = App.navState.currentContext!;
  await _performOnboarding(currentContext, targetAtsign);
}

/// Performs the onboarding process for the given atsign, which is already
/// present in the local keychain.
Future<void> _performOnboarding(BuildContext context, Atsign atsign) async {
  final rootDomain = context.read<OnboardingCubit>().getRootDomain();

  NoPortsOnboardingResult onboardingResult;
  try {
    final response = await AuthService().authenticate(
      AtAuthRequest(
        atsign,
        atKeysIo: KeychainAtKeysIo(),
        rootDomain: AtRootDomain.parse(rootDomain),
      ),
      backupKeys: [KeychainAtKeysIo()],
    );
    if (response.isSuccessful) {
      await AtClientMethods.activateFromAuthResponse(response, rootDomain);
      onboardingResult = NoPortsOnboardingResult.success(atsign: atsign);
    } else {
      onboardingResult = NoPortsOnboardingResult.error(
        message: context.mounted
            ? AppLocalizations.of(context)!.onboardingError
            : '',
      );
    }
  } catch (e) {
    onboardingResult = NoPortsOnboardingResult.error(message: e.toString());
  }

  if (onboardingResult.status == NoPortsOnboardingResultStatus.success) {
    await BackupKeyUtils().backupKeyStatusCheck();
    log("postOnbarding called");
    await postOnboard(atsign, rootDomain);
  }
}

class _HoverableMenuItem extends StatefulWidget {
  /// The label to display for this menu item. This can be an atsign or a special action like "Add Atsign" or "Sign Out".
  final String label;

  const _HoverableMenuItem({required this.label});
  @override
  State<_HoverableMenuItem> createState() => _HoverableMenuItemState();
}

class _HoverableMenuItemState extends State<_HoverableMenuItem> {
  bool _hovering = false;

  // Function to determine the prefix based on label value
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
