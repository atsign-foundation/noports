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
import 'package:meta/meta.dart';
import 'package:noports_core/src/commands/issue_keys/issue_keys_params.dart';
import 'package:noports_core/src/commands/utils/constants.dart';

/// Handles the issuance of enrollment keys for new device enrollment.
///
/// Manages the enrollment flow:
/// 1. Generates an OTP and enrollment command
/// 2. Waits for the enrollment request from the new device
/// 3. Approves the enrollment request
class IssueKeys {
  static const _baseEnrollCommand = '<atsign>:enroll:otp:<otp>:name:<device>';
  static const _defaultDeviceNamePrefix = 'noports_';

  static const _otpExpirySeconds = 3600; // 1 hour
  static const _otpExpiryString = '${_otpExpirySeconds}s';
  static const _enrollmentCheckIntervalSeconds = 3;

  static final _defaultMaxRetries =
      (_otpExpirySeconds / _enrollmentCheckIntervalSeconds).floor();
  final int _maxRetries;
  final Duration _checkInterval;

  EnrollmentService? _enrollmentService;
  AtClient? _atClient;

  @protected
  final IssueKeysParams params;

  final logger = AtSignLogger('IssueKeys', loggingHandler: CLILoggingHandler())
    ..level = 'info';

  IssueKeys(
    this.params, {
    AtClient? atClient,
    EnrollmentService? enrollmentService,
    int? maxRetries,
    Duration? checkInterval,
  }) : _atClient = atClient,
       _enrollmentService = enrollmentService,
       _maxRetries = maxRetries ?? _defaultMaxRetries,
       _checkInterval =
           checkInterval ?? Duration(seconds: _enrollmentCheckIntervalSeconds);

  factory IssueKeys.fromArgs(List<String> args) {
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }

    final params = IssueKeysParams.fromArgs(args);
    return IssueKeys(params);
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
    _setLoggingLevel();
    await _init();

    // Check for matching pending enrollment, approve if found | works like a resume
    final existingEnrollment = await fetchMatchingEnrollment();
    if (existingEnrollment != null) {
      await approveEnrollment(existingEnrollment);
    } else {
      await generateOTP();
      ensureDeviceName();
      _displayActivationCommand();
      final enrollment = await waitForMatchingEnrollment();
      await approveEnrollment(enrollment);
    }

    return 0;
  }

  void _setLoggingLevel() {
    if (params.verbose) {
      AtSignLogger.root_level = 'INFO';
    }
    if (params.debug) {
      AtSignLogger.root_level = 'FINEST';
      logger.level = 'FINEST';
    }
  }

  Future<void> _init() async {
    stderr.write(chalk.blue('Connecting...\t'));

    _atClient ??= await createAtClient(
      atSign: params.atsign,
      atKeysFilePath: params.atKeysFilePath,
      rootDomain: params.rootDomain,
    );
    stderr.writeln('\n');

    _enrollmentService ??= DefaultAtServiceFactory().enrollmentService(
      _atClient!,
    );
  }

  @visibleForTesting
  Future<void> generateOTP() async {
    params.otp = await requestEnrollmentOtp(
      _atClient!,
      otpExpiry: _otpExpiryString,
    );
  }

  /// Uses "noports_<otp>" as fallback device name
  @visibleForTesting
  void ensureDeviceName() {
    params.device ??= '$_defaultDeviceNamePrefix${params.otp}';
  }

  void _displayActivationCommand() {
    final activationStr = generateEnrollmentCommand();
    logger.info(
      'Copy the string below and run `noports activate <string>` on the other device:\n'
      '\n\tNoPorts Desktop:\n\t$activationStr\n'
      '\n\tNoPorts CLI:\n\tnoports activate \'$activationStr\'\n',
    );
  }

  /// Builds the activation command string.
  ///
  /// Format: `<atsign>:enroll:otp:<otp>:name:<deviceName>`
  @visibleForTesting
  String generateEnrollmentCommand() {
    final buffer = StringBuffer();

    buffer.write(
      _baseEnrollCommand
          .replaceFirst('<atsign>', params.atsign)
          .replaceFirst('<otp>', params.otp!)
          .replaceFirst('<device>', params.device!),
    );

    return buffer.toString();
  }

  @visibleForTesting
  Future<void> approveEnrollment(Enrollment enrollment) async {
    logger.info('Approving enrollment...');

    final decisionBuilder = ApprovedRequestDecisionBuilder(
      enrollmentId: enrollment.enrollmentId!,
      encryptedAPKAMSymmetricKey: enrollment.encryptedAPKAMSymmetricKey!,
    );

    final decision = EnrollmentRequestDecision.approved(decisionBuilder);
    AtEnrollmentResponse er = await _enrollmentService!.approve(decision);

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
  @visibleForTesting
  Future<Enrollment> waitForMatchingEnrollment() async {
    logger.info(
      'Waiting for enrollment request '
      '(retry every ${_checkInterval.inSeconds}s)...',
    );

    final rp = EnrollmentListRequestParam()
      ..deviceName = params.device
      ..appName = defaultAppName
      ..namespace = defaultEnrollmentNamespaces.toString()
      ..enrollmentListFilter = [EnrollmentStatus.pending];

    logger.info('Listening...');

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      Enrollment? e = await fetchMatchingEnrollment(requestParam: rp);

      if (e == null) {
        await Future.delayed(_checkInterval);
        continue;
      }
      return e;
    }
    throw AtEnrollmentException('OTP expired. Please re-run the command');
  }

  @visibleForTesting
  Future<Enrollment?> fetchMatchingEnrollment({
    EnrollmentListRequestParam? requestParam,
  }) async {
    requestParam ??= EnrollmentListRequestParam()
      ..deviceName = params.device
      ..appName = defaultAppName
      ..namespace = defaultEnrollmentNamespaces.toString()
      ..enrollmentListFilter = [EnrollmentStatus.pending];

    final results = await _enrollmentService!.fetchEnrollmentRequests(
      enrollmentListParams: requestParam,
    );
    logger.finer('Found matching enrollments: ${results.toString()}');

    // There can only be one pending enrollment for a given device name
    if (results.length == 1) {
      logger.info('Enrollment found with id: ${results.first.enrollmentId}');
      return results.first;
    } else if (results.length > 1) {
      // This should never happen
      throw AtEnrollmentException(
        'Multiple enrollments found for device ${params.device}',
      );
    }

    return null;
  }
}
