import 'dart:async';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_error.dart';
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

import '../../../app.dart';

export 'package:at_server_status/at_server_status.dart' show AtStatus;

class NoPortsOnboardingUtil {
  AtServerStatus? _atServerStatus;
  late final String rootDomain;
  late final String? apiKey;
  NoPortsOnboardingUtil._();

  static Future<NoPortsOnboardingUtil> create(BuildContext context) async {
    final util = NoPortsOnboardingUtil._();
    final cubit = context.read<OnboardingCubit>().state;
    util.rootDomain = cubit.rootDomain;
    util.apiKey = await Constants.appAPIKey;
    return util;
  }

  /// A method to check whether an atsign has been activated or not
  Future<AtStatus> atServerStatus(Atsign atsign) async {
    _atServerStatus ??= AtStatusImpl(rootUrl: rootDomain, rootPort: 64);
    return _atServerStatus!.get(atsign);
  }

  /// Drops the keychain entry for [atsign] when the atServer says it is not
  /// activated.
  ///
  /// Resetting an atsign on the registrar wipes the atServer but leaves this
  /// device's copy of the keys behind. Those keys can never authenticate again,
  /// and `AtAuth.onboard` refuses to run at all while they exist
  /// ("... is already onboarded. Cannot perform onboarding again."), so every
  /// re-activation attempt fails until they are removed.
  ///
  /// Returns true if stale keys were found and removed.
  static Future<bool> discardStaleKeys(Atsign atsign) async {
    final atsigns = await KeychainStorage().getAllAtsigns();
    if (!atsigns.contains(atsign)) return false;

    await KeychainStorage().removeAtsignFromKeychain(atsign);
    App.log(
      'Removed stale keychain keys for $atsign - the atServer reports it is '
              'not activated, so the stored keys are from a previous life of '
              'this atsign.'
          .loggable,
    );
    return true;
  }

  /// Handles onboarding an atsign by checking its status and showing appropriate dialogs
  /// This is shared between the main onboarding button and the switch atsign functionality
  Future<NoPortsOnboardingResult?> handleAtsignByStatus({
    required BuildContext context,
    required Atsign atsign,
  }) async {
    final strings = AppLocalizations.of(context)!;

    AtStatus status;
    try {
      status = await atServerStatus(atsign);
    } catch (e) {
      App.log('Error checking atServerStatus: $e'.loggable);

      return NoPortsOnboardingResult.error(
        message: strings.errorAtServerUnavailable,
      );
    }

    if (!context.mounted) return null;

    final initialStatus = status.status();
    NoPortsOnboardingResult? result;

    switch (initialStatus) {
      case AtSignStatus.unavailable:
        await Future.delayed(const Duration(seconds: 2));
        if (!context.mounted) return null;
        try {
          final AtSignStatus? retryStatus =
              (await atServerStatus(atsign)).status();
          if (retryStatus == AtSignStatus.activated) {
            result = await _handleActivatedAtsign(
              context: context,
              atsign: atsign,
              strings: strings,
            );
            break;
          }
        } catch (_) {}
        if (!context.mounted) return null;
        result = await _handleActivation(
          context: context,
          atsign: atsign,
          initialStatus: initialStatus,
          strings: strings,
        );

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
        );

      case AtSignStatus.notFound:
        result = NoPortsOnboardingResult.error(
          message: strings.errorAtsignNotExist,
        );

      case null:
      case AtSignStatus.error:
        result = NoPortsOnboardingResult.error(
          message: strings.errorAtServerUnavailable,
        );
    }

