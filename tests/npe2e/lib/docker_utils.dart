import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';

// Local-run aid: when the npe2e tests run against atServers on the developer's
// own machine (reached via `/etc/hosts` overrides such as
// `127.0.0.1 vip.ve.atsign.zone`), mirror those overrides into the containers
// (daemon / relay / policy server / containerised client). A container can't
// reach the host on 127.0.0.1, so each mapped name is re-pointed at
// `host-gateway`, Docker's route back to the host.
//
// Scoped to `*.atsign.zone` names mapped to 127.0.0.1: that covers the atsign
// test domains without touching unrelated /etc/hosts entries, and it leaves
// deliberate black-holes (e.g. `127.1.1.1 unreachable.atsign.zone`) alone. On a
// clean CI checkout there are no such entries, so this returns nothing (the
// harness normally runs against the public root.atsign.org).
List<String> hostGatewayAddHostArgs() {
  final File hostsFile = File('/etc/hosts');
  if (!hostsFile.existsSync()) {
    return const <String>[];
  }

  final Set<String> names = <String>{};
  for (String line in hostsFile.readAsLinesSync()) {
    final int hash = line.indexOf('#');
    if (hash >= 0) {
      line = line.substring(0, hash);
    }
    final List<String> parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.first != '127.0.0.1') {
      continue;
    }
    for (final String name in parts.skip(1)) {
      if (name.endsWith('.atsign.zone')) {
        names.add(name);
      }
    }
  }

  final List<String> args = <String>[];
  for (final String name in names) {
    args.add('--add-host');
    args.add('$name:host-gateway');
  }
  return args;
}

DockerImage dockerImageForVersion(final NoPortsVersion version) {
  final Language language = version.language;
  final String versionTag = version.version;

  if (versionTag == 'current') {
    return DockerImage.current(language: language);
  } else if (versionTag.startsWith('v')) {
    return DockerImage.release(language: language, version: versionTag);
  } else {
    return DockerImage.branch(language: language, branch: versionTag);
  }
}

/// Collects stdout and stderr from a [Process] into string buffers.
/// Returns a record of (stdout, stderr) after the process completes.
Future<(String, String)> _captureProcessOutput(final Process process) async {
  final StringBuffer stdoutBuf = StringBuffer();
  final StringBuffer stderrBuf = StringBuffer();
  await Future.wait([
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) => stdoutBuf.write(chunk)),
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) => stderrBuf.write(chunk)),
  ]);
  return (stdoutBuf.toString(), stderrBuf.toString());
}

Future<DockerImage> ensureDockerImageVersion({
  required final NoPortsVersion daemonVersion,
  final bool skipBuildCurrent = false,
}) async {
  final DockerImage dockerImage = dockerImageForVersion(daemonVersion);

  if (dockerImage.tag == 'current') {
    if (!skipBuildCurrent) {
      final Process buildProcess = await dockerImage.build(quiet: true);
      final (String buildStdout, String buildStderr) =
          await _captureProcessOutput(buildProcess);
      final int buildExitCode = await buildProcess.exitCode;
      if (buildExitCode != 0) {
        throw Exception(
          'Failed to build docker image ${dockerImage.fullImageName}.'
          ' Exit code: $buildExitCode'
          '\nstdout:\n$buildStdout'
          '\nstderr:\n$buildStderr',
        );
      }
    }
  } else {
    final Process pullProcess = await dockerImage.pull(quiet: true);
    final (String pullStdout, String pullStderr) = await _captureProcessOutput(
      pullProcess,
    );
    final int pullExitCode = await pullProcess.exitCode;
    if (pullExitCode != 0) {
      print(
        'docker pull failed for ${dockerImage.fullImageName}'
        ' (exit $pullExitCode) — falling back to build.'
        '\npull stdout:\n$pullStdout'
        '\npull stderr:\n$pullStderr',
      );
      final Process buildProcess = await dockerImage.build(quiet: true);
      final (String buildStdout, String buildStderr) =
          await _captureProcessOutput(buildProcess);
      final int buildExitCode = await buildProcess.exitCode;
      if (buildExitCode != 0) {
        throw Exception(
          'Failed to build docker image ${dockerImage.fullImageName}'
          ' after pull also failed.'
          ' Build exit code: $buildExitCode'
          '\nbuild stdout:\n$buildStdout'
          '\nbuild stderr:\n$buildStderr',
        );
      }
    }
  }

  if (!(await dockerImage.existsOnMachine())) {
    throw Exception(
      'Docker image ${dockerImage.fullImageName} should have been built or pulled, but it does not exist on machine',
    );
  }

  return dockerImage;
}

Future<List<DockerImage>> ensureDockerImagesVersionBuiltParallel({
  required final List<NoPortsVersion> versions,
  final bool skipBuildCurrent = false,
}) {
  final Map<String, NoPortsVersion> deduped = {};
  for (final NoPortsVersion version in versions) {
    deduped['${version.language.name}:${version.version}'] = version;
  }

  return Future.wait(
    deduped.values.map((version) {
      return ensureDockerImageVersion(
        daemonVersion: version,
        skipBuildCurrent: skipBuildCurrent,
      );
    }),
  );
}

Future<DockerInstance> runDockerInstance({
  required final DockerImage dockerImage,
  required final String testRunId,
  required final Directory logsDirectory,
  required final List<String> entrypoint,
  final String uniqueIdentifier = '',
  final String? containerName,
  final List<VolumeMapping> volumeMappings = const <VolumeMapping>[],
  final List<PortMapping> portMappings = const <PortMapping>[],
  final Map<String, String> environment = const <String, String>{},
  final String? networkName,
  final String? networkAlias,
  final List<String> additionalDockerArgs = const <String>[],
  final bool quiet = false,
  final bool removeWhenStopped = true,
  final bool printCommand = true,
}) async {
  final DockerInstance dockerInstance = DockerInstance(
    dockerImage: dockerImage,
    testRunId: testRunId,
    uniqueIdentifier: uniqueIdentifier,
    containerName: containerName,
  );
  final File stdoutLogFile = File(
    '${logsDirectory.path}/${dockerInstance.containerName}_stdout.log',
  );
  final File stderrLogFile = File(
    '${logsDirectory.path}/${dockerInstance.containerName}_stderr.log',
  );

  await dockerInstance.run(
    entrypoint: entrypoint,
    quiet: quiet,
    removeWhenStopped: removeWhenStopped,
    printCommand: printCommand,
    volumeMappings: volumeMappings,
    portMappings: portMappings,
    environment: environment,
    networkName: networkName,
    networkAlias: networkAlias,
    additionalDockerArgs: additionalDockerArgs,
    stdoutLogFile: stdoutLogFile,
    stderrLogFile: stderrLogFile,
  );

  return dockerInstance;
}
