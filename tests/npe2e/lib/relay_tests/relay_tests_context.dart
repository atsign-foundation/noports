import 'dart:io';

import 'package:npe2e/docker_image.dart';

class RelayTestsContext {
  final String testRunId;
  final Directory baseDirectory;
  final Directory logsDirectory;
  final Map<String, File> apkamKeys;
  final List<DockerImage> dockerImages;
  final String clientAtsign;
  final String daemonAtsign;
  final String prodRelayAtsign;
  final List<String> selfRelayAtsigns;
  final String rootDomain;

  RelayTestsContext({
    required this.testRunId,
    required this.baseDirectory,
    required this.logsDirectory,
    required this.apkamKeys,
    required this.dockerImages,
    required this.clientAtsign,
    required this.daemonAtsign,
    required this.prodRelayAtsign,
    required this.selfRelayAtsigns,
    required this.rootDomain,
  });
}
