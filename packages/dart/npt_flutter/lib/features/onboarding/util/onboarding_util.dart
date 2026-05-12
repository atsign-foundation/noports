import 'dart:async';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_contacts_flutter/utils/init_contacts_service.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_flutter/features/onboarding/util/profile_progress_listener.dart';
import 'package:npt_flutter/features/onboarding/widgets/activate_atsign_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/apkam_choice_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_apkam_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/sign_in_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:npt_flutter/util/language.dart';

import '../../../app.dart';

// These types are returned from methods in this class so exports are provided for ease of use

export 'package:at_server_status/at_server_status.dart' show AtStatus;

class NoPortsOnboardingUtil {
  /// The upload service will be created when the first time [uploadAtKeysFile] is called
  AtKeysFileUploadService? _uploadService;
  AtServerStatus? _atServerStatus;
  late final AtOnboardingConfig config;
  NoPortsOnboardingUtil._();

  static Future<NoPortsOnboardingUtil> create(BuildContext context) async {
    final util = NoPortsOnboardingUtil._();
    await util._initializeConfig(context);
    return util;
  }

  Future<void> _initializeConfig(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>().state;

    config = AtOnboardingConfig(
      atClientPreference: await AtClientMethods.loadAtClientPreference(
        cubit.rootDomain,
      ),
      rootEnvironment: RootEnvironment.Production,
      domain: cubit.rootDomain,
      appAPIKey: await Constants.appAPIKey,
    );
  }

  /// A method to check whether an atsign has been activated or not
  Future<AtStatus> atServerStatus(Atsign atsign) async {
    _atServerStatus ??= AtStatusImpl(
      rootUrl: config.atClientPreference.rootDomain,
      rootPort: config.atClientPreference.rootPort,
    );
    return _atServerStatus!.get(atsign);
  }

  /// Upload an atKeys file, returning a stream with the progress so we can update the ui accordingly.
  /// Example implementation:
  /// https://github.com/atsign-foundation/at_widgets/blob/b4006854fa93c21eeb5bcea41044787bdf0f6f32/packages/at_onboarding_flutter/lib/src/screen/at_onboarding_home_screen.dart#L659
  Stream<FileUploadStatus> uploadAtKeysFile(Atsign? atsign) {
    _uploadService ??= AtKeysFileUploadService(config: config);
    return _uploadService!.uploadKeyFile(atsign);
  }

  /// Handles onboarding an atsign by checking its status and showing appropriate dialogs
  /// This is shared between the main onboarding button and the switch atsign functionality
  Future<AtOnboardingResult?> handleAtsignByStatus({
    required BuildContext context,
    required Atsign atsign,
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
        result = AtOnboardingResult.error(message: strings.errorAtsignNotExist);

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
    required Atsign atsign,
    AtSignStatus? initialStatus,
    required AppLocalizations strings,
  }) async {
    // When onboarding from teapot, set backup status to false (atKeys not backed up)
    // False is initially saved in memory since access to the atServer is not available as yet.
    context.read<BackupKeyCubit>().setBackupKeyStatus(false);

    final apiKey = await Constants.appAPIKey;
    if (apiKey == null) {
      return AtOnboardingResult.error(message: strings.errorAtsignNotExist);
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
        atsign: atsign,
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
      );
      if (!res) {
        return AtOnboardingResult.error(
          message: strings.errorSwitchAtsignFailed,
        );
      }
    }

    return result;
  }

  /// Handles flow for already activated atsigns (APKAM or file upload)
  Future<AtOnboardingResult?> _handleActivatedAtsign({
    required BuildContext context,
    required Atsign atsign,
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
    }

    // When onboarding via APKAM or uploading atKeys, set backup status to true.
    // True is initially saved in memory since access to the atServer is not available as yet.
    if (context.mounted && result?.status == AtOnboardingResultStatus.success) {
      context.read<BackupKeyCubit>().setBackupKeyStatus(true);
    }

    return result;
  }

  /// Handles file upload status stream and returns appropriate result
  Future<AtOnboardingResult?> _handleFileUploadStatusStream({
    required BuildContext context,
    required Stream<FileUploadStatus> statusStream,
    required Atsign atsign,
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
            message: strings.errorAtsignAlreadyPaired(status.atSign ?? atsign),
          );
          break;
        case FilePickingCanceled():
          result = AtOnboardingResult.cancelled();
          break;
        case FileUploadAuthSuccess _:
          result = AtOnboardingResult.success(atsign: status.atSign ?? atsign);
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

  /// Returns true if the user completed the selection and wants to proceed with onboarding. Returns false if the user cancelled the selection.
  /// Displays the onboarding dialog for the user to select an atsign. If there are no atsigns available, the atsign field will be blank.
  /// If there is an atsign available, it will be pre-selected along with its associated root domain.
  Future<bool> selectAtsign(BuildContext context) async {
    var options = await getAtsignEntries();

    final cubit = App.navState.currentContext!.read<OnboardingCubit>();
    Atsign? atsign = cubit.state.atsign;
    String? rootDomain = cubit.state.rootDomain;

    if (options.isEmpty) {
      atsign = null;
    } else
      atsign ??= options.keys.first.toAtsign();
    if (options.keys.contains(atsign)) {
      rootDomain = options[atsign]?.rootDomain;
    } else {
      rootDomain = Constants.getRootDomains(
        App.navState.currentContext!,
      ).keys.first;
    }

    cubit.setState(atsign: atsign, rootDomain: rootDomain);
    final results = await showDialog(
      context: App.navState.currentContext!,

      builder: (BuildContext context) => SignInDialog(options: options),
    );

    return results ?? false;
  }

  Future<void> onboard({
    required Atsign atsign,
    required String rootDomain,
    required BuildContext context,
    bool isFromInitState = false,
  }) async {
    var atsigns = await KeyChainManager.getInstance()
        .getAtSignListFromKeychain();

    AtOnboardingResult? onboardingResult;

    if (!context.mounted) return;

    if (atsigns.contains(atsign)) {
      onboardingResult = await AtOnboarding.onboard(
        atsign: atsign,
        context: context,
        config: config,
      );
    } else {
      // Use the shared util method with progress callback
      onboardingResult = await handleAtsignByStatus(
        context: context,
        atsign: atsign,
        onProgress: (status) {
          // Handle file upload progress states
          if (status is FilePickingInProgress ||
              status is ProcessingAesKeyInProgress) {
            // TODO: You can implement a progress indicator update here if needed
            App.log('File upload progress: $status'.loggable);
          }
        },
      );
    }

    if (!context.mounted) return;
    switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
      case AtOnboardingResultStatus.success:
        await initializeContactsService(rootDomain: rootDomain);
        AtClientManager.getInstance().atClient.syncService.addProgressListener(
          ProfileProgressListener(),
        );
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

        App.log('atsign result is:$result'.loggable);

        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pushNamed(Routes.home);

        break;
      case AtOnboardingResultStatus.error:
        if (isFromInitState) break;
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
        break;
    }
  }
}