    return result;
  }

  /// Handles activation flow for unavailable/teapot atsigns
  Future<NoPortsOnboardingResult?> _handleActivation({
    required BuildContext context,
    required Atsign atsign,
    AtSignStatus? initialStatus,
    required AppLocalizations strings,
  }) async {
    // When onboarding from teapot, set backup status to false (atKeys not backed up)
    // False is initially saved in memory since access to the atServer is not available as yet.
    context.read<BackupKeyCubit>().setBackupKeyStatus(false);

    if (apiKey == null) {
      return NoPortsOnboardingResult.error(
        message: strings.errorAtsignNotExist,
      );
    }

    Map<String, String> apis = {
      "root.atsign.org": "my.atsign.com",
      "root.atsign.wtf": "my.atsign.wtf",
    };

    final regUrl = apis[rootDomain];
    if (regUrl == null) {
      return NoPortsOnboardingResult.error(
        message: strings.errorRootDomainNotSupported,
      );
    }

    final result = await showDialog<NoPortsOnboardingResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ActivateAtsignDialog(
        atsign: atsign,
        apiKey: apiKey!,
        rootDomain: rootDomain,
        registrarUrl: regUrl,
        onboardingUtil: this,
        waitForTeapot: initialStatus != AtSignStatus.teapot,
      ),
    );

    return result;
  }

  /// Handles flow for already activated atsigns (APKAM or file upload)
  Future<NoPortsOnboardingResult?> _handleActivatedAtsign({
    required BuildContext context,
    required Atsign atsign,
    required AppLocalizations strings,
  }) async {
    final flowChoice = await showDialog<APKAMFlow?>(
      context: context,
      routeSettings: const RouteSettings(name: 'APKAM choice'),
      builder: (context) => const ApkamChoiceDialog(),
    );

    if (flowChoice == null) {
      return NoPortsOnboardingResult.cancelled();
    }

    // Wait for the modal to close
    await Future.delayed(const Duration(milliseconds: 300));

    if (!context.mounted) return null;

    NoPortsOnboardingResult? result;

    if (flowChoice == APKAMFlow.atKeys) {
      result = await _handleAtKeysFileLogin(
        context: context,
        atsign: atsign,
        strings: strings,
      );
    } else {
      final atClientPreference = await AtClientMethods.loadAtClientPreference(
        rootDomain,
      );
      if (!context.mounted) return null;

      result = await showDialog<NoPortsOnboardingResult>(
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
    if (context.mounted &&
        result?.status == NoPortsOnboardingResultStatus.success) {
      context.read<BackupKeyCubit>().setBackupKeyStatus(true);
    }

    return result;
  }

  /// Authenticates an already-activated atsign from a local `.atKeys` file.
  Future<NoPortsOnboardingResult?> _handleAtKeysFileLogin({
    required BuildContext context,
    required Atsign atsign,
    required AppLocalizations strings,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['atKeys'],
    );
    if (result == null || result.files.isEmpty) {
      return NoPortsOnboardingResult.cancelled();
    }

    final atKeysIo = FileAtKeysIo(filePath: (_) => result.files.single.path!);
    final authRequest = AtAuthRequest(
      atsign,
      atKeysIo: atKeysIo,
      rootDomain: AtRootDomain.parse(rootDomain),
    );

    try {
      final response = await AuthService().authenticate(
        authRequest,
        backupKeys: [KeychainAtKeysIo()],
      );
      if (!response.isSuccessful) {
        return NoPortsOnboardingResult.error(
          message: strings.errorAuthenticatinFailed,
        );
      }
      await AtClientMethods.activateFromAuthResponse(response, rootDomain);
      return NoPortsOnboardingResult.success(atsign: atsign);
    } on AtTimeoutException {
      return NoPortsOnboardingResult.error(
        message: strings.errorAuthenticationTimedOut,
      );
    } catch (e) {
      // A bad atKeys file is only one of the ways this fails - report what
      // actually went wrong rather than blaming the file every time.
      App.log('atKeys sign in failed for $atsign: $e'.loggable);
      return NoPortsOnboardingResult.error(
        message: describeOnboardingError(e, strings),
      );
    }
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
    var atsigns = await KeychainStorage().getAllAtsigns();

    NoPortsOnboardingResult? onboardingResult;

    if (!context.mounted) return;

    if (atsigns.contains(atsign)) {
      Object? authFailure;
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
          authFailure = AppLocalizations.of(context)!.errorAuthenticatinFailed;
        }
      } catch (e) {
        App.log('Authentication failed for $atsign: $e'.loggable);
        authFailure = e;
      }

      if (authFailure != null) {
        final String errorDetail = authFailure is String
            ? authFailure
            : onboardingErrorDetail(authFailure);

        final bool isRevoked =
            errorDetail.contains('AT0027') || errorDetail.contains('is revoked');

        if (isRevoked) {
          await discardStaleKeys(atsign);
          if (!context.mounted) return;
          onboardingResult = await handleAtsignByStatus(
            context: context,
            atsign: atsign,
          );
        } else {
          AtSignStatus? status;
          try {
            status = (await atServerStatus(atsign)).status();
          } catch (_) {
            status = null;
          }

          if (status == AtSignStatus.teapot) {
            await discardStaleKeys(atsign);
            if (!context.mounted) return;
            onboardingResult = await handleAtsignByStatus(
              context: context,
              atsign: atsign,
            );
          } else {
            onboardingResult = NoPortsOnboardingResult.error(
              message: authFailure is String
                  ? authFailure
                  : describeOnboardingError(
                      authFailure,
                      AppLocalizations.of(context)!,
                    ),
            );
          }
        }
      }
    } else {
      // Use the shared util method
      onboardingResult = await handleAtsignByStatus(
        context: context,
        atsign: atsign,
      );
    }

    if (!context.mounted) return;
    switch (onboardingResult?.status ?? NoPortsOnboardingResultStatus.cancel) {
      case NoPortsOnboardingResultStatus.success:
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
      case NoPortsOnboardingResultStatus.error:
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
      case NoPortsOnboardingResultStatus.cancel:
        break;
    }
  }
}
