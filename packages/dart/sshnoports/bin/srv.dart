import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/srv.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:sshnoports/src/print_version.dart';

class TmpFileLoggingHandler implements LoggingHandler {
  File f = File('/tmp/noports/srv.$pid.log');

  TmpFileLoggingHandler() {
    f.createSync(recursive: true);
  }

  @override
  void call(LogRecord record) {
    f.writeAsStringSync('${record.level.name}'
        '|${record.time}'
        '|${record.loggerName}'
        '|${record.message} \n',
    mode: FileMode.writeOnlyAppend);
  }
}

Future<void> main(List<String> args) async {
  // For production usage, do not change this to anything below SHOUT or this
  // programme will crash when emitting log messages, as this process's parent
  // will have exited and closed its stderr.
  // However you can set this log level to whatever you wish if you also change
  // the default logging handler (see below)
  AtSignLogger.root_level = 'FINEST';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  // Uncomment this next line if you need to debug and see all output.
  AtSignLogger.defaultLoggingHandler = TmpFileLoggingHandler();

  AtSignLogger logger = AtSignLogger(' srv.main ');
  final ArgParser parser = ArgParser(showAliasesInUsage: true)
    ..addOption('host', abbr: 'h', mandatory: true, help: 'rvd host')
    ..addOption('port', abbr: 'p', mandatory: true, help: 'rvd port')
    ..addOption('local-port',
        defaultsTo: '22',
        help: 'Local port (usually the sshd port) to bridge to; defaults to 22')
    ..addFlag('bind-local-port',
        defaultsTo: false,
        negatable: false,
        help: 'Set this flag when we are bridging from a local sender')
    ..addOption('local-host',
        mandatory: false,
        help: 'Host on the local network to bridge to; defaults to localhost')
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

    try {
      SocketConnector sc = await Srv.dart(
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

      /// Shut myself down once the socket connector closes
      stderr.writeln('Waiting for Srv to close');
      await sc.done;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      // Do not remove this output; it is specifically looked for in
      // [SrvImplExec.run].
      stderr.writeln('${Srv.completedWithExceptionString} : $e');
      exit(1);
    }

    stderr.writeln('Closed - exiting');
    exit(0);
  } on ArgumentError catch (e) {
    printVersion();
    stderr.writeln(parser.usage);
    stderr.writeln('\n$e');
    exit(1);
  }
  }, (Object error, StackTrace stackTrace) async {
    logger.severe('Unhandled exception $error; stackTrace follows\n$stackTrace');
  });
}
