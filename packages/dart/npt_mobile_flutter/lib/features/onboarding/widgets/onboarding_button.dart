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
import 'package:at_commons/at_builders.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_chops/at_chops.dart';

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
      // AtSign already exists in KeyChain - keys were uploaded via file or APKAM
      // Dismiss the loading dialog first
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Just return success - DO NOT call changePrimaryAtsign or any other method
      // that might delete the KeyChain entry
      App.log(
        '[OnboardingButton] Atsign exists in KeyChain, returning success'
            .loggable,
      );
      onboardingResult = AtOnboardingResult.success(atsign: atsign);
    } else {
      // Dismiss loading dialog before showing onboarding flow dialogs
      // (APKAM or file picker will show their own UI)
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

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

      // For NEW onboarding (APKAM or file upload), don't show loading dialog
      // Just let the flow continue to show success message
      // Only show loading dialog for existing atsign login
      // NOTE: atSigns was captured BEFORE APKAM, so atsign won't be in it for new enrollments
      final isNewEnrollment = !atSigns.contains(onboardingResult?.atsign ?? '');
      if (mounted &&
          onboardingResult?.status == AtOnboardingResultStatus.success &&
          !isNewEnrollment) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const LoadingDialog(),
        );
      }
    }
    setState(() {
      buttonStatus = _OnboardingButtonStatus.ready;
    });

    if (!mounted) return;
    App.log(
      '[OnboardingButton] onboardingResult status: ${onboardingResult?.status}'
          .loggable,
    );
    App.log(
      '[OnboardingButton] onboardingResult atsign: ${onboardingResult?.atsign}'
          .loggable,
    );
    switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
      case AtOnboardingResultStatus.success:
        final atsign = onboardingResult?.atsign ?? '';
        App.log('[OnboardingButton] SUCCESS case - atsign: $atsign'.loggable);

        // Check if this was a file upload or APKAM enrollment (atsign not in keychain before)
        // vs a normal login (atsign already in keychain)
        final wasNewOnboarding = !atSigns.contains(atsign);
        App.log(
          '[OnboardingButton] wasNewOnboarding: $wasNewOnboarding, atSigns: $atSigns'
              .loggable,
        );

        if (wasNewOnboarding) {
          // NEW ONBOARDING FLOW (file upload or APKAM) - Don't log in, just prepare for login screen
          try {
            App.log(
              '[OnboardingButton] New onboarding completed - keys are in KeyChain'
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

            // Note: No loading dialog was shown for new onboarding, so no need to dismiss

            // Show success message
            App.log(
              '[OnboardingButton] About to show success snackbar'.loggable,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(
                    'Setup complete! Please tap Get Started to log in as $atsign.',
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }

            // IMPORTANT: Return here - don't continue to normal login flow
            App.log(
              '[OnboardingButton] Returning from new onboarding flow - user can now tap Get Started'
                  .loggable,
            );
            return;
          } catch (initError, stackTrace) {
            App.log(
              '[OnboardingButton] Key storage failed: $initError'.loggable,
            );
            App.log('[OnboardingButton] Stack trace: $stackTrace'.loggable);

            if (!mounted) return;

            // Note: No loading dialog was shown for new onboarding, so no need to dismiss

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
          '[OnboardingButton] Loading APKAM keys from KeyChain for login'
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

          // Debug: Log which keys we got from KeyChain
          App.log('[OnboardingButton] Keys from KeyChain:'.loggable);
          App.log(
            '[OnboardingButton]   pkamPublicKey: ${pkamPublicKey != null ? "${pkamPublicKey.substring(0, 30)}..." : "NULL"}'
                .loggable,
          );
          App.log(
            '[OnboardingButton]   pkamPrivateKey: ${pkamPrivateKey != null ? "${pkamPrivateKey.substring(0, 30)}..." : "NULL"}'
                .loggable,
          );
          App.log(
            '[OnboardingButton]   encryptionPublicKey: ${encryptionPublicKey != null ? "${encryptionPublicKey.substring(0, 30)}..." : "NULL"}'
                .loggable,
          );
          App.log(
            '[OnboardingButton]   encryptionPrivateKey: ${encryptionPrivateKey != null ? "${encryptionPrivateKey.substring(0, 30)}..." : "NULL"}'
                .loggable,
          );
          App.log(
            '[OnboardingButton]   selfEncryptionKey: ${selfEncryptionKey != null ? "${selfEncryptionKey.substring(0, 30)}..." : "NULL"}'
                .loggable,
          );

          if (pkamPublicKey == null ||
              pkamPrivateKey == null ||
              encryptionPublicKey == null ||
              encryptionPrivateKey == null ||
              selfEncryptionKey == null) {
            throw Exception('Incomplete keys in KeyChain for $atsign');
          }

          // Create AtChops with the keys from KeyChain
          App.log(
            '[OnboardingButton] Creating AtChops with keys from KeyChain'
                .loggable,
          );

          // Create key pairs for AtChops
          final atEncryptionKeyPair = AtEncryptionKeyPair.create(
            encryptionPublicKey,
            encryptionPrivateKey,
          );
          final atPkamKeyPair = AtPkamKeyPair.create(
            pkamPublicKey,
            pkamPrivateKey,
          );
          final atChopsKeys = AtChopsKeys.create(
            atEncryptionKeyPair,
            atPkamKeyPair,
          );
          atChopsKeys.selfEncryptionKey = AESKey(selfEncryptionKey);
          final atChops = AtChopsImpl(atChopsKeys);

          final atClientManager = AtClientManager.getInstance();

          // Check if atClient already exists for this atsign
          // If so, we need to update its atChops directly
          // If not, we call setCurrentAtSign normally
          bool atClientExists = false;
          try {
            final existingClient = atClientManager.atClient;
            atClientExists = existingClient.getCurrentAtSign() == atsign;
          } catch (_) {
            // atClient doesn't exist yet
            atClientExists = false;
          }

          // Get enrollmentId from AtsignInformation file (stored during APKAM approval)
          // This is more reliable than localStorage since atClient might not be initialized yet
          String? enrollmentId;
          try {
            final atsignEntries = await getAtsignEntries();
            final atsignInfo = atsignEntries[atsign];
            if (atsignInfo?.enrollmentId != null) {
              enrollmentId = atsignInfo!.enrollmentId;
              App.log(
                '[OnboardingButton] Found enrollmentId in AtsignInformation: $enrollmentId'
                    .loggable,
              );
            } else {
              App.log(
                '[OnboardingButton] No enrollmentId in AtsignInformation for $atsign'
                    .loggable,
              );
            }
          } catch (e) {
            App.log(
              '[OnboardingButton] Could not read enrollmentId from AtsignInformation: $e'
                  .loggable,
            );
          }

          if (atClientExists) {
            // atClient already exists for this atsign - just update atChops
            App.log(
              '[OnboardingButton] atClient exists, updating atChops directly'
                  .loggable,
            );
            atClientManager.atClient.atChops = atChops;
            // Also set enrollmentId for APKAM authentication
            if (enrollmentId != null) {
              atClientManager.atClient.enrollmentId = enrollmentId;
              atClientManager.atClient
                      .getRemoteSecondary()
                      ?.atLookUp
                      .enrollmentId =
                  enrollmentId;
              App.log(
                '[OnboardingButton] Set enrollmentId on existing atClient: $enrollmentId'
                    .loggable,
              );
            }
          } else {
            // atClient doesn't exist or is for different atsign - create normally
            App.log(
              '[OnboardingButton] Creating new atClient with AtChops'.loggable,
            );
            if (enrollmentId != null) {
              App.log(
                '[OnboardingButton] Passing enrollmentId to setCurrentAtSign: $enrollmentId'
                    .loggable,
              );
            }
            await atClientManager.setCurrentAtSign(
              atsign,
              'npt',
              config.atClientPreference,
              atChops: atChops,
              enrollmentId: enrollmentId,
            );
          }

          // Also populate localStorage for any operations that read from there
          App.log('[OnboardingButton] Copying keys to localStorage'.loggable);
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
