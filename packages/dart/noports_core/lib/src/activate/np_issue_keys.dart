import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:at_auth/at_auth.dart'
    show
        AtEnrollmentResponse,
        ApprovedRequestDecisionBuilder,
        EnrollmentRequestDecision;
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
    show requestEnrollmentOtp, createAtClient;
import 'package:at_utils/at_logger.dart';
import 'package:chalkdart/chalk.dart';
import 'package:noports_core/src/activate/np_activate_params.dart';
import 'package:noports_core/src/activate/utils/console.dart';
import 'package:noports_core/src/activate/utils/constants.dart';
import 'package:noports_core/src/activate/utils/usage_messages.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as p;

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
  static const otpExpiryString = '${_otpExpiry}s';
  static const _enrollmentCheckInterval = 3; // in seconds
  static const _maxRetries = _otpExpiry / _enrollmentCheckInterval;
  static final _stateFilePath = p.join(
    Directory.current.path,
    'noports.issue-keys.state',
  );
  static final _stateFile = File(_stateFilePath);

  late final EnrollmentService _enrollmentService;
  late final AtClient _atClient;
  final NPActivateParams _params;

  final AtSignLogger logger = AtSignLogger(
    'NPIssueKeys',
    loggingHandler: CLILoggingHandler(),
  )..level = 'info';

  NPIssueKeys._(this._params);

  /// Creates and initializes an instance.
  ///
  /// Attempts to resume from a state file if present, otherwise parses
  /// command-line arguments. Establishes connection to atServer and
  /// initializes the enrollment service.
  factory NPIssueKeys.fromArgs(List<String> args) {
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }

    NPActivateParams? params;
    // Resume from state file if present
    if (_stateFile.existsSync()) {
      final content = _stateFile.readAsStringSync();
      params = NPActivateParams.fromJson(jsonDecode(content));
      stderr.writeln('Found state file. Resuming...\n');
    }

    params ??= NPActivateParams.fromArgs(args);

    return NPIssueKeys._(params);
  }

  // File get stateFile => File(_stateFilePath);

  /// Entry point for the `issue-keys` command.
  ///
  /// Orchestrates the complete enrollment flow: prompts for missing parameters,
  /// generates OTP, waits for enrollment request, and approves it.
  ///
  /// Returns: 0 on success, 1 on failure
  Future<int> wrappedMain() async {
    if (_params.showHelp) {
      stderr.writeln(UsageMessages.issueKeysHelp);
      return 0;
    }

    await _initAtClient();
    _params.otp ??= await requestEnrollmentOtp(
      _atClient,
      otpExpiry: otpExpiryString,
    );
    await _promptForMissingParams();
    await _createStateFile(_params);
    _displayActivationCommand();

    try {
      await _waitForAndApproveEnrollment();
    } finally {
      if (_stateFile.existsSync()) _stateFile.deleteSync(); // Cleanup stateFile
    }
    return 0;
  }

  Future<void> _initAtClient() async {
    stderr.write(chalk.blue('Connecting...\t'));
    _atClient = await createAtClient(
      atSign: _params.atsign,
      atKeysFilePath: _params.atKeysFilePath,
    );
    stderr.writeln('\n');

    _enrollmentService = DefaultAtServiceFactory().enrollmentService(_atClient);
  }

  Future<void> _promptForMissingParams() async {
    _params.atKeysFilePath ??= promptUser('atKeys file path (target location)');

    _params.deviceName ??=
        promptUser('deviceName') ?? '$_defaultDeviceNamePrefix${_params.otp}';
  }

  /// Writes the state file that store the [NPActivateParams]
  ///
  /// State file is used to resume the
  Future<void> _createStateFile(NPActivateParams params) async {
    final stateFile = File(_stateFilePath);
    if (stateFile.existsSync()) return;

    final jsonString = jsonEncode(params.toJson());
    stateFile.createSync();

    final sink = stateFile.openWrite();
    sink.write(jsonString);
    await sink.flush();
    await sink.close();

    logger.finer('Successfully created state file: $_stateFilePath');
  }

  void _displayActivationCommand() {
    final activationStr = _generateEnrollCommand(_params);
    logger.info(
      'Copy the string below and run `noports activate <string>`:\n'
      '\n\tNoPorts Desktop:\n\t$activationStr\n'
      '\n\tNoPorts CLI:\n\tnoports activate \'$activationStr\'\n',
    );
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

  Future<void> _waitForAndApproveEnrollment() async {
    final enrollment = await _waitForMatchingEnrollment(_params);
    final response = await _approveEnrollment(enrollment);

    if (response.enrollStatus != EnrollmentStatus.approved) {
      throw AtEnrollmentException(
        'Failed to approve enrollment.\nStatus: $response',
      );
    }

    logger.info('Enrollment approved: ${response.enrollmentId}\n');
  }

  Future<AtEnrollmentResponse> _approveEnrollment(Enrollment enrollment) async {
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

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
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

    throw AtEnrollmentException('OTP expired. Please re-run the command');
  }
}
