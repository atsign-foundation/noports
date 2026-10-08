import 'dart:io';
import 'package:npe2e/client_binary.dart';
import 'package:npe2e/docker_instance.dart';

class CoreTestsContext {
  final String testRunId;
  final String clientAtsign;
  final String daemonAtsign;
  final String relayAtsign;
  final String unauthorizedAtsign;
  final String rootDomain;
  final String remoteUsername;
  final String identityFilePath;
  final List<ClientBinary> clientBinaries;
  final List<(String, DockerInstance)>
  dockerInstances; // deviceName, DockerInstance
  final Map<String, File> apkamKeys;
  final Directory logsDirectory;

  CoreTestsContext({
    required this.testRunId,
    required this.clientAtsign,
    required this.daemonAtsign,
    required this.relayAtsign,
    required this.unauthorizedAtsign,
    required this.rootDomain,
    required this.remoteUsername,
    required this.identityFilePath,
    required this.clientBinaries,
    required this.dockerInstances,
    required this.apkamKeys,
    required this.logsDirectory,
  });
}
