import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/srv.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:sshnoports/src/print_version.dart';

class TmpFileLoggingHandler implements LoggingHandler {
  late final File f;

  bool logToStderr = true;

  TmpFileLoggingHandler() {
    if (Platform.isWindows) {
      f = File(path.normalize('${Platform.environment['TEMP']}'
          '/srv.$pid.log'));
    } else {
      f = File('/tmp/srv.$pid.log');
    }
    f.createSync(recursive: true);
  }

  @override
  void call(LogRecord record) {
    f.writeAsStringSync(
        '${record.level.name}'
        '|${record.time}'
        '|${record.loggerName}'
        '|${record.message} \n',
        mode: FileMode.writeOnlyAppend);
    if (logToStderr) {
      try {
        AtSignLogger.stdErrLoggingHandler.call(record);
      } catch (e) {
        f.writeAsStringSync('********** Failed to log to stderr: $e',
            mode: FileMode.writeOnlyAppend);
      }
    }
  }
}

Future<void> main(List<String> args) async {
  AtSignLogger.root_level = 'INFO';
  var fileLoggingHandler = TmpFileLoggingHandler();
  AtSignLogger.defaultLoggingHandler = fileLoggingHandler;

  AtSignLogger logger = AtSignLogger(' srv.main ');

  final ArgParser parser = ArgParser(showAliasesInUsage: true)
    ..addOption('host', abbr: 'h', mandatory: true, help: 'rvd host')
    ..addOption('port', abbr: 'p', mandatory: true, help: 'rvd port')
    ..addOption('local-port',
        defaultsTo: '22',
        help: 'On the daemon side, this is the local port to connect to.'
            ' On the client side this is the local port which the srv will bind'
            ' to so that client-side programs can create sockets to it.')
    ..addFlag('bind-local-port',
        defaultsTo: false,
        negatable: false,
        help: 'Client side flag.')
    ..addOption('local-host',
        mandatory: false,
        defaultsTo: 'localhost',
        help: 'Used on daemon side for npt sessions only. The host on the'
            ' daemon\'s local network to connect to; defaults to localhost.')
    ..addFlag('rv-auth',
        defaultsTo: false,
        help: 'Whether this rv process will authenticate to rvd')
    ..addFlag('rv-e2ee',
        defaultsTo: false,
        help: 'Whether this rv process will encrypt/decrypt'
            ' all rvd socket traffic')
    ..addFlag('multi',
        defaultsTo: false,
        negatable: false,
        help: 'Set this flag when we want multiple connections via the rvd');

  await runZonedGuarded(() async {
    final SocketConnector sc;
    try {
      final ArgResults parsed;
      try {
        parsed = parser.parse(args);
      } on FormatException catch (e) {
        throw ArgumentError(e.message);
      }

      final String streamingHost = parsed['host'];
      final int streamingPort = int.parse(parsed['port']);
      final int localPort = int.parse(parsed['local-port']);
      final bool bindLocalPort = parsed['bind-local-port'];
      final String localHost = parsed['local-host'];
      final bool rvAuth = parsed['rv-auth'];
      final bool rvE2ee = parsed['rv-e2ee'];
      final bool multi = parsed['multi'];

      String? rvdAuthString = rvAuth ? Platform.environment['RV_AUTH'] : null;
      String? sessionAESKeyString =
          rvE2ee ? Platform.environment['RV_AES'] : null;
      String? sessionIVString = rvE2ee ? Platform.environment['RV_IV'] : null;

      if (rvAuth && (rvdAuthString ?? '').isEmpty) {
        throw ArgumentError(
            '--rv-auth required, but RV_AUTH is not in environment');
      }
      if (rvE2ee && (sessionAESKeyString ?? '').isEmpty) {
        throw ArgumentError(
            '--rv-e2ee required, but RV_AES is not in environment');
      }
      if (rvE2ee && (sessionIVString ?? '').isEmpty) {
        throw ArgumentError(
            '--rv-e2ee required, but RV_IV is not in environment');
      }

      sc = await Srv.dart(
        streamingHost,
        streamingPort,
        localPort: localPort,
        localHost: localHost,
        bindLocalPort: bindLocalPort,
        rvdAuthString: rvdAuthString,
        sessionAESKeyString: sessionAESKeyString,
        sessionIVString: sessionIVString,
        multi: multi,
        detached: true, // by definition - this is the srv binary
      ).run();
    } on ArgumentError catch (e) {
      printVersion();
      stderr.writeln(parser.usage);
      stderr.writeln('\n$e');

      // We will leave the log file in /tmp since we are exiting abnormally
      exit(1);
    }

    /// No more writing to stderr, as the parent process will have exited,
    /// and stderr no longer exists
    fileLoggingHandler.logToStderr = false;

    /// Wait for socket connector to close
    await sc.done;

    /// We will clean up the log file in /tmp since we are exiting normally
    try {
      fileLoggingHandler.f.deleteSync();
    } catch (_) {}

    exit(0);
  }, (error, StackTrace stackTrace) async {
    logger.shout('Unhandled exception $error; stackTrace follows\n$stackTrace');
    // Do not remove this output; it is specifically looked for in
    // [SrvImplExec.run].
    logger.shout('${Srv.completedWithExceptionString} : $error');

    // We will leave the log file in /tmp since we are exiting abnormally
    exit(200);
  });
}
