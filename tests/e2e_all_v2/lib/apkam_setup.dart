
import 'dart:convert';
import 'dart:io';

import 'package:e2e_all_v2/client_binaries.dart';

String getApkamApp() {
  return 'e2e_all_v2';
}

String getApkamDeviceName({
  required final String which,
  required final String testRunId}) {
  return 'v2_${which}_${testRunId}';
}

String getApkamKeysFileName({
  required final Directory apkamKeysDirectory,
  required final String clientAtSign,
  required final String apkamApp,
  required final String apkamDeviceName,
}) {
  return '${apkamKeysDirectory.path}/$clientAtSign.$apkamApp.$apkamDeviceName.atKeys';
}

/// Enrolls an atsign with APKAM.
///
/// Note: The deny and revoke operations are non-fatal - they will log warnings
/// but continue even if they fail. This is because they are cleanup operations
/// that may fail if no matching enrollments exist.
Future<int> enroll({
  required final Directory apkamKeysDirectory,
  required final String atsign,
  required final String which, // client|daemon
  required final ClientBinary atActivateClientBinary,
  required final String atDirectoryHost,
  required final String testRunId,
}) async {
  int exitCode;

  if(!apkamKeysDirectory.existsSync()) {
    apkamKeysDirectory.createSync(recursive: true);
  }

  print('Generating OTP for ${atsign}');
  final List<String> otpArgs = [
    'otp',
    '-a', atsign,
    '-r', atDirectoryHost,
  ];
  print('Executing: ${atActivateClientBinary.binaryPath} ${otpArgs.join(' ')}');

  final ProcessResult otpProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    otpArgs,
  );
  exitCode = await otpProcessResult.exitCode;
  print('OTP stdout: ${otpProcessResult.stdout}');
  print('OTP stderr: ${otpProcessResult.stderr}');
  if(exitCode != 0) {
    print('Failed to generate OTP for ${atsign}. Exit code: $exitCode');
    return exitCode;
  }
  final String otp = otpProcessResult.stdout.toString().trim();
  print('Generated OTP: $otp');

  // Buffer between at_activate commands
  await Future.delayed(const Duration(seconds: 2));

  final String apkamApp = getApkamApp();
  final String apkamDeviceName = getApkamDeviceName(which: which, testRunId: testRunId);
  final String apkamKeysFilePath = getApkamKeysFileName(
    apkamKeysDirectory: apkamKeysDirectory,
    clientAtSign: atsign,
    apkamApp: apkamApp,
    apkamDeviceName: apkamDeviceName,
  );

  File potentiallyExistingKeysFile = File(apkamKeysFilePath);
  
  if(potentiallyExistingKeysFile.existsSync()) {
    print('Keys file already exists for ${atsign} at ${potentiallyExistingKeysFile.path}. Deleting it before enrollment.');
    potentiallyExistingKeysFile.deleteSync();
  }

  print('Denying any pending enrollment requests for $atsign with $apkamApp and apkamDeviceName $apkamDeviceName');
  final List<String> denyArgs = [
    'deny',
    '-r', atDirectoryHost,
    '-a', atsign,
    '--arx', apkamApp,
    '--drx', apkamDeviceName,
  ];
  print('Executing: ${atActivateClientBinary.binaryPath} ${denyArgs.join(' ')}');
  final ProcessResult denyProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    denyArgs,
  );
  exitCode = await denyProcessResult.exitCode;
  print('Deny stdout: ${denyProcessResult.stdout}');
  print('Deny stderr: ${denyProcessResult.stderr}');
  print('Deny exit code: $exitCode');
  if(exitCode != 0) {
    print('Warning: deny command returned non-zero exit code. Continuing anyway...');
  }

  // Buffer between at_activate commands
  await Future.delayed(const Duration(seconds: 2));

  print('Revoking any approved enrollments for $atsign with $apkamApp and apkamDeviceName $apkamDeviceName');
  final List<String> revokeArgs = [
    'revoke',
    '-r', atDirectoryHost,
    '-a', atsign,
    '--arx', apkamApp,
    '--drx', apkamDeviceName,
  ];
  print('Executing: ${atActivateClientBinary.binaryPath} ${revokeArgs.join(' ')}');
  final ProcessResult revokeProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    revokeArgs,
  );
  exitCode = await revokeProcessResult.exitCode;
  print('Revoke stdout: ${revokeProcessResult.stdout}');
  print('Revoke stderr: ${revokeProcessResult.stderr}');
  print('Revoke exit code: $exitCode');
  if(exitCode != 0) {
    print('Warning: revoke command returned non-zero exit code. Continuing anyway...');
  }

  // Buffer between at_activate commands
  await Future.delayed(const Duration(seconds: 2));

  print('Submitting enrollment request for $atsign with apkamApp $apkamApp and apkamDeviceName $apkamDeviceName');
  final List<String> enrollArgs = [
    'enroll',
    '-r', atDirectoryHost,
    '-a', atsign,
    '--app', apkamApp,
    '--device', apkamDeviceName,
    '--namespaces', 'sshnp:rw,sshrvd:rw',
    '--keys', apkamKeysFilePath,
    '--passcode', otp,
  ];
  print('Executing: ${atActivateClientBinary.binaryPath} ${enrollArgs.join(' ')}');
  final Process enrollProcess = await Process.start(
    atActivateClientBinary.binaryPath,
    enrollArgs,
  );

  // Capture stdout and stderr from enroll process
  final StringBuffer enrollStdout = StringBuffer();
  final StringBuffer enrollStderr = StringBuffer();
  enrollProcess.stdout.transform(utf8.decoder).listen((data) => enrollStdout.write(data));
  enrollProcess.stderr.transform(utf8.decoder).listen((data) => enrollStderr.write(data));

  print('Waiting for enrollment approval for ${atsign}...');
  sleep(const Duration(seconds: 5));

  // approve enrollment
  print('Approving enrollment request for $atsign with apkamApp $apkamApp and apkamDeviceName $apkamDeviceName');
  final List<String> approveArgs = [
    'approve',
    '-a', atsign,
    '-r', atDirectoryHost,
    '--drx', apkamDeviceName,
  ];
  print('Executing: ${atActivateClientBinary.binaryPath} ${approveArgs.join(' ')}');
  final ProcessResult approveProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    approveArgs,
  );
  exitCode = await approveProcessResult.exitCode;
  print('Approve stdout: ${approveProcessResult.stdout}');
  print('Approve stderr: ${approveProcessResult.stderr}');
  print('Approve exit code: $exitCode');
  if(exitCode != 0) {
    print('Failed to approve ${atsign}.');
    return exitCode;
  }
  print('Approval completed for ${atsign}');

  // Ensure enrollment process exits
  print('Waiting for enrollment process to complete for ${atsign}...');
  exitCode = await enrollProcess.exitCode;
  print('Enroll stdout: ${enrollStdout.toString()}');
  print('Enroll stderr: ${enrollStderr.toString()}');
  print('Enroll exit code: $exitCode');
  if(exitCode != 0) {
    print('Failed to enroll ${atsign}.');
    return exitCode;
  }
  print('Enrollment process completed for ${atsign}');

  // Ensure keys file exists
  File potentiallyExistingKeysFile2 =  File(apkamKeysFilePath);
  if(!potentiallyExistingKeysFile2.existsSync()) {
    print('Enrollment process for ${atsign} completed but keys file not found at ${potentiallyExistingKeysFile2.path}');
    return 1;
  }


  return exitCode;
}

