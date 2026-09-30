import 'dart:io';

import 'package:npe2e/client_binary.dart';
import 'package:npe2e/process_utils.dart';
import 'package:path/path.dart' as path;

typedef ApkamAtsign = ({String which, String atsign});

String getApkamDeviceName({
  required final String which,
  required final String testRunId,
}) {
  return '${which}_$testRunId';
}

String getApkamKeysFilePath({
  required final Directory apkamKeysDirectory,
  required final String atsign,
  required final String apkamApp,
  required final String apkamDeviceName,
}) {
  return path.join(
    apkamKeysDirectory.path,
    '$atsign.$apkamApp.$apkamDeviceName.atKeys',
  );
}

Future<File> setUpApkamKeyForAtsign({
  required final ClientBinary atActivateClientBinary,
  required final String atsign,
  required final String which,
  required final String rootDomain,
  required final Directory apkamKeysDirectory,
  required final String testRunId,
  required final String apkamApp,
}) async {
  await _validateApkamSetupInputs(
    atActivateClientBinary: atActivateClientBinary,
    apkamKeysDirectory: apkamKeysDirectory,
  );

  final String apkamDeviceName = getApkamDeviceName(
    which: which,
    testRunId: testRunId,
  );

  final ProcessResult revokeProcess = await runCommand(
    atActivateClientBinary.file.path,
    [
      'revoke',
      '-a',
      atsign,
      '-r',
      rootDomain,
      '--arx',
      apkamApp,
      '--drx',
      apkamDeviceName,
    ],
  );
  if (revokeProcess.exitCode != 0) {
    print('Error revoking $atsign: ${revokeProcess.stderr}');
    throw Exception('Error revoking $atsign: ${revokeProcess.stderr}');
  }

  final ProcessResult denyProcessResult = await runCommand(
    atActivateClientBinary.file.path,
    [
      'deny',
      '-a',
      atsign,
      '-r',
      rootDomain,
      '--arx',
      apkamApp,
      '--drx',
      apkamDeviceName,
    ],
  );
  if (denyProcessResult.exitCode != 0) {
    print('Error denying $atsign: ${denyProcessResult.stderr}');
    throw Exception('Error denying $atsign: ${denyProcessResult.stderr}');
  }

  final ProcessResult otpProcess = await runCommand(
    atActivateClientBinary.file.path,
    ['otp', '-a', atsign, '-r', rootDomain],
  );
  if (otpProcess.exitCode != 0) {
    print('Error generating OTP for $atsign: ${otpProcess.stderr}');
    throw Exception('Error generating OTP for $atsign: ${otpProcess.stderr}');
  }
  final String otp = otpProcess.stdout.toString().trim();

  final String apkamKeysPath = getApkamKeysFilePath(
    apkamKeysDirectory: apkamKeysDirectory,
    atsign: atsign,
    apkamApp: apkamApp,
    apkamDeviceName: apkamDeviceName,
  );

  final ProcessOutputCapture enrollCapture = await startCommandWithCapture(
    atActivateClientBinary.file.path,
    [
      'enroll',
      '-a',
      atsign,
      '-s',
      otp,
      '-p',
      apkamApp,
      '-k',
      apkamKeysPath,
      '-d',
      apkamDeviceName,
      '-r',
      rootDomain,
      '-n',
      'sshnp:rw,sshrvd:rw',
    ],
    stdoutLogFile: File('$apkamKeysPath.enroll.stdout.log'),
    stderrLogFile: File('$apkamKeysPath.enroll.stderr.log'),
  );

  sleep(const Duration(seconds: 3));

  final ProcessResult approveProcess = await runCommand(
    atActivateClientBinary.file.path,
    [
      'approve',
      '-a',
      atsign,
      '--arx',
      apkamApp,
      '--drx',
      apkamDeviceName,
      '-r',
      rootDomain,
    ],
  );
  if (approveProcess.exitCode != 0) {
    print('Error approving $atsign: ${approveProcess.stderr}');
    throw Exception('Error approving $atsign: ${approveProcess.stderr}');
  }

  final int enrollProcessExitCode = await enrollCapture.exitCode;
  if (enrollProcessExitCode != 0) {
    print('Error enrolling $atsign: ${enrollCapture.stderr}');
    throw Exception('Error enrolling $atsign: ${enrollCapture.stderr}');
  }

  final File apkamKeysFile = File(apkamKeysPath);
  if (!(await apkamKeysFile.exists())) {
    throw Exception(
      'Error: apkam keys file was not created for $atsign at expected path: $apkamKeysPath',
    );
  }

  // NOTE at_activate writes keyfiles owner-only, and the containers that mount
  // this one run as a different user.
  final ProcessResult chmodProcess = await runCommand('chmod', [
    '644',
    apkamKeysPath,
  ]);
  if (chmodProcess.exitCode != 0) {
    throw Exception(
      'Error making $apkamKeysPath readable: ${chmodProcess.stderr}',
    );
  }

  return apkamKeysFile;
}

