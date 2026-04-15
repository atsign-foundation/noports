import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';

// returns a list of tuples of (deviceName, DockerInstance)
// all of these docker instances have been started
Future<List<(String, DockerInstance)>> startDockerDaemons({
  required final List<String> daemonVersions,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String daemonAtsignContainerKeyFilePath,
  required final String rootDomain,
  required final String testRunId,
  required final Directory apkamKeysDirectory,
}) async {
  final List<DockerImage> dockerImages = [];
  for(final String daemonVersion in daemonVersions) {
    final NoPortsVersion noPortsVersion = NoPortsVersion.fromLanguageVersionString(daemonVersion);
    final Language language = noPortsVersion.language;
    final String version = noPortsVersion.version;
    
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
      final Process pullProcess = await dockerImage.pull(quiet: true);
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

  final List<(String, DockerInstance)> dockerInstances = [];
  for(final DockerImage dockerImage in dockerImages) {
    final DockerInstance dockerInstance1 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );
    final String deviceNameNoFlags = getDeviceNameNoFlags(testRunId: testRunId,
      language: dockerInstance1.dockerImage.language,
      version: dockerInstance1.dockerImage.tag);
    await dockerInstance1.run(
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
    );
    dockerInstances.add((deviceNameNoFlags, dockerInstance1));

    final DockerInstance dockerInstance2 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      uniqueIdentifier: '_f',
    );
    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
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
    ); 
    dockerInstances.add((deviceNameWithFlags, dockerInstance2));
  }

  sleep(const Duration(seconds: 2));

  // ensure monitor has started
  final List<(String deviceName, Completer<void> completer, Process process)> monitors = [];

  for(final (String deviceName, DockerInstance dockerInstance) in dockerInstances) {
    const String monitorMessage = 'monitor started';
    final Completer<void> monitorStartedCompleter = Completer<void>();
    final Process logsProcess = await Process.start('docker', ['logs', '-f', dockerInstance.containerName]);

    logsProcess.stdout.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((String line) {
      // print('stdout [$deviceName] $line');
      if(line.toLowerCase().contains(monitorMessage)) {
        // print('stdout [$deviceName] Monitor started, SSH server is ready');
        if(!monitorStartedCompleter.isCompleted) {
          monitorStartedCompleter.complete();
        }
        logsProcess.kill();
      }
    });

    logsProcess.stderr.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((String line) {
      // print('stderr [$deviceName] $line');
      if(line.toLowerCase().contains(monitorMessage)) {
        // print('stderr [$deviceName] Monitor started, SSH server is ready');
        if(!monitorStartedCompleter.isCompleted) {
          monitorStartedCompleter.complete();
        }
        logsProcess.kill();
      }
    });

    monitors.add((deviceName, monitorStartedCompleter, logsProcess));
  }

  // now wait for all monitors to complete
  for(final (String deviceName, Completer<void> completer, Process process) in monitors) {
    await completer.future.timeout(
      Duration(seconds: 60),
      onTimeout: () {
        process.stderr.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((String line) {
          print('stderr [$deviceName] $line');
        });
        process.stdout.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((String line) {
          print('stdout [$deviceName] $line');
        });
        throw TimeoutException('[$deviceName] Monitor did not start within 60 seconds');
      },
    );
  }

  return dockerInstances;
}
