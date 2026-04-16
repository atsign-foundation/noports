import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';

// returns a list of tuples of (deviceName, DockerInstance)
// all of these docker instances have been started
Future<List<(String, DockerInstance)>> startDockerDaemons({
  required final List<NoPortsVersion> daemonVersions,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String daemonAtsignContainerKeyFilePath,
  required final String rootDomain,
  required final String testRunId,
  required final Directory apkamKeysDirectory,
  required final Directory logsDirectory,
}) async {
  final List<DockerImage> dockerImages = [];
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
    dockerImages.add(dockerImage);
  }

  // ensure all docker images exist on machine
  for(final DockerImage dockerImage in dockerImages) {
    if(!(await dockerImage.existsOnMachine())) {
      print('Docker image not found on machine: ${dockerImage.fullImageName}. Pulling from registry...');
      final Process pullProcess = await dockerImage.pull(quiet: true); // sudo docker pull <imageName>
      if((await pullProcess.exitCode) != 0) {
        print('Failed to pull docker image ${dockerImage.fullImageName}. Exit code: ${await pullProcess.exitCode}');
        print('Building instead...');
        final Process buildProcess = await dockerImage.build(quiet: true);
        if((await buildProcess.exitCode) != 0) {
          throw Exception('Failed to build docker image ${dockerImage.fullImageName}. Exit code: ${await buildProcess.exitCode}');
        }
      }
    } else {
      print('Docker image already exists on machine: ${dockerImage.fullImageName}');
    }
  }

  // create log directory structure
  final Directory daemonsLogsDirectory = Directory(path.join(logsDirectory.path, 'daemons'));
  if (!daemonsLogsDirectory.existsSync()) {
    daemonsLogsDirectory.createSync(recursive: true);
  }

  final List<(String, DockerInstance)> dockerInstances = [];
  for(final DockerImage dockerImage in dockerImages) {
    final DockerInstance dockerInstance1 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );
    final String deviceNameNoFlags = getDeviceNameNoFlags(testRunId: testRunId,
      language: dockerInstance1.dockerImage.language,
      version: dockerInstance1.dockerImage.tag);

    final File stdout1 = File('${daemonsLogsDirectory.path}/${dockerInstance1.containerName}_stdout.log');
    final File stderr1 = File('${daemonsLogsDirectory.path}/${dockerInstance1.containerName}_stderr.log');

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
        VolumeMapping(
          localDirectory: apkamKeysDirectory,
          containerDirectory: '/atsign/.atsign/keys',
        ),
      ],
      stdoutLogFile: stdout1,
      stderrLogFile: stderr1,
    );
    dockerInstances.add((deviceNameNoFlags, dockerInstance1));

    final DockerInstance dockerInstance2 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      uniqueIdentifier: '_f',
    );
    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';

    final File stdout2 = File('${daemonsLogsDirectory.path}/${dockerInstance2.containerName}_stdout.log');
    final File stderr2 = File('${daemonsLogsDirectory.path}/${dockerInstance2.containerName}_stderr.log');

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
        VolumeMapping(
          localDirectory: apkamKeysDirectory,
          containerDirectory: '/atsign/.atsign/keys',
        ),
      ],
      stdoutLogFile: stdout2,
      stderrLogFile: stderr2,
    );
    dockerInstances.add((deviceNameWithFlags, dockerInstance2));
  }

  sleep(Duration(seconds: 5));

  // now wait for all monitors to complete by polling log files
  const String monitorMessage = 'monitor started';
  for(final (String deviceName, DockerInstance dockerInstance) in dockerInstances) {
    final File? stdoutLog = dockerInstance.stdoutLogFile;
    final File? stderrLog = dockerInstance.stderrLogFile;
    if (stdoutLog == null || stderrLog == null) {
      throw Exception('[${dockerInstance.containerName}] Log files not set on docker instance');
    }

    final DateTime startTime = DateTime.now();
    const Duration timeout = Duration(seconds: 60);
    bool monitorStarted = false;

    while (!monitorStarted && DateTime.now().difference(startTime) < timeout) {
      // Check if log files exist and contain the monitor started message
      if (stderrLog.existsSync()) {
        final String content = stderrLog.readAsStringSync();
        if (content.toLowerCase().contains(monitorMessage)) {
          print('Daemon ${dockerInstance.dockerImage.language.name} ${dockerInstance.dockerImage.tag} (container: ${dockerInstance.containerName}) Monitor started');
          monitorStarted = true;
          break;
        }
      }
      await Future.delayed(Duration(seconds: 1));
    }

    if (!monitorStarted) {
      print('[${dockerInstance.containerName}] TIMEOUT: Monitor did not start within 60 seconds');
      print('[${dockerInstance.containerName}] Dumping recent stderr logs:');

      if (stderrLog.existsSync()) {
        final String stderrContent = stderrLog.readAsStringSync();
        print(stderrContent);
      } else {
        throw Exception('[${dockerInstance.containerName}] Monitor did not start and stderr log file is missing');
      }

      if (stdoutLog.existsSync()) {
        final String stdoutContent = stdoutLog.readAsStringSync();
        print(stdoutContent);
      } else {
        throw Exception('[$deviceName] Monitor did not start and stdout log file is missing');
      }

      throw TimeoutException('[${dockerInstance.containerName}] Monitor did not start within 60 seconds');
    }
  }

  return dockerInstances;
}
