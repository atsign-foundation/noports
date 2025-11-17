import 'dart:core';
import 'dart:io';

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
        AtServiceFactory;
import 'package:at_commons/at_commons.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart'
    show requestEnrollmentOtp;
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/noports_cli/activate/np_activate_params.dart';
import 'package:sshnoports/src/noports_cli/util/constants.dart';
import 'package:sshnoports/src/noports_cli/util/np_utils.dart';

sealed class NPIssueKeys {
  /// Entry point for the issue-keys command
  Future<int> wrappedMain(List<String> args);

  static final baseEnrollCommand = '<atsign>:enroll:otp:<otp>';
  static final defaultDeviceNamePrefix = 'noports_';
}

class NPIssueKeysImpl implements NPIssueKeys {
  final AtServiceFactory _factory = DefaultAtServiceFactory();
  EnrollmentService? _enrollmentService;

  @override
  Future<int> wrappedMain(List<String> args) async {
    NoportsParams params = NoportsParams.fromArgs(args);
    // fetch atKeys filePath from user (can be null)
    params.atKeysFilePath = _promptUser('atKeys filepath (target location): ');
    writeWarning('atkeys: \'${params.atKeysFilePath}\'');
    final atClient = await createAtClientCli(
        atsign: params.atsign,
        atKeysFilePath: params.atKeysFilePath,
        atServiceFactory: _factory,
        namespace: defaultCurrentNamespace,
        storagePath: standardAtClientStoragePath(
            baseDir: getHomeDirectory()!,
            atSign: params.atsign,
            progName: defaultCurrentNamespace));

    _enrollmentService = DefaultAtServiceFactory().enrollmentService(atClient);

    // fetch enrollment OTP using at_client instance
    params.otp = await requestEnrollmentOtp(atClient);

    //fetch deviceName from user (defaults to: noports_<otp>)
    params.deviceName = _promptUser('deviceName: ') ??
        '${NPIssueKeys.defaultDeviceNamePrefix}${params.otp}';

    String command = _generateEnrollCommand(params);
    writeInfoMessage('Copy the string below \t\'noports activate <string>\'\n'
        '\n\tFor Noports Desktop use:\n\t$command\n'
        '\n\tFor Noports CLI use:\n\tnoports activate \'$command\'\n');

    AtEnrollmentResponse er = await _approveFirstPendingEnrollment(params);
    if (er.enrollStatus != EnrollmentStatus.approved) {
      writeError('Failed to approve enrollment\nStatus: $er');
      return 1;
    }
    writeSuccessMessage('Enrollment approved: ${er.enrollmentId}\n');
    return 0;
  }

  String? _promptUser(String prompt) {
    stdout.write(prompt);
    String? input = stdin.readLineSync();
    if (input == null) writeWarning('Missing input, using default');
    // ensure output is either user input or null
    return (input == null || input.isEmpty) ? null : input;
  }

  /// Generates an activation string from the provided [params]
  ///
  /// Combines atsign, otp, and optional deviceName and atKeysFilePath
  /// into a format compatible with 'noports activate' command.
  ///
  /// Returns: activation string in format `<atsign>:enroll:otp:<otp>[:name:<deviceName>[:keyfile:<path>]]`
  String _generateEnrollCommand(NoportsParams params) {
    StringBuffer cbuf = StringBuffer();
    cbuf.append(NPIssueKeys.baseEnrollCommand
        .replaceFirst('<atsign>', params.atsign)
        .replaceFirst('<otp>', params.otp!));

    // write optional args if available
    cbuf.append('[:name:${params.deviceName}');
    if (!(params.atKeysFilePath == null || params.atKeysFilePath == '')) {
      cbuf.append(':keyfile:${params.atKeysFilePath}');
    }
    cbuf.append(']');

    return cbuf.message!;
  }

  /// Approves the first pending enrollment request with inferred noports parameters
  ///
  /// Creates an ApprovedRequestDecision and submits it to the enrollment service.
  ///
  /// Throws: [AtEnrollmentException] if enrollment approval fails
  /// Returns: [AtEnrollmentResponse] containing the enrollment status
  Future<AtEnrollmentResponse> _approveFirstPendingEnrollment(
      NoportsParams params) async {
    Enrollment enrollment = await _awaitAndFetchEnrollmentRequest(params);
    writeInfoMessage(
        'Approving enrollment with id: ${enrollment.enrollmentId}');

    ApprovedRequestDecisionBuilder decisionBuilder =
        ApprovedRequestDecisionBuilder(
            enrollmentId: enrollment.enrollmentId!,
            encryptedAPKAMSymmetricKey: enrollment.encryptedAPKAMSymmetricKey!);
    EnrollmentRequestDecision decision =
        EnrollmentRequestDecision.approved(decisionBuilder);

    AtEnrollmentResponse response = await _enrollmentService!.approve(decision);

    return response;
  }

  /// Waits for and fetches the first pending enrollment request matching [params]
  ///
  /// Polls the enrollment service at regular intervals until an enrollment request
  /// is found with matching deviceName, appName, and namespace.
  ///
  /// Throws: [AtEnrollmentException] if enrollmentId is missing from the response
  /// Returns: The first pending [Enrollment] that matches the criteria
  Future<Enrollment> _awaitAndFetchEnrollmentRequest(
      NoportsParams params) async {
    writeInfoMessage('Waiting for enrollment request - '
        'will retry every ${enrollmentCheckInterval / 1000}s');
    EnrollmentListRequestParam enrollListParams = EnrollmentListRequestParam()
      ..deviceName = params.deviceName
      ..appName = defaultAppName
      ..namespace = defaultEnrollmentNamespaces.toString()
      ..enrollmentListFilter = [EnrollmentStatus.pending];

    writeInfoMessage('Listening...');
    while (true) {
      List<Enrollment> enrollRequests = await _enrollmentService!
          .fetchEnrollmentRequests(enrollmentListParams: enrollListParams);

      if (enrollRequests.isEmpty) {
        // keeps the loop active until enrollment fetched or terminated
        await Future.delayed(Duration(milliseconds: enrollmentCheckInterval));
        continue;
      }

      if (enrollRequests.first.enrollmentId == null) {
        throw AtEnrollmentException(
            'Failed to read enrollmentId from object: ${enrollRequests.first}');
      }
      writeInfoMessage('Enrollment Found!');
      return enrollRequests.first;
    }
  }
}
