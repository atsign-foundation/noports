import 'dart:async';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/at_client_activation.dart';
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

import '../../../app.dart';

// These types are returned from methods in this class so exports are provided for ease of use
export 'package:at_server_status/at_server_status.dart' show AtStatus;
export 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';

class NoPortsOnboardingUtil {
  AtServerStatus? _atServerStatus;
  late final AtClientPreference atClientPreference;
  late final String? appAPIKey;
  NoPortsOnboardingUtil._();

  static Future<NoPortsOnboardingUtil> create(BuildContext context) async {
    final util = NoPortsOnboardingUtil._();
    await util._initializeConfig(context);
    return util;
  }

  Future<void> _initializeConfig(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>().state;

    atClientPreference = await AtClientMethods.loadAtClientPreference(
      cubit.rootDomain,
    );
    appAPIKey = await Constants.appAPIKey;
  }

  AtRootDomain get _rootDomain =>
      AtRootDomain(atClientPreference.rootDomain, atClientPreference.rootPort);

  /// A method to check whether an atsign has been activated or not
  Future<AtStatus> atServerStatus(Atsign atsign) async {
    _atServerStatus ??= AtStatusImpl(
      rootUrl: atClientPreference.rootDomain,
      rootPort: atClientPreference.rootPort,
    );
    return _atServerStatus!.get(atsign);
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

    final apiKey = appAPIKey;
    if (apiKey == null) {
      return NoPortsOnboardingResult.error(
        message: strings.errorAtsignNotExist,
      );
    }

    Map<String, String> apis = {
      "root.atsign.org": "my.atsign.com",
      "root.atsign.wtf": "my.atsign.wtf",
    };

    final regUrl = apis[atClientPreference.rootDomain];
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
        apiKey: apiKey,
        atClientPreference: atClientPreference,
        registrarUrl: regUrl,
        onboardingUtil: this,
        waitForTeapot: initialStatus != AtSignStatus.teapot,
      ),
    );

    return result;
  }

  /// Handles flow for already activated atsigns (APKAM or atKeys file upload)
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
      result = await authenticateWithAtKeysFile(
        context: context,
        atsign: atsign,
        strings: strings,
      );
    } else {
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

  /// Pick an atKeys file and authenticate with it, persisting the keys to the
  /// keychain on success.
  Future<NoPortsOnboardingResult?> authenticateWithAtKeysFile({
    required BuildContext context,
    required Atsign atsign,
    required AppLocalizations strings,
  }) async {
    final FileAtKeysIo? atKeysIo = await AtKeysFileDialog.show(context);
    if (atKeysIo == null) {
      return NoPortsOnboardingResult.cancelled();
    }

    if (!context.mounted) return null;

    final AtAuthResponse? response = await PkamDialog.show(
      context,
      request: AtAuthRequest(
        atsign,
        rootDomain: _rootDomain,
        atKeysIo: atKeysIo,
      ),
      backupKeys: [KeychainAtKeysIo()],
    );

    if (response == null) {
      return NoPortsOnboardingResult.cancelled();
    }
    if (!response.isSuccessful) {
      return NoPortsOnboardingResult.error(
        message: strings.errorAuthenticatinFailed,
      );
    }
    await activateAtClientFromAuthResponse(
      atsign: atsign,
      atClientPreference: atClientPreference,
      response: response!,
    );
    return NoPortsOnboardingResult.success(atsign: atsign);
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

  Future<void> onboard({
    required Atsign atsign,
    required String rootDomain,
    required BuildContext context,
    bool isFromInitState = false,
  }) async {
    final strings = AppLocalizations.of(context)!;
    var atsigns = await KeychainStorage().getAllAtsigns();

    NoPortsOnboardingResult? onboardingResult;

    if (!context.mounted) return;

    if (atsigns.contains(atsign)) {
      final AtAuthResponse? response = await PkamDialog.show(
        context,
        request: AtAuthRequest(
          atsign,
          rootDomain: _rootDomain,
          atKeysIo: KeychainAtKeysIo(),
        ),
      );
      if (response == null) {
        onboardingResult = NoPortsOnboardingResult.cancelled();
      } else if (response.isSuccessful) {
        await activateAtClientFromAuthResponse(
          atsign: atsign,
          atClientPreference: atClientPreference,
          response: response,
        );
        onboardingResult = NoPortsOnboardingResult.success(atsign: atsign);
      } else {
        onboardingResult = NoPortsOnboardingResult.error(
          message: strings.errorAuthenticatinFailed,
        );
      }
    } else {
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
