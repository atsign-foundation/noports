
import 'dart:io';

import 'package:e2e_all_v2/client_binaries.dart';

String getApkamApp() {
  return 'e2e_all';
}

String getApkamDeviceName({
  required final String which,
  required final String testRunId}) {
  return '${which}_${testRunId}';
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
  if(exitCode != 0) {
    print('Failed to generate OTP for ${atsign}. Output: ${otpProcessResult.stdout}, Error: ${otpProcessResult.stderr}');
    return exitCode;
  }
  final String otp = otpProcessResult.stdout.toString().trim();

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
    '-a', atsign,
    '-r', atDirectoryHost,
    '--arx', apkamApp,
    '--drx', apkamDeviceName,
  ];
  print('Executing: ${atActivateClientBinary.binaryPath} ${denyArgs.join(' ')}');
  final ProcessResult denyProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    denyArgs,
  );
  exitCode = await denyProcessResult.exitCode;
  if(exitCode != 0) {
    print('Warning: deny command returned non-zero exit code. Output: ${denyProcessResult.stdout}, Error: ${denyProcessResult.stderr}');
    print('Continuing anyway...');
  }

  // Buffer between at_activate commands
  await Future.delayed(const Duration(seconds: 2));

  print('Revoking any approved enrollments for $atsign with $apkamApp and apkamDeviceName $apkamDeviceName');
  final List<String> revokeArgs = [
    'revoke',
    '-a', atsign,
    '-r', atDirectoryHost,
    '--arx', apkamApp,
    '--drx', apkamDeviceName,
  ];
  print('Executing: ${atActivateClientBinary.binaryPath} ${revokeArgs.join(' ')}');
  final ProcessResult revokeProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    revokeArgs,
  );
  exitCode = await revokeProcessResult.exitCode;
  if(exitCode != 0) {
    print('Warning: revoke command returned non-zero exit code. Output: ${revokeProcessResult.stdout}, Error: ${revokeProcessResult.stderr}');
    print('Continuing anyway...');
  }

  // Buffer between at_activate commands
  await Future.delayed(const Duration(seconds: 2));

  print('Submitting enrollment request for $atsign with apkamApp $apkamApp and apkamDeviceName $apkamDeviceName');
  final List<String> enrollArgs = [
    'enroll',
    '-a', atsign,
    '-r', atDirectoryHost,
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
  if(exitCode != 0) {
    print('Failed to approve ${atsign}.');
    return exitCode;
  }

  // Ensure enrollment process exits
  exitCode = await enrollProcess.exitCode;
  if(exitCode != 0) {
    print('Failed to enroll ${atsign}. Output: ${enrollProcess.stdout}, Error: ${enrollProcess.stderr}');
    return exitCode;
  }

  // Ensure keys file exists
  File potentiallyExistingKeysFile2 =  File(apkamKeysFilePath);
  if(!potentiallyExistingKeysFile2.existsSync()) {
    print('Enrollment process for ${atsign} completed but keys file not found at ${potentiallyExistingKeysFile2.path}');
    return 1;
  }


  return exitCode;
}

