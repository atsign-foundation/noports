import 'dart:io';

import 'package:args/args.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/srv.dart';
import 'package:sshnoports/src/print_version.dart';

Future<void> main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

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
        help: 'Set this flag when we want multiple connections via the rvd')
  ;

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
      Future done = await Srv.dart(
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
      await done;
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
}
