import 'dart:async';
import 'dart:io';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_version.dart';

Future<void> run(
  NPARequestHandler handler,
  List<String> commandLineArgs,
) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final NPA sshnpa;

  try {
    sshnpa = await NPA.fromCommandLineArgs(
      commandLineArgs,
      handler: handler,
      atClientGenerator: (NPAParams p) => createAtClientCli(
        atsign: p.policyAtsign,
        atKeysFilePath: p.atKeysFilePath,
        passPhrase: p.passPhrase,
        rootDomain: p.rootDomain,
        atServiceFactory: ServiceFactoryWithNoOpSyncService(),
        namespace: DefaultArgs.namespace,
        storagePath: p.storagePath,
      ),
      usageCallback: (e, s) {
        printVersion();
        stdout.writeln(NPAOption.usage);
        stderr.writeln('\n$e');
      },
      helpCallback: () {
        printVersion();
        stdout.writeln(NPAOption.usage);
        exit(0);
      },
      versionCallback: () {
        printVersion();
        exit(0);
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
