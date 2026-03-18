import 'dart:convert';
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
        AtClient,
        EncryptionUtil,
        AtKey,
        PutRequestOptions,
        AtRootDomain;
import 'package:at_onboarding_cli/at_onboarding_cli.dart'
    show requestEnrollmentOtp, createAtClient;
import 'package:at_utils/at_logger.dart';
import 'package:chalkdart/chalk.dart';
import 'package:cryptography/cryptography.dart' show SecureRandom;
import 'package:meta/meta.dart';
import 'package:noports_core/src/commands/activate/activate_params.dart';
import 'package:noports_core/src/commands/issue_keys/issue_keys_params.dart';
import 'package:noports_core/src/commands/utils/constants.dart';

/// Handles the issuance of enrollment keys for new device enrollment.
///
/// We're handling either
/// - (1) Three-step enrollment flow
///   - (i) Approver (this program)
///     - generates otp
///     - sets default device name, if not provided
///     - displays activate command
///   - (ii) Enroller runs the activate command on the device
///   - (iii) Approver (this program) approves the enrollment request
/// - (2) Two-step enrollment flow
///   - (i)
///     - sets default device name, if not provided
///     - does the full otp-enroll-approve here
///     - encrypts and saves generated keys to a public hidden record
///     - displays activate command
///   - (ii) Enroller runs the activate command, which fetches the keys
///
class IssueKeys {
  static const _enrollWithOtpCommandTemplate =
      '<atsign>:enroll:otp:<otp>:name:<device>';
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

  /// Returns: 0 on success, 1 on failure
  Future<int> wrappedMain() async {
    _setLoggingLevel();
    await _init();

    await generateOTP();
    ensureDeviceName();

    if (params.generate) {
      return await generateAtKeys();
    } else {
      // Check for matching pending enrollment, approve if found | works like a resume
      final existingEnrollment = await fetchMatchingEnrollment();
      if (existingEnrollment != null) {
        await approveEnrollment(existingEnrollment);
      } else {
        // display the command to run on the device
        final activationStr = generateEnrollmentCommand();
        logger.info(
          'On the other device:\n'
          '\n  Using NoPorts Desktop, paste this string:'
          '\n    $activationStr\n'
          '\n  Using NoPorts CLI, run this command:'
          '\n    noports activate \'$activationStr\'\n',
        );

        // now wait for the enrollment to be submitted, and approve it
        final enrollment = await waitForMatchingEnrollment();
        await approveEnrollment(enrollment);
      }
      return 0;
    }
  }

  Future<int> generateAtKeys() async {
    File tmpKeysFile = createTmpFile();
    // submit the enrollment request
    logger.info('Submitting enrollment request');
    Process enroller = await submitEnrollmentRequest(tmpKeysFile);

    // TODO wait for enroller stderr:     Enroll : submitted OK
    await Future.delayed(Duration(seconds: 3));

    // start approver for the enrollment request
    logger.info('Starting approver');
    Process autoApprover = await startAutoApprover();

    // wait for the approval to complete
    int approverExitCode = await autoApprover.exitCode;
    if (approverExitCode != 0) {
      throw Exception('auto approver: exit code $approverExitCode');
    }

    // wait for the enrollment to complete
    int enrollExitCode = await enroller.exitCode;
    if (enrollExitCode != 0) {
      throw Exception('enroll: exit code $enrollExitCode');
    }

    logger.info('Complete');

    // we now have atKeys in tmpKeysFile
    String atKeys = tmpKeysFile.readAsStringSync();

    tmpKeysFile.deleteSync();

    // generate aes/iv, encrypt the atKeys, save to public hidden key
    String aes = EncryptionUtil.generateAESKey();
    String iv = EncryptionUtil.generateIV();
    String atKeysEncrypted64 = EncryptionUtil.encryptValue(
      atKeys,
      aes,
      ivBase64: iv,
    );
    String publicHiddenEncryptedKeysID =
        '_${createRandomLowercaseString(10)}'
        '.__utils.sshnp'
        '${_atClient!.getCurrentAtSign()}';
    AtKey k = AtKey.fromString('public:$publicHiddenEncryptedKeysID');
    k.metadata.ttl = 60 * 60 * 1000; // ttl 1 hour
    await _atClient!.put(
      k,
      atKeysEncrypted64,
      putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
    );

    // Finally, display the noports activate:@alice:fetch:<base64> command
    FetchParams fp = FetchParams(
      device: params.device!,
      location: await urlFromId(publicHiddenEncryptedKeysID),
      aes64: aes,
      iv64: iv,
    );
    final activationStr =
        '${params.atsign}:fetch:${base64Encode(jsonEncode(fp.toJson()).codeUnits)}';
    logger.info(
      'On the other device:'
      '\n  Using NoPorts Desktop, paste this string:'
      '\n    $activationStr\n'
      '\n  Using NoPorts CLI, run this command:'
      '\n    noports activate \'$activationStr\'\n',
    );

    return 0;
  }

