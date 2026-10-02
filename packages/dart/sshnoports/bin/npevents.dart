// dart core packages
import 'dart:async';
import 'dart:io';

// other packages
import 'package:args/args.dart';

// atPlatform packages
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/events.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/utils.dart';

// local packages
import 'package:sshnoports/src/print_version.dart';

const String _description =
    'NoPorts session events listener: listens for NoPorts session events'
    ' and writes them to stdout as JSON.';

/// Minimal implementation of a NoPorts session events listener.
///
/// Listens for NoPorts session events, writes to stdout
void main(List<String> args) async {
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  ArgParser parser = CLIBase.createArgsParser(
      namespace: DefaultArgs.namespace, addLegacyRootDomainArg: false);
  parser.addFlag('version', negatable: false, help: 'Print version');
  parser.addFlag('debug', help: 'maximum debug verbosity ');
  parser.addOption('logging-atsigns',
      abbr: 'A',
      help: 'Comma-separated list of atSigns with whom to share logging config',
      mandatory: true);

  void printUsage({Object? error}) {
    stderr.write(
        formatCliHelp(description: _description, optionsUsage: parser.usage));
    if (error != null) {
      stderr.writeln('\n$error');
    }
  }

  void exitProgram({int exitCode = 0}) {
    // deleteStorage();
    exit(exitCode);
  }

  // After parsing, this gets set to whatever the command-line specifies
  bool verboseLogging = false;
  bool debugLogging = false;

  await runZonedGuarded(() async {
    try {
      // Parse Args
      ArgResults parsedArgs = parser.parse(args);

      if (parsedArgs['help'] == true) {
        stdout.write(formatCliHelp(
            description: _description, optionsUsage: parser.usage));
        exit(0);
      }

      if (parsedArgs['version'] == true) {
        printVersion();
        exit(0);
      }

      verboseLogging = parsedArgs['verbose'];
      debugLogging = parsedArgs['debug'];

      if (debugLogging) {
        AtSignLogger.root_level = 'FINEST';
      } else if (verboseLogging) {
        AtSignLogger.root_level = 'INFO';
      } else {
        AtSignLogger.root_level = 'SHOUT';
      }

      ProcessSignal.sigint.watch().listen((signal) {
        exitProgram(exitCode: 1);
      });
      if (!Platform.isWindows) {
        ProcessSignal.sigterm.watch().listen((signal) {
          exitProgram(exitCode: 1);
        });
      }

      List<Atsign> loggingAtsigns = parsedArgs['logging-atsigns']!
          .toString()
          .split(',')
          .map((s) => s.toAtsign())
          .toList();
      CLIBase cliBase = await CLIBase.fromCommandLineArgs(args, parser: parser);

      AtEventListenerService svc =
          AtEventListenerService(atClient: cliBase.atClient);
      final elc = await svc.getOrCreateConfig(
          namespace: DefaultArgs.eventLoggingNamespace, ttln: 60 * 60 * 1000);
      await svc.shareEventLoggingConfigWithAtsigns(
          config: elc,
          atSigns: loggingAtsigns,
          namespace: DefaultArgs.eventLoggingNamespace);
      svc.logger.shout('Shared AtEventLogger config $elc with $loggingAtsigns');

      while (true) {
        await for (final String json in svc.getJsonStream(elc)) {
          stdout.writeln(json);
        }
        await Future.delayed(Duration(milliseconds: 100));
      }
    } on ArgumentError catch (error) {
      printUsage(error: error);
      exitProgram(exitCode: 1);
    } on FormatException catch (error) {
      printUsage(error: error);
      exitProgram(exitCode: 1);
    } on SshnpException catch (error, stackTrace) {
      stderr.writeln('\nError : $error');
      if (verboseLogging) {
        stderr.writeln('\nStack Trace: $stackTrace');
      }
      exitProgram(exitCode: 1);
    } catch (error, stackTrace) {
      stderr.writeln('\nError : $error');
      stderr.writeln('\nStack Trace: $stackTrace');
      exitProgram(exitCode: 1);
    }
  }, (Object error, StackTrace stackTrace) async {
    if (error is SshnpError) {
      stderr.writeln('\nError: $error');
    } else {
      stderr.writeln('\nError: $error');
      stderr.writeln('\nStack Trace: $stackTrace');
    }
    exitProgram(exitCode: 1);
  });
}
