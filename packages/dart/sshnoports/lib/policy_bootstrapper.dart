import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_logger.dart';
import 'package:at_policy/at_policy.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_version.dart';
import 'package:sshnoports/src/service_factories.dart';

Future<void> run(
  PolicyRequestHandler handler,
  List<String> commandLineArgs, {
  Set<String>? daemonAtsigns,
}) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final PolicyService sshnpa;

  try {
    sshnpa = await PolicyService.fromCommandLineArgs(
      commandLineArgs,
      handler: handler,
      daemonAtsigns: daemonAtsigns,
      atClientGenerator: (PolicyServiceParams p) => createAtClientCli(
        atsign: p.authorizerAtsign,
        atKeysFilePath: p.atKeysFilePath,
        rootDomain: p.rootDomain,
        atServiceFactory: ServiceFactoryWithNoOpSyncService(),
        namespace: DefaultArgs.namespace,
        storagePath: standardAtClientStoragePath(
            homeDirectory: p.homeDirectory,
            atSign: p.authorizerAtsign,
            progName: '.${DefaultArgs.namespace}',
            uniqueID: 'single'),
      ),
      usageCallback: (e, s) {
        printVersion();
        stdout.writeln(PolicyServiceParams.parser.usage);
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