  Future<String> urlFromId(String id) async {
    AtRootDomain d = AtRootDomain.parse(params.rootDomain);
    if (d.isProxyAddress) {
      String domainPart = d.rootDomain.replaceFirst('proxy:', '');
      String portPart = d.rootPort == 443 ? '' : ':${d.rootPort}';
      return 'https://$domainPart$portPart/${params.atsign}/$id';
    } else {
      final sa = await _atClient!
          .getRemoteSecondary()!
          .atLookUp
          .secondaryAddressFinder
          .findSecondary(params.atsign);
      return 'https://${sa.host}:${sa.port}/$id';
    }
  }

  Future<Process> startAutoApprover() async {
    List<String> execArgs = ['auto'];
    // execArgs.add('-v');
    execArgs.addAll(['-r', params.rootDomain.toString()]);
    execArgs.addAll(['-a', params.atsign]);
    execArgs.addAll(['-k', params.atKeysFilePath!]);
    execArgs.addAll(['-A', defaultAppName]);
    execArgs.addAll(['-D', params.device!]);
    execArgs.addAll(['--approve-existing']);
    logger.info('Executing at_activate ${execArgs.join(' ')}');
    Process autoApprover = await Process.start('at_activate', execArgs);
    autoApprover.stderr.listen(
      (list) => outputRewriter('approver stderr', list),
    );
    autoApprover.stdout.listen(
      (list) => outputRewriter('approver stdout', list),
    );
    return autoApprover;
  }

  Future<Process> submitEnrollmentRequest(File tmpKeysFile) async {
    List<String> execArgs = ['enroll'];
    // execArgs.add('-v');
    execArgs.addAll(['-r', params.rootDomain]);
    execArgs.addAll(['-a', params.atsign]);
    execArgs.addAll(['-k', tmpKeysFile.path]);
    execArgs.addAll(['--app', defaultAppName]);
    execArgs.addAll(['--device', params.device!]);
    execArgs.addAll(['--passcode', params.otp!]);
    // TODO mod at_activate to include ability to set retryInterval
    // Relevant code in auth_cli.dart starting line 525:
    //   stderr.writeln('Waiting for approval; will check every 10 seconds');
    //   await svc.awaitApproval(er,
    //       retryInterval: AtOnboardingService.defaultApkamRetryInterval,
    //       logProgress: true,
    //       maxRetries: int.parse(argResults[AuthCliArgs.argNameMaxRetries]));
    execArgs.addAll(['--max-retries', '5']);
    execArgs.addAll(['--namespaces', defaultNamespacesString]);

    logger.info('Executing at_activate ${execArgs.join(' ')}');
    Process enroller = await Process.start('at_activate', execArgs);
    enroller.stderr.listen((list) => outputRewriter('enroller stderr', list));
    enroller.stdout.listen((list) => outputRewriter('enroller stdout', list));
    return enroller;
  }

  void outputRewriter(String tag, List<int> list) {
    final lines = String.fromCharCodes(list).split('\n');
    for (final l in lines) {
      logger.info('\t$tag: ${l.trim()}');
    }
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

  File createTmpFile() {
    if (Platform.isWindows) {
      return File(
        '${Platform.environment['TEMP']!}'
        '${Platform.pathSeparator}'
        'noports'
        '${Platform.pathSeparator}'
        '${DateTime.now().microsecondsSinceEpoch}.atKeys',
      );
    } else {
      return File(
        '${Platform.pathSeparator}'
        'tmp'
        '${Platform.pathSeparator}'
        'noports'
        '${Platform.pathSeparator}'
        '${DateTime.now().microsecondsSinceEpoch}.atKeys',
      );
    }
  }

  static String createRandomLowercaseString(int length) {
    final String characters = '0123456789abcdefghijklmnopqrstuvwxyz';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (index) =>
            characters.codeUnitAt(SecureRandom.fast.nextInt(characters.length)),
      ),
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

  /// Builds the activation command string.
  ///
  /// Format: `<atsign>:enroll:otp:<otp>:name:<deviceName>`
  @visibleForTesting
  String generateEnrollmentCommand() {
    final buffer = StringBuffer();

    buffer.write(
      _enrollWithOtpCommandTemplate
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
      ..namespace = defaultNamespaces.toString()
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
      ..namespace = defaultNamespaces.toString()
      ..enrollmentListFilter = [EnrollmentStatus.pending];

    final results = await _enrollmentService!.fetchEnrollmentRequests(
      enrollmentListParams: requestParam,
    );
    logger.info('Found matching enrollments: ${results.toString()}');

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
