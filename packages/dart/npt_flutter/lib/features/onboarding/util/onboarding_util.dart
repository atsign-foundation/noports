import 'dart:async';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_contacts_flutter/utils/init_contacts_service.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/models/onboard_result.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_flutter/features/onboarding/util/profile_progress_listener.dart';
import 'package:npt_flutter/features/onboarding/widgets/apkam_choice_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_apkam_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/sign_in_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:npt_flutter/util/constants.dart';

import '../../../app.dart';

export 'package:at_server_status/at_server_status.dart' show AtStatus;
export 'package:npt_flutter/features/onboarding/models/onboard_result.dart';

/// Shared post-authentication initialisation called after every successful auth flow.
/// Callers must ensure any previous session is cleaned up (preSignout) before calling this.
Future<void> initializeAfterAuth({
  required Atsign atsign,
  required String rootDomain,
  required AtClientPreference atClientPreference,
  String? enrollmentId,
}) async {
  await AtClientManager.getInstance().setCurrentAtSign(
    atsign,
    Constants.namespace,
    atClientPreference,
    enrollmentId: enrollmentId,
  );
  await initializeContactsService(rootDomain: rootDomain);
  AtClientManager.getInstance().atClient.syncService.addProgressListener(
    ProfileProgressListener(),
  );
  AtClientManager.getInstance().atClient.syncService.sync();
  postOnboard(atsign, rootDomain);
  await saveAtsignInformation(
    AtsignInformation(atsign: atsign, rootDomain: rootDomain),
  );
  final backupKeyCubit = App.navState.currentContext!.read<BackupKeyCubit>();
  await backupKeyCubit.putBackupKeyStatus(backupKeyCubit.state);
}

class NoPortsOnboardingUtil {
  AtServerStatus? _atServerStatus;
  late final AtClientPreference _atClientPreference;
  late final String _rootDomain;
  late final String? _apiKey;

  NoPortsOnboardingUtil._();

  static Future<NoPortsOnboardingUtil> create(BuildContext context) async {
    final util = NoPortsOnboardingUtil._();
    await util._initialize(context);
    return util;
  }

  Future<void> _initialize(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>().state;
    _rootDomain = cubit.rootDomain;
    _atClientPreference = await AtClientMethods.loadAtClientPreference(
      _rootDomain,
    );
    _apiKey = await Constants.appAPIKey;
  }

  /// Check atServer status for an atsign.
  Future<AtStatus> atServerStatus(Atsign atsign) async {
    _atServerStatus ??= AtStatusImpl(
      rootUrl: _atClientPreference.rootDomain,
      rootPort: _atClientPreference.rootPort,
    );
    return _atServerStatus!.get(atsign);
  }

  /// Determine the correct onboarding flow based on atServer status and show
  /// the appropriate dialogs. Returns an [OnboardResult] describing the outcome.
  Future<OnboardResult?> handleAtsignByStatus({
    required BuildContext context,
    required Atsign atsign,
  }) async {
    final strings = AppLocalizations.of(context)!;

    AtStatus status;
    try {
      status = await atServerStatus(atsign);
    } catch (e) {
      App.log('Error checking atServerStatus: $e'.loggable);
      return OnboardError(strings.errorAtServerUnavailable);
    }

    if (!context.mounted) return null;

    switch (status.status()) {
      case AtSignStatus.unavailable:
      case AtSignStatus.teapot:
        return _handleActivation(
          context: context,
          atsign: atsign,
          strings: strings,
        );

      case AtSignStatus.activated:
        return _handleActivatedAtsign(
          context: context,
          atsign: atsign,
          strings: strings,
        );

      case AtSignStatus.notFound:
        return OnboardError(strings.errorAtsignNotExist);

      case null:
      case AtSignStatus.error:
        return OnboardError(strings.errorAtServerUnavailable);
    }
  }

  /// CRAM activation flow for unavailable/teapot atsigns.
  /// Shows [RegistrarCramDialog] to obtain OTP → CRAM key, then activates.
  Future<OnboardResult?> _handleActivation({
    required BuildContext context,
    required Atsign atsign,
    required AppLocalizations strings,
  }) async {
    // Mark backup as not done before activation
    context.read<BackupKeyCubit>().setBackupKeyStatus(false);

    final apiKey = _apiKey;
    if (apiKey == null) {
      return OnboardError(strings.errorAtsignNotExist);
    }

    const Map<String, String> registrarUrls = {
      'root.atsign.org': 'my.atsign.com',
      'root.atsign.wtf': 'my.atsign.wtf',
    };

    final registrarUrl = registrarUrls[_rootDomain];
    if (registrarUrl == null) {
      return OnboardError(strings.errorRootDomainNotSupported);
    }

    final registrar = RegistrarService(
      registrarUrl: registrarUrl,
      apiKey: apiKey,
    );
    final request = AtOnboardingRequest(
      atsign,
      rootDomain: AtRootDomain(_rootDomain, 64),
    );

    String? cramKey;
    try {
      cramKey = await RegistrarCramDialog.show(
        context,
        request,
        registrar: registrar,
      );
    } catch (e) {
      App.log('RegistrarCramDialog error: $e'.loggable);
      return OnboardError(e.toString());
    }

    if (cramKey == null) return OnboardCancelled();
    if (!context.mounted) return null;

    try {
      final response = await AuthService().onboard(request, cramKey);
      if (!response.isSuccessful) {
        return OnboardError(strings.errorAuthenticatinFailed);
      }
    } catch (e) {
      App.log('Onboard (CRAM) error: $e'.loggable);
      return OnboardError(e.toString());
    }

    // Backup required after CRAM activation (keys are new, not yet backed up)
    if (context.mounted) {
      context.read<BackupKeyCubit>().setBackupKeyStatus(false);
    }

    return OnboardSuccess(atsign.toAtsign());
  }

