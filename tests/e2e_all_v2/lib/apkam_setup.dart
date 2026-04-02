
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

  final ProcessResult otpProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    [
      'otp',
      '-a', atsign,
      '-r', atDirectoryHost,
    ],
  );
  exitCode = await otpProcessResult.exitCode;
  if(exitCode != 0) {
    print('Failed to generate OTP for ${atsign}. Output: ${otpProcessResult.stdout}, Error: ${otpProcessResult.stderr}');
    return exitCode;
  }
  final String otp = otpProcessResult.stdout.toString().trim();

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
  final ProcessResult denyProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    [
      'deny',
      '-a', atsign,
      '-r', atDirectoryHost,
      '--arx', apkamApp,
      '--drx', apkamDeviceName, 
    ]
  );
  exitCode = await denyProcessResult.exitCode;
  if(exitCode != 0) {
    print('Failed to deny pending enrollment requests for ${atsign}. Output: ${denyProcessResult.stdout}, Error: ${denyProcessResult.stderr}');
    return exitCode;
  }

  print('Revoking any approved enrollments for $atsign with $apkamApp and apkamDeviceName $apkamDeviceName');
  final ProcessResult revokeProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    [
      'revoke',
      '-a', atsign,
      '-r', atDirectoryHost,
      '--arx', apkamApp,
      '--drx', apkamDeviceName,
    ]
  );
  exitCode = await revokeProcessResult.exitCode;
  if(exitCode != 0) {
    print('Failed to revoke approved enrollments for ${atsign}. Output: ${revokeProcessResult.stdout}, Error: ${revokeProcessResult.stderr}');
    return exitCode;
  }

  print('Submitting enrollment request for $atsign with apkamApp $apkamApp and apkamDeviceName $apkamDeviceName');
  final Process enrollProcess = await Process.start(
    atActivateClientBinary.binaryPath,
    [
      'enroll',
      '-a', atsign,
      '-r', atDirectoryHost,
      '--app', apkamApp,
      '--device', apkamDeviceName,
      '--namespaces', 'sshnp:rw,sshrvd:rw',
      '--keys', apkamKeysFilePath,
      '--passcode', otp,
    ],
  );
  print('Waiting for enrollment approval for ${atsign}...');
  sleep(const Duration(seconds: 5));

  // approve enrollment
  print('Approving enrollment request for $atsign with apkamApp $apkamApp and apkamDeviceName $apkamDeviceName');
  final ProcessResult approveProcessResult = await Process.run(
    atActivateClientBinary.binaryPath,
    [
      'approve',
      '-a', atsign,
      '-r', atDirectoryHost,
      '--drx', apkamDeviceName,
    ],
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

