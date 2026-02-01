import 'dart:async';
import 'dart:io';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/utils/at_onboarding_app_constants.dart';
import 'package:at_onboarding_flutter/utils/at_onboarding_response_status.dart';
import 'package:npt_mobile_flutter/util/onboarding_service.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/activate_atsign_dialog.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/apkam_choice_dialog.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/onboarding_apkam_dialog.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/util/at_client_methods.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:npt_mobile_flutter/util/language.dart';

import '../../../app.dart';

// These types are returned from methods in this class so exports are provided for ease of use
export 'package:npt_mobile_flutter/util/onboarding_service.dart'
    show FileUploadStatus;
export 'package:at_server_status/at_server_status.dart' show AtStatus;

class NoPortsOnboardingUtil {
  /// The upload service will be created when the first time [uploadAtKeysFile] is called
  AtKeysFileUploadService? _uploadService;
  AtServerStatus? _atServerStatus;
  AtOnboardingConfig config;
  NoPortsOnboardingUtil(this.config);

  /// A method to check whether an atSign has been activated or not
  Future<AtStatus> atServerStatus(String atSign) async {
    _atServerStatus ??= AtStatusImpl(
      rootUrl: config.atClientPreference.rootDomain,
      rootPort: config.atClientPreference.rootPort,
    );
    return _atServerStatus!.get(atSign);
  }

  /// Upload an atKeys file, returning a stream with the progress so we can update the ui accordingly.
  /// Example implementation:
  /// https://github.com/atsign-foundation/at_widgets/blob/b4006854fa93c21eeb5bcea41044787bdf0f6f32/packages/at_onboarding_flutter/lib/src/screen/at_onboarding_home_screen.dart#L659
  Stream<FileUploadStatus> uploadAtKeysFile(String? atSign) {
    _uploadService ??= AtKeysFileUploadService(config: config);
    return _uploadService!.uploadKeyFile(atSign);
  }

  /// Handles onboarding an atsign by checking its status and showing appropriate dialogs
  /// This is shared between the main onboarding button and the switch atsign functionality
  Future<AtOnboardingResult?> handleAtsignByStatus({
    required BuildContext context,
    required String atsign,
    void Function(FileUploadStatus)? onProgress,
  }) async {
    final strings = AppLocalizations.of(context)!;

    AtStatus status;
    try {
      status = await atServerStatus(atsign);
    } catch (e) {
      App.log('Error checking atServerStatus: $e'.loggable);

      return AtOnboardingResult.error(
        message: strings.errorAtServerUnavailable,
      );
    }

    if (!context.mounted) return null;

    final initialStatus = status.status();
    AtOnboardingResult? result;

    switch (initialStatus) {
      case AtSignStatus.unavailable:
      case AtSignStatus.teapot:
        result = await _handleActivation(
          context: context,
          atsign: atsign,
          initialStatus: initialStatus,
          strings: strings,
        );

      case AtSignStatus.activated:
        result = await _handleActivatedAtsign(
          context: context,
          atsign: atsign,
          strings: strings,
          onProgress: onProgress, // Pass it through);
        );

      case AtSignStatus.notFound:
        result = AtOnboardingResult.error(message: strings.errorAtSignNotExist);

      case null:
      case AtSignStatus.error:
        result = AtOnboardingResult.error(
          message: strings.errorAtServerUnavailable,
        );
    }

    return result;
  }

  /// Handles activation flow for unavailable/teapot atsigns
  Future<AtOnboardingResult?> _handleActivation({
    required BuildContext context,
    required String atsign,
    AtSignStatus? initialStatus,
    required AppLocalizations strings,
  }) async {
    // When onboarding from teapot, set backup status to false (atKeys not backed up)
    // Value will be in atServer as true after onboarding and false if the user back up their key.
    context.read<BackupKeyCubit>().setBackupKeyStatus(false);

    final apiKey = await Constants.appAPIKey;
    if (apiKey == null) {
      return AtOnboardingResult.error(message: strings.errorAtSignNotExist);
    }

    AtOnboardingConstants.setApiKey(apiKey);
    AtOnboardingConstants.rootDomain = config.atClientPreference.rootDomain;

    await AtOnboardingLocalizations.load(
      LanguageUtil.getLanguageFromLocale(Locale(Platform.localeName)).locale,
    );

    if (!context.mounted) return null;

    Map<String, String> apis = {
      "root.atsign.org": "my.atsign.com",
      "root.atsign.wtf": "my.atsign.wtf",
    };

    final regUrl = apis[config.atClientPreference.rootDomain];
    if (regUrl == null) {
      return AtOnboardingResult.error(
        message: strings.errorRootDomainNotSupported,
      );
    }

    final result = await showDialog<AtOnboardingResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ActivateAtsignDialog(
        atSign: atsign,
        apiKey: apiKey,
        config: config,
        registrarUrl: regUrl,
        onboardingUtil: this,
        waitForTeapot: initialStatus != AtSignStatus.teapot,
      ),
    );

