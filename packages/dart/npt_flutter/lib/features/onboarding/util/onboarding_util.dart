import 'dart:async';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_lookup/at_lookup.dart'
    show AtSignServerCheck, AtSignServerState, checkAtSignServer;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
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

class NoPortsOnboardingUtil {
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

  /// Where [atsign] stands: whether the atDirectory knows it, whether its
  /// atServer answers, and whether it has been activated.
  Future<AtSignServerCheck> checkAtServer(Atsign atsign) async {
    final lookUp = secureSocketLookUps()(
      atSign: atsign,
      rootDomain: AtRootDomain(rootDomain, 64),
      authenticator: null,
    );
    try {
      return await checkAtSignServer(lookUp, atsign);
    } finally {
      await lookUp.close();
    }
  }

  /// Drops the keychain entry for [atsign] when the atServer says it is not
  /// activated.
  ///
  /// Resetting an atsign on the registrar wipes the atServer but leaves this
  /// device's copy of the keys behind. Those keys can never authenticate again,
  /// and activation refuses to overwrite them, so every re-activation attempt
  /// fails until they are removed.
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

    AtSignServerCheck check;
    try {
      check = await checkAtServer(atsign);
    } catch (e) {
      App.log('Error checking the atServer: $e'.loggable);

      return NoPortsOnboardingResult.error(
        message: strings.errorAtServerUnavailable,
      );
    }

    if (!context.mounted) return null;

    final initialState = check.state;
    NoPortsOnboardingResult? result;

    switch (initialState) {
      // NOTE: a newly registered atsign has no atDirectory entry until it is
      // provisioned, so a miss goes on to activation, which waits for it.
      case AtSignServerState.notInDirectory:
      case AtSignServerState.directoryUnreachable:
        await Future.delayed(const Duration(seconds: 2));
        if (!context.mounted) return null;
        try {
          final retry = await checkAtServer(atsign);
          if (!context.mounted) return null;
          if (retry.state == AtSignServerState.activated) {
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
          initialState: initialState,
          strings: strings,
        );

      case AtSignServerState.notActivated:
        result = await _handleActivation(
          context: context,
          atsign: atsign,
          initialState: initialState,
          strings: strings,
        );

      case AtSignServerState.activated:
        result = await _handleActivatedAtsign(
          context: context,
          atsign: atsign,
          strings: strings,
        );

      case AtSignServerState.atServerUnreachable:
        result = NoPortsOnboardingResult.error(
          message: strings.errorAtServerUnavailable,
        );
    }

    return result;
  }

  /// Handles activation flow for atsigns that are not yet activated, not yet
  /// in the atDirectory, or whose atDirectory could not be reached
  Future<NoPortsOnboardingResult?> _handleActivation({
    required BuildContext context,
    required Atsign atsign,
    AtSignServerState? initialState,
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
        waitForTeapot: initialState != AtSignServerState.notActivated,
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
    final String? defaultDir = await _defaultAtKeysDir();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['atKeys'],
      initialDirectory: defaultDir,
    );
    if (result == null || result.files.isEmpty) {
      return NoPortsOnboardingResult.cancelled();
    }

    final atKeysIo = FileAtKeysIo(filePath: (_) => result.files.single.path!);

    try {
      final client = await AtClientMethods.openAndAdopt(
        atsign: atsign,
        keys: atKeysIo,
        rootDomain: rootDomain,
      );
      final state = client.connection.current;
      if (state.isRefused) {
        await client.stop();
        return NoPortsOnboardingResult.error(
          message: describeOnboardingError(state.error, strings),
        );
      }
      await _backUpToKeychain(atsign, atKeysIo);
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

  /// Copies the keys a file sign in opened on into the keychain, unless it
  /// already holds the atsign.
  Future<void> _backUpToKeychain(Atsign atsign, AtKeysIo source) async {
    final held = await KeychainStorage().getAllAtsigns();
    if (held.contains(atsign)) return;
    await KeychainAtKeysIo().write(atsign, await source.read(atsign));
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
    } else {
      atsign ??= options.keys.first.toAtsign();
    }
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

  /// Signs in to [atsign] on [rootDomain] - from the keychain when it holds
  /// keys for it, otherwise by activation or enrollment - and goes to the
  /// home page, or shows why it could not. Returns the outcome, or null if
  /// [context] went away before there was one to act on.
  Future<NoPortsOnboardingResult?> onboard({
    required Atsign atsign,
    required String rootDomain,
    required BuildContext context,
    bool isFromInitState = false,
  }) async {
    var atsigns = await KeychainStorage().getAllAtsigns();

    NoPortsOnboardingResult? onboardingResult;

    if (!context.mounted) return null;
    final strings = AppLocalizations.of(context)!;

    if (atsigns.contains(atsign)) {
      Object? authFailure;
      bool revokedByServer = false;
      try {
        final client = await AtClientMethods.openAndAdopt(
          atsign: atsign,
          keys: KeychainAtKeysIo(),
          rootDomain: rootDomain,
        );
        final state = client.connection.current;
        if (state.isRefused) {
          await client.stop();
          revokedByServer = state.cause == AtConnectionCause.revoked;
          authFailure = state.error ?? strings.errorAuthenticatinFailed;
        } else {
          onboardingResult = NoPortsOnboardingResult.success(atsign: atsign);
        }
      } on AtEnrollmentPendingException {
        // The keychain holds an enrollment this device submitted and never
        // completed; the APKAM flow picks it up where it left off.
        if (!context.mounted) return null;
        onboardingResult = await handleAtsignByStatus(
          context: context,
          atsign: atsign,
        );
      } catch (e) {
        App.log('Authentication failed for $atsign: $e'.loggable);
        authFailure = e;
      }

      if (authFailure != null) {
        final String errorDetail = authFailure is String
            ? authFailure
            : onboardingErrorDetail(authFailure);

        final bool isRevoked =
            revokedByServer ||
            errorDetail.contains('AT0027') ||
            errorDetail.contains('is revoked');

        if (isRevoked) {
          await discardStaleKeys(atsign);
          if (!context.mounted) return null;
          onboardingResult = await handleAtsignByStatus(
            context: context,
            atsign: atsign,
          );
        } else {
          AtSignServerState? state;
          try {
            state = (await checkAtServer(atsign)).state;
          } catch (_) {
            state = null;
          }

          if (state == AtSignServerState.notActivated) {
            await discardStaleKeys(atsign);
            if (!context.mounted) return null;
            onboardingResult = await handleAtsignByStatus(
              context: context,
              atsign: atsign,
            );
          } else {
            onboardingResult = NoPortsOnboardingResult.error(
              message: authFailure is String
                  ? authFailure
                  : describeOnboardingError(authFailure, strings),
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

    if (!context.mounted) return null;
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

        if (!context.mounted) return onboardingResult;
        // Replace the whole root stack: pushing a second [HomeWrapperWidget]
        // on top of an existing one duplicates the `wrapperNav` GlobalKey,
        // which reparents the old navigator (keeping the old page) under a
        // fresh wrapper.
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil(Routes.home, (route) => false);

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
    return onboardingResult;
  }

  static Future<String?> _defaultAtKeysDir() async {
    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return null;
    final Directory dir = Directory(p.join(home, '.atsign', 'keys'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }
}
