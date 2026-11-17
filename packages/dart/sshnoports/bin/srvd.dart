import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:at_client_cli/at_client_cli.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_version.dart';
import 'package:sshnoports/src/signal_stopper.dart';

const String _description =
    'NoPorts relay daemon: the rendezvous service via which NoPorts clients'
    ' and daemons exchange end-to-end encrypted traffic.';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = StdErrLoggingHandler();
  Srvd? srvd;

  Directory storageDir;

  ArgResults r;
  try {
    r = SrvdParams.parser.parse(args);
  } on FormatException catch (e) {
    stderr.write(formatCliHelp(
        description: _description, optionsUsage: SrvdParams.parser.usage));
    stderr.writeln('\n${e.message}');
    exit(1);
  }

  if (r.wasParsed('version')) {
    printVersion();
    exit(0);
  }

  if (r.wasParsed('help')) {
    stdout.write(formatCliHelp(
        description: _description, optionsUsage: SrvdParams.parser.usage));
    exit(0);
  }

  SrvdParams p;

  try {
    p = await SrvdParams.fromArgs(args);
  } on ArgumentError catch (e) {
    stderr.write(formatCliHelp(
        description: _description, optionsUsage: SrvdParams.parser.usage));
    stderr.writeln('\n$e');
    exit(1);
  }

  // Windows will not let us delete files in use so
  // We will point storage to temp directory and let OS clean up
  String uniqueID;
  if (p.perSessionStorage) {
    uniqueID = DateTime.now().millisecondsSinceEpoch.toString();
  } else {
    uniqueID = 'single';
  }
  if (Platform.isWindows) {
    storageDir = Directory(standardAtClientStoragePath(
      baseDir: Platform.environment['TEMP']!,
      atSign: p.atSign,
      progName: 'srvd',
      uniqueID: uniqueID,
    ));
  } else {
    storageDir = Directory(standardAtClientStoragePath(
      baseDir: p.homeDirectory,
      atSign: p.atSign,
      progName: 'srvd',
      uniqueID: uniqueID,
    ));
  }
  stderr.writeln('Using local storage directory $storageDir');
  storageDir.createSync(recursive: true);

  void deleteStorage() {
    if (!p.perSessionStorage) {
      return;
    }

    // Windows will not let us delete files that are open
    // so will will ignore this step and leave them in %localappdata%\Temp
    if (!Platform.isWindows) {
      if (storageDir.existsSync()) {
        stderr.writeln('${DateTime.now()}'
            ' : Cleaning up temporary files in $storageDir');
        storageDir.deleteSync(recursive: true);
      }
    }
  }

  void exitProgram({int exitCode = 0}) {
    deleteStorage();
    exit(exitCode);
  }

  final SignalStopper stopper = SignalStopper(
    exit: (int code) => exitProgram(exitCode: code),
    log: (String message) => stderr.writeln('${DateTime.now()} : $message'),
  );
  ProcessSignal.sigint.watch().listen(stopper.handle);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(stopper.handle);
  }

  try {
    srvd = await Srvd.fromCommandLineArgs(
      args,
      atClientGenerator: (SrvdParams p) => createAtClientCli(
        storagePath: storageDir.path,
        atsign: p.atSign,
        atKeysFilePath: p.atKeysFilePath,
        passPhrase: p.passPhrase,
        namespace: Srvd.namespace,
        rootDomain: p.rootDomain,
        atServiceFactory: ServiceFactoryWithNoOpSyncService(),
      ),
      usageCallback: (e, s) {
        stderr.write(formatCliHelp(
            description: _description, optionsUsage: SrvdParams.parser.usage));
        stderr.writeln('\n$e');
      },
      version: versionString,
    );
  } on ArgumentError catch (_) {
    exit(1);
  } on AtException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } catch (e, s) {
    stderr.writeln('Error: $e\n$s');
    exit(1);
  }

  final relay = srvd;
  stopper.stop = relay.stop;
  await runZonedGuarded(() async {
    await relay.init();
    await relay.run();
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}
