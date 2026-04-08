import 'dart:io';
import 'package:e2e_all_v2/utils.dart';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/client_binary.dart';

String getApkamApp() {
  return 'e2e_all_v2';
}

String getApkamDeviceName({
  required final String which, // 'client', 'daemon'
  required final String testRunId}) {
  return '${which}_${testRunId}';
}

String getApkamKeysFilePath({
  required final Directory apkamKeysDirectory,
  required final String atsign,
  required final String apkamApp,
  required final String apkamDeviceName,
}) {
  return path.join(apkamKeysDirectory.path, '${atsign}_${apkamApp}_${apkamDeviceName}_key.atKeys');
}

Future<void> setUpApkamKeys({
  required final ClientBinary atActivateClientBinary,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String rootDomain,
  required final Directory apkamKeysDirectory,
  required final String testRunId,
}) async {
  // 1. validate paramters
  if(atActivateClientBinary.binaryType != ClientBinaryType.at_activate) {
    throw ArgumentError('atActivateClientBinary must be of type at_activate');
  }

  if(!(await atActivateClientBinary.exists())) {
    throw ArgumentError('atActivateClientBinary does not exist at path: ${atActivateClientBinary.file.path}');
  }

  if(!(await apkamKeysDirectory.exists())) {
    throw ArgumentError('apkamKeysDirectory does not exist at path: ${apkamKeysDirectory.path}');
  }

  for(final (String, String) entry in [
    ('client', clientAtsign),
    ('daemon', daemonAtsign),
  ]) {
    final String which = entry.$1;
    final String atsign = entry.$2;

    // 2. otp
    final ProcessResult otpProcess = await runCommand(
      atActivateClientBinary.file.path,
      [
        'otp',
        '-a', atsign,
        '-r', rootDomain,
      ],
    );
    if(otpProcess.exitCode != 0) {
      print('Error generating OTP for $clientAtsign: ${otpProcess.stderr}');
      throw Exception('Error generating OTP for $clientAtsign: ${otpProcess.stderr}');
    }
    final String otp = otpProcess.stdout.toString().trim();

    // 3. enroll
    final String apkamApp = getApkamApp();
    final String apkamDeviceName = getApkamDeviceName(which: which, testRunId: testRunId);
    final String apkamKeysPath = getApkamKeysFilePath(
      apkamKeysDirectory: apkamKeysDirectory,
      atsign: atsign,
      apkamApp: apkamApp,
      apkamDeviceName: apkamDeviceName,
    );

    final Process enrollProcess = await startCommand(
      atActivateClientBinary.file.path,
      [
        'enroll',
        '-a', clientAtsign,
        '-s', otp,
        '-p', apkamApp,
        '-k', apkamKeysPath,
        '-d', apkamDeviceName,
        '-r', rootDomain,
        '-n', 'sshnp:rw,sshrvd:rw',
      ],
    );

    // 4. approve
    final ProcessResult approveProcess = await runCommand(
      atActivateClientBinary.file.path,
      [
        'approve',
        '-a', atsign,
        '--arx', apkamApp,
        '--drx', apkamDeviceName,
        '-r', rootDomain,
      ],
    );
    if(approveProcess.exitCode != 0) {
      print('Error approving $clientAtsign: ${approveProcess.stderr}');
      throw Exception('Error approving $clientAtsign: ${approveProcess.stderr}');
    }

    final int enrollProcessExitCode = await enrollProcess.exitCode;
    if(enrollProcessExitCode != 0) {
      print('Error enrolling $clientAtsign: ${enrollProcess.stderr}');
      throw Exception('Error enrolling $clientAtsign: ${enrollProcess.stderr}');
    }
  }
}

