import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';

// Ensures that the docker daemons for specified daemon versions are built and available on machine.
// Things to note:
// 1. It will always build any `current` images, unless skipBuildCurrent=true
// 2. It will try to `docker pull`, if it DNE, it will `docker build`.
// 3. Current images are not pushed to registry, so they will always be built locally (unless skipBuildCurrent=true)
Future<List<DockerImage>> ensureDockerDaemonsBuiltParallel({
  required final List<NoPortsVersion> daemonVersions,
  final bool skipBuildCurrent = false, // setting this to true will skip building the `d:current` and `c:current` docker images, and use ones if ones already exist
}) async {
  // 1. Let's build a list of Docker images (not yet confirmed existance on machine)
  final List<DockerImage> dockerImagesToEnsure = [];
  for(final NoPortsVersion daemonVersion in daemonVersions) {
    final Language language = daemonVersion.language;
    final String version = daemonVersion.version;
    
    DockerImage dockerImage;
    if(version == 'current') {
      dockerImage = DockerImage.current(language: language); 
    } else if(version.startsWith('v')) {
      dockerImage = DockerImage.release(language: language, version: version);
    } else {
      dockerImage = DockerImage.branch(language: language, branch: version);
    }
    dockerImagesToEnsure.add(dockerImage);
  }

  final List<Future<Process>> pullFutures = []; // list of docker pull processes
  final List<Future<Process>> buildFutures = []; // list of docker build processes

  // 2. Let's set up `pullFutures` and `buildFutures` lists

  // 2a. Set up `pullFutures`. If it's `current`, then we know it can't be pulled.
  for(final DockerImage dockerImage in dockerImagesToEnsure) {
    if(dockerImage.tag == 'current') {
      final Future<Process> buildFuture = dockerImage.build(quiet: true);
      buildFutures.add(buildFuture);
    } else {
      final Future<Process> pullProcess = dockerImage.pull(quiet: true);
      pullFutures.add(pullProcess);
    }
  }

  // 2b. Try to pull . If pull fails, add to `buildFutures`
  for(final Future<Process> pullFuture in pullFutures) {
    final DockerImage dockerImage = dockerImagesToEnsure[pullFutures.indexOf(pullFuture)];
    final Process pullProcess = await pullFuture;
    final int pullExitCode = await pullProcess.exitCode;
    if (pullExitCode != 0) {
      final Future<Process> buildFuture = dockerImage.build(quiet: true);
      buildFutures.add(buildFuture);
    }
  }

  // 2c. Resolve buildFutures, if any build fails, throw
  for(final Future<Process> buildFuture in buildFutures) {
    final Process buildProcess = await buildFuture;
    final int buildExitCode = await buildProcess.exitCode;
    if (buildExitCode != 0) {
      throw Exception('Failed to build docker image. Exit code: $buildExitCode');
    }
  }

  // 2d. ATP we should have all images either pulled or built.
  for(final DockerImage dockerImage in dockerImagesToEnsure) {
    if(!(await dockerImage.existsOnMachine())) {
      throw Exception('Docker image ${dockerImage.fullImageName} should have been built or pulled, but it does not exist on machine');
    }
  }

  return dockerImagesToEnsure;
}

