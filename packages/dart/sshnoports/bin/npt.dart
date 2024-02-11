// dart core packages
import 'dart:async';
import 'dart:io';

// other packages
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

// atPlatform packages
import 'package:at_utils/at_logger.dart';
import 'package:at_cli_commons/at_cli_commons.dart' as cli;
import 'package:noports_core/npt.dart';
import 'package:noports_core/sshnp_foundation.dart';

// local packages
import 'package:sshnoports/src/print_version.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  Directory? storageDir;

  bool perSessionStorage = false;

  void deleteStorage() {
    if (!perSessionStorage) {
      return;
    }

    // Windows will not let us delete files that are open
    // so will will ignore this step and leave them in %localappdata%\Temp
    if (!Platform.isWindows) {
      if (storageDir?.existsSync() ?? false) {
        stderr.writeln('${DateTime.now()} : Cleaning up temporary files');
        storageDir?.deleteSync(recursive: true);
      }
    }
  }

  void exitProgram({int exitCode = 0}) {
    deleteStorage();
    exit(exitCode);
  }

  ArgParser parser = Npt.createArgParser();

  // Create the printUsage closure
  void printUsage({Object? error}) {
    printVersion();
    stderr.writeln(parser.usage);
    if (error != null) {
      stderr.writeln('\n$error');
    }
  }

  final String homeDirectory = getHomeDirectory()!;

  // After parsing, this gets set to whatever the command-line specifies
  bool verbose = true;

  await runZonedGuarded(() async {
    try {
      parser.addOption(
        'from',
        abbr: 'f',
        mandatory: true,
        help: 'This client\'s atSign',
      );
      parser.addOption(
        'to',
        abbr: 't',
        mandatory: true,
        help: 'The device daemon\'s atSign',
      );
      parser.addOption(
        'srvd',
        abbr: 'r',
        mandatory: true,
        help: 'The socket rendezvous\'s atSign',
      );
      parser.addOption(
        'device',
        abbr: 'd',
        mandatory: true,
        help: 'The device name'
            ' The same atSign may be used to run daemons on many devices,'
            ' therefore each one must run with its own unique device name',
      );
      parser.addOption(
        'local-port',
        aliases: ['lp'],
        abbr: 'l',
        help: 'client-side local port for the socket tunnel.'
            ' If not supplied, we will ask the o/s for a spare port',
        defaultsTo: '0',
      );
      parser.addOption(
        'remote-port',
        abbr: 'p',
        aliases: ['rp'],
        mandatory: true,
        help: 'The remote port required',
      );
      parser.addOption(
        'remote-host',
        abbr: 'h',
        aliases: ['rh'],
        defaultsTo: 'localhost',
        help: 'The remote host required',
      );
      parser.addOption(
        'key-file',
        abbr: 'k',
        mandatory: false,
        aliases: const ['keyFile'],
        help:
            'Path to this client\'s atSign\'s keyFile, if not in ~/.atsign/keys/',
      );
      parser.addOption(
        'root-domain',
        mandatory: false,
        defaultsTo: 'root.atsign.org',
        help: 'atDirectory domain',
      );
      parser.addFlag(
        'per-session-storage',
        aliases: ['pss'],
        defaultsTo: true,
        negatable: true,
        help: 'Use ephemeral local storage for each session.'
            ' Defaults to true, enabling you to run multiple local clients'
            ' concurrently. However: if you wish to run just one client at a'
            ' time, then you will get a performance boost if you negate this'
            ' flag.',
      );
      parser.addFlag(
        'verbose',
        abbr: 'v',
        defaultsTo: false,
        negatable: false,
        help: 'More logging',
      );
      parser.addFlag('help',
          defaultsTo: false, negatable: false, help: 'Print usage');

      // Parse Args
      ArgResults parsedArgs = parser.parse(args);

      if (parsedArgs['help'] == true) {
        print(parser.usage);
        exit(0);
      }

      verbose = parsedArgs['verbose'];
      String daemonAtSign = parsedArgs['to'];
      String srvdAtSign = parsedArgs['srvd'];
      int remotePort = int.parse(parsedArgs['remote-port']);
      String remoteHost = parsedArgs['remote-host'];
      String device = parsedArgs['device'];
      String rootDomain = parsedArgs['root-domain'];
      perSessionStorage = parsedArgs['per-session-storage'];
      int localPort = int.parse(parsedArgs['local-port']);

      // Windows will not let us delete files in use so
      // We will point storage to temp directory and let OS clean up
      var clientAtSign = parsedArgs['from'];

      late String storageDirLastPart;
      if (perSessionStorage) {
        storageDirLastPart = DateTime.now().millisecondsSinceEpoch.toString();
      } else {
        storageDirLastPart = 'single';
      }
      if (Platform.isWindows) {
        storageDir = Directory(path.normalize('${Platform.environment['TEMP']}'
            '/${DefaultArgs.storagePathSubDirectory}'
            '/$clientAtSign'
            '/storage'
            '/$storageDirLastPart'));
      } else {
        storageDir = Directory(path.normalize('$homeDirectory'
            '/${DefaultArgs.storagePathSubDirectory}'
            '/$clientAtSign'
            '/storage'
            '/$storageDirLastPart'));
      }
      storageDir?.createSync(recursive: true);

      ProcessSignal.sigint.watch().listen((signal) {
        exitProgram(exitCode: 1);
      });
      if (!Platform.isWindows) {
        ProcessSignal.sigterm.watch().listen((signal) {
          exitProgram(exitCode: 1);
        });
      }

      cli.CLIBase cliBase = cli.CLIBase(
          atSign: clientAtSign,
          atKeysFilePath: parsedArgs['key-file'],
          nameSpace: DefaultArgs.namespace,
          rootDomain: rootDomain,
          homeDir: getHomeDirectory(),
          storageDir: storageDir?.path,
          verbose: parsedArgs['verbose'],
          syncDisabled: true);

      await cliBase.init();

      final npt = Npt.create(
        params: NptParams(
          clientAtSign: clientAtSign,
          sshnpdAtSign: daemonAtSign,
          srvdAtSign: srvdAtSign,
          remoteHost: remoteHost,
          remotePort: remotePort,
          device: device,
          localPort: localPort,
          verbose: verbose,
          rootDomain: parsedArgs['root-domain'],
        ),
        atClient: cliBase.atClient,
      );

      // A listen progress listener for the CLI
      // Will only log if verbose is false, since if verbose is true
      // there will already be a boatload of log messages
      void logProgress(String s) {
        if (!verbose) {
          stderr.writeln('${DateTime.now()} : $s');
        }
      }

      npt.progressStream?.listen((s) => logProgress(s));

      final actualLocalPort = await npt.run();

      stderr.writeln(
          'requested localPort $localPort actual localPort $actualLocalPort');
      stdout.writeln('$actualLocalPort');

      exit(0);
    } on ArgumentError catch (error) {
      printUsage(error: error);
      exitProgram(exitCode: 1);
    } on FormatException catch (error) {
      printUsage(error: error);
      exitProgram(exitCode: 1);
    } on SshnpException catch (error, stackTrace) {
      stderr.writeln('\nError : $error');
      if (verbose) {
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
