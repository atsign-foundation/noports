import 'dart:io';
import 'package:at_utils/at_utils.dart';
import 'package:e2e_all_v2/docker_manager.dart';
import 'package:e2e_all_v2/e2e_all_v2_params.dart';

final AtSignLogger logger = AtSignLogger('test_minus_r_flag');

/// Test: minus_r_flag
///
/// 1. Run sshnp with `--host` (expect to pass)
/// 2. Run sshnp with `-h` invalid and `-r` valid (expect to pass)
/// 3. Run sshnp with `-h` valid and `-r` invalid (expect to fail)
///
/// Test matrix:
/// - Client: Dart (current) | Daemon: Dart (current)
/// - Client: Dart v5.9.4 | Daemon: Dart (current)
/// - Client: Dart v5.11.2 | Daemon: Dart (current)
/// - Client: Dart v5.13.0 | Daemon: Dart (current)
/// - Client: Dart (current) | Daemon: Dart v5.9.4
/// - Client: Dart v5.9.4 | Daemon: Dart v5.9.4
/// - Client: Dart v5.11.2 | Daemon: Dart v5.9.4
/// - Client: Dart v5.13.0 | Daemon: Dart v5.9.4
/// - Client: Dart (current) | Daemon: Dart v5.11.2
/// - Client: Dart v5.9.4 | Daemon: Dart v5.11.2
/// - Client: Dart v5.11.2 | Daemon: Dart v5.11.2
/// - Client: Dart v5.13.0 | Daemon: Dart v5.11.2
/// - Client: Dart (current) | Daemon: Dart v5.13.0
/// - Client: Dart v5.9.4 | Daemon: Dart v5.13.0
/// - Client: Dart v5.11.2 | Daemon: Dart v5.13.0
/// - Client: Dart v5.13.0 | Daemon: Dart v5.13.0
Future<int> testMinusRFlag({
  required E2EAllV2Params params,
  required String testRunId,
}) async {
  logger.info('Starting test: minus_r_flag');

  // Define test matrix - all combinations of client/daemon versions
  final List<String> clientVersions = [
    'd:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];

  final List<String> daemonVersions = [
    'd:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];

  final List<(String, String)> testCases = [];
  for (final clientVersion in clientVersions) {
    for (final daemonVersion in daemonVersions) {
      testCases.add((clientVersion, daemonVersion));
    }
  }

  // Build unique set of Docker images needed
  final Set<String> uniqueImageSpecs = {};
  for (final testCase in testCases) {
    uniqueImageSpecs.add(testCase.$1); // client
    uniqueImageSpecs.add(testCase.$2); // daemon
  }

  logger.info('Test cases: ${testCases.length}');
  logger.info('Unique images needed: ${uniqueImageSpecs.length}');

  // Build or pull all required Docker images
  final List<DockerImage> builtDockerImages = [];
  final List<DockerImage> failedDockerImages = [];

  for (final imageSpec in uniqueImageSpecs) {
    final dockerImage = _parseImageSpec(imageSpec);
    if (dockerImage == null) continue;

    final bool existsOnMachine = await dockerImage.existsOnMachine();
    if (!existsOnMachine) {
      final Process tryPullProcess = await dockerImage.pull();
      final int tryPullProcessExitCode = await tryPullProcess.exitCode;
      if (tryPullProcessExitCode != 0) {
        logger.info('Attempted to pull ${dockerImage.fullImageName} but was not found. Building it locally...');
        final Process buildProcess = await dockerImage.build(forceOverwriteCache: false);
        final int buildExitCode = await buildProcess.exitCode;
        if (buildExitCode == 0) {
          logger.info('Built ${dockerImage.fullImageName} successfully');
          builtDockerImages.add(dockerImage);
        } else {
          logger.severe('Failed to build ${dockerImage.fullImageName}');
          failedDockerImages.add(dockerImage);
        }
      } else {
        logger.info('Pulled ${dockerImage.fullImageName} successfully');
        builtDockerImages.add(dockerImage);
      }
    } else {
      logger.info('${dockerImage.fullImageName} already exists on machine');
      builtDockerImages.add(dockerImage);
    }
  }

  if (failedDockerImages.isNotEmpty) {
    logger.severe('Failed to build ${failedDockerImages.length} images');
    return 1;
  }

  logger.info('All Docker images ready (${builtDockerImages.length})');

  // TODO: Run actual tests with the built images
  logger.info('Test execution not yet implemented');

  return 0;
}

DockerImage? _parseImageSpec(String imageSpec) {
  final parts = imageSpec.split(':');
  if (parts.length != 2) {
    logger.severe('Invalid image spec: $imageSpec');
    return null;
  }

  Language language;
  switch (parts[0]) {
    case 'd':
      language = Language.dart;
      break;
    case 'c':
      language = Language.c;
      break;
    default:
      logger.severe('Unknown language: ${parts[0]}');
      return null;
  }

  final String version = parts[1];
  if (version.startsWith('v')) {
    return DockerImage.release(language: language, version: version);
  } else if (version == 'current') {
    return DockerImage.current(language: language);
  } else {
    return DockerImage.branch(language: language, branch: version);
  }
}
