// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:noports_core/sshnp_foundation.dart';
import 'package:sshnoports/src/extended_arg_parser.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_devices.dart';
import 'package:sshnoports/src/print_version.dart';
import 'package:sshnoports/src/create_sshnp.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  ExtendedArgParser parser = ExtendedArgParser();

  // Create the printUsage closure
  void printUsage({Object? error, StackTrace? stackTrace}) {
    printVersion();
    stderr.writeln(parser.usage);
    if (error != null) {
      stderr.writeln('\n$error');
    }
    if (stackTrace != null) {
      stderr.writeln('\n$stackTrace');
    }
  }

  // Manually check if the help flag is set and print usage
  Set<String> helpSet = SshnpArg.fromName('help').aliasList.toSet();
  if (args.toSet().intersection(helpSet).isNotEmpty) {
    printUsage();
    exit(0);
  }

  await runZonedGuarded(() async {
    final String homeDirectory = getHomeDirectory()!;

    try {
      final argResults = parser.parse(args);
      final coreArgs = parser.extractCoreArgs(args);

      final params = SshnpParams.fromPartial(
        SshnpPartialParams.fromArgList(
          coreArgs,
          parserType: ParserType.commandLine,
        ),
      );

      final sshnp = await createSshnp(
        params,
        atClientGenerator: (SshnpParams params) => createAtClientCli(
          homeDirectory: homeDirectory,
          atsign: params.clientAtSign,
          atKeysFilePath: params.atKeysFilePath ??
              getDefaultAtKeysFilePath(homeDirectory, params.clientAtSign),
          rootDomain: params.rootDomain,
        ),
        legacyDaemon: argResults['legacy-daemon'] as bool,
        sshClient:
            SupportedSshClient.fromString(argResults['ssh-client'] as String),
      ).catchError((e) {
        if (e.stackTrace != null) {
          Error.throwWithStackTrace(e, e.stackTrace!);
        }
        throw e;
      });

      if (params.listDevices) {
        stderr.writeln('Searching for devices...');
        var deviceList = await sshnp.listDevices();
        printDevices(deviceList);
        exit(0);
      }

      final res = await sshnp.run();

      if (res is SshnpError) {
        if (res.stackTrace != null) {
          Error.throwWithStackTrace(res, res.stackTrace!);
        }
        throw res;
      }
      if (res is SshnpNoOpSuccess) {
        stdout.write('$res\n');
        exit(0);
      }
      if (res is SshnpCommand) {
        if (sshnp.canRunShell) {
          // ignore: unused_local_variable
          SshnpRemoteProcess shell = await sshnp.runShell();
          shell.stdout.listen(stdout.add);
          shell.stderr.listen(stderr.add);
          stdin.listen(shell.stdin.add);
          exit(0);
        } else {
          stdout.write('$res\n');
          exit(0);
        }
      }
    } on ArgumentError catch (error, stackTrace) {
      printUsage(error: error, stackTrace: stackTrace);
      exit(1);
    } on SshnpError catch (error, stackTrace) {
      stderr.writeln(error.toString());
      stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
      exit(1);
    }
  }, (Object error, StackTrace stackTrace) async {
    if (error is ArgumentError) return;
    if (error is SshnpError) return;
    stderr.writeln('Unknown error: ${error.toString()}');
    stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
    exit(1);
  });
}