  /// Flow for already-activated atsigns: prompts for APKAM or atKeys file.
  Future<OnboardResult?> _handleActivatedAtsign({
    required BuildContext context,
    required Atsign atsign,
    required AppLocalizations strings,
  }) async {
    final flowChoice = await showDialog<APKAMFlow?>(
      context: context,
      routeSettings: const RouteSettings(name: 'APKAM choice'),
      builder: (context) => const ApkamChoiceDialog(),
    );

    if (flowChoice == null) return OnboardCancelled();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return null;

    OnboardResult? result;

    if (flowChoice == APKAMFlow.atKeys) {
      // --- File-upload flow ---
      final fileAtKeysIo = await AtKeysFileDialog.show(context);
      if (fileAtKeysIo == null) return OnboardCancelled();
      if (!context.mounted) return null;

      final authRequest = AtAuthRequest(
        atsign,
        atKeysIo: fileAtKeysIo,
        rootDomain: AtRootDomain(_rootDomain, 64),
      );
      final authResponse = await PkamDialog.show(
        context,
        request: authRequest,
        backupKeys: [KeychainAtKeysIo()],
      );

      if (authResponse == null) return OnboardCancelled();
      if (!authResponse.isSuccessful) {
        return OnboardError(strings.errorAuthenticatinFailed);
      }
      result = OnboardSuccess(atsign.toAtsign());
    } else {
      // --- APKAM flow ---
      result = await showDialog<OnboardResult>(
        context: context,
        routeSettings: const RouteSettings(name: 'APKAM onboarding'),
        barrierDismissible: false,
        builder: (context) => OnboardingApkamDialog(
          atsign: atsign,
          atClientPreference: _atClientPreference,
        ),
      );
    }

    // File-upload and APKAM flows don't need a forced backup (keys already exist)
    if (context.mounted && result is OnboardSuccess) {
      context.read<BackupKeyCubit>().setBackupKeyStatus(true);
    }

    return result;
  }

  /// Shows the sign-in dialog to let the user select an atsign.
  /// Returns true if the user confirmed and wants to proceed with onboarding.
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
    final result = await showDialog(
      context: App.navState.currentContext!,
      builder: (BuildContext context) => SignInDialog(options: options),
    );

    return result ?? false;
  }

  /// Main onboarding entry point.
  ///
  /// If [atsign] is already in the keychain, authenticates via PKAM.
  /// Otherwise, calls [handleAtsignByStatus] for the appropriate flow.
  Future<void> onboard({
    required Atsign atsign,
    required String rootDomain,
    required BuildContext context,
    bool isFromInitState = false,
  }) async {
    final atsigns = await KeychainStorage().getAllAtsigns();

    OnboardResult? onboardResult;

    if (!context.mounted) return;

    if (atsigns.contains(atsign)) {
      // --- Keychain flow: atsign has been authenticated before ---
      final authRequest = AtAuthRequest(
        atsign,
        atKeysIo: KeychainAtKeysIo(),
        rootDomain: AtRootDomain(rootDomain, 64),
      );
      final authResponse = await PkamDialog.show(context, request: authRequest);

      if (authResponse == null) {
        onboardResult = OnboardCancelled();
      } else if (authResponse.isSuccessful) {
        onboardResult = OnboardSuccess(atsign.toAtsign());
      } else {
        onboardResult = OnboardError(
          AppLocalizations.of(context)!.errorAuthenticatinFailed,
        );
      }
    } else {
      onboardResult = await handleAtsignByStatus(
        context: context,
        atsign: atsign,
      );
    }

    if (!context.mounted) return;

    switch (onboardResult) {
      case null:
      case OnboardCancelled():
        break;

      case OnboardError(:final message):
        if (isFromInitState) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(message),
          ),
        );

      case OnboardSuccess(:final atsign, :final enrollmentId):
        await initializeAfterAuth(
          atsign: atsign,
          rootDomain: rootDomain,
          atClientPreference: _atClientPreference,
          enrollmentId: enrollmentId,
        );
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pushNamed(Routes.home);
    }
  }
}
