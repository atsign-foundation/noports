import 'dart:developer';
import 'dart:io';

import 'package:at_contacts_flutter/at_contacts_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
// ignore: implementation_imports
import 'package:at_onboarding_flutter/src/utils/at_onboarding_app_constants.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/util/profile_progress_listener.dart';
import 'package:npt_flutter/features/onboarding/widgets/activate_atsign_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/apkam_choice_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_apkam_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_dialog.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final strings = AppLocalizations.of(App.navState.currentContext!)!;

class OnboardingButton extends StatefulWidget {
  const OnboardingButton({
    super.key,
  });

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

enum _OnboardingButtonStatus {
  ready,
  loading,
}

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
                var atsignInformation = context.read<OnboardingCubit>().state;
                onboard(atsign: atsignInformation.atSign, rootDomain: atsignInformation.rootDomain);
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

    final cubit = context.read<OnboardingCubit>();
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

  Future<void> onboard({required String atsign, required String rootDomain, bool isFromInitState = false}) async {
    var atSigns = await KeyChainManager.getInstance().getAtSignListFromKeychain();
    var apiKey = await Constants.appAPIKey;
    var config = AtOnboardingConfig(
      atClientPreference: await AtClientMethods.loadAtClientPreference(rootDomain),
      rootEnvironment: RootEnvironment.Production,
      domain: rootDomain,
      appAPIKey: apiKey,
    );

    var util = NoPortsOnboardingUtil(config);
    AtOnboardingResult? onboardingResult;

    if (!mounted) return;

    if (atSigns.contains(atsign)) {
      onboardingResult = await AtOnboarding.onboard(
        atsign: atsign,
        context: context,
        config: util.config,
      );
    } else {
      onboardingResult = await handleAtsignByStatus(atsign, util);
    }
    setState(() {
      buttonStatus = _OnboardingButtonStatus.ready;
    });
    if (!mounted) return;
    switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
      case AtOnboardingResultStatus.success:
        await initializeContactsService(rootDomain: rootDomain);
        AtClientManager.getInstance().atClient.syncService.addProgressListener(ProfileProgressListener());
        AtClientManager.getInstance().atClient.syncService.sync();
        postOnboard(onboardingResult!.atsign!, rootDomain);
        final result = await saveAtsignInformation(
          AtsignInformation(
            atSign: onboardingResult.atsign!,
            rootDomain: rootDomain,
          ),
        );
        final backupKeyCubit = App.navState.currentContext!.read<BackupKeyCubit>();
        if (backupKeyCubit.state == false) {
          await backupKeyCubit.putBackupKeyStatus(backupKeyCubit.state);
        }

        log('atsign result is:$result');

        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushNamed(Routes.home);

        break;
      case AtOnboardingResultStatus.error:
        if (isFromInitState) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              onboardingResult?.message ?? AppLocalizations.of(context)!.onboardingError,
            ),
          ),
        );
        break;
      case AtOnboardingResultStatus.cancel:
        break;
    }
  }

  Future<AtOnboardingResult?> handleAtsignByStatus(String atsign, NoPortsOnboardingUtil util) async {
    AtStatus status;

    try {
      status = await util.atServerStatus(atsign);
    } catch (_) {
      return AtOnboardingResult.error(
        message: strings.errorAtServerUnavailable,
      );
    }
    AtOnboardingResult? result;
    if (!mounted) return null;
    var initialStatus = status.status();
    switch (initialStatus) {
      // Automatically start activation with the already entered atSign
      case AtSignStatus.unavailable:
      case AtSignStatus.teapot:
        // If the atSign is in teapot, we have to back up the keys after onboarding
        App.navState.currentContext!.read<BackupKeyCubit>().setBackupKeyStatus(false);
        final apiKey = await Constants.appAPIKey;

        if (apiKey == null) {
          result = AtOnboardingResult.error(
            message: strings.errorAtSignNotExist,
          );
          break;
        }
        AtOnboardingConstants.setApiKey(apiKey);
        AtOnboardingConstants.rootDomain = util.config.atClientPreference.rootDomain;

        await AtOnboardingLocalizations.load(LanguageUtil.getLanguageFromLocale(Locale(Platform.localeName)).locale);
        if (!mounted) return null;
        Map<String, String> apis = {
          "root.atsign.org": "my.atsign.com",
          "root.atsign.wtf": "my.atsign.wtf",
        };
        var regUrl = apis[util.config.atClientPreference.rootDomain];
        if (regUrl == null) {
          result ??= AtOnboardingResult.error(
            message: strings.errorRootDomainNotSupported,
          );
          break;
        }
        result = await showDialog<AtOnboardingResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ActivateAtsignDialog(
            atSign: atsign,
            apiKey: apiKey,
            config: util.config,
            registrarUrl: regUrl,
            onboardingUtil: util,
            waitForTeapot: initialStatus != AtSignStatus.teapot,
          ),
        );

        if (result is AtOnboardingResult) {
          //Update primary atsign after onboard success
          if (result.status == AtOnboardingResultStatus.success && result.atsign != null) {
            var onboardingService = OnboardingService.getInstance();
            bool res = await onboardingService.changePrimaryAtsign(atsign: result.atsign!);
            if (!res) {
              result = AtOnboardingResult.error(message: strings.errorSwitchAtSignFailed);
            }
          }
        }
      case AtSignStatus.activated:
        log('Atsign is activated but not in keychain');
        final flowChoice = await showDialog<APKAMFlow?>(
          context: context,
          routeSettings: const RouteSettings(name: 'APKAM choice'),
          builder: (context) => const ApkamChoiceDialog(),
        );
        if (flowChoice == null) {
          result = AtOnboardingResult.cancelled();
          break;
        }
        // Wait for the modal to close
        await Future.delayed(const Duration(milliseconds: 300));
        if (flowChoice == APKAMFlow.atKeys) {
          final statusStream = util.uploadAtKeysFile(atsign);
          result = await handleFileUploadStatusStream(statusStream, atsign);
        } else {
          final atClientPrefernce = await AtClientMethods.loadAtClientPreference(
            util.config.atClientPreference.rootDomain,
          );
          if (!mounted) return null;
          result = await showDialog<AtOnboardingResult>(
            context: context,
            routeSettings: const RouteSettings(name: 'APKAM onboarding'),
            builder: (context) => OnboardingApkamDialog(
              atsign: atsign,
              atClientPreference: atClientPrefernce,
            ),
          );
        }
      case AtSignStatus.notFound:
        result = AtOnboardingResult.error(
          message: strings.errorAtSignNotExist,
        );
      case null: // This case should never happen, treat it as an error
      case AtSignStatus.error:
        result = AtOnboardingResult.error(
          message: strings.errorAtServerUnavailable,
        );
    }
    return result;
  }

  Future<AtOnboardingResult?> handleFileUploadStatusStream(Stream<FileUploadStatus> statusStream, String atsign) async {
    AtOnboardingResult? result;
    outer:
    await for (FileUploadStatus status in statusStream) {
      // Don't return from inside this switch other wise the buttonStatus
      // won't be reset to ready state
      switch (status) {
        case ErrorIncorrectKeyFile():
          result = AtOnboardingResult.error(
            message: strings.errorAtKeysInvalid,
          );
          break outer;
        case ErrorAtSignMismatch():
          result = AtOnboardingResult.error(
            message: strings.errorAtKeysUploadedMismatch,
          );
          break outer;
        case ErrorFailedFileProcessing():
          result = AtOnboardingResult.error(
            message: strings.errorAtKeysFileProcessFailed,
          );
          break outer;
        case ErrorAtServerUnreachable():
          result = AtOnboardingResult.error(
            message: strings.errorAtServerUnavailable,
          );
          break outer;
        case ErrorAuthFailed():
          result = AtOnboardingResult.error(
            message: strings.errorAuthenticatinFailed,
          );
          break outer;
        case ErrorAuthTimeout():
          result = AtOnboardingResult.error(
            message: strings.errorAuthenticationTimedOut,
          );
          break outer;
        case ErrorPairedAtsign _:
          result = AtOnboardingResult.error(
            message: strings.errorAtSignAlreadyPaired(status.atSign ?? atsign),
          );
          break outer;
        case FilePickingInProgress():
          setState(() {
            buttonStatus = _OnboardingButtonStatus.loading;
          });
          break;
        case ProcessingAesKeyInProgress():
          setState(() {
            buttonStatus = _OnboardingButtonStatus.loading;
          });
          break;

        // We don't really need to handle these
        case FilePickingDone():
        case ProcessingAesKeyDone():
          break;

        case FilePickingCanceled():
          result = AtOnboardingResult.cancelled();
          break outer;
        case FileUploadAuthSuccess _:
          result = AtOnboardingResult.success(atsign: status.atSign ?? atsign);
          break outer;
      }
    }
    return result;
  }
}
