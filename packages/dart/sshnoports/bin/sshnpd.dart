import 'dart:async';
import 'dart:io';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/sshnpd.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_version.dart';
import 'package:sshnoports/src/version.dart';

const String _description =
    'NoPorts SSH daemon: accepts SSH sessions from authorized NoPorts'
    ' clients without this device having any open ports.';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SEVERE';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final Sshnpd sshnpd;

  try {
    sshnpd = await Sshnpd.fromCommandLineArgs(
      args,
      atClientGenerator: (SshnpdParams p) => createAtClientCli(
        atsign: p.deviceAtsign,
        atKeysFilePath: p.atKeysFilePath,
        passPhrase: p.passPhrase,
        rootDomain: p.rootDomain,
        storagePath: p.storagePath,
        namespace: DefaultArgs.namespace,
        atServiceFactory: ServiceFactoryWithNoOpSyncService(),
      ),
      usageCallback: (e, s) {
        stderr.write(formatCliHelp(
            description: _description, optionsUsage: SshnpdOption.usage));
        stderr.writeln('\n$e');
      },
      helpCallback: () {
        stdout.write(formatCliHelp(
            description: _description, optionsUsage: SshnpdOption.usage));
        exit(0);
      },
      versionCallback: () {
        printVersion();
        exit(0);
      },
      doctorCallback: () async {
        await SshnpdDoctor().run(args, packageVersion: packageVersion);
        exit(0);
      },
      version: packageVersion,
    );
  } on ArgumentError catch (_) {
    exit(1);
  } catch (e, s) {
    print("Unknown Error, please contact support: $e\n$s");
    exit(1);
  }

  await runZonedGuarded(
    () async {
      await sshnpd.init();
      await sshnpd.run();
    },
    (Object error, StackTrace stackTrace) async {
      stderr.writeln('Error: ${error.toString()}');
      stderr.writeln('Stack Trace: ${stackTrace.toString()}');
      await stderr.flush().timeout(Duration(milliseconds: 100));
      exit(1);
    },
  );
}
