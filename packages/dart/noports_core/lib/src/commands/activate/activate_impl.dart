import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_logger.dart';

import 'package:noports_core/commands.dart';
import 'package:noports_core/src/commands/activate/activate_params.dart';
import 'package:noports_core/utils.dart';

class Activate {
  final ActivateParams _params;

  final AtOnboardingService _onboardingService;

  final AtSignLogger logger = AtSignLogger(
    'NPActivate',
    loggingHandler: CLILoggingHandler(),
  )..level = 'info';

  Activate._(this._onboardingService, this._params);

  factory Activate.fromArgs(List<String> args) {
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }

    ActivateParams params = ActivateParams.fromArgs(args);

    final preference = AtOnboardingPreference()
      ..cramSecret = params.cramSecret
      ..atKeysFilePath = params.atKeysFilePath;
    AtOnboardingService service = AtOnboardingServiceImpl(params.atsign, preference);

    return Activate._(service, params);
  }

  /// Entry point for the activate command
  Future<int> wrappedMain() async {
    if (_params.showHelp) {
      stderr.writeln(UsageMessages.activateHelp);
      return 0;
    }

    switch (_params.type) {
      case ActivateType.cram:
        return await cramAuthenticate();
      case ActivateType.enroll:
        return await enroll();
    }
  }

  /// Authenticates an existing atSign using CRAM credentials
  ///
  /// Requires [_params.cramSecret] to be set
  ///
  /// Returns: 0 if authentication succeeds
  /// Throws: [ArgumentError] if cram credentials are missing
  Future<int> cramAuthenticate() async {
    if (_params.cramSecret == null) {
      throw ArgumentError('Cannot perform CRAM auth without secret');
    }
    logger.info('Activating atsign: ${_params.atsign}');

    final success = await _onboardingService.onboard();

    if (!success) {
      logger.shout('Activation Failed');
      return 1;
    }
    logger.info('Activated');
    return 0;
  }

  /// Enrolls a new device using APKAM enrollment
  ///
  /// Requires [_params.otp] and [_params.device] to be set.
  /// Optionally uses [_params.atKeysFilePath] if provided.
  ///
  /// Returns: [AtEnrollmentResponse] containing enrollment status and details
  /// Throws: [ArgumentError] if otp is missing
  Future<int> enroll() async {
    if (_params.otp == null) {
      throw ArgumentError('Cannot create enrollment without otp');
    }

    logger.info(
      'Creating new enrollment with deviceName: ${_params.deviceName}',
    );

    await _validateAndPrepareKeysFile();

    final response = await _onboardingService.enroll(
      _params.appName,
      _params.deviceName!,
      _params.otp!,
      _params.namespaces,
      atKeysFile: _getKeysFile(),
    );

    return response.enrollStatus == EnrollmentStatus.approved ? 0 : 1;
  }

  /// Validates and prepares the atKeys file location before enrollment.
  ///
  /// This method checks if a keys file already exists at the target location
  /// (either specified by the user or at the default path) and prompts the user
  /// to provide an alternate location if a file is found. This prevents
  /// accidentally overwriting existing authentication keys during enrollment.
  ///
  /// The validation flow:
  /// 1. If [_params.atKeysFilePath] is null, checks the default keys file path
  ///    from the [AtOnboardingPreference]
  /// 2. If [_params.atKeysFilePath] is provided, checks that custom path
  /// 3. If a file exists at either location, prompts the user for an alternate
  ///    path and updates [_params.atKeysFilePath]
  /// 4. If no file exists, returns without modification (safe to proceed)
  ///
  ///
  /// TODO: Replace [AtOnboardingServiceImpl] after ensuring that
  /// [AtOnboardingService] provides a standard way to check for existing keys
  /// files or throws a specific exception when keys files are missing.
  Future<void> _validateAndPrepareKeysFile() async {
    final String? keysFilePath;

    if (_params.atKeysFilePath == null) {
      // Use the default path from onboarding service preferences
      keysFilePath = (_onboardingService as AtOnboardingServiceImpl)
          .atOnboardingPreference
          .atKeysFilePath;
    } else {
      // Use the user-provided path
      keysFilePath = _params.atKeysFilePath;
    }

    if (keysFilePath == null && !File(keysFilePath!).existsSync()) {
      return;
    }

    logger.shout('KeysFile exists at $keysFilePath');
    _params.atKeysFilePath = promptUser(
      'Please provide alternate location to store keyfile',
    );
  }

  File? _getKeysFile() {
    final path = _params.atKeysFilePath;
    return path != null ? File(path) : null;
  }
}
