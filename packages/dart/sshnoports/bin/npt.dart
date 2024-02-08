// dart core packages
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

  late Directory storageDir;

  void deleteStorage() {
    // Windows will not let us delete files that are open
    // so will will ignore this step and leave them in %localappdata%\Temp
    if (!Platform.isWindows) {
      if (storageDir.existsSync()) {
        // stderr.writeln('${DateTime.now()} : Cleaning up temporary files');
        storageDir.deleteSync(recursive: true);
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

  bool verbose = true;

  try {
    parser.addOption(
      'from',
      abbr: 'f',
      mandatory: true,
      help: 'This client\'s atSign',
    );
    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'This client\'s atSign\'s keyFile if not in ~/.atsign/keys/',
    );
    parser.addOption(
      'to',
      abbr: 't',
      mandatory: true,
      help: 'The device daemon\'s atSign',
    );
    parser.addOption(
      'device',
      abbr: 'd',
      mandatory: true,
      help: 'The device name'
          ' The same atSign may be used to run daemons on many devices,'
          ' therefore each one must run with its own unique device name',
    );
    parser.addFlag(
      'help',
      abbr: 'h',
      help: 'Print usage'
    );
    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );
    parser.addOption(
      'atd',
      aliases: ['root-domain'],
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory domain',
    );

    // Parse Args
    ArgResults parsedArgs = parser.parse(args);

    if (parsedArgs['help'] == true) {
      print(parser.usage);
      exit(0);
    }

    // Windows will not let us delete files in use so
    // We will point storage to temp directory and let OS clean up
    if (Platform.isWindows) {
      storageDir = Directory(path.normalize('${Platform.environment['TEMP']}'
          '/${DefaultArgs.storagePathSubDirectory}'
          '/${parsedArgs['from']}'
          '/storage'
          '/${DateTime.now().millisecondsSinceEpoch}'));
    } else {
      storageDir = Directory(path.normalize('$homeDirectory'
          '/${DefaultArgs.storagePathSubDirectory}'
          '/${parsedArgs['from']}'
          '/storage'
          '/${DateTime.now().millisecondsSinceEpoch}'));
    }
    storageDir.createSync(recursive: true);

    ProcessSignal.sigint.watch().listen((signal) {
      exitProgram(exitCode: 1);
    });
    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((signal) {
        exitProgram(exitCode: 1);
      });
    }

    cli.CLIBase cliBase = cli.CLIBase(
        atSign: parsedArgs['from'],
        atKeysFilePath: parsedArgs['key-file'],
        nameSpace: parsedArgs['namespace'],
        rootDomain: parsedArgs['root-domain'],
        homeDir: getHomeDirectory(),
        storageDir: storageDir.path,
        verbose: parsedArgs['verbose'],
        cramSecret: parsedArgs['cram-secret'],
        syncDisabled: parsedArgs['never-sync']);

    await cliBase.init();

    final npt = Npt.create(
      params: NptParams(
        clientAtSign: parsedArgs['from'],
        sshnpdAtSign: parsedArgs['npd'],
        srvdAtSign: parsedArgs['rvd'],
        remotePort: parsedArgs['remote-port'],
        device: parsedArgs['device'],
        verbose: parsedArgs['verbose'],
        rootDomain: parsedArgs['root-domain'],
      ),
      atClient: cliBase.atClient,
    );

    // A listen progress listener for the CLI
    // Will only log if verbose is false, since if verbose is true
    // there will already be a boatload of log messages
    void logProgress(String s) {
      if (parsedArgs['verbose'] != true) {
        stderr.writeln('${DateTime.now()} : $s');
      }
    }

    npt.progressStream?.listen((s) => logProgress(s));

    verbose = parsedArgs['verbose'];

    final localPort = await npt.run();

    stdout.writeln('Local port: $localPort');
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
}
