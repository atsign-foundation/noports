import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/srvd.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_version.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final Srvd srvd;

  try {
    srvd = await Srvd.fromCommandLineArgs(
      args,
      atClientGenerator: (SrvdParams p) => createAtClientCli(
        homeDirectory: p.homeDirectory,
        subDirectory: '.srvd',
        atsign: p.atSign,
        atKeysFilePath: p.atKeysFilePath,
        namespace: Srvd.namespace,
        rootDomain: p.rootDomain,
      ),
      usageCallback: (e, s) {
        printVersion();
        stdout.writeln(SrvdParams.parser.usage);
        stderr.writeln('\n$e');
      },
    );
  } on ArgumentError catch (_) {
    exit(1);
  }

  await runZonedGuarded(() async {
    await srvd.init();
    await srvd.run();
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}
