import 'dart:developer';

import 'package:at_chops/at_chops.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_mobile_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_mobile_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/profile_progress_listener.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/onboarding_dialog.dart';
import 'package:npt_mobile_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_mobile_flutter/features/profile_list/widgets/connected_profiles_dialog.dart';
import 'package:npt_mobile_flutter/home_wrapper_widget.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/pages/loading_page.dart';
import 'package:npt_mobile_flutter/routes.dart';
import 'package:npt_mobile_flutter/styles/app_color.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/util/at_client_methods.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:npt_mobile_flutter/util/onboarding_service.dart'
    show initializeContactsService;
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

Future<void> _handleSwitchAtsign(BuildContext context) async {
  final strings = AppLocalizations.of(context)!;

  // Step 1: Show the menu and get selection
  final selectedAtsign = await _showAtsignMenu(context);
  if (selectedAtsign == null) return; // User cancelled;

  // Step 2: Check for connected profiles
  if (!await _checkAndHandleConnectedProfiles(context)) return;

  // Step 3: Handle the selection
  await _handleSelection(context, selectedAtsign, strings);
}

/// Shows the atsign menu and returns the selected option
Future<String?> _showAtsignMenu(BuildContext context) async {
  final strings = AppLocalizations.of(context)!;
  final atSignList = await KeychainUtil.getAtsignList();

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
      ...(atSignList ?? []).map(
        (atSign) => PopupMenuItem<String>(
          padding: const EdgeInsets.all(Sizes.p0),
          value: atSign,
          child: _HoverableMenuItem(atSign: atSign),
        ),
      ),
      PopupMenuItem<String>(
        padding: const EdgeInsets.all(Sizes.p0),
        value: strings.addAtsign,
        child: _HoverableMenuItem(atSign: strings.addAtsign),
      ),
      PopupMenuItem<String>(
        padding: const EdgeInsets.all(Sizes.p0),
        value: strings.signout,
        child: _HoverableMenuItem(atSign: strings.signout),
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
  String selectedAtSign,
  AppLocalizations strings,
) async {
  if (selectedAtSign == strings.signout) {
    await _handleSignout(context);
  } else if (selectedAtSign == strings.addAtsign) {
    await _handleAddAtsign(context);
  } else {
    await _handleSwitchToAtsign(context, selectedAtSign);
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
  final currentContext = App.navState.currentContext!;
  final originalAtsign = currentContext.read<OnboardingCubit>().state.atSign;
  final originalRootDomain = currentContext
      .read<OnboardingCubit>()
      .state
      .rootDomain;

  // Clear the atsign field before showing the dialog
  if (currentContext.mounted) {
    currentContext.read<OnboardingCubit>().setState(
      atSign: '',
      rootDomain: originalRootDomain,
    );
  }

  final shouldOnboard = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) => OnboardingDialog(options: options),
  );

  if (shouldOnboard != true) {
    log('should Onboard is false or null');
    // User cancelled - revert to original atsign
    if (currentContext.mounted) {
      currentContext.read<OnboardingCubit>().setState(
        atSign: originalAtsign,
        rootDomain: originalRootDomain,
      );
    }
    return;
  }

  final atsignInfo = currentContext.read<OnboardingCubit>().state;
  final newAtSign = atsignInfo.atSign;
  final rootDomain = atsignInfo.rootDomain;

  // Check if atsign already exists in keychain
  final atSignList = await KeychainUtil.getAtsignList();

  // Show loading dialog
  if (currentContext.mounted) {
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  try {
    if (atSignList?.contains(newAtSign) ?? false) {
      // Atsign exists in keychain - use existing flow
      await _performOnboarding(currentContext, newAtSign);
    } else {
      // New atsign - use shared util method for activation/APKAM flow
      final apiKey = await Constants.appAPIKey;
      final config = AtOnboardingConfig(
        atClientPreference: await AtClientMethods.loadAtClientPreference(
          rootDomain,
        ),
        rootEnvironment: RootEnvironment.Production,
        domain: rootDomain,
        appAPIKey: apiKey,
      );

      final util = NoPortsOnboardingUtil(config);
      final onboardingResult = await util.handleAtsignByStatus(
        context: currentContext,
        atsign: newAtSign,
      );

      switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
        case AtOnboardingResultStatus.success:
          await preSignout();

          await initializeContactsService(currentContext, newAtSign);
          AtClientManager.getInstance().atClient.syncService
              .addProgressListener(ProfileProgressListener());
          AtClientManager.getInstance().atClient.syncService.sync();
          postOnboard(onboardingResult!.atsign!, rootDomain);
          final result = await saveAtsignInformation(
            AtsignInformation(
              atSign: onboardingResult.atsign!,
              rootDomain: rootDomain,
            ),
          );
          final backupKeyCubit = App.navState.currentContext!
              .read<BackupKeyCubit>();

          await backupKeyCubit.putBackupKeyStatus(backupKeyCubit.state);

          await BackupKeyUtils().backupKeyStatusCheck(context: context);

          App.log('atsign result is:$result'.loggable);
          return;
        case AtOnboardingResultStatus.error:
          if (currentContext.mounted) {
            currentContext.read<OnboardingCubit>().setState(
              atSign: originalAtsign,
              rootDomain: originalRootDomain,
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                onboardingResult?.message ??
                    AppLocalizations.of(context)!.onboardingError,
              ),
            ),
          );

          break;
        case AtOnboardingResultStatus.cancel:
          if (currentContext.mounted) {
            currentContext.read<OnboardingCubit>().setState(
              atSign: originalAtsign,
              rootDomain: originalRootDomain,
            );
          }
          break;
      }
    }
  } finally {
    // Dismiss loading dialog
    if (currentContext.mounted) {
      Navigator.of(currentContext).pop();
    }
  }
}

