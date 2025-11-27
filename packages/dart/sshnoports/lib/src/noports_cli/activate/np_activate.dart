import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_logger.dart';
import 'package:sshnoports/src/noports_cli/activate/np_activate_params.dart';
import 'package:sshnoports/src/noports_cli/util/cli_logging_handler.dart';

import '../util/usage_messages.dart';

enum NPActivateType {
  cram,
  enroll;

  static NPActivateType parse(String cmd) {
    if (cmd.contains('cram')) {
      return NPActivateType.cram;
    } else if (cmd.contains('enroll')) {
      return NPActivateType.enroll;
    }
    throw ArgumentError('Invalid argument string: $cmd');
  }
}

class NPActivate {
  final AtOnboardingService _onboardingService;
  final NPActivateParams _params;
  final NPActivateType _activateType;

  final AtSignLogger logger =
      AtSignLogger('NPActivate', loggingHandler: CLILoggingHandler())
        ..level = 'info';

  NPActivate._(this._onboardingService, this._activateType, this._params);

  factory NPActivate.fromArgs(List<String> args) {
    if (args.isEmpty) {
      throw ArgumentError('You must supply an argument string');
    }

    NPActivateParams params = NPActivateParams.fromArgs(args);
    NPActivateType activateType = NPActivateType.parse(args.first);

    AtOnboardingPreference preference = AtOnboardingPreference()
      ..cramSecret = params.cram;
    AtOnboardingService service =
        AtOnboardingServiceImpl(params.atsign, preference);

    return NPActivate._(service, activateType, params);
  }

  /// Entry point for the activate command
  Future<int> wrappedMain() async {
    if (_params.showHelp) {
      stderr.writeln(UsageMessages.activateHelp);
      return 0;
    }

    switch (_activateType) {
      case NPActivateType.cram:
        return await cramAuthenticate(_params);
      case NPActivateType.enroll:
        return await enroll(_params);
    }
  }

  /// Authenticates an existing atSign using CRAM credentials
  ///
  /// Requires [params.cram] to be set
  ///
  /// Returns: true if authentication succeeds
  /// Throws: [ArgumentError] if cram credentials are missing
  Future<int> cramAuthenticate(NPActivateParams params) async {
    validateArgs(params, NPActivateType.cram);

    logger.info('Activating atsign: ${params.atsign}');

    bool success = await _onboardingService.onboard();
    if (!success) {
      logger.info('Activated Failed');
      return 1;
    }
    logger.shout('Activated');
    return 0;
  }

  /// Enrolls a new device using APKAM enrollment
  ///
  /// Requires [params.otp] and [params.deviceName] to be set.
  /// Optionally uses [params.atKeysFilePath] if provided.
  ///
  /// Returns: [AtEnrollmentResponse] containing enrollment status and details
  /// Throws: [ArgumentError] if otp is missing
  Future<int> enroll(NPActivateParams params) async {
    validateArgs(params, NPActivateType.enroll);

    logger
        .info('Creating new enrollment with deviceName: ${params.deviceName}');

    AtEnrollmentResponse response = await _onboardingService.enroll(
        params.appName, params.deviceName!, params.otp!, params.namespaces,
        atKeysFile: params.atKeysFilePath != null
            ? File(params.atKeysFilePath!)
            : null);

    return response.enrollStatus == EnrollmentStatus.approved ? 0 : 1;
  }

  /// Validates that required parameters are present for the given activation [type]
  ///
  /// For CRAM: requires [params.cram]
  /// For ENROLL: requires [params.otp]
  ///
  /// Throws: [ArgumentError] if required parameters are missing
  void validateArgs(NPActivateParams params, NPActivateType type) {
    switch (type) {
      case NPActivateType.cram:
        if (params.cram == null) {
          throw ArgumentError(
            'Cannot perform CRAM auth without secret',
          );
        }
        break;
      case NPActivateType.enroll:
        if (params.otp == null) {
          throw ArgumentError(
            'Cannot create enrollment without otp',
          );
        }
    }
  }
}
