import 'dart:core';
import 'dart:io';

import 'package:at_auth/at_auth.dart'
    show
        AtEnrollmentResponse,
        ApprovedRequestDecisionBuilder,
        EnrollmentRequestDecision;
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
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
  AtClient? atClient;
  EnrollmentService? _enrollmentService;

  /// Initializes the AtClient and EnrollmentService for the given [atsign]
  Future<void> init(String atsign) async {
    atClient = await createAtClient(atSign: atsign);
    _enrollmentService = DefaultAtServiceFactory().enrollmentService(atClient!);
  }

  @override
  Future<int> wrappedMain(List<String> args) async {
    NoportsParams params = NoportsParams.fromArgs(args);
    await init(params.atsign);

    params.otp = await requestEnrollmentOtp(atClient!);

    stdout.write('\ndeviceName: ');
    params.deviceName = stdin.readLineSync();
    if (params.deviceName == null || params.deviceName == '') {
      // create deviceName if missing, appending the OTP for uniqueness
      params.deviceName = '${NPIssueKeys.defaultDeviceNamePrefix}${params.otp}';
      writeWarning('Missing deviceName, using ${params.deviceName}');
    }
    stdout.writeln();

    stdout.write('atKeys filepath (target location): ');
    params.atKeysFilePath = stdin.readLineSync();
    if (params.atKeysFilePath == null || params.atKeysFilePath == '') {
      writeWarning('Missing keyfile, using default');
    }
    stdout.writeln();

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

  /// Generates an activation string from the provided [params]
  ///
  /// Combines atsign, otp, and optional deviceName and atKeysFilePath
  /// into a format compatible with 'noports activate' command.
  ///
  /// Returns: activation string in format `<atsign>:enroll:otp:<otp>[:name:<deviceName>[:keyfile:<path>]]`
  String _generateEnrollCommand(NoportsParams params) {
    StringBuffer cbuf = StringBuffer(NPIssueKeys.baseEnrollCommand
        .replaceFirst('<atsign>', params.atsign)
        .replaceFirst('<otp>', params.otp!));

    // write optional args if available
    cbuf.write('[:name:${params.deviceName}');
    if (!(params.atKeysFilePath == null || params.atKeysFilePath == '')) {
      cbuf.write(':keyfile:${params.atKeysFilePath}');
    }
    cbuf.write(']');

    return cbuf.toString();
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
