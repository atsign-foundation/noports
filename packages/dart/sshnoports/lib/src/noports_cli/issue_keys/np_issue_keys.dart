import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:at_auth/at_auth.dart'
    show
    AtEnrollmentResponse,
    ApprovedRequestDecisionBuilder,
    EnrollmentRequestDecision;
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart'
    show
    EnrollmentService,
    Enrollment,
    EnrollmentListRequestParam,
    DefaultAtServiceFactory,
    EnrollmentStatus,
    AtEnrollmentException,
    AtClient;
import 'package:at_onboarding_cli/at_onboarding_cli.dart'
    show requestEnrollmentOtp;
import 'package:at_utils/at_logger.dart';
import 'package:chalkdart/chalk.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/noports_cli/activate/np_activate_params.dart';
import 'package:sshnoports/src/noports_cli/util/constants.dart';

import '../util/cli_logging_handler.dart';

/// Handles the issuance of enrollment keys for new device enrollment.
///
/// This class manages the enrollment flow:
/// 1. Generates an OTP and enrollment command
/// 2. Waits for the enrollment request from the new device
/// 3. Approves the enrollment request
class NPIssueKeys {
  static const _baseEnrollCommand = '<atsign>:enroll:otp:<otp>';
  static const _defaultDeviceNamePrefix = 'noports_';
  static const _otpExpiry = 3600; // in seconds (1 hour)
  static const _enrollmentCheckInterval = 3; // in seconds
  static const _maxRetries = _otpExpiry / _enrollmentCheckInterval;
  static final _stateFilePath =
  p.join(Directory.current.path, 'noports.issue-keys.state');

  final EnrollmentService _enrollmentService;
  final AtClient _atClient;
  final NPActivateParams _params;

  final AtSignLogger logger =
  AtSignLogger('NPIssueKeys', loggingHandler: CLILoggingHandler())
    ..level = 'info';

  NPIssueKeys._(this._enrollmentService, this._atClient, this._params);

  /// Creates and initializes an instance.
  ///
  /// Attempts to resume from a state file if present, otherwise parses
  /// command-line arguments. Establishes connection to atServer and
  /// initializes the enrollment service.
  static Future<NPIssueKeys> create(List<String> args) async {
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }

    NPActivateParams? params;

    // Resume from state file if present
    final stateFile = File(_stateFilePath);
    if (stateFile.existsSync()) {
      final content = stateFile.readAsStringSync();
      params = NPActivateParams.fromJson(jsonDecode(content));
      stderr.writeln('Found state file. Resuming...\n');
    }

    params ??= NPActivateParams.fromArgs(args);

    stderr.write(chalk.blue('Connecting...\t'));
    final atClient = await createAtClientCli(
      atsign: params.atsign,
      atServiceFactory: DefaultAtServiceFactory(),
      namespace: defaultCurrentNamespace,
      storagePath: standardAtClientStoragePath(
        baseDir: getHomeDirectory()!,
        atSign: params.atsign,
        progName: defaultCurrentNamespace,
      ),
    );
    stderr.writeln(chalk.green('Connected\n'));

    final service = DefaultAtServiceFactory().enrollmentService(atClient);

