import 'dart:async';
import 'dart:io';
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/docker_utils.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/process_utils.dart';
import 'package:path/path.dart' as path;

// Goal of policy server:
//
// A policy server is just running either one of these binaries:
// - npp
// - npp_atserver
//
// npp is available as of v5.14.13 Dart.
// npp_atserver is available as of v5.13.0 Dart.
//
// It represents a Docker instance. All you need to do is get the Docker image
// (e.g. d:v5.14.13), then you can expect the binary (npp|npp_atserver) to be
// available at /usr/local/bin, just like where all the other binaries are held
// in the image.
//
// To run the binary:
// npp|npp_atserver -a <policy atsign> -v -r <root domain> -k <path to policy atsign apkam keys>
//
// The policy server should have a PolicyServerType enum.
//
// Depending on which policy server it is, there are different ways to inject
// and tear down the policy rules. Write a function for that, and it can be
// implemented by hand later.
//
// It should contain an instance of a DockerInstance, then have functions like
// ensuring it is running, ensuring it is up by reading for a certain message,
// injecting policy rules, tearing down policy rules, and stopping the Docker
// instance.

enum PolicyServerType { npp, nppAtServer }

extension PolicyServerTypeProperties on PolicyServerType {
  String get uniqueIdentifier {
    switch (this) {
      case PolicyServerType.npp:
        return '_npp';
      case PolicyServerType.nppAtServer:
        return '_npp_atserver';
    }
  }

  String get label {
    switch (this) {
      case PolicyServerType.npp:
        return 'npp';
      case PolicyServerType.nppAtServer:
        return 'npp_atserver';
    }
  }

  String get processReadyMessage {
    switch (this) {
      case PolicyServerType.npp:
        return 'monitor started';
      case PolicyServerType.nppAtServer:
        return 'Load complete';
    }
  }

  String get executablePath {
    return '/usr/local/bin/$label';
  }
}

class PolicyServer {
  final PolicyServerType type;
  final NoPortsVersion version;
  final String atsign;
  final String rootDomain;
  final Directory logsDirectory;
  final File apkamKeysFile;
  final DockerImage dockerImage;
  final String testRunId;
  final String uniqueIdentifierSuffix;
  final List<String> additionalArgs;
  late DockerInstance dockerInstance;

  PolicyServer({
    required this.type,
    required this.version,
    required this.atsign,
    required this.rootDomain,
    required this.logsDirectory,
    required this.apkamKeysFile,
    required this.dockerImage,
    required this.testRunId,
    this.uniqueIdentifierSuffix = '',
    this.additionalArgs = const <String>[],
  });

  String get containerName => dockerInstance.containerName;

  File? get stdoutLogFile => dockerInstance.stdoutLogFile;

  File? get stderrLogFile => dockerInstance.stderrLogFile;

  Future<void> injectPolicyRules() {
    throw UnimplementedError(
      'Policy rule injection is different for ${type.label} and must be implemented by the caller.',
    );
  }

  Future<void> tearDownPolicyRules() {
    throw UnimplementedError(
      'Policy rule teardown is different for ${type.label} and must be implemented by the caller.',
    );
  }

  String _buildContainerName() {
    final String uniqueId = '${type.uniqueIdentifier}$uniqueIdentifierSuffix';
    return 'npe2e_${dockerImage.language.name}_${dockerImage.tag}_$testRunId$uniqueId';
  }

  Future<void> start() async {
    final String containerKeyFilePath =
        '/atsign/.atsign/keys/${path.basename(apkamKeysFile.path)}';

    await runCommand(
      'docker',
      ['rm', '-f', _buildContainerName()],
      printCommand: false,
    );

    dockerInstance = await runDockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      logsDirectory: logsDirectory,
      uniqueIdentifier: '${type.uniqueIdentifier}$uniqueIdentifierSuffix',
      entrypoint: [
        type.executablePath,
        '-a',
        atsign,
        '-v',
        '-k',
        containerKeyFilePath,
        '--root-domain',
        rootDomain,
        ...additionalArgs,
      ],
      volumeMappings: [
        VolumeMapping(
          local: apkamKeysFile.absolute.path,
          container: containerKeyFilePath,
        ),
      ],
      printCommand: false,
    );
  }

  Future<bool> isRunning() async {
    final ProcessResult result = await runCommand('docker', [
      'inspect',
      '--format',
      '{{.State.Running}}',
      containerName,
    ], printCommand: false);
    return result.exitCode == 0 && result.stdout.toString().trim() == 'true';
  }

  Future<void> ensureRunning() async {
    if (await isRunning()) {
      return;
    }
    throw Exception('Policy server container is not running: $containerName');
  }

  Future<void> ensureProcessMessage({
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final String successMessage = type.processReadyMessage;
    final Stopwatch stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final String logs = await _readLogs();
      final String? matchingLine = _matchingLogLine(
        logs: logs,
        message: successMessage,
      );
      if (matchingLine != null) {
        return;
      }

      final int? exitCode = await _processExitCodeIfComplete();
      if (exitCode != null) {
        throw Exception(
          'Policy server $containerName exited with code $exitCode before outputting "$successMessage". Logs:\n$logs',
        );
      }

      await Future.delayed(pollInterval);
    }

    final String logs = await _readLogs();
    throw Exception(
      'Policy server $containerName did not output "$successMessage" within $timeout. Logs:\n$logs',
    );
  }

  Future<ProcessResult> stop() {
    return dockerInstance.stop();
  }

  Future<String> _readLogs() async {
    final List<File> logFiles = [
      if (stdoutLogFile != null) stdoutLogFile!,
      if (stderrLogFile != null) stderrLogFile!,
    ];
    final List<String> contents = await Future.wait(
      logFiles.map((file) async {
        if (await file.exists()) {
          return file.readAsString();
        }
        return '';
      }),
    );
    return contents.join();
  }

  String? _matchingLogLine({
    required final String logs,
    required final String message,
  }) {
    for (final String line in logs.split('\n')) {
      if (line.contains(message)) {
        return line;
      }
    }
    return null;
  }

  Future<int?> _processExitCodeIfComplete() async {
    final Process? process = dockerInstance.process;
    if (process == null) {
      return null;
    }
    try {
      return await process.exitCode.timeout(Duration.zero);
    } on TimeoutException {
      return null;
    }
  }
}
