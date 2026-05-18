import 'dart:io';

import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';

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

Future<DockerImage> ensureDockerImageVersion({
  required final NoPortsVersion daemonVersion,
  final bool skipBuildCurrent = false,
}) async {
  final DockerImage dockerImage = dockerImageForVersion(daemonVersion);

  if (dockerImage.tag == 'current') {
    if (!skipBuildCurrent) {
      final Process buildProcess = await dockerImage.build(quiet: true);
      final int buildExitCode = await buildProcess.exitCode;
      if (buildExitCode != 0) {
        throw Exception(
          'Failed to build docker image ${dockerImage.fullImageName}. Exit code: $buildExitCode',
        );
      }
    }
  } else {
    final Process pullProcess = await dockerImage.pull(quiet: true);
    final int pullExitCode = await pullProcess.exitCode;
    if (pullExitCode != 0) {
      final Process buildProcess = await dockerImage.build(quiet: true);
      final int buildExitCode = await buildProcess.exitCode;
      if (buildExitCode != 0) {
        throw Exception(
          'Failed to build docker image ${dockerImage.fullImageName}. Exit code: $buildExitCode',
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