    return NPIssueKeys._(service, atClient, params);
  }

  /// Entry point for the `issue-keys` command.
  ///
  /// Orchestrates the complete enrollment flow: prompts for missing parameters,
  /// generates OTP, waits for enrollment request, and approves it.
  ///
  /// Returns: 0 on success, 1 on failure
  Future<int> wrappedMain() async {
    // Prompt for missing parameters
    _params.atKeysFilePath ??=
        _promptUser('atKeys file path (target location): ');

    // Generate enrollment OTP
    final otpExpiryString = '${_otpExpiry}s';
    _params.otp ??=
    await requestEnrollmentOtp(_atClient, otpExpiry: otpExpiryString);

    _params.deviceName ??= _promptUser('deviceName: ') ??
        '$_defaultDeviceNamePrefix${_params.otp}';

    await _createStateFile(_params);

    // Display enrollment command for user
    final activationStr = _generateEnrollCommand(_params);
    logger.info(
      'Copy the string below and run `noports activate <string>`:\n'
          '\n\tNoPorts Desktop:\n\t$activationStr\n'
          '\n\tNoPorts CLI:\n\tnoports activate \'$activationStr\'\n',
    );

    // Wait for and approve enrollment
    try {
      final enrollment = await _waitForMatchingEnrollment(_params);
      final response = await _approveFirstPendingEnrollment(enrollment);

      if (response.enrollStatus != EnrollmentStatus.approved) {
        throw AtEnrollmentException('Failed to approve enrollment.\nStatus: $response');
      }

      logger.info('Enrollment approved: ${response.enrollmentId}\n');
    } catch (e) {
      rethrow;
    } finally {
      // Clean up state file after success
      final f = File(_stateFilePath);
      if (f.existsSync()) f.deleteSync();
    }
    return 0;
  }

  /// Writes the state file using atomic write to avoid corruption.
  Future<void> _createStateFile(NPActivateParams params) async {
    final stateFile = File(_stateFilePath);
    if (stateFile.existsSync()) return;

    final jsonString = jsonEncode(params.toJson());
    stateFile.createSync();

    final sink = stateFile.openWrite();
    sink.write(jsonString);
    await sink.flush();
    await sink.close();

    logger.finer('Successfully wrote state file: $_stateFilePath');
  }

  /// Builds the activation command string.
  ///
  /// Format: `<atsign>:enroll:otp:<otp>[:name:<deviceName>:keyfile:<path>]`
  String _generateEnrollCommand(NPActivateParams params) {
    final buffer = StringBuffer();

    buffer.write(
      _baseEnrollCommand
          .replaceFirst('<atsign>', params.atsign)
          .replaceFirst('<otp>', params.otp!),
    );

    // Append optional parameters
    buffer.write('[:name:${params.deviceName}');
    final keyFile = params.atKeysFilePath;
    if (keyFile?.isNotEmpty == true) {
      buffer.write(':keyfile:$keyFile');
    }
    buffer.write(']');

    return buffer.toString();
  }

  /// Approves the given enrollment request.
  Future<AtEnrollmentResponse> _approveFirstPendingEnrollment(
      Enrollment enrollment,
      ) async {
    logger.info('Approving enrollment...');

    final decisionBuilder = ApprovedRequestDecisionBuilder(
      enrollmentId: enrollment.enrollmentId!,
      encryptedAPKAMSymmetricKey: enrollment.encryptedAPKAMSymmetricKey!,
    );

    final decision = EnrollmentRequestDecision.approved(decisionBuilder);

    return _enrollmentService.approve(decision);
  }

  /// Polls until a matching pending enrollment request is found.
  ///
  /// Checks every [_enrollmentCheckInterval] seconds for up to [_maxRetries]
  /// attempts before timing out.
  ///
  /// Throws: [AtEnrollmentException] if OTP expires before enrollment found
  Future<Enrollment> _waitForMatchingEnrollment(NPActivateParams params) async {
    logger.info(
      'Waiting for enrollment request '
          '(retry every ${_enrollmentCheckInterval}s)...',
    );

    final req = EnrollmentListRequestParam()
      ..deviceName = params.deviceName
      ..appName = defaultAppName
      ..namespace = defaultEnrollmentNamespaces.toString()
      ..enrollmentListFilter = [EnrollmentStatus.pending];

    logger.info('Listening...');

    for (int retryCount = 0; retryCount < _maxRetries; retryCount++) {
      final results = await _enrollmentService.fetchEnrollmentRequests(
        enrollmentListParams: req,
      );

      if (results.isEmpty) {
        await Future.delayed(Duration(seconds: _enrollmentCheckInterval));
        continue;
      }

      final e = results.first;
      logger.finer('Found matching enrollments: $results');
      logger.info('Enrollment found with id: ${e.enrollmentId}');
      return e;
    }

    throw AtEnrollmentException('OTP expired. Re-run the command');
  }

  /// Prompts the user for input via stdin.
  ///
  /// Returns: trimmed string or null if input is empty
  String? _promptUser(String prompt) {
    stderr.write(prompt);
    final input = stdin.readLineSync();

    if (input == null || input.trim().isEmpty) {
      logger.warning('No input provided; using default\n');
      return null;
    }

    return input.trim();
  }
}