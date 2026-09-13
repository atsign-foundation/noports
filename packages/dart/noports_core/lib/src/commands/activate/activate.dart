import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart' show getHomeDirectory;
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/commands.dart';
import 'package:noports_core/src/commands/activate/activate_params.dart';
import 'package:path/path.dart' as path;

/// The two lifecycle verbs [Activate] runs, as one object a test can stand
/// in for: the verbs themselves are extension methods on `Atsign`, which no
/// mock can intercept. Each hands back the client it opened.
class ActivateFlows {
  const ActivateFlows();

  Future<AtClient> activate(
    Atsign atsign, {
    required String cramSecret,
    required WrittenAtKeysIo keys,
    required AtClientPreference preference,
    AtClientStorage? storage,
  }) =>
      atsign.activate(
          cramSecret: cramSecret,
          keys: keys,
          preference: preference,
          storage: storage);

  /// Submits the enrollment and waits for its approval; a denial throws
  /// `AtEnrollmentException`.
  Future<AtClient> enroll(
    Atsign atsign, {
    required String otp,
    required String app,
    required String device,
    required Map<String, String> namespaces,
    required WrittenAtKeysIo keys,
    required AtClientPreference preference,
    AtClientStorage? storage,
  }) async {
    final pending = await atsign.enroll(
        otp: otp,
        app: app,
        device: device,
        namespaces: namespaces,
        keys: keys,
        preference: preference);
    return pending.client(preference, storage: storage);
  }
}

class Activate {
  final ActivateParams _params;

  final ActivateFlows _flows;

  final logger = AtSignLogger('Activate', loggingHandler: CLILoggingHandler())
    ..level = 'info';

  Activate(this._flows, this._params);

  factory Activate.fromArgs(List<String> args) {
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }
    return Activate(const ActivateFlows(), ActivateParams.fromArgs(args));
  }

  /// Entry point for the activate command
  Future<int> wrappedMain() async {
    _setLoggingLevel();

    switch (_params.type) {
      case ActivateType.cram:
        return await cramAuthenticate();
      case ActivateType.enroll:
        return await enroll();
    }
  }

  void _setLoggingLevel() {
    if (_params.verbose) {
      AtSignLogger.root_level = 'INFO';
    }
    if (_params.debug) {
      AtSignLogger.root_level = 'FINEST';
      logger.level = 'FINEST';
    }
  }

  /// The keyfile the activation or enrollment writes: the one `-t` named, or
  /// the atSign's default under the user's home.
  FileAtKeysIo _keys() => FileAtKeysIo(
      filePath: (_) =>
          _params.atKeysFilePath ??
          path.join(getHomeDirectory(throwIfNull: true)!, '.atsign', 'keys',
              '${_params.atsign}_key.atKeys'));

  AtOnboardingPreference _preference() => AtOnboardingPreference()
    ..rootDomain = _params.rootDomain
    ..namespace = _params.appName;

  /// Activates a newly registered atSign with its CRAM secret, writing its
  /// keys to the keyfile. The client the activation opens is stopped at
  /// once: this command wants the keys, not a session.
  ///
  /// Returns: 0 if activation succeeds, 1 in case of failure
  /// Throws: [ArgumentError] if cram credentials are missing
  Future<int> cramAuthenticate() async {
    if (_params.cramSecret == null) {
      throw ArgumentError('Cannot perform CRAM auth without secret');
    }
    logger.info('Activating atsign: ${_params.atsign}');

    _validateAndPrepareKeysFile();
    final preference = _preference();
    try {
      final client = await _flows.activate(_params.atsign,
          cramSecret: _params.cramSecret!,
          keys: _keys(),
          preference: preference,
          storage: preference.storageFor(_params.atsign));
      await client.stop();
    } catch (e) {
      logger.shout('Activation Failed: $e');
      return 1;
    }
    logger.info('Activated');
    return 0;
  }

  /// Enrolls a new device using APKAM enrollment, writing its keys to the
  /// keyfile once the atSign's owner approves. The client the approval
  /// opens is stopped at once.
  ///
  /// Requires [_params.otp] and [_params.device] to be set.
  /// Optionally uses [_params.atKeysFilePath] if provided.
  ///
  /// Returns: 0 once the enrollment is approved, 1 if it is denied or fails
  /// Throws: [ArgumentError] if otp is missing
  Future<int> enroll() async {
    if (_params.otp == null) {
      throw ArgumentError('Cannot create enrollment without otp');
    }
    logger.info(
      'Creating new enrollment with deviceName: ${_params.deviceName}',
    );

    _validateAndPrepareKeysFile();
    final preference = _preference();
    try {
      final client = await _flows.enroll(_params.atsign,
          otp: _params.otp!,
          app: _params.appName,
          device: _params.deviceName!,
          namespaces: _params.namespaces,
          keys: _keys(),
          preference: preference,
          storage: preference.storageFor(_params.atsign));
      await client.stop();
    } on AtEnrollmentException catch (e) {
      logger.shout('Enrollment not approved: ${e.message}');
      return 1;
    }
    logger.info('Enrolled');
    return 0;
  }

  /// Validates and prepares the atKeys file location before enrollment.
  ///
  /// This method checks if a keys file already exists at the target location
  /// and prompts the user to provide an alternate location if a file is found.
  /// This prevents accidentally overwriting existing authentication keys
  /// during enrollment.
  ///
  /// The validation flow:
  /// 1. If [_params.atKeysFilePath] is provided, checks that custom path
  /// 2. If a file exists at either location, prompts the user for an alternate
  ///    path and updates [_params.atKeysFilePath]
  /// 3. If no file exists, returns without modification
  ///
  /// TODO: Replace this with AtKeysFile collision handler from OnboardingCLI
  void _validateAndPrepareKeysFile() {
    if (_params.atKeysFilePath != null) {
      if (!File(_params.atKeysFilePath!).existsSync()) {
        return;
      } else {
        _params.atKeysFilePath = promptUser(
          'Please provide alternate location to store keyfile',
        );
        logger.info('Writing keys to ${_params.atKeysFilePath}');
      }
    }
    return;
  }

  @visibleForTesting
  File? getKeysFile() {
    final path = _params.atKeysFilePath;
    return path != null ? File(path) : null;
  }
}
