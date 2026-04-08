import 'package:e2e_all_v2/docker_image.dart';
import 'package:path/path.dart' as path;

import './utils.dart';
import 'dart:io';

enum ClientBinaryType {
  sshnp,
  npt,
  srv,
  npp_client,
  at_activate,
}

class ClientBinary {
  final ClientBinaryType binaryType; // sshnp, npt, srv, npp_client, etc,.
  final Language language; // dart or c
  final String version; // "current", "v5.9.4", "v5.11.2", "v5.13.0"
  final File file;

  ClientBinary({
    required this.binaryType,
    required this.language,
    required this.version,
    required this.file,
  });

  Future<bool> exists() async {
    return file.exists();
  }

  Future<Process> execute({
    required List<String> args,
    String? logDirectory,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (!exists()) {
      throw Exception('Binary does not exist: $binaryPath');
    }

    print('Executing $binaryPath ${args.join(' ')}');
    final Process process = await Process.start(
      binaryPath,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
    );

    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/execute_${language.name}_${binaryType.name}_${version}_$timestamp';

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      process.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      process.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      print('Execute logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    return process;
  }
}
