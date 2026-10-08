import 'dart:io';

import 'package:npe2e/process_utils.dart';

Future<bool> ensureDirectoryExists(final Directory directory) async {
  if (await directory.exists()) {
    return true;
  }
  try {
    await directory.create(recursive: true);
    return true;
  } catch (e) {
    throw Exception('Failed to create directory ${directory.path}: $e');
  }
}

bool ensureDirectoryExistsSync(final Directory directory) {
  if (directory.existsSync()) {
    return true;
  }
  try {
    directory.createSync(recursive: true);
    return true;
  } catch (e) {
    throw Exception('Failed to create directory ${directory.path}: $e');
  }
}

Future<String> getShortenedGitCommitHash() async {
  final ProcessResult gitResult = await runCommand('git', [
    'rev-parse',
    '--short',
    'HEAD',
  ]);
  if (gitResult.exitCode != 0) {
    print('stderr: ${gitResult.stderr}');
    exit(1);
  }
  return gitResult.stdout.toString().trim();
}