// starts a collection of DockerInstance objects in parallel
// for each daemonVersion, we will start 2 docker instances:
// 1. one without -s -u flag (deviceName will be `getDeviceNameNoFlags()`
// 2. one with -s -u flag (deviceName will be '${getDeviceNameNoFlags()}_f')
Future<List<(String, DockerInstance)>> startDockerDaemonsParallel({
  required final List<NoPortsVersion> daemonVersions,
  required final List<DockerImage> allDockerImages, // expected to exist and be built
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String rootDomain,
  required final String testRunId,
  required final Directory daemonLogsDirectory, // the directory where we're going to pull full life daemon logs
  required final File daemonApkamKeysFile, // atKeys file of daemon to put into the container
}) async {
  final List<(String, DockerInstance)> dockerInstances = [];
  for(final NoPortsVersion daemonVersion in daemonVersions) {
    final DockerImage dockerImage = allDockerImages.firstWhere((image) => image.language == daemonVersion.language && image.tag == daemonVersion.version, orElse: () => throw Exception('Docker image for language ${daemonVersion.language.name} and version ${daemonVersion.version} not found in allDockerImages list'));
    final String daemonAtsignContainerKeyFilePath =
      '/atsign/.atsign/keys/'
      '${path.basename(daemonApkamKeysFile.path)}';
    final VolumeMapping volumeMapping = VolumeMapping(
      local: daemonApkamKeysFile.absolute.path,
      container: daemonAtsignContainerKeyFilePath);

    // 1. start up first docker instance (without -s -u flag)
    final DockerInstance dockerInstance1 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );
    final String deviceNameNoFlags = getDeviceNameNoFlags(
      testRunId: testRunId,
      noPortsVersion: daemonVersion,
    );
    final File stdout1 = File('${daemonLogsDirectory.path}/${dockerInstance1.containerName}_stdout.log');
    final File stderr1 = File('${daemonLogsDirectory.path}/${dockerInstance1.containerName}_stderr.log');
    await dockerInstance1.run( // sudo docker run 
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
        '/usr/local/bin/sshnpd '
          '-a ${daemonAtsign} '
          '-m ${clientAtsign} '
          '-k ${daemonAtsignContainerKeyFilePath} '
          '--root-domain ${rootDomain} '
          '-d ${deviceNameNoFlags} '
          '-v '
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [
        volumeMapping,
      ],
      stdoutLogFile: stdout1,
      stderrLogFile: stderr1,
    );
    dockerInstances.add((deviceNameNoFlags, dockerInstance1));

    // 2. start up second docker instance (with -s -u flag)
    final DockerInstance dockerInstance2 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      uniqueIdentifier: '_f',
    );
    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
    final File stdout2 = File('${daemonLogsDirectory.path}/${dockerInstance2.containerName}_stdout.log');
    final File stderr2 = File('${daemonLogsDirectory.path}/${dockerInstance2.containerName}_stderr.log');
    await dockerInstance2.run(
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
        '/usr/local/bin/sshnpd '
        '-a ${daemonAtsign} '
        '-m ${clientAtsign} '
        '-k ${daemonAtsignContainerKeyFilePath} '
        '--root-domain ${rootDomain} '
        '-d ${deviceNameWithFlags} '
        '-v -s -u'
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [
        volumeMapping,
      ],
      stdoutLogFile: stdout2,
      stderrLogFile: stderr2,
    );
    dockerInstances.add((deviceNameWithFlags, dockerInstance2));
  }

  await Future.delayed(Duration(milliseconds: 100));

  // now wait for all monitors to complete by polling log files
  const String monitorMessage = 'monitor started';
  const int monitorTimeoutSeconds = 30; // TODO make this a params flag
  for(final (String _, DockerInstance dockerInstance) in dockerInstances) {
    final File? stdoutLogFile = dockerInstance.stdoutLogFile;
    if (stdoutLogFile == null && !(await stdoutLogFile!.exists())) {
      throw Exception('[${dockerInstance.containerName}] Log files not set on docker instance');
    }
    final File? stderrLogFile = dockerInstance.stderrLogFile;
    if (stderrLogFile == null && !(await stderrLogFile!.exists())) {
      throw Exception('[${dockerInstance.containerName}] Log files not set on docker instance');
    }
  
    bool monitorMessageFound = false;
    for(int i = 0; i < monitorTimeoutSeconds; i++) {
      final String stdoutContent = await stdoutLogFile.readAsString();
      final String stderrContent = await stderrLogFile.readAsString();
      if(stdoutContent.contains(monitorMessage) || stderrContent.contains(monitorMessage)) {
        monitorMessageFound = true;
        print('Monitor message found for container ${dockerInstance.containerName} after ${i+1} seconds');
        break;
      }
      await Future.delayed(Duration(seconds: 1));
    }

    if(!monitorMessageFound) {
      throw Exception('Monitor message not found in logs for container ${dockerInstance.containerName} after waiting for $monitorTimeoutSeconds seconds. Please check the logs for more details.');
    }
  }

  return dockerInstances;
}

