import 'dart:io';

import 'package:npe2e/client_binary.dart';
import 'package:npe2e/docker_image.dart';

class PolicyTestsContext {
  final String testRunId;
  final Directory baseDirectory;
  final Directory logsDirectory;
  final Directory daemonLogsDirectory;
  final Directory nppLogsDirectory;
  final Directory nppAtServerLogsDirectory;
  final Map<String, File> apkamKeys;
  final List<ClientBinary> clientBinaries;
  final List<DockerImage> dockerImages;
  final String clientAtsign;
  final String daemonAtsign;
  final String relayAtsign;
  final String nppAtsign;
  final String nppAtServerAtsign;
  final String rootDomain;

  /// Run-level plain-text copy of the harness's narration. Lives under
  /// [logsDirectory] because CI archives only that tree, so this is the only
  /// place the narration survives a failed run.
  final File transcriptLogFile;

  final bool verbose;

  PolicyTestsContext({
    required this.testRunId,
    required this.baseDirectory,
    required this.logsDirectory,
    required this.daemonLogsDirectory,
    required this.nppLogsDirectory,
    required this.nppAtServerLogsDirectory,
    required this.apkamKeys,
    required this.clientBinaries,
    required this.dockerImages,
    required this.clientAtsign,
    required this.daemonAtsign,
    required this.relayAtsign,
    required this.nppAtsign,
    required this.nppAtServerAtsign,
    required this.rootDomain,
    required this.transcriptLogFile,
    required this.verbose,
  });
}
