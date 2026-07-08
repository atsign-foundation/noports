import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/docker_utils.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';

// e.g. 'v5.9.4' --> '594', 'c0.0.1' --> '001', 'current' --> 'c'
// '5.9.4' --> '594', '0.0.1' --> '001'
String _versionForDeviceName(final String version) {
  String s;
  if (version == 'current') {
    s = 'c';
    return s;
  }
  s = version.replaceAll('.', '').replaceAll('v', '').replaceAll('c', '');

  if (s.length > 6) {
    s = s.substring(0, 6);
  }
  return s;
}

String getDeviceNameNoFlags({
  required final String testRunId,
  required final NoPortsVersion noPortsVersion,
}) {
  final Language language = noPortsVersion.language;
  final String version = noPortsVersion.version;
  return '${testRunId}${language.name.substring(0, 1)}${_versionForDeviceName(version)}';
}

// Ensures that the docker daemons for specified daemon versions are built and available on machine.
// Things to note:
// 1. It will always build any `current` images, unless skipBuildCurrent=true
// 2. It will try to `docker pull`, if it DNE, it will `docker build`.
// 3. Current images are not pushed to registry, so they will always be built locally (unless skipBuildCurrent=true)
Future<List<DockerImage>> ensureDockerDaemonsBuiltParallel({
  required final List<NoPortsVersion> daemonVersions,
  final bool skipBuildCurrent =
      false, // setting this to true will skip building the `d:current` and `c:current` docker images, and use ones if ones already exist
}) async {
  return Future.wait(
    daemonVersions.map((daemonVersion) {
      return ensureDockerImageVersion(
        daemonVersion: daemonVersion,
        skipBuildCurrent: skipBuildCurrent,
      );
    }),
  );
}

// Local-run aid: when the npe2e tests run against atServers on the developer's
// own machine (reached via `/etc/hosts` overrides such as
// `127.0.0.1 vip.ve.atsign.zone`), mirror those overrides into the daemon
// containers. A container can't reach the host on 127.0.0.1, so each mapped
// name is re-pointed at `host-gateway`, Docker's route back to the host.
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

// starts a collection of DockerInstance objects in parallel
// for each daemonVersion, we will start 2 docker instances:
// 1. one without -s -u flag (deviceName will be `getDeviceNameNoFlags()`
// 2. one with -s -u flag (deviceName will be '${getDeviceNameNoFlags()}_f')
Future<List<(String, DockerInstance)>> startDockerDaemonsParallel({
  required final List<NoPortsVersion> daemonVersions,
  required final List<DockerImage>
  allDockerImages, // expected to exist and be built
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String rootDomain,
  required final String testRunId,
  required final Directory
  daemonLogsDirectory, // the directory where we're going to pull full life daemon logs
  required final File
  daemonApkamKeysFile, // atKeys file of daemon to put into the container
}) async {
  final List<(String, DockerInstance)> dockerInstances = [];
  final List<String> addHostArgs = hostGatewayAddHostArgs();
  if (addHostArgs.isNotEmpty) {
    print('Injecting host /etc/hosts overrides into daemon containers: '
        '${addHostArgs.join(' ')}');
  }
  for (final NoPortsVersion daemonVersion in daemonVersions) {
    final DockerImage dockerImage = allDockerImages.firstWhere(
      (image) =>
          image.language == daemonVersion.language &&
          image.tag == daemonVersion.version,
      orElse: () => throw Exception(
        'Docker image for language ${daemonVersion.language.name} and version ${daemonVersion.version} not found in allDockerImages list',
      ),
    );
    final String daemonAtsignContainerKeyFilePath =
        '/atsign/.atsign/keys/'
        '${path.basename(daemonApkamKeysFile.path)}';
    final VolumeMapping volumeMapping = VolumeMapping(
      local: daemonApkamKeysFile.absolute.path,
      container: daemonAtsignContainerKeyFilePath,
    );

    // 1. start up first docker instance (without -s -u flag)
    final DockerInstance dockerInstance1 = await runDockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      logsDirectory: daemonLogsDirectory,
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
            '/usr/local/bin/sshnpd '
            '-a ${daemonAtsign} '
            '-m ${clientAtsign} '
            '-k ${daemonAtsignContainerKeyFilePath} '
            '--root-domain ${rootDomain} '
            '-d ${getDeviceNameNoFlags(testRunId: testRunId, noPortsVersion: daemonVersion)} '
            '-v ',
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [volumeMapping],
      additionalDockerArgs: addHostArgs,
    );
    final String deviceNameNoFlags = getDeviceNameNoFlags(
      testRunId: testRunId,
      noPortsVersion: daemonVersion,
    );
    dockerInstances.add((deviceNameNoFlags, dockerInstance1));

    // 2. start up second docker instance (with -s -u flag)
    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
    final DockerInstance dockerInstance2 = await runDockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      logsDirectory: daemonLogsDirectory,
      uniqueIdentifier: '_f',
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
            '-v -s -u',
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [volumeMapping],
      additionalDockerArgs: addHostArgs,
    );
    dockerInstances.add((deviceNameWithFlags, dockerInstance2));
  }

  await Future.delayed(Duration(milliseconds: 100));

  // now wait for all monitors to complete by polling log files
  const String monitorMessage = 'monitor started';
  const int monitorTimeoutSeconds = 30; // TODO make this a params flag
  for (final (String _, DockerInstance dockerInstance) in dockerInstances) {
    final File? stdoutLogFile = dockerInstance.stdoutLogFile;
    if (stdoutLogFile == null || !(await stdoutLogFile.exists())) {
      throw Exception(
        '[${dockerInstance.containerName}] Log files not set on docker instance',
      );
    }
    final File? stderrLogFile = dockerInstance.stderrLogFile;
    if (stderrLogFile == null || !(await stderrLogFile.exists())) {
      throw Exception(
        '[${dockerInstance.containerName}] Log files not set on docker instance',
      );
    }

    bool monitorMessageFound = false;
    for (int i = 0; i < monitorTimeoutSeconds; i++) {
      final String stdoutContent = await stdoutLogFile.readAsString();
      final String stderrContent = await stderrLogFile.readAsString();
      if (stdoutContent.contains(monitorMessage) ||
          stderrContent.contains(monitorMessage)) {
        monitorMessageFound = true;
        print(
          'Monitor message found for container ${dockerInstance.containerName} after ${i + 1} seconds',
        );
        break;
      }
      await Future.delayed(Duration(seconds: 1));
    }

    if (!monitorMessageFound) {
      throw Exception(
        'Monitor message not found in logs for container ${dockerInstance.containerName} after waiting for $monitorTimeoutSeconds seconds. Please check the logs for more details.',
      );
    }
  }

  return dockerInstances;
}
