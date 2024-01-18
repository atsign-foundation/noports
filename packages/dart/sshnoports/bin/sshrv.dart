import 'dart:io';

import 'package:args/args.dart';
import 'package:noports_core/sshrv.dart';
import 'package:socket_connector/socket_connector.dart';

Future<void> main(List<String> args) async {
  final ArgParser parser = ArgParser()
    ..addOption('host', abbr: 'h', mandatory: true, help: 'rvd host')
    ..addOption('port', abbr: 'p', mandatory: true, help: 'rvd port')
    ..addOption('local-port',
        defaultsTo: '22',
        help: 'Local port (usually the sshd port) to bridge to; defaults to 22')
    ..addFlag('bind-local-port',
        defaultsTo: false,
        negatable: false,
        help: 'Set this flag when we are bridging from a local sender')
    ..addFlag('rv-auth',
        defaultsTo: false,
        help: 'Whether this rv process will authenticate to rvd')
    ..addFlag('rv-e2ee',
        defaultsTo: false,
        help: 'Whether this rv process will encrypt/decrypt'
            ' all rvd socket traffic');
  final parsed = parser.parse(args);

  final String host = parsed['host'];
  final int streamingPort = int.parse(parsed['port']);
  final int localPort = int.parse(parsed['local-port']);
  final bool bindLocalPort = parsed['bind-local-port'];
  final bool rvAuth = parsed['rv-auth'];
  final bool rvE2ee = parsed['rv-e2ee'];

  String? rvdAuthString = rvAuth ? Platform.environment['RV_AUTH'] : null;
  String? sessionAESKeyString = rvE2ee ? Platform.environment['RV_AES'] : null;
  String? sessionIVString = rvE2ee ? Platform.environment['RV_IV'] : null;

  SocketConnector connector = await Sshrv.dart(
    host,
    streamingPort,
    localPort: localPort,
    bindLocalPort: bindLocalPort,
    rvdAuthString: rvdAuthString,
    sessionAESKeyString: sessionAESKeyString,
    sessionIVString: sessionIVString,
  ).run();

  /// Shut myself down once the socket connector closes
  stderr.writeln('Waiting for connector to close');
  await connector.done;

  stderr.writeln('Closed - exiting');
  exit(0);
}
