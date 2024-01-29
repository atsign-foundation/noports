// dart core packages
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// other packages
import 'package:path/path.dart' as path;
import 'package:dartssh2/dartssh2.dart';

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

  ExtendedArgParser parser = ExtendedArgParser(
    usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : null,
  );

  // Create the printUsage closure
  void printUsage({Object? error}) {
    printVersion();
    stderr.writeln(parser.usage);
    if (error != null) {
      stderr.writeln('\n$error');
    }
  }

  final bool originalLineMode = stdin.lineMode;
  final bool originalEchoMode = stdin.echoMode;
  bool shouldResetTerminal = false;

  void configureRemoteShell() {
    shouldResetTerminal = true;
    // echo only what is sent back from the other side
    stdin.echoMode = false;
    // don't wait for a newline before sending to remote stdin
    stdin.lineMode = false;
  }

  void resetShell() {
    stdin.lineMode = originalLineMode;
    stdin.echoMode = originalEchoMode;
  }

  Directory? storageDir;

  void deleteStorage() {
    // Windows will not let us delete files that are open
    // so will will ignore this step and leave them in %localappdata%\Temp
    if (!Platform.isWindows) {
      if (storageDir != null) {
        if (storageDir!.existsSync()) {
          // stderr.writeln('${DateTime.now()} : Cleaning up temporary files');
          storageDir!.deleteSync(recursive: true);
        }
      }
    }
  }

  void exitProgram({int exitCode = 0}) {
    if (shouldResetTerminal) resetShell();
    deleteStorage();
    exit(exitCode);
  }

  // Manually check if the help flag is set and print usage
  Set<String> helpSet = SshnpArg.fromName('help').aliasList.toSet();
  if (args.toSet().intersection(helpSet).isNotEmpty) {
    printUsage();
    exitProgram();
  }

  await runZonedGuarded(() async {
    final String homeDirectory = getHomeDirectory()!;
    SshnpParams? params;
    try {
      // Parse Args
      final argResults = parser.parse(args);
      final coreArgs = parser.extractCoreArgs(args);

      params = SshnpParams.fromPartial(
        SshnpPartialParams.fromArgList(
          coreArgs,
          parserType: ParserType.commandLine,
        ),
      );

      // Windows will not let us delete files in use so
      // We will point storage to temp directory and let OS clean up
      if (Platform.isWindows) {
        storageDir = Directory(path.normalize('${Platform.environment['TEMP']}'
            '/${DefaultArgs.storagePathSubDirectory}'
            '/${params.clientAtSign}'
            '/storage'
            '/${DateTime.now().millisecondsSinceEpoch}'));
      } else {
        storageDir = Directory(path.normalize('$homeDirectory'
            '/${DefaultArgs.storagePathSubDirectory}'
            '/${params.clientAtSign}'
            '/storage'
            '/${DateTime.now().millisecondsSinceEpoch}'));
      }
      storageDir!.createSync(recursive: true);
      final sigintListener = ProcessSignal.sigint.watch().listen((signal) {
        exitProgram(exitCode: 1);
      });
      if (!Platform.isWindows) {
        ProcessSignal.sigterm.watch().listen((signal) {
          exitProgram(exitCode: 1);
        });
      }

      // Create Sshnp Instance
      final sshnp = await createSshnp(
        params,
        atClientGenerator: (SshnpParams params) => createAtClientCli(
          homeDirectory: homeDirectory,
          atsign: params.clientAtSign,
          atKeysFilePath: params.atKeysFilePath ??
              getDefaultAtKeysFilePath(homeDirectory, params.clientAtSign),
          rootDomain: params.rootDomain,
          storagePath: storageDir!.path,
        ),
        sshClient:
            SupportedSshClient.fromString(argResults['ssh-client'] as String),
      ).catchError((e) {
        if (e is SshnpError && e.stackTrace != null) {
          Error.throwWithStackTrace(e, e.stackTrace!);
        }
        throw e;
      });

      // A listen progress listener for the CLI
      // Will only log if verbose is false, since if verbose is true
      // there will already be a boatload of log messages
      void logProgress(String s) {
        if (!(params?.verbose ?? true)) {
          stderr.writeln('${DateTime.now()} : $s');
        }
      }

      sshnp.progressStream?.listen((s) => logProgress(s));

      // Run List Devices Operation
      if (params.listDevices) {
        stderr.writeln('Searching for devices...');
        var deviceList = await sshnp.listDevices();
        printDevices(deviceList);
        exitProgram();
      }

      // Run Sshnp
      final res = await sshnp.run();

      if (res is SshnpError) {
        if (res.stackTrace != null) {
          Error.throwWithStackTrace(res, res.stackTrace!);
        }
        throw res;
      }
      if (res is SshnpNoOpSuccess) {
        stdout.write('$res\n');
        exitProgram();
      }
      if (res is SshnpCommand) {
        if (sshnp.canRunShell) {
          SshnpRemoteProcess shell = await sshnp.runShell();
          configureRemoteShell();
          shell.stdout.listen(stdout.add);
          shell.stderr.listen(stderr.add);
          stdin.listen(shell.stdin.add);

          // Cancel the previous ctrl-c listener which would call exitProgram
          await sigintListener.cancel();

          // catch local ctrl-c's and forward to remote
          ProcessSignal.sigint.watch().listen((signal) {
            shell.stdin.add(Uint8List.fromList([3]));
          });

          await shell.done;
          exitProgram();
        } else if (argResults[outputExecutionCommandFlag] as bool) {
          stdout.write('$res\n');
          exitProgram();
        } else {
          logProgress('Starting user session');
          Process process = await Process.start(
            res.command,
            res.args,
            mode: ProcessStartMode.inheritStdio,
          );

          exitProgram(exitCode: await process.exitCode);
        }
      }
    } on ArgumentError catch (error) {
      printUsage(error: error);
      exitProgram(exitCode: 1);
    } on FormatException catch (error) {
      printUsage(error: error);
      exitProgram(exitCode: 1);
    } on SshnpError catch (error, stackTrace) {
      stderr.writeln('\nError : $error');
      if (params?.verbose ?? true) {
        stderr.writeln('\nStack Trace: $stackTrace');
      }
      exitProgram(exitCode: 1);
    } catch (error, stackTrace) {
      stderr.writeln('\nError : $error');
      stderr.writeln('\nStack Trace: $stackTrace');
      exitProgram(exitCode: 1);
    }
  }, (Object error, StackTrace stackTrace) async {
    if (error is SSHError || error is SshnpError) {
      stderr.writeln('\nError: $error');
    } else {
      stderr.writeln('\nError: $error');
      stderr.writeln('\nStack Trace: $stackTrace');
    }
    exitProgram(exitCode: 1);
  });
}
