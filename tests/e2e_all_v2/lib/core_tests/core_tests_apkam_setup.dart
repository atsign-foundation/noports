import 'dart:io';
import 'package:e2e_all_v2/process_utils.dart';
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
  return path.join(apkamKeysDirectory.path, '${atsign}.${apkamApp}.${apkamDeviceName}.atKeys');
}

Future<Map<String, File>> setUpApkamKeys({
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

  Map<String, File> result = {};
  for(final (String, String) entry in [
    ('client', clientAtsign),
    ('daemon', daemonAtsign),
  ]) {
    final String which = entry.$1;
    final String atsign = entry.$2;

    final String apkamApp = getApkamApp();
    final String apkamDeviceName = getApkamDeviceName(which: which, testRunId: testRunId);

    // 1. revoke
    final ProcessResult revokeProcess = await runCommand(
      atActivateClientBinary.file.path,
      [
        'revoke',
        '-a', atsign,
        '-r', rootDomain,
        '--arx', apkamApp,
        '--drx', apkamDeviceName,
      ],
      // printCommand: true,
    );
    if(revokeProcess.exitCode != 0) {
      print('Error revoking $atsign: ${revokeProcess.stderr.toString()}');
      throw Exception('Error revoking $atsign: ${revokeProcess.stderr}');
    }

    // 2. deny
    final ProcessResult denyProcessResult = await runCommand(
      atActivateClientBinary.file.path,
      [
        'deny',
        '-a', atsign,
        '-r', rootDomain,
        '--arx', apkamApp,
        '--drx', apkamDeviceName,
      ],
      // printCommand: true,
    );
    if(denyProcessResult.exitCode != 0) {
      print('Error denying $atsign: ${denyProcessResult.stderr.toString()}');
      throw Exception('Error denying $atsign: ${denyProcessResult.stderr}');
    }

    // 3. otp
    final ProcessResult otpProcess = await runCommand(
      atActivateClientBinary.file.path,
      [
        'otp',
        '-a', atsign,
        '-r', rootDomain,
      ],
      // printCommand: true,
    );
    if(otpProcess.exitCode != 0) {
      print('Error generating OTP for $clientAtsign: ${otpProcess.stderr}');
      throw Exception('Error generating OTP for $clientAtsign: ${otpProcess.stderr}');
    }
    final String otp = otpProcess.stdout.toString().trim();

    // 4. enroll
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
        '-a', atsign,
        '-s', otp,
        '-p', apkamApp,
        '-k', apkamKeysPath,
        '-d', apkamDeviceName,
        '-r', rootDomain,
        '-n', 'sshnp:rw,sshrvd:rw',
      ],
      // printCommand: true,
    );

    sleep(const Duration(seconds: 3)); 

    // 5. approve
    final ProcessResult approveProcess = await runCommand(
      atActivateClientBinary.file.path,
      [
        'approve',
        '-a', atsign,
        '--arx', apkamApp,
        '--drx', apkamDeviceName,
        '-r', rootDomain,
      ],
      // printCommand: true,
    );
    if(approveProcess.exitCode != 0) {
      print('Error approving $atsign: ${approveProcess.stderr.toString()}');
      throw Exception('Error approving $atsign: ${approveProcess.stderr}');
    }

    final int enrollProcessExitCode = await enrollProcess.exitCode;
    if(enrollProcessExitCode != 0) {
      print('Error enrolling $atsign: ${enrollProcess.stderr.toString()}');
      throw Exception('Error enrolling $atsign: ${enrollProcess.stderr}');
    }

    final File apkamKeysFile = File(apkamKeysPath);
    if(!(await apkamKeysFile.exists())) {
      throw Exception('Error: apkam keys file was not created for $atsign at expected path: $apkamKeysPath');
    }
    result[atsign] = File(apkamKeysPath);
  }
  return result;
}
