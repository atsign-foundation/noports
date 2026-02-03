import 'package:at_onboarding_flutter/at_onboarding_flutter.dart'
    hide OnboardingStatus;
import 'package:npt_mobile_flutter/util/onboarding_service.dart'
    as custom_onboarding;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/onboarding/cubit/onboarding_cubit.dart'
    as app_onboarding;
import 'package:npt_mobile_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/profile_progress_listener.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/onboarding_dialog.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/routes.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/util/at_client_methods.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:npt_mobile_flutter/widgets/loading_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:at_client/at_client.dart';
import 'package:at_commons/at_commons.dart';

final strings = AppLocalizations.of(App.navState.currentContext!)!;

class OnboardingButton extends StatefulWidget {
  const OnboardingButton({super.key});

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

enum _OnboardingButtonStatus { ready, loading }

class _OnboardingButtonState extends State<OnboardingButton> {
  _OnboardingButtonStatus buttonStatus = _OnboardingButtonStatus.ready;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return ElevatedButton.icon(
      onPressed: () async {
        switch (buttonStatus) {
          case _OnboardingButtonStatus.ready:
            try {
              setState(() {
                buttonStatus = _OnboardingButtonStatus.loading;
              });
              bool shouldOnboard = await selectAtsign();
              if (shouldOnboard && context.mounted) {
                var atsignInformation = context
                    .read<app_onboarding.OnboardingCubit>()
                    .state;
                await onboard(
                  atsign: atsignInformation.atSign,
                  rootDomain: atsignInformation.rootDomain,
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  buttonStatus = _OnboardingButtonStatus.ready;
                });
              }
            }
          case _OnboardingButtonStatus.loading:
          // Do nothing
        }
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (buttonStatus) {
          _OnboardingButtonStatus.ready => PhosphorIcon(
            key: const Key('getStartedIcon'),
            PhosphorIcons.arrowUpRight(),
          ),
          _OnboardingButtonStatus.loading => const SizedBox(
            key: Key('loading state'),
            height: Sizes.p18,
            width: Sizes.p18,
            child: CircularProgressIndicator(strokeWidth: Sizes.p2),
          ),
        },
      ),
      label: Text(strings.getStarted),
      iconAlignment: IconAlignment.end,
    );
  }

  Future<bool> selectAtsign() async {
    var options = await getAtsignEntries();
    if (!mounted) return false;

    final cubit = context.read<app_onboarding.OnboardingCubit>();
    String atsign = cubit.state.atSign;
    String? rootDomain = cubit.state.rootDomain;

    if (options.isEmpty) {
      atsign = "";
    } else if (atsign.isEmpty) {
      atsign = options.keys.first;
    }
    if (options.keys.contains(atsign)) {
      rootDomain = options[atsign]?.rootDomain;
    } else {
      rootDomain = Constants.getRootDomains(context).keys.first;
    }

    cubit.setState(atSign: atsign, rootDomain: rootDomain);
    final results = await showDialog(
      context: context,
      builder: (BuildContext context) => OnboardingDialog(options: options),
    );

    return results ?? false;
  }

  Future<void> onboard({
    required String atsign,
    required String rootDomain,
    bool isFromInitState = false,
  }) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const LoadingDialog(),
      );
    }

    var atSigns = await KeyChainManager.getInstance()
        .getAtSignListFromKeychain();
    var apiKey = await Constants.appAPIKey;
    var config = AtOnboardingConfig(
      atClientPreference: await AtClientMethods.loadAtClientPreference(
        rootDomain,
      ),
      rootEnvironment: RootEnvironment.Production,
      domain: rootDomain,
      appAPIKey: apiKey,
    );

    var util = NoPortsOnboardingUtil(config);
    AtOnboardingResult? onboardingResult;

    if (!mounted) return;

    if (atSigns.contains(atsign)) {
      // AtSign already exists in KeyChain - keys were uploaded via file
      // Just return success - DO NOT call changePrimaryAtsign or any other method
      // that might delete the KeyChain entry
      App.log(
        '[OnboardingButton] Atsign exists in KeyChain, returning success'
            .loggable,
      );
      onboardingResult = AtOnboardingResult.success(atsign: atsign);
    } else {
      // Use the shared util method with progress callback
      onboardingResult = await util.handleAtsignByStatus(
        context: context,
        atsign: atsign,
        onProgress: (status) {
          // Handle file upload progress states
          if (status is custom_onboarding.FilePickingInProgress ||
              status is custom_onboarding.ProcessingAesKeyInProgress) {
            setState(() {
              buttonStatus = _OnboardingButtonStatus.loading;
            });
          }
        },
      );
    }
    setState(() {
      buttonStatus = _OnboardingButtonStatus.ready;
    });

    if (!mounted) return;
    switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
      case AtOnboardingResultStatus.success:
        final atsign = onboardingResult?.atsign ?? '';

        // Check if this was a file upload (atsign not in keychain before)
        // vs a normal login (atsign already in keychain)
        final wasFileUpload = !atSigns.contains(atsign);

        if (wasFileUpload) {
          // FILE UPLOAD FLOW - Don't log in, just prepare for login screen
          try {
            App.log(
              '[OnboardingButton] File uploaded successfully - keys are in KeyChain'
                  .loggable,
            );

            // Set OnboardingCubit to offboarded so user can select and log in
            if (context.mounted) {
              context.read<app_onboarding.OnboardingCubit>().setState(
                atSign: atsign,
                rootDomain: rootDomain,
                status: app_onboarding.OnboardingStatus.offboarded,
              );
              App.log(
                '[OnboardingButton] State set to offboarded - ready for login'
                    .loggable,
              );
            }

            // Save atsign to dropdown
            await saveAtsignInformation(
              AtsignInformation(atSign: atsign, rootDomain: rootDomain),
            );

            if (!mounted) return;

            // Dismiss loading dialog
            Navigator.of(context, rootNavigator: true).pop();

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(
                    'Keys uploaded successfully! Please select $atsign from the dropdown to log in.',
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }

            // IMPORTANT: Return here - don't continue to normal login flow
            return;
          } catch (initError, stackTrace) {
            App.log(
              '[OnboardingButton] Key storage failed: $initError'.loggable,
            );
            App.log('[OnboardingButton] Stack trace: $stackTrace'.loggable);

            if (!mounted) return;

            // Dismiss loading dialog on error
            Navigator.of(context, rootNavigator: true).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text('Failed to store keys: $initError'),
              ),
            );
            return;
          }
        }

        // NORMAL LOGIN FLOW - atsign was already in keychain
        // Keys are in KeyChain (APKAM keys from file upload or enrollment).
        // APKAM keys use PKAM authentication, not CRAM.
        App.log(
          '[OnboardingButton] Loading APKAM keys from KeyChain to localStorage'
              .loggable,
        );

        try {
          // Get keys from KeyChain
          final keyChainManager = KeyChainManager.getInstance();
          final atsignKey = await keyChainManager.readAtsign(name: atsign);

          if (atsignKey == null) {
            throw Exception('Keys not found in KeyChain for $atsign');
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
            throw Exception('Incomplete keys in KeyChain for $atsign');
          }

          // Step 1: Call setCurrentAtSign to create atClient instance
          App.log(
            '[OnboardingButton] Calling setCurrentAtSign to create atClient'
                .loggable,
          );
          final atClientManager = AtClientManager.getInstance();
          await atClientManager.setCurrentAtSign(
            atsign,
            'npt',
            config.atClientPreference,
          );

          // Step 2: Now populate localStorage with keys from KeyChain
          App.log(
            '[OnboardingButton] Copying keys from KeyChain to localStorage'
                .loggable,
          );
          final atClient = atClientManager.atClient;
          final localStorage = atClient.getLocalSecondary();

          if (localStorage != null) {
            // Store PKAM keys
            await localStorage.putValue(
              AtConstants.atPkamPublicKey,
              pkamPublicKey,
            );
            await localStorage.putValue(
              AtConstants.atPkamPrivateKey,
              pkamPrivateKey,
            );

            // Store encryption private key
            await localStorage.putValue(
              AtConstants.atEncryptionPrivateKey,
              encryptionPrivateKey,
            );

            // Store encryption public key (must use UpdateVerbBuilder)
            var updateBuilder = UpdateVerbBuilder()
              ..atKey = AtKey.public('publickey', sharedBy: atsign).build();
            updateBuilder.atKey.metadata.ttr = -1;
            updateBuilder.value = encryptionPublicKey;
            await localStorage.executeVerb(updateBuilder, sync: true);

            // Store self encryption key
            await localStorage.putValue(
              AtConstants.atEncryptionSelfKey,
              selfEncryptionKey,
            );

            App.log(
              '[OnboardingButton] Keys copied to localStorage successfully'
                  .loggable,
            );
          }

          // Step 3: Call setCurrentAtSign again to reinitialize atChops with the new keys
          App.log(
            '[OnboardingButton] Reinitializing atClient to load keys from localStorage'
                .loggable,
          );
          await atClientManager.setCurrentAtSign(
            atsign,
            'npt',
            config.atClientPreference,
          );

          App.log('[OnboardingButton] Login complete with APKAM keys'.loggable);
        } catch (e, st) {
          App.log('[OnboardingButton] Onboarding failed: $e\n$st'.loggable);
          rethrow;
        }

        // After successful login, complete the setup
        await custom_onboarding.initializeContactsService(context, atsign);

        // Add sync listener and start sync
        try {
          final atClientManager = AtClientManager.getInstance();
          final atClient = atClientManager.atClient;
          atClient.syncService.addProgressListener(ProfileProgressListener());
          atClient.syncService.sync();
        } catch (e) {
          App.log('AtClient not ready for sync: $e'.loggable);
        }

        await postOnboard(atsign, rootDomain);

        final result = await saveAtsignInformation(
          AtsignInformation(atSign: atsign, rootDomain: rootDomain),
        );

        App.log('atsign login result: $result'.loggable);

        if (!mounted) return;

        // Dismiss loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        // Navigate to home screen
        Navigator.of(context, rootNavigator: true).pushNamed(Routes.home);

        break;
      case AtOnboardingResultStatus.error:
        if (isFromInitState) break;

        // Dismiss loading dialog on error
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
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
        // Dismiss loading dialog on cancel
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        break;
    }
  }
}
