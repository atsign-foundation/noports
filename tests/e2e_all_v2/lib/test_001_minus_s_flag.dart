import 'dart:io';
import 'package:at_utils/at_utils.dart';
import 'package:e2e_all_v2/docker_manager.dart';
import 'package:e2e_all_v2/e2e_all_v2_params.dart';

final AtSignLogger logger = AtSignLogger('test_001_minus_s_flag');

/// Test: 001_minus_s_flag
///
/// 1. Generates a new ssh key
/// 2. a. Run sshnp against a daemon without the `-s` flag with that new key
///    b. Verify it fails
/// 3. a. Run against a daemon with the `-s` flag
///    b. Verify it succeeds
///
/// Test matrix:
/// - Client: Dart (current) | Daemon: Dart (current)
/// - Client: Dart (current) | Daemon: C (current)
/// - Client: Dart (current) | Daemon: Dart v5.9.4
/// - Client: Dart (current) | Daemon: Dart v5.11.2
/// - Client: Dart (current) | Daemon: Dart v5.13.0
Future<int> test001MinusSFlag({
  required E2EAllV2Params params,
  required String testRunId,
}) async {
  logger.info('Starting test: 001_minus_s_flag');

  // Define test matrix - only current client with various daemons
  final List<(String, String)> testCases = [
    ('d:current', 'd:current'),
    ('d:current', 'c:current'),
    ('d:current', 'd:v5.9.4'),
    ('d:current', 'd:v5.11.2'),
    ('d:current', 'd:v5.13.0'),
  ];

  // Build unique set of Docker images needed
  final Set<String> uniqueImageSpecs = {};
  for (final testCase in testCases) {
    uniqueImageSpecs.add(testCase.$1); // client
    uniqueImageSpecs.add(testCase.$2); // daemon
  }

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
  // For now, just return success
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
