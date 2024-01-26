import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/sshnpa.dart';
import 'package:sshnoports/create_at_client_cli.dart';
import 'package:sshnoports/print_version.dart';

Future<void> run(
    SSHNPARequestHandler handler, List<String> commandLineArgs) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final SSHNPA sshnpa;

  try {
    sshnpa = await SSHNPA.fromCommandLineArgs(
      commandLineArgs,
      handler: handler,
      atClientGenerator: (SSHNPAParams p) => createAtClientCli(
        homeDirectory: p.homeDirectory,
        atsign: p.authorizerAtsign,
        atKeysFilePath: p.atKeysFilePath,
        rootDomain: p.rootDomain,
      ),
      usageCallback: (e, s) {
        printVersion();
        stdout.writeln(SSHNPAParams.parser.usage);
        stderr.writeln('\n$e');
      },
    );
  } on ArgumentError catch (_) {
    exit(1);
  }

  await runZonedGuarded(() async {
    await sshnpa.run();
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}
