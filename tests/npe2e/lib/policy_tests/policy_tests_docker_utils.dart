import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/docker_utils.dart';
import 'package:npe2e/noports_version.dart';
export 'package:npe2e/docker_utils.dart';

String getPolicyDaemonDeviceName({
  required final String testRunId,
  required final NoPortsVersion daemonVersion,
}) {
  return '${testRunId}_${daemonVersion.language.name}_${daemonVersion.version}_policy';
}

Future<List<DockerImage>> ensurePolicyDockerDaemonsBuiltParallel({
  required final List<NoPortsVersion> daemonVersions,
  final bool skipBuildCurrent = false,
}) {
  return ensureDockerImagesVersionBuiltParallel(
    versions: daemonVersions,
    skipBuildCurrent: skipBuildCurrent,
  );
}

Future<List<(String, DockerInstance)>> startPolicyDockerDaemonsParallel({
  required final List<NoPortsVersion> daemonVersions,
  required final List<DockerImage> allDockerImages,
  required final String daemonAtsign,
  required final String policyManagerAtsign,
  required final String rootDomain,
  required final String testRunId,
  required final Directory daemonLogsDirectory,
  required final File daemonApkamKeysFile,
}) {
  final List<Future<(String, DockerInstance)>> futures = [];

  for (final NoPortsVersion daemonVersion in daemonVersions) {
    final DockerImage dockerImage = allDockerImages.firstWhere(
      (image) =>
          image.language == daemonVersion.language &&
          image.tag == daemonVersion.version,
      orElse: () => throw Exception(
        'Docker image for language ${daemonVersion.language.name} and version ${daemonVersion.version} not found in allDockerImages list',
      ),
    );
    final String deviceName = getPolicyDaemonDeviceName(
      testRunId: testRunId,
      daemonVersion: daemonVersion,
    );
    final String daemonAtsignContainerKeyFilePath =
        '/atsign/.atsign/keys/${path.basename(daemonApkamKeysFile.path)}';

    futures.add(
      runDockerInstance(
        dockerImage: dockerImage,
        testRunId: testRunId,
        logsDirectory: daemonLogsDirectory,
        entrypoint: [
          '/bin/bash',
          '-c',
          'sudo service ssh start && '
              '/usr/local/bin/sshnpd '
              '-a ${daemonAtsign} '
              '-p ${policyManagerAtsign} '
              '-k ${daemonAtsignContainerKeyFilePath} '
              '--root-domain ${rootDomain} '
              '-d ${deviceName} '
              '-v -s -u',
        ],
        volumeMappings: [
          VolumeMapping(
            local: daemonApkamKeysFile.absolute.path,
            container: daemonAtsignContainerKeyFilePath,
          ),
        ],
      ).then((dockerInstance) => (deviceName, dockerInstance)),
    );
  }

  return Future.wait(futures);
}
