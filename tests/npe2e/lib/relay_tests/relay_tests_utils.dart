import 'dart:async';
import 'dart:io';

import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/process_utils.dart';

Future<void> createDockerNetwork(String networkName) async {
  final ProcessResult inspectResult = await runCommand('docker', [
    'network',
    'inspect',
    networkName,
  ], printCommand: false);
  if (inspectResult.exitCode == 0) {
    return;
  }
  final ProcessResult createResult = await runCommand('docker', [
    'network',
    'create',
    networkName,
  ]);
  if (createResult.exitCode != 0) {
    throw Exception(
      'Failed to create Docker network $networkName: ${createResult.stderr}',
    );
  }
}

Future<void> removeDockerNetwork(String networkName) async {
  await runCommand('docker', [
    'network',
    'rm',
    networkName,
  ], printCommand: false);
}

Future<void> stopDockerInstanceQuietly(DockerInstance? dockerInstance) async {
  if (dockerInstance == null) {
    return;
  }
  try {
    await dockerInstance.stop();
  } catch (_) {}
}

Future<void> waitForLogMessage(
  DockerInstance dockerInstance,
  String message, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    final File? stdout = dockerInstance.stdoutLogFile;
    final File? stderr = dockerInstance.stderrLogFile;
    final String stdoutText = stdout != null && await stdout.exists()
        ? await stdout.readAsString()
        : '';
    final String stderrText = stderr != null && await stderr.exists()
        ? await stderr.readAsString()
        : '';
    if (stdoutText.contains(message) || stderrText.contains(message)) {
      return;
    }
    final Process? process = dockerInstance.process;
    if (process != null) {
      try {
        final int exitCode = await process.exitCode.timeout(Duration.zero);
        throw Exception(
          '${dockerInstance.containerName} exited with $exitCode before "$message". Logs:\n$stdoutText\n$stderrText',
        );
      } on TimeoutException {
        // Still running.
      }
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw TimeoutException(
    'Did not find "$message" in ${dockerInstance.containerName} logs',
  );
}

Future<void> ensureDockerProcessStillRunning(
  DockerInstance dockerInstance, {
  Duration delay = const Duration(seconds: 3),
}) async {
  await Future<void>.delayed(delay);
  final Process? process = dockerInstance.process;
  if (process == null) {
    throw Exception('${dockerInstance.containerName} has no running process');
  }
  try {
    final int exitCode = await process.exitCode.timeout(Duration.zero);
    final String stdoutText =
        dockerInstance.stdoutLogFile != null &&
            await dockerInstance.stdoutLogFile!.exists()
        ? await dockerInstance.stdoutLogFile!.readAsString()
        : '';
    final String stderrText =
        dockerInstance.stderrLogFile != null &&
            await dockerInstance.stderrLogFile!.exists()
        ? await dockerInstance.stderrLogFile!.readAsString()
        : '';
    throw Exception(
      '${dockerInstance.containerName} exited with $exitCode. Logs:\n$stdoutText\n$stderrText',
    );
  } on TimeoutException {
    return;
  }
}

String sanitizeForDockerName(String value, {int maxLength = 48}) {
  final String cleaned = value
      .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase();
  if (cleaned.length <= maxLength) {
    return cleaned;
  }
  return cleaned.substring(0, maxLength);
}

String sanitizeForDeviceName(String value, {int maxLength = 36}) {
  final String cleaned = value
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase();
  final String withValidStart = cleaned.startsWith('-') ? '_$cleaned' : cleaned;
  if (withValidStart.length <= maxLength) {
    return withValidStart;
  }
  return withValidStart.substring(0, maxLength);
}
