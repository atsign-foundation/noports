import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/sshrvd.dart';
import 'package:sshnoports/create_at_client_cli.dart';
import 'package:sshnoports/print_version.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final SSHRVD sshrvd;

  try {
    sshrvd = await SSHRVD.fromCommandLineArgs(
      args,
      atClientGenerator: (SSHRVDParams p) => createAtClientCli(
        homeDirectory: p.homeDirectory,
        subDirectory: '.sshrvd',
        atsign: p.atSign,
        atKeysFilePath: p.atKeysFilePath,
        namespace: SSHRVD.namespace,
        rootDomain: p.rootDomain,
      ),
      usageCallback: (e, s) {
        printVersion();
        stdout.writeln(SSHRVDParams.parser.usage);
        stderr.writeln('\n$e');
      },
    );
  } on ArgumentError catch (_) {
    exit(1);
  }

  await runZonedGuarded(() async {
    await sshrvd.init();
    await sshrvd.run();
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}
