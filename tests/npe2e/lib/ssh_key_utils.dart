import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:npe2e/process_utils.dart';
import 'package:path/path.dart' as path;

String getIdentityFilePath({required final String testRunId}) {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if (homeDirectoryPath == null) {
    throw Exception(
      'Unable to determine home directory path for current user.',
    );
  }
  return path.join(homeDirectoryPath, '.ssh', 'npe2e.$testRunId');
}

Future<(File, File)> generateNewSshKey({
  required final String testRunId,
}) async {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if (homeDirectoryPath == null) {
    throw Exception(
      'Unable to determine home directory path for current user.',
    );
  }

  final Directory sshDirectory = Directory(
    path.join(homeDirectoryPath, '.ssh'),
  );
  if (!(await sshDirectory.exists())) {
    throw Exception('SSH directory does not exist: ${sshDirectory.path}');
  }

  await runCommand('chmod', [
    'go-rwx',
    path.join(sshDirectory.path, 'authorized_keys'),
  ]);

  final String identityFilePath = getIdentityFilePath(testRunId: testRunId);
  await runCommand('ssh-keygen', [
    '-t',
    'ed25519',
    '-q',
    '-N',
    '',
    '-f',
    identityFilePath,
    '-C',
    testRunId,
  ]);

  final File identityFile = File(identityFilePath);
  final File publicIdentityFile = File('$identityFilePath.pub');
  if (!(await identityFile.exists()) || !(await publicIdentityFile.exists())) {
    throw Exception(
      'Failed to generate ssh key pair. Expected files not found: $identityFilePath and ${publicIdentityFile.path}',
    );
  }
  return (publicIdentityFile, identityFile);
}
