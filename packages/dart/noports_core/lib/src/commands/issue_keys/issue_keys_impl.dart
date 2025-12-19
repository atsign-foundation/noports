import 'dart:core';
import 'dart:io';

import 'package:at_auth/at_auth.dart'
    show
        ApprovedRequestDecisionBuilder,
        EnrollmentRequestDecision,
        AtEnrollmentResponse;
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
import 'package:noports_core/src/commands/issue_keys/issue_keys_params.dart';
import 'package:noports_core/src/commands/utils/constants.dart';
import 'package:noports_core/utils.dart';

/// Handles the issuance of enrollment keys for new device enrollment.
///
/// Manages the enrollment flow:
/// 1. Generates an OTP and enrollment command
/// 2. Waits for the enrollment request from the new device
/// 3. Approves the enrollment request
class IssueKeys {
  static const _baseEnrollCommand = '<atsign>:enroll:otp:<otp>';
  static const _defaultDeviceNamePrefix = 'noports_';

  static const _otpExpirySeconds = 3600; // 1 hour
  static const otpExpiryString = '${_otpExpirySeconds}s';

  static const _enrollmentCheckIntervalSeconds = 3;
  static const _maxRetries =
      _otpExpirySeconds / _enrollmentCheckIntervalSeconds;

  late final EnrollmentService _enrollmentService;
  late final AtClient _atClient;

  final IssueKeysParams _params;

  final logger = AtSignLogger('IssueKeys', loggingHandler: CLILoggingHandler())
    ..level = 'info';

  IssueKeys(this._params);

  factory IssueKeys.fromArgs(List<String> args) {
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }
    return IssueKeys(IssueKeysParams.fromArgs(args));
  }

  /// Entry point for the `issue-keys` command.
  ///
  /// Orchestrates the complete enrollment flow:
  /// 1. Initialize AtClient connection
  /// 2. Generate OTP
  /// 3. Set default device name, if not provided
  /// 4. Display activation command for user
  /// 5. Wait for and approve the enrollment request
  ///
  /// Returns: 0 on success, 1 on failure
  Future<int> wrappedMain() async {
    await _init();

    // Check for matching pending enrollment, approve if found | works like a resume
    final existingEnrollment = await _fetchMatchingEnrollment();
    if (existingEnrollment != null) {
      await _approveEnrollment(existingEnrollment);
      return 0;
    }

    await _generateOtpAndEnsureDeviceName();
    _displayActivationCommand();
    final enrollment = await _waitForMatchingEnrollment();
    await _approveEnrollment(enrollment);

    return 0;
  }

  Future<void> _init() async {
    stderr.write(chalk.blue('Connecting...\t'));

    _atClient = await createAtClient(
      atSign: _params.atsign,
      atKeysFilePath: _params.atKeysFilePath,
    );
    stderr.writeln('\n');

    _enrollmentService = DefaultAtServiceFactory().enrollmentService(_atClient);
  }

  /// Generated enrollment OTP
  ///
  /// Uses default device name(noports_<otp>) as fallback
  Future<void> _generateOtpAndEnsureDeviceName() async {
    _params.otp = await requestEnrollmentOtp(
      _atClient,
      otpExpiry: otpExpiryString,
    );

    _params.device ??= '$_defaultDeviceNamePrefix${_params.otp}';
  }

  void _displayActivationCommand() {
    final activationStr = _generateEnrollmentCommand();
    logger.info(
      'Copy the string below and run `noports activate <string>` on the other device:\n'
      '\n\tNoPorts Desktop:\n\t$activationStr\n'
      '\n\tNoPorts CLI:\n\tnoports activate \'$activationStr\'\n',
    );
  }

  /// Builds the activation command string.
  ///
  /// Format: `<atsign>:enroll:otp:<otp>[:name:<deviceName>]`
  String _generateEnrollmentCommand() {
    final buffer = StringBuffer();

    buffer.write(
      _baseEnrollCommand
          .replaceFirst('<atsign>', _params.atsign)
          .replaceFirst('<otp>', _params.otp!),
    );
    buffer.write('[:name:${_params.device}]'); // Optional parameter(s)

    return buffer.toString();
  }

  Future<void> _approveEnrollment(Enrollment enrollment) async {
    logger.info('Approving enrollment...');

    final decisionBuilder = ApprovedRequestDecisionBuilder(
      enrollmentId: enrollment.enrollmentId!,
      encryptedAPKAMSymmetricKey: enrollment.encryptedAPKAMSymmetricKey!,
    );

    final decision = EnrollmentRequestDecision.approved(decisionBuilder);
    AtEnrollmentResponse er = await _enrollmentService.approve(decision);

    if (er.enrollStatus != EnrollmentStatus.approved) {
      throw AtEnrollmentException('Failed to approve enrollment | $er');
    }

    logger.info('Enrollment approved: ${er.enrollmentId}\n');
    return;
  }

  /// Polls until a matching pending enrollment request is found.
  ///
  /// Checks every [_enrollmentCheckIntervalSeconds] seconds for up to [_maxRetries]
  /// attempts before timing out.
  ///
  /// Throws: [AtEnrollmentException] if OTP expires before enrollment found
  Future<Enrollment> _waitForMatchingEnrollment() async {
    logger.info(
      'Waiting for enrollment request '
      '(retry every ${_enrollmentCheckIntervalSeconds}s)...',
    );

    final rp = EnrollmentListRequestParam()
      ..deviceName = _params.device
      ..appName = defaultAppName
      ..namespace = defaultEnrollmentNamespaces.toString()
      ..enrollmentListFilter = [EnrollmentStatus.pending];

    logger.info('Listening...');

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      Enrollment? e = await _fetchMatchingEnrollment(requestParam: rp);

      if (e == null) {
        await Future.delayed(
          Duration(seconds: _enrollmentCheckIntervalSeconds),
        );
        continue;
      }
      return e;
    }
    throw AtEnrollmentException('OTP expired. Please re-run the command');
  }

  Future<Enrollment?> _fetchMatchingEnrollment({
    EnrollmentListRequestParam? requestParam,
  }) async {
    requestParam ??= EnrollmentListRequestParam()
      ..deviceName = _params.device
      ..appName = defaultAppName
      ..namespace = defaultEnrollmentNamespaces.toString()
      ..enrollmentListFilter = [EnrollmentStatus.pending];

    final results = await _enrollmentService.fetchEnrollmentRequests(
      enrollmentListParams: requestParam,
    );
    logger.finer('Found matching enrollments: ${results.toString()}');

    if (results.isNotEmpty) {
      logger.info('Enrollment found with id: ${results.first.enrollmentId}');
      return results.first;
    }

    return null;
  }
}
