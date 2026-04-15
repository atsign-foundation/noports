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

  // Create log directory structure
  final Directory logDirectory = Directory('e2e_all_v2/$testRunId/daemons');
  if (!logDirectory.existsSync()) {
    logDirectory.createSync(recursive: true);
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

    final File stdout1 = File('${logDirectory.path}/${dockerInstance1.containerName}_stdout.log');
    final File stderr1 = File('${logDirectory.path}/${dockerInstance1.containerName}_stderr.log');

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

    final File stdout2 = File('${logDirectory.path}/${dockerInstance2.containerName}_stdout.log');
    final File stderr2 = File('${logDirectory.path}/${dockerInstance2.containerName}_stderr.log');

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

  // ensure monitor has started by monitoring the log processes
  final List<(String deviceName, Completer<void> completer)> monitors = [];

  for(final (String deviceName, DockerInstance dockerInstance) in dockerInstances) {
    const String monitorMessage = 'monitor started';
    final Completer<void> monitorStartedCompleter = Completer<void>();

    // Use the logProcess that was already started by DockerInstance.run()
    final Process? logProcess = dockerInstance.logProcess;
    if (logProcess == null) {
      throw Exception('[$deviceName] Log process not started for docker instance');
    }

    logProcess.stdout.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((String line) {
      if(line.toLowerCase().contains(monitorMessage)) {
        if(!monitorStartedCompleter.isCompleted) {
          monitorStartedCompleter.complete();
        }
      }
    });

    logProcess.stderr.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((String line) {
      if(line.toLowerCase().contains(monitorMessage)) {
        if(!monitorStartedCompleter.isCompleted) {
          monitorStartedCompleter.complete();
        }
      }
    });

    monitors.add((deviceName, monitorStartedCompleter));
  }

  // now wait for all monitors to complete
  for(final (String deviceName, Completer<void> completer) in monitors) {
    // Find the corresponding docker instance to access its log files
    final DockerInstance dockerInstance = dockerInstances.firstWhere((tuple) => tuple.$1 == deviceName).$2;

    await completer.future.timeout(
      Duration(seconds: 60),
      onTimeout: () async {
        print('[$deviceName] TIMEOUT: Monitor did not start within 60 seconds');
        print('[$deviceName] Dumping recent stderr logs:');

        // Read the stderr log file to show what went wrong
        final File stderrLogFile = File('${logDirectory.path}/${dockerInstance.containerName}_stderr.log');
        final File stdoutLogFile = File('${logDirectory.path}/${dockerInstance.containerName}_stdout.log');

        if (stderrLogFile.existsSync()) {
          final String stderrContent = stderrLogFile.readAsStringSync();
          final List<String> stderrLines = stderrContent.split('\n');
          // Print last 50 lines of stderr
          final int startLine = stderrLines.length > 50 ? stderrLines.length - 50 : 0;
          for (int i = startLine; i < stderrLines.length; i++) {
            if (stderrLines[i].isNotEmpty) {
              print('  stderr: ${stderrLines[i]}');
            }
          }
        } else {
          print('  (stderr log file not found)');
        }

        print('[$deviceName] Dumping recent stdout logs:');
        if (stdoutLogFile.existsSync()) {
          final String stdoutContent = stdoutLogFile.readAsStringSync();
          final List<String> stdoutLines = stdoutContent.split('\n');
          // Print last 50 lines of stdout
          final int startLine = stdoutLines.length > 50 ? stdoutLines.length - 50 : 0;
          for (int i = startLine; i < stdoutLines.length; i++) {
            if (stdoutLines[i].isNotEmpty) {
              print('  stdout: ${stdoutLines[i]}');
            }
          }
        } else {
          print('  (stdout log file not found)');
        }

        throw TimeoutException('[$deviceName] Monitor did not start within 60 seconds');
      },
    );
  }

  return dockerInstances;
}
