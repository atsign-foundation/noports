import 'dart:io';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_instance.dart';

class CoreTestsContext {
  final String testRunId;
  final String clientAtsign;
  final String daemonAtsign;
  final String relayAtsign;
  final String rootDomain;
  final String remoteUsername;
  final String identityFilePath;
  final List<ClientBinary> clientBinaries;
  final List<(String, DockerInstance)> dockerInstances;
  final Map<String, File> apkamKeys;
  final Directory logsDirectory;
  final bool alwaysOutputLogs;

  CoreTestsContext({
    required this.testRunId,
    required this.clientAtsign,
    required this.daemonAtsign,
    required this.relayAtsign,
    required this.rootDomain,
    required this.remoteUsername,
    required this.identityFilePath,
    required this.clientBinaries,
    required this.dockerInstances,
    required this.apkamKeys,
    required this.logsDirectory,
    required this.alwaysOutputLogs,
  });
}
