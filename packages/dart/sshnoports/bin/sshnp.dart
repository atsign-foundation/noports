// dart packages
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  void printUsage({Object? error}) {
    printVersion();
    stderr.writeln(parser.usage);
    if (error != null) {
      stderr.writeln('\n$error');
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
    SshnpParams? params;
    try {
      final argResults = parser.parse(args);
      final coreArgs = parser.extractCoreArgs(args);

      params = SshnpParams.fromPartial(
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
        if (e is SshnpError && e.stackTrace != null) {
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
          SshnpRemoteProcess shell = await sshnp.runShell();
          shell.stdout.listen(stdout.add);
          shell.stderr.listen(stderr.add);

          // don't wait for a newline before sending to remote stdin
          stdin.lineMode = false;
          // echo only what is sent back from the other side
          stdin.echoMode = false;

          stdin.listen(shell.stdin.add);

          // catch local ctrl-c's and forward to remote
          ProcessSignal.sigint.watch().listen((signal) {
            shell.stdin.add(Uint8List.fromList([3]));
          });

          await shell.done;
          exit(0);
        } else if (argResults['output-execution-command'] ?? false) {
          stdout.write('$res\n');
          exit(0);
        } else {
          Process process = await Process.start(
            res.command,
            res.args,
            mode: ProcessStartMode.inheritStdio,
          );

          exit(await process.exitCode);
        }
      }
    } on ArgumentError catch (error) {
      printUsage(error: error);
      exit(1);
    } on FormatException catch (error) {
      printUsage(error: error);
      exit(1);
    } on SshnpError catch (error, stackTrace) {
      stderr.writeln(error.toString());
      if (params?.verbose ?? true) {
        stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
      }
      exit(1);
    } catch (error, stackTrace) {
      stderr.writeln(error.toString());
      stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
      exit(1);
    }
  }, (Object error, StackTrace stackTrace) async {
    // if (error is ArgumentError) return;
    // if (error is SshnpError) return;
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
    exit(1);
  });
}