/// Revokes the enrollment [setUpApkamKeyForAtsign] makes for each of
/// [atsigns] in this run. A failure is reported rather than thrown, so it
/// cannot mask the run's own result.
Future<void> revokeApkamKeys({
  required final ClientBinary atActivateClientBinary,
  required final List<ApkamAtsign> atsigns,
  required final String rootDomain,
  required final String testRunId,
  required final String apkamApp,
}) async {
  for (final ApkamAtsign entry in atsigns) {
    final String apkamDeviceName = getApkamDeviceName(
      which: entry.which,
      testRunId: testRunId,
    );
    final ProcessResult revokeProcess = await runCommand(
      atActivateClientBinary.file.path,
      [
        'revoke',
        '-a',
        entry.atsign,
        '-r',
        rootDomain,
        '--arx',
        apkamApp,
        '--drx',
        apkamDeviceName,
      ],
    );
    if (revokeProcess.exitCode == 0) {
      print('Revoked $apkamApp $apkamDeviceName for ${entry.atsign}');
    } else {
      print(
        'Warning: could not revoke $apkamApp $apkamDeviceName for '
        '${entry.atsign}: ${revokeProcess.stderr}',
      );
    }
  }
}

/// The enrollments a run has made, to revoke once it is over: each carries
/// sshnp and sshrvd access for its atSign, so none should outlive the run.
class ApkamRevocations {
  final List<Future<void> Function()> _revocations = [];

  /// Registers the enrollments [setUpApkamKeys] is about to make for
  /// [atsigns], before it makes them, so a setup that fails part way is
  /// revoked too.
  void add({
    required final ClientBinary atActivateClientBinary,
    required final List<ApkamAtsign> atsigns,
    required final String rootDomain,
    required final String testRunId,
    required final String apkamApp,
  }) {
    _revocations.add(
      () => revokeApkamKeys(
        atActivateClientBinary: atActivateClientBinary,
        atsigns: atsigns,
        rootDomain: rootDomain,
        testRunId: testRunId,
        apkamApp: apkamApp,
      ),
    );
  }

  /// Revokes every enrollment registered with [add].
  Future<void> revokeAll() async {
    for (final Future<void> Function() revoke in _revocations) {
      await revoke();
    }
  }
}

Future<Map<String, File>> setUpApkamKeys({
  required final ClientBinary atActivateClientBinary,
  required final List<ApkamAtsign> atsigns,
  required final String rootDomain,
  required final Directory apkamKeysDirectory,
  required final String testRunId,
  required final String apkamApp,
}) async {
  await _validateApkamSetupInputs(
    atActivateClientBinary: atActivateClientBinary,
    apkamKeysDirectory: apkamKeysDirectory,
  );

  final Map<String, File> result = {};
  for (final ApkamAtsign entry in atsigns) {
    final File apkamKeysFile = await setUpApkamKeyForAtsign(
      atActivateClientBinary: atActivateClientBinary,
      atsign: entry.atsign,
      which: entry.which,
      rootDomain: rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
      apkamApp: apkamApp,
    );

    result[entry.atsign] = apkamKeysFile;
  }
  return result;
}

Future<Map<String, File>> setUpApkamKeysParallel({
  required final ClientBinary atActivateClientBinary,
  required final List<ApkamAtsign> atsigns,
  required final String rootDomain,
  required final Directory apkamKeysDirectory,
  required final String testRunId,
  required final String apkamApp,
}) async {
  await _validateApkamSetupInputs(
    atActivateClientBinary: atActivateClientBinary,
    apkamKeysDirectory: apkamKeysDirectory,
  );

  final List<Future<(String, File)>> futures = atsigns.map((entry) {
    return setUpApkamKeyForAtsign(
      atActivateClientBinary: atActivateClientBinary,
      atsign: entry.atsign,
      which: entry.which,
      rootDomain: rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
      apkamApp: apkamApp,
    ).then((file) => (entry.atsign, file));
  }).toList();

  final List<(String, File)> results = await Future.wait(futures);

  return Map.fromEntries(results.map((entry) => MapEntry(entry.$1, entry.$2)));
}

Future<void> _validateApkamSetupInputs({
  required final ClientBinary atActivateClientBinary,
  required final Directory apkamKeysDirectory,
}) async {
  if (atActivateClientBinary.binaryType != ClientBinaryType.at_activate) {
    throw ArgumentError('atActivateClientBinary must be of type at_activate');
  }

  if (!(await atActivateClientBinary.exists())) {
    throw ArgumentError(
      'atActivateClientBinary does not exist at path: ${atActivateClientBinary.file.path}',
    );
  }

  if (!(await apkamKeysDirectory.exists())) {
    throw ArgumentError(
      'apkamKeysDirectory does not exist at path: ${apkamKeysDirectory.path}',
    );
  }
}