/// Handles switching to an existing atsign
Future<void> _handleSwitchToAtsign(
  BuildContext context,
  String targetAtSign,
) async {
  await preSignout();

  log('change primary atsign called: $targetAtSign');

  // Check if this is an APKAM atsign
  final atsignEntries = await getAtsignEntries();
  final atsignInfo = atsignEntries[targetAtSign];
  final isApkamAtsign = atsignInfo?.enrollmentId != null;

  if (!isApkamAtsign) {
    // Regular atsign - use standard flow
    final changeSuccess = await AtOnboarding.changePrimaryAtsign(
      atsign: targetAtSign,
    );

    if (!changeSuccess) return;
  }
  // For APKAM atsigns, skip changePrimaryAtsign and let _performOnboarding handle it

  final currentContext = App.navState.currentContext!;
  await _performOnboarding(currentContext, targetAtSign);
}

/// Performs the onboarding process for the given atsign
/// Handles both regular atKeys and APKAM atsigns
Future<void> _performOnboarding(BuildContext context, String atsign) async {
  final rootDomain = context.read<OnboardingCubit>().getRootDomain();
  final atClientPreference = await AtClientMethods.loadAtClientPreference(
    rootDomain,
  );

  // Check if this is an APKAM atsign (has enrollmentId in AtsignInformation)
  final atsignEntries = await getAtsignEntries();
  final atsignInfo = atsignEntries[atsign];
  final enrollmentId = atsignInfo?.enrollmentId;

  if (enrollmentId != null) {
    // APKAM atsign - need to set up atClient manually with enrollmentId
    App.log(
      '[SwitchAtsign] APKAM atsign detected with enrollmentId: $enrollmentId'
          .loggable,
    );

    // Read keys from KeyChain
    final keyChainManager = KeyChainManager.getInstance();
    final atsignKey = await keyChainManager.readAtsign(name: atsign);

    if (atsignKey == null) {
      App.log('[SwitchAtsign] Keys not found in KeyChain for $atsign'.loggable);
      return;
    }

    final pkamPublicKey = atsignKey.pkamPublicKey;
    final pkamPrivateKey = atsignKey.pkamPrivateKey;
    final encryptionPublicKey = atsignKey.encryptionPublicKey;
    final encryptionPrivateKey = atsignKey.encryptionPrivateKey;
    final selfEncryptionKey = atsignKey.selfEncryptionKey;

    if (pkamPublicKey == null ||
        pkamPrivateKey == null ||
        encryptionPublicKey == null ||
        encryptionPrivateKey == null ||
        selfEncryptionKey == null) {
      App.log('[SwitchAtsign] Missing keys for $atsign'.loggable);
      return;
    }

    // Create AtChops with the keys
    final atEncryptionKeyPair = AtEncryptionKeyPair.create(
      encryptionPublicKey,
      encryptionPrivateKey,
    );
    final atPkamKeyPair = AtPkamKeyPair.create(pkamPublicKey, pkamPrivateKey);
    final atChopsKeys = AtChopsKeys.create(atEncryptionKeyPair, atPkamKeyPair);
    atChopsKeys.selfEncryptionKey = AESKey(selfEncryptionKey);
    final atChops = AtChopsImpl(atChopsKeys);

    final atClientManager = AtClientManager.getInstance();

    // Set up atClient with enrollmentId
    await atClientManager.setCurrentAtSign(
      atsign,
      'npt',
      atClientPreference,
      atChops: atChops,
      enrollmentId: enrollmentId,
    );

    App.log('[SwitchAtsign] APKAM atClient set up successfully'.loggable);

    // Initialize services and sync
    await initializeContactsService(context, atsign);
    atClientManager.atClient.syncService.addProgressListener(
      ProfileProgressListener(),
    );
    atClientManager.atClient.syncService.sync();

    await BackupKeyUtils().backupKeyStatusCheck();
    log("postOnboarding called for APKAM atsign");
    await postOnboard(atsign, rootDomain);
  } else {
    // Regular atKeys atsign - use standard SDK flow
    App.log(
      '[SwitchAtsign] Regular atKeys atsign, using AtOnboarding.onboard()'
          .loggable,
    );

    final onboardingResult = await AtOnboarding.onboard(
      atsign: atsign,
      context: context,
      config: AtOnboardingConfig(
        atClientPreference: atClientPreference,
        domain: rootDomain,
        rootEnvironment: RootEnvironment.Production,
        appAPIKey: await Constants.appAPIKey,
      ),
    );

    if (onboardingResult.status == AtOnboardingResultStatus.success) {
      await BackupKeyUtils().backupKeyStatusCheck();
      log("postOnboarding called");
      await postOnboard(atsign, rootDomain);
    }
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

  // Function to determine the prefix based on atSign value
  String displayAtsignPrefix(AppLocalizations strings) {
    if (widget.atSign == strings.addAtsign) {
      return '+ ';
    } else if (widget.atSign == strings.signout) {
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
                            fontSize: widget.atSign == strings.addAtsign
                                ? Sizes.p20
                                : Sizes.p12,
                          ),
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