    if (!context.mounted) return result;

    // Update primary atsign after successful onboard
    if (result is AtOnboardingResult &&
        result.status == AtOnboardingResultStatus.success &&
        result.atsign != null) {
      final onboardingService = OnboardingService.getInstance();
      final res = await onboardingService.changePrimaryAtsign(
        atsign: result.atsign!,
        atClientPreference: config.atClientPreference,
      );
      if (res.status != AtOnboardingResponseStatus.authSuccess) {
        return AtOnboardingResult.error(
          message: strings.errorSwitchAtSignFailed,
        );
      }
    }

    return result;
  }

  /// Handles flow for already activated atsigns (APKAM or file upload)
  Future<AtOnboardingResult?> _handleActivatedAtsign({
    required BuildContext context,
    required String atsign,
    required AppLocalizations strings,
    void Function(FileUploadStatus)? onProgress,
  }) async {
    final flowChoice = await showDialog<APKAMFlow?>(
      context: context,
      routeSettings: const RouteSettings(name: 'APKAM choice'),
      builder: (context) => const ApkamChoiceDialog(),
    );

    if (flowChoice == null) {
      return AtOnboardingResult.cancelled();
    }

    // Wait for the modal to close
    await Future.delayed(const Duration(milliseconds: 300));

    if (!context.mounted) return null;

    AtOnboardingResult? result;

    if (flowChoice == APKAMFlow.atKeys) {
      final statusStream = uploadAtKeysFile(atsign);
      result = await _handleFileUploadStatusStream(
        context: context,
        statusStream: statusStream,
        atsign: atsign,
        strings: strings,
        onProgress: onProgress, // Pass it through
      );
    } else {
      final atClientPreference = await AtClientMethods.loadAtClientPreference(
        config.atClientPreference.rootDomain,
      );
      if (!context.mounted) return null;

      result = await showDialog<AtOnboardingResult>(
        context: context,
        routeSettings: const RouteSettings(name: 'APKAM onboarding'),
        barrierDismissible: false,
        builder: (context) => OnboardingApkamDialog(
          atsign: atsign,
          atClientPreference: atClientPreference,
        ),
      );
      App.log(
        '[OnboardingUtil] APKAM dialog returned result: ${result?.status}'
            .loggable,
      );
    }

    // When onboarding via APKAM or uploading atKeys, set backup status to true.
    if (context.mounted && result?.status == AtOnboardingResultStatus.success) {
      App.log(
        '[OnboardingUtil] Setting backup key status to true for ${result?.atsign}'
            .loggable,
      );
      context.read<BackupKeyCubit>().setBackupKeyStatus(true);
    }

    App.log('[OnboardingUtil] Returning result: ${result?.status}'.loggable);
    return result;
  }

  /// Handles file upload status stream and returns appropriate result
  Future<AtOnboardingResult?> _handleFileUploadStatusStream({
    required BuildContext context,
    required Stream<FileUploadStatus> statusStream,
    required String atsign,
    required AppLocalizations strings,
    void Function(FileUploadStatus)? onProgress, // Add this callback
  }) async {
    AtOnboardingResult? result;

    await for (FileUploadStatus status in statusStream) {
      switch (status) {
        case ErrorIncorrectKeyFile():
          result = AtOnboardingResult.error(
            message: strings.errorAtKeysInvalid,
          );
          break;
        case ErrorAtSignMismatch():
          result = AtOnboardingResult.error(
            message: strings.errorAtKeysUploadedMismatch,
          );
          break;
        case ErrorFailedFileProcessing():
          result = AtOnboardingResult.error(
            message: strings.errorAtKeysFileProcessFailed,
          );
          break;
        case ErrorAtServerUnreachable():
          result = AtOnboardingResult.error(
            message: strings.errorAtServerUnavailable,
          );
          break;
        case ErrorAuthFailed():
          result = AtOnboardingResult.error(
            message: strings.errorAuthenticatinFailed,
          );
          break;
        case ErrorAuthTimeout():
          result = AtOnboardingResult.error(
            message: strings.errorAuthenticationTimedOut,
          );
          break;
        case ErrorPairedAtsign _:
          result = AtOnboardingResult.error(
            message: strings.errorAtSignAlreadyPaired(status.atSign ?? atsign),
          );
          break;
        case FilePickingCanceled():
          result = AtOnboardingResult.cancelled();
          break;
        case FileUploadAuthSuccess _:
          result = AtOnboardingResult.success(atsign: status.atSign);
          break;
        // Progress states - notify caller via callback
        case FilePickingInProgress():
        case ProcessingAesKeyInProgress():
          onProgress?.call(status); // Notify the caller
          break;
        case FilePickingDone():
        case ProcessingAesKeyDone():
          break;
      }

      // Break out if we have a final result
      if (result != null) break;
    }

    return result;
  }
}
