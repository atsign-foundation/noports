import 'dart:io';

import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_image.dart';

class PolicyTestsContext {
  final String testRunId;
  final Directory baseDirectory;
  final Directory logsDirectory;
  final Map<String, File> apkamKeys;
  final List<ClientBinary> clientBinaries;
  final List<DockerImage> dockerImages;
  final String clientAtsign;
  final String daemonAtsign;
  final String relayAtsign;
  final String nppAtsign;
  final String nppAtServerAtsign;
  final String rootDomain;

  PolicyTestsContext({
    required this.testRunId,
    required this.baseDirectory,
    required this.logsDirectory,
    required this.apkamKeys,
    required this.clientBinaries,
    required this.dockerImages,
    required this.clientAtsign,
    required this.daemonAtsign,
    required this.relayAtsign,
    required this.nppAtsign,
    required this.nppAtServerAtsign,
    required this.rootDomain,
  });
}
